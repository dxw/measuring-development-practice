require_relative "../lib/release_analyser"
require_relative "../lib/pull_request"

RSpec.describe ReleaseAnalyser do
  let(:git_client) {
    double(:git_client,
      compare: compare_response,
      pull_request_reviews: pull_request_reviews,
      pull_request_comments: pull_request_comments,
      commit: commit_with_stats)
  }
  let(:pull_request_reviews) { double(:pull_request_reviews, size: 1) }
  let(:pull_request_comments) { double(:pull_request_comments, size: 2) }
  let(:commit_with_stats) { double(:commit_with_stats, stats: double(total: 12)) }

  let(:repo) { "dxw/test-repo" }
  let(:deploy_time) { Time.new(2022, 3, 1) }
  let(:release) { double(:release, repo: repo, project: "a project", env: "test", deploy_time: deploy_time, head_sha: "a1b2c3", starting_sha: "z9y8x7") }

  let(:compare_response) { double(:compare_response, commits: [commit_1, commit_2, commit_3, commit_4]) }

  let(:pull_request_1) { double(:pull_request, number: 1, created_at: "2021-12-31", merged_at: "2022-01-01") }
  let(:commit_1) { double(:commit, sha: "abc123", commit: double(author: double(date: "2021-12-10"))) }
  let(:commit_2) { double(:commit, sha: "def456", commit: double(author: double(date: "2021-12-02"))) }

  let(:pull_request_2) { double(:pull_request, number: 2, created_at: "2022-02-01", merged_at: "2022-02-02") }
  let(:commit_3) { double(:commit, sha: "ghi123", commit: double(author: double(date: "2021-12-03"))) }
  let(:commit_4) { double(:commit, sha: "jkl456", commit: double(author: double(date: "2022-01-12"))) }

  subject(:release_analyser) {
    ReleaseAnalyser.new(git_client: git_client, release: release)
  }

  describe "#get_pull_requests" do
    before do
      allow(git_client).to receive(:commit_pulls).with(repo, commit_1.sha).and_return([pull_request_1])
      allow(git_client).to receive(:commit_pulls).with(repo, commit_2.sha).and_return([pull_request_1])
      allow(git_client).to receive(:commit_pulls).with(repo, commit_3.sha).and_return([pull_request_2])
      allow(git_client).to receive(:commit_pulls).with(repo, commit_4.sha).and_return([pull_request_2])
    end

    it "fetches pull requests for the specified release" do
      pulls = release_analyser.get_pull_requests

      expect(pulls[0].number).to eq(1)
      expect(pulls[0].started_time).to eq("2021-12-02")

      expect(pulls[1].number).to eq(2)
      expect(pulls[1].started_time).to eq("2021-12-03")
    end
  end

  describe "#pr_data_for_influx" do
    it "returns the transformed PR data" do
      pr = PullRequest.new(1)
      pr.started_time = "2021-12-02"
      pr.opened_time = "2021-12-31"
      pr.merged_time = "2022-01-01"
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

      expect(release_analyser.pr_data_for_influx(pr)).to eq(result)
    end
  end
end
