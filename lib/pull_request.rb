class PullRequest
  attr_accessor :number, :started_time, :opened_time, :merged_time,
    :number_of_commits, :total_line_changes, :number_of_reviews, :number_of_comments
  attr_reader :release

  def initialize(number, release:)
    @number = number
    @release = release
  end

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
end
