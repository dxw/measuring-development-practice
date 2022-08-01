require "spec_helper"
require_relative "../lib/pull_request"
require_relative "../lib/release"

RSpec.describe PullRequest do
  let(:git_client) { double(:git_client) }
  let(:release) { build(:release, git_client: git_client) }

  subject(:pull_request) { build(:pull_request, number: 1, release: release) }

  describe "#data_for_influx" do
    it "returns the transformed PR data" do
      result = {
        name: "deployment",
        tags: {
          project: release.project,
          env: release.env,
          pr: "1",
          deploy_sha: release.head_sha
        },
        fields: {
          seconds_since_first_commit: release.deploy_time.to_i - pull_request.started_time.to_i,
          seconds_since_pr_opened: release.deploy_time.to_i - pull_request.opened_time.to_i,
          seconds_since_pr_merged: release.deploy_time.to_i - pull_request.merged_time.to_i,
          number_of_commits_in_pr: pull_request.number_of_commits,
          total_line_changes_in_pr: pull_request.total_line_changes,
          average_changes_per_commit_in_pr: (pull_request.total_line_changes / pull_request.number_of_commits),
          number_of_reviews_on_pr: pull_request.number_of_reviews,
          number_of_comments_on_pr: pull_request.number_of_comments
        },
        time: release.deploy_time.to_i
      }

      expect(pull_request.data_for_influx).to eq(result)
    end
  end
end
