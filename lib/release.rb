class Release
  attr_reader :repo, :env, :project, :head_sha, :starting_sha, :deploy_time

  def initialize(repo:, env:, project:, head_sha:, starting_sha:, deploy_time:)
    @repo = repo
    @env = env
    @project = project
    @head_sha = head_sha
    @starting_sha = starting_sha
    @deploy_time = deploy_time
  end
end
