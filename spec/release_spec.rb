require_relative "../lib/release"

RSpec.describe Release do
  let(:repo) { "dxw/test-repo" }
  let(:deploy_time) { Time.new(2022, 3, 1) }
  let(:git_client) { double(:git_client) }

  subject(:release) { Release.new(repo: repo, project: "a project", env: "test", deploy_time: deploy_time, head_sha: "a1b2c3", starting_sha: "z9y8x7", git_client: git_client) }

  describe "#data_for_influx" do
    it "returns an array of pull request data formatted for influx" do
      pr = PullRequest.new(1, release: release)
      pr.started_time = Time.new(2021, 12, 0o2)
      pr.opened_time = Time.new(2021, 12, 31)
      pr.merged_time = Time.new(2022, 0o1, 0o1)
      pr.number_of_commits = 2
      pr.total_line_changes = 24
      pr.number_of_reviews = 1
      pr.number_of_comments = 2

      allow_any_instance_of(ReleaseAnalyser).to receive(:get_pull_requests).and_return([pr])

      result = [{
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
      }]

      expect(release.data_for_influx).to eq(result)
    end
  end
end
