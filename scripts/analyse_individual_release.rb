require "octokit"
require "pp"
require "./lib/release"
require "./lib/influx_client"

require "dotenv"
Dotenv.load

# This script is mostly useful for debug; uncomment the last section to write the data
release = Release.new(
  repo: "UKGovernmentBEIS/beis-report-official-development-assistance",
  env: "production",
  project: "roda",
  head_sha: "87f71354467dda7435cbbb2a26169a6e9860cfc0",
  starting_sha: "ddf9f3bd7ab7945f958a17951576f776c9e9ccaa",
  deploy_time: Time.utc(2022, 3, 29, 17, 0, 5)
)

release_data_debug = release.data_for_debugging

pp release_data_debug

# release_data = release.data_for_influx
# @influx_client = influx_client
# write_api = @influx_client.create_write_api
# send_data_to_influx(write_api, release_data)
# @influx_client.close!
