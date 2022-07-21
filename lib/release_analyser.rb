require_relative "./pull_request"

class ReleaseAnalyser
  attr_accessor :git_client, :release

  def initialize(release:, git_client:)
    self.release = release
    self.git_client = git_client
  end

  # A release is delimited by the head_sha (the commit at the HEAD of the branch at the time of deploy),
  # and the "starting" SHA, which is the previous release's HEAD commit
  # We need at least these two delimiting commits in order to analyse a release
  #
  # Analysing the release means identifying which pull requests contributed to it,
  # and then collecting all the data we want to store in InfluxDB for each PR
  def get_pull_requests
    repo = release.repo
    commits_between = git_client.compare(repo, release.starting_sha, release.head_sha).commits

    pull_requests = []

    commits_between.each do |commit|
      # The merged PR that this commit is part of (it could also be part of closed-but-unmerged PRs)
      pull_request = git_client.commit_pulls(repo, commit.sha).find { |pr| pr.merged_at }

      # Skip merge commits (they are not the result of PRs so pull_request will be nil)
      next if pull_request.nil?

      pr_number = pull_request.number
      if (pr = pull_requests.find { |pr| pr.number == pr_number }).nil?
        pr = PullRequest.new(pr_number, release: release)

        pr.started_time = authored_date(commit)
        pr.opened_time = pull_request.created_at
        pr.merged_time = pull_request.merged_at
        pr.number_of_commits = 1
        pr.total_line_changes = total_line_changes(commit)
        pr.number_of_reviews = git_client.pull_request_reviews(repo, pr_number).size
        pr.number_of_comments = git_client.pull_request_comments(repo, pr_number).size

        pull_requests << pr
      else
        # Check if this commit was authored before the provisional started_time and keep the earlier of the two dates
        pr.started_time = [pr.started_time, authored_date(commit)].min
        pr.number_of_commits += 1
        pr.total_line_changes += total_line_changes(commit)
      end
    end

    pull_requests
  end

  private

  def authored_date(commit)
    commit.commit.author.date
  end

  def total_line_changes(commit)
    git_client.commit(release.repo, commit.sha).stats.total
  end
end
