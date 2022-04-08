require "net/http"
require "json"
require "dotenv"
require "octokit"
require "time"
require "pp"
require "./lib/release_analyser.rb"
require "./lib/influx_client.rb"

# This script gets the data from a health check endpoint (as specified in the site structure below)
# It uses the SHA of the latest release, and the built_at time, to plot one deployment
# It also uses the previous recorded SHA (if available in Influx) to analyse the release
# by comparing the two commits and extracting info about the commits and the PRs they belong to

monitored_sites = [
  {
    project: "roda",
    env: "production",
    endpoint: "https://www.report-official-development-assistance.service.gov.uk/health_check",
    repository: "UKGovernmentBEIS/beis-report-official-development-assistance",
    branch_name: "master"
  },
  {
    project: "roda",
    env: "staging",
    endpoint: "https://staging.report-official-development-assistance.service.gov.uk/health_check",
    repository: "UKGovernmentBEIS/beis-report-official-development-assistance",
    branch_name: "develop"
  },
  {
    project: "rpr",
    env: "production",
    endpoint: "https://www.regulated-professions.beis.gov.uk/health-check",
    repository: "UKGovernmentBEIS/regulated-professions-register",
    branch_name: "main"
  },
  {
    project: "rpr",
    env: "staging",
    endpoint: "https://#{ENV["RPR_STAGING_BASIC_AUTH_USERNAME"]}:#{ENV["RPR_STAGING_BASIC_AUTH_PASSWORD"]}@staging.regulated-professions.beis.gov.uk/health-check",
    repository: "UKGovernmentBEIS/regulated-professions-register",
    branch_name: "develop"
  }
]

def get_health_check(url)
  uri = URI(url)
  JSON.parse(Net::HTTP.get(uri))
end

def get_sha(response)
  response["git_sha"]
end

def get_deploy_time(response)
  Time.parse(response["built_at"])
end

def get_last_sha_from_influx(influx_bucket_name, project:, env:)
  query_api = @influx_client.create_query_api
  query = 'from(bucket:"' + influx_bucket_name + '") |> range(start: 1970-01-01T00:00:00.000000001Z) ' \
    '|> filter(fn: (r) => r["_measurement"] == "deployments") ' \
    '|> filter(fn: (r) => r["project"] == "' + project + '") ' \
    '|> filter(fn: (r) => r["env"] == "' + env + '") ' \
    '|> last()'
  result = query_api.query(query: query)
  return if result.nil? || result.empty?

  # this is horrible, but we only ever want the last record, as our `query`, this
  # gets us started
  result[0].records[0].values["_value"]
end

Dotenv.load

@influx_client = influx_client
write_api = @influx_client.create_write_api

@git_client = Octokit::Client.new(access_token: ENV["GITHUB_ACCESS_TOKEN"])

monitored_sites.each do |site|
  response = get_health_check(site[:endpoint])
  current_sha = get_sha(response)
  latest_deploy_time = get_deploy_time(response)

  last_recorded_sha = get_last_sha_from_influx(ENV["INFLUX_DEPLOYMENTS_BUCKET"], project: site[:project], env: site[:env])

  puts "#{Time.now.utc}\nCurrent SHA: #{current_sha}\nLast SHA: #{last_recorded_sha}\n"

  if current_sha == last_recorded_sha
    puts "#{site[:project]} #{site[:env]}: No new release"
  else
    puts "#{site[:project]} #{site[:env]}: Writing release analysis to influx"

    release = {
      starting_sha: last_recorded_sha,
      head_sha: current_sha,
      deploy_time: latest_deploy_time,
      repo: site[:repository],
      project: site[:project],
      env: site[:env]
    }

    release_analyser = ReleaseAnalyser.new(git_client: @git_client, release: release)

    deploy_data = release_analyser.deployment_data_for_influx
    pp deploy_data

    pr_data = release_analyser.pull_requests_data_for_influx
    pp pr_data

    send_data_to_influx(write_api, deploy_data, bucket: ENV["INFLUX_DEPLOYMENTS_BUCKET"])
    send_data_to_influx(write_api, pr_data, bucket: ENV["INFLUX_PULL_REQUESTS_BUCKET"])
  end
end

@influx_client.close!
