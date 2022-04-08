require "octokit"
require "dotenv"
require "./lib/release_analyser.rb"
require "./lib/influx_client.rb"
require "pp"

Dotenv.load
@git_client = Octokit::Client.new(access_token: ENV["GITHUB_ACCESS_TOKEN"])
@influx_client = influx_client
write_api = @influx_client.create_write_api

# This script uses the GitHub Actions workflows for the deploy workflow to analyse historical releases
# It relies on the project doing releases via GH Actions
# It assumes the deploy workflow is named "deploy.yml", but this can be configured if needed
# It uses the same release analyser as the script that analyses single releases

# Currently only analysing one site at a time, could be extended by using the other sites from
# "analyse_latest_release.rb"

monitored_sites = [
  {
    project: "rpr",
    env: "production",
    endpoint: "https://www.regulated-professions.beis.gov.uk/health-check",
    repository: "UKGovernmentBEIS/regulated-professions-register",
    branch_name: "main"
  }
]

# This data is meant to be used by clever manipulation in Flux
# A sample query might look something like this:
# from(bucket: "production-lead-time-test")
#   |> range(start: 1970-01-01)
#   |> filter(fn: (r) => r["env"] == "production")
#   |> filter(fn: (r) => r["project"] == "rpr")
#   |> group(columns: ["pr", "deploy_sha"], mode:"by")
# but any actually useful graphs are left as an exercise to the consumer of this data

monitored_sites.each do |site|
  repo = site[:repository]
  branch = site[:branch_name]

  successful_deploys = @git_client.workflow_runs(repo, "deploy.yml", branch: branch, status: "success").workflow_runs

  puts "*** PROJECT #{site[:project]}, ENV #{site[:env]} ***"
  puts "Found #{successful_deploys.size} successful deploy runs on branch #{branch}"

  successful_deploys.each_with_index do |deploy_run, i|
    deploy_sha = deploy_run.head_sha
    deploy_started_time = deploy_run.created_at
    deploy_finished_time = deploy_run.updated_at # check if true

    puts "Deploy #{i}: #{deploy_sha} : #{deploy_started_time} - #{deploy_finished_time}"

    deploy_data = deployment_data_for_influx(deploy_sha, deploy_finished_time, project: site[:project], env: site[:env])
    puts deploy_data
    send_data_to_influx(write_api, deploy_data)

    previous_deploy_run = successful_deploys[i + 1]
    # we cannot analyse the release if we don't know where to delimit it
    next if previous_deploy_run.nil?

    previous_release_sha = previous_deploy_run.head_sha
    release = {
      starting_sha: previous_release_sha,
      head_sha: deploy_sha,
      deploy_time: deploy_finished_time,
      repo: repo,
      project: site[:project],
      env: site[:env]
    }
    pr_data = ReleaseAnalyser.new(git_client: @git_client, release: release).analyse_release
    pp pr_data
    send_data_to_influx(write_api, pr_data)
  end
end

@influx_client.close!
