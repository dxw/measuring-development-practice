require_relative "../lib/release_analyser"

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
  let(:release) { {repo: repo} }

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
      result = {
        "1" => {
          started_time: "2021-12-02",
          opened_time: "2021-12-31",
          merged_time: "2022-01-01",
          number_of_commits: 2,
          total_changes: 24,
          number_of_reviews: 1,
          number_of_comments: 2
        },
        "2" => {
          started_time: "2021-12-03",
          opened_time: "2022-02-01",
          merged_time: "2022-02-02",
          number_of_commits: 2,
          total_changes: 24,
          number_of_reviews: 1,
          number_of_comments: 2
        }
      }

      expect(release_analyser.get_pull_requests).to eql(result)
    end
  end
end
