require_relative "../lib/pull_request"

RSpec.describe PullRequest do
  let(:repo) { "dxw/test-repo" }
  let(:deploy_time) { Time.new(2022, 3, 1) }
  let(:release) { double(:release, repo: repo, project: "a project", env: "test", deploy_time: deploy_time, head_sha: "a1b2c3", starting_sha: "z9y8x7") }

  describe "#data_for_influx" do
    it "returns the transformed PR data" do
      pr = PullRequest.new(1, release: release)
      pr.started_time = Time.new(2021, 12, 0o2)
      pr.opened_time = Time.new(2021, 12, 31)
      pr.merged_time = Time.new(2022, 0o1, 0o1)
      pr.number_of_commits = 2
      pr.total_line_changes = 24
      pr.number_of_reviews = 1
      pr.number_of_comments = 2

      result = {
        name: "deployment",
        tags: {
          project: release.project,
          env: release.env,
          pr: "1",
          deploy_sha: release.head_sha
        },
        fields: {
          seconds_since_first_commit: release.deploy_time.to_i - pr.started_time.to_i,
          seconds_since_pr_opened: release.deploy_time.to_i - pr.opened_time.to_i,
          seconds_since_pr_merged: release.deploy_time.to_i - pr.merged_time.to_i,
          number_of_commits_in_pr: pr.number_of_commits,
          total_line_changes_in_pr: pr.total_line_changes,
          average_changes_per_commit_in_pr: (pr.total_line_changes / pr.number_of_commits),
          number_of_reviews_on_pr: pr.number_of_reviews,
          number_of_comments_on_pr: pr.number_of_comments
        },
        time: release.deploy_time.to_i
      }

      expect(pr.data_for_influx).to eq(result)
    end
  end
end
