require "octokit"
require "dotenv"
require "./lib/release_analyser.rb"

Dotenv.load
@git_client = Octokit::Client.new(access_token: ENV["GITHUB_ACCESS_TOKEN"])

release = {
  repo: "UKGovernmentBEIS/beis-report-official-development-assistance",
  env: "production",
  project: "roda"
}

release[:ending_sha] = "87f71354467dda7435cbbb2a26169a6e9860cfc0"
release[:starting_sha] = "ddf9f3bd7ab7945f958a17951576f776c9e9ccaa"
release[:deploy_time] = Date.new(2022,3,29).to_time

pr_data = analyse_work_between(git_client: @git_client, release: release)

puts pr_data
