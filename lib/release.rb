require_relative "./release_analyser"

class Release
  attr_reader :repo, :env, :project, :head_sha, :starting_sha, :deploy_time

  def initialize(repo:, env:, project:, head_sha:, starting_sha:, deploy_time:, git_client: Octokit::Client.new(access_token: ENV["GITHUB_ACCESS_TOKEN"]))
    @repo = repo
    @env = env
    @project = project
    @head_sha = head_sha
    @starting_sha = starting_sha
    @deploy_time = deploy_time
    @git_client = git_client
  end

  def data_for_influx
    pull_requests.map(&:data_for_influx)
  end

  private

  def pull_requests
    @pull_requests ||= ReleaseAnalyser.new(release: self, git_client: @git_client).get_pull_requests
  end
end
