require "octokit"
require "./lib/release_analyser"
require "./lib/influx_client"
require "pp"

require "dotenv"
Dotenv.load

@git_client = Octokit::Client.new(access_token: ENV["GITHUB_ACCESS_TOKEN"])
@influx_client = influx_client
write_api = @influx_client.create_write_api

# This script uses the GitHub Actions workflows for the deploy workflow to analyse historical releases
# It relies on the project doing releases via GH Actions
# It assumes the deploy workflow is named "deploy.yml", but this can be configured if needed
# It uses the same release analyser as the script that analyses single releases

MONITORED_SITES = [
  {
    project: "roda",
    env: "production",
    endpoint: "https://www.report-official-development-assistance.service.gov.uk/health_check",
    repository: "UKGovernmentBEIS/beis-report-official-development-assistance",
    branch_name: "main"
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

MONITORED_SITES.each do |site|
  repo = site[:repository]
  branch = site[:branch_name]

  successful_deploys = @git_client.workflow_runs(repo, "deploy.yml", branch: branch, status: "success").workflow_runs

  puts "*** PROJECT #{site[:project]}, ENV #{site[:env]} ***"
  puts "Found #{successful_deploys.size} successful deploy runs on branch #{branch}"

  successful_deploys.each_with_index do |deploy_run, i|
    deploy_sha = deploy_run.head_sha
    deploy_started_time = deploy_run.created_at
    deploy_finished_time = deploy_run.updated_at

    puts "Deploy #{i}: #{deploy_sha} : #{deploy_started_time} - #{deploy_finished_time}"

    previous_release_sha = successful_deploys[i + 1]&.head_sha
    # we cannot analyse the release if we don't know where to delimit it
    next if previous_release_sha.nil?

    release = Release.new(
      starting_sha: previous_release_sha,
      head_sha: deploy_sha,
      deploy_time: deploy_finished_time,
      repo: repo,
      project: site[:project],
      env: site[:env],
      git_client: @git_client
    )
    release_data = release.data_for_influx
    release_data_debug = release.data_for_debugging

    pp release_data_debug

    send_data_to_influx(write_api, release_data)
  end
end

@influx_client.close!
