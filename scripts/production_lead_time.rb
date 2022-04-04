require "influxdb-client"
require "net/http"
require "json"
require "dotenv"

monitored_sites = [
  {
    project: "roda",
    env: "production",
    endpoint: "https://www.report-official-development-assistance.service.gov.uk/health_check"
  },
  {
    project: "roda",
    env: "staging",
    endpoint: "https://staging.report-official-development-assistance.service.gov.uk/health_check"
  }
]

def influx_client(influx_url, influx_organisation_name, influx_bucket_name, influx_api_token)
  InfluxDB2::Client.new(influx_url, influx_api_token,
    bucket: influx_bucket_name,
    org: influx_organisation_name,
    precision: InfluxDB2::WritePrecision::SECOND)
end

def get_health_check(url)
  uri = URI(url)
  JSON.parse(Net::HTTP.get(uri))
end

def get_sha(response)
  response["git_sha"]
end

def get_deploy_time(response)
  response["built_at"]
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

def send_deployment_data_to_influx(sha, deploy_time, project:, env:)
  write_api = @influx_client.create_write_api

  data = {
    name: "deployments",
    tags: {
      project: project,
      env: env
    },
    fields: {sha: sha},
    time: Time.parse(deploy_time).to_i
  }

  write_api.write(data: data)
end

Dotenv.load

influx_api_token = ENV["INFLUX_API_TOKEN"]
influx_url = ENV["INFLUX_URL"]
influx_bucket_name = ENV["INFLUX_BUCKET_NAME"]
influx_organisation_name = ENV["INFLUX_ORGANISATION_NAME"]

@influx_client = influx_client(influx_url, influx_organisation_name, influx_bucket_name, influx_api_token)

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
    send_deployment_data_to_influx(current_sha, latest_deploy_time, project: site[:project], env: site[:env])
  end
end

@influx_client.close!
