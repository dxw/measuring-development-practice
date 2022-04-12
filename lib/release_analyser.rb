# This mini-library contains methods to prepare the data for inserting into InfluxDB
#   where it can be visualised via Flux queries and visualisations
#
class ReleaseAnalyser
  attr_accessor :git_client, :release

  def initialize(git_client:, release:)
    self.git_client = git_client
    self.release = release
  end

  ### GENERIC FIELDS
  #
  # The timestamp, _time, is what Influx will interpret as the time the "measured event" happened,
  #   and it must be a Unix timestamp
  # The range is mandatory for all, or almost all, Flux queries, and it refers to the time window
  #   for which to process measurement data
  #   _start and _stop are special Influx fields that map to the start and end of this time window
  # The special _measurement field corresponds to the "name", and it is how we can filter
  #   for the entire stream of these specific "measurements"
  # Tags will allow us to filter and group projects, environments, and individual deploys
  #
  ### PULL REQUEST TAGS AND FIELDS
  #
  # Pull request data is meant to serve our goals of measuring how long it takes our work
  #   to go from start to being available to users on production, and identifying where there are any
  #   slow points in the development pipeline
  #
  # Time-related measurements
  #   * the oldest commit in the PR is a proxy for when work on a specific story started
  #   * when PRs are opened / merged, to measure whether there are any bottlenecks in our review processes
  #   * the time when the work was deployed
  #
  # Code-related measurements
  #   * total number of commits in a PR
  #   * total line changes in a PR
  #   * average number of line changes per commit in a PR
  #   * number of reviews on a PR
  #   * number of comments on a PR
  def pr_data_for_influx(pr_number, pr_data)
    {
      name: "deployment",
      tags: {
        project: release[:project],
        env: release[:env],
        pr: pr_number,
        deploy_sha: release[:head_sha]
      },
      fields: {
        seconds_since_first_commit: release[:deploy_time].to_i - pr_data[:started_time].to_i,
        seconds_since_pr_opened: release[:deploy_time].to_i - pr_data[:opened_time].to_i,
        seconds_since_pr_merged: release[:deploy_time].to_i - pr_data[:merged_time].to_i,
        number_of_commits_in_pr: pr_data[:number_of_commits],
        total_line_changes_in_pr: pr_data[:total_changes],
        average_changes_per_commit_in_pr: (pr_data[:total_changes] / pr_data[:number_of_commits]),
        number_of_reviews_on_pr: pr_data[:number_of_reviews],
        number_of_comments_on_pr: pr_data[:number_of_comments]
      },
      time: release[:deploy_time].to_i
    }
  end

  # A release is delimited by the head_sha (the commit at the HEAD of the branch at the time of deploy),
  # and the "starting" SHA, which is the previous release's HEAD commit
  # We need at least these two delimiting commits in order to analyse a release
  #
  # Analysing the release means identifying which pull requests contributed to it,
  # and then collecting all the data we want to store in InfluxDB for each PR
  def pull_requests_data_for_influx
    repo = release[:repo]
    commits_between = git_client.compare(repo, release[:starting_sha], release[:head_sha]).commits

    pull_requests = {}

    commits_between.each do |commit|
      # The merged PR that this commit is part of (it could also be part of closed-but-unmerged PRs)
      pull_request = git_client.commit_pulls(repo, commit.sha).find { |pr| pr.merged_at }

      # merge commits are not the result of PRs so we skip them
      next if pull_request.nil?

      pr_number = pull_request.number.to_s
      if pull_requests[pr_number].nil?
        pull_requests[pr_number] = {
          commits: [commit],
          opened_time: pull_request.created_at,
          merged_time: pull_request.merged_at,
          number_of_reviews: git_client.pull_request_reviews(repo, pull_request.number).size,
          number_of_comments: git_client.pull_request_comments(repo, pull_request.number).size
        }
      else
        pull_requests[pr_number][:commits] << commit
      end
    end

    pull_requests.each do |pr_number, pr_data|
      # the oldest authored time of all commits in the PR (rebasing could have rearranged them non-chronologically)
      pull_requests[pr_number][:started_time] = pr_data[:commits].map { |c| c.commit.author.date }.min
      pull_requests[pr_number][:number_of_commits] = pr_data[:commits].size
      total_changes = pr_data[:commits].map do |commit|
        git_client.commit(repo, commit.sha).stats.total
      end.sum
      pull_requests[pr_number][:total_changes] = total_changes
    end

    pull_requests.map do |pr_number, pr_data|
      pr_data_for_influx(pr_number, pr_data)
    end
  end
end
