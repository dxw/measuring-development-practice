require "octokit"
require "./lib/release_analyser"
require "./lib/influx_client"

require "dotenv"
Dotenv.load

@git_client = Octokit::Client.new(access_token: ENV["GITHUB_ACCESS_TOKEN"])

# This script is mostly useful for debug; uncomment the last section to write the data
release = Release.new(
  repo: "UKGovernmentBEIS/beis-report-official-development-assistance",
  env: "production",
  project: "roda",
  head_sha: "87f71354467dda7435cbbb2a26169a6e9860cfc0",
  starting_sha: "ddf9f3bd7ab7945f958a17951576f776c9e9ccaa",
  deploy_time: Time.new(2022, 3, 29, 15, 0, 5)
)

release_analyser = ReleaseAnalyser.new(git_client: @git_client, release: release)
pr_data = release_analyser.pull_requests_data_for_influx
puts pr_data

# @influx_client = influx_client
# write_api = @influx_client.create_write_api
# send_data_to_influx(write_api, pr_data)
# @influx_client.close!
