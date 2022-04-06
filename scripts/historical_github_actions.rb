require "octokit"
require "dotenv"
require "./lib/release_analyser.rb"
require "./lib/influx_client.rb"

Dotenv.load
@git_client = Octokit::Client.new(access_token: ENV["GITHUB_ACCESS_TOKEN"])

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
  successful_deploys.each do |deploy_run|
    deploy_sha = deploy_run.head_sha
    deploy_started_time = deploy_run.created_at
    deploy_finished_time = deploy_run.updated_at # check if true

    # deploy_data = deployment_data_for_influx(current_sha, latest_deploy_time, project: site[:project], env: site[:env])
    # puts deploy_data
    # send_data_to_influx(write_api, deploy_data)
  end
end
