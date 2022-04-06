require "net/http"
require "json"
require "dotenv"
require "octokit"
require "time"
require "./lib/release_analyser.rb"
require "./lib/influx_client.rb"

monitored_sites = [
  {
    project: "roda",
    env: "production",
    endpoint: "https://www.report-official-development-assistance.service.gov.uk/health_check",
    repository: "UKGovernmentBEIS/beis-report-official-development-assistance"
  },
  {
    project: "roda",
    env: "staging",
    endpoint: "https://staging.report-official-development-assistance.service.gov.uk/health_check",
    repository: "UKGovernmentBEIS/beis-report-official-development-assistance"
  },
  {
    project: "rpr",
    env: "production",
    endpoint: "https://www.regulated-professions.beis.gov.uk/health-check",
    repository: "UKGovernmentBEIS/regulated-professions-register"
  },
  {
    project: "rpr",
    env: "staging",
    endpoint: "https://#{ENV["RPR_STAGING_BASIC_AUTH_USERNAME"]}:#{ENV["RPR_STAGING_BASIC_AUTH_PASSWORD"]}@staging.regulated-professions.beis.gov.uk/health-check",
    repository: "UKGovernmentBEIS/regulated-professions-register"
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

def deployment_data_for_influx(sha, deploy_time, project:, env:)
  {
    name: "deployments",
    tags: {
      project: project,
      env: env
    },
    fields: {sha: sha},
    time: deploy_time.to_i
  }
end

Dotenv.load

influx_bucket_name = ENV["INFLUX_BUCKET_NAME"]

@influx_client = influx_client
write_api = @influx_client.create_write_api

@git_client = Octokit::Client.new(access_token: ENV["GITHUB_ACCESS_TOKEN"])

monitored_sites.each do |site|
  response = get_health_check(site[:endpoint])
  current_sha = get_sha(response)
  latest_deploy_time = get_deploy_time(response)

  last_recorded_sha = get_last_sha_from_influx(influx_bucket_name, project: site[:project], env: site[:env])

  puts "#{Time.now.utc}\nCurrent SHA: #{current_sha}\nLast SHA: #{last_recorded_sha}\n"

  if current_sha == last_recorded_sha
    puts "#{site[:project]} #{site[:env]}: No new release"
  else
    puts "#{site[:project]} #{site[:env]}: Writing sha to influx"

    deploy_data = deployment_data_for_influx(current_sha, latest_deploy_time, project: site[:project], env: site[:env])
    puts deploy_data
    send_data_to_influx(write_api, deploy_data)

    repo = site[:repository]

    release = {
      starting_sha: last_recorded_sha,
      ending_sha: current_sha,
      deploy_time: latest_deploy_time,
      repo: repo,
      project: site[:project],
      env: site[:env]
    }

    pr_data = analyse_release(git_client: @git_client, release: release)
    puts pr_data
    send_data_to_influx(write_api, pr_data)
  end
end

@influx_client.close!
