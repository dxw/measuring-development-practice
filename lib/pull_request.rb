class PullRequest
  attr_accessor :number, :started_time, :opened_time, :merged_time,
    :number_of_commits, :total_line_changes, :number_of_reviews, :number_of_comments
  attr_reader :release

  def initialize(number, release:)
    @number = number
    @release = release
  end

  def ==(other)
    number == other.number &&
      started_time == other.started_time &&
      opened_time == other.opened_time &&
      merged_time == other.merged_time &&
      number_of_commits == other.number_of_commits &&
      total_line_changes == other.total_line_changes &&
      number_of_reviews == other.number_of_reviews &&
      number_of_comments == other.number_of_comments
  end
  alias_method :eql?, :==

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
  def data_for_influx
    {
      name: "deployment",
      tags: {
        project: release.project,
        env: release.env,
        pr: number.to_s,
        deploy_sha: release.head_sha
      },
      fields: {
        seconds_since_first_commit: release.deploy_time.to_i - started_time.to_i,
        seconds_since_pr_opened: release.deploy_time.to_i - opened_time.to_i,
        seconds_since_pr_merged: release.deploy_time.to_i - merged_time.to_i,
        number_of_commits_in_pr: number_of_commits,
        total_line_changes_in_pr: total_line_changes,
        average_changes_per_commit_in_pr: (total_line_changes / number_of_commits),
        number_of_reviews_on_pr: number_of_reviews,
        number_of_comments_on_pr: number_of_comments
      },
      time: release.deploy_time.to_i
    }
  end

  def data_for_debugging
    {
      name: "deployment",
      tags: {
        project: release.project,
        env: release.env,
        pr: number.to_s,
        deploy_sha: release.head_sha
      },
      fields: {
        deploy_time: release.deploy_time,
        seconds_since_first_commit: release.deploy_time.to_i - started_time.to_i,
        started_time: started_time,
        seconds_since_pr_opened: release.deploy_time.to_i - opened_time.to_i,
        opened_time: opened_time,
        seconds_since_pr_merged: release.deploy_time.to_i - merged_time.to_i,
        merged_time: merged_time,
        number_of_commits_in_pr: number_of_commits,
        total_line_changes_in_pr: total_line_changes,
        average_changes_per_commit_in_pr: (total_line_changes / number_of_commits),
        number_of_reviews_on_pr: number_of_reviews,
        number_of_comments_on_pr: number_of_comments
      },
      time: release.deploy_time.to_i
    }
  end
end
