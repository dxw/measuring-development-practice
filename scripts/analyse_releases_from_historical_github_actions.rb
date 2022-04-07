require "octokit"
require "dotenv"
require "./lib/release_analyser.rb"
require "./lib/influx_client.rb"

Dotenv.load
@git_client = Octokit::Client.new(access_token: ENV["GITHUB_ACCESS_TOKEN"])
@influx_client = influx_client
write_api = @influx_client.create_write_api

monitored_sites = [
  {
    project: "roda",
    env: "production",
    endpoint: "https://www.report-official-development-assistance.service.gov.uk/health_check",
    repository: "UKGovernmentBEIS/beis-report-official-development-assistance",
    branch_name: "master"
  }
]

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
      ending_sha: deploy_sha,
      deploy_time: deploy_finished_time,
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
