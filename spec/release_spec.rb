require "spec_helper"
require_relative "../lib/release"

RSpec.describe Release do
  let(:git_client) { double(:git_client) }

  subject(:release) { build(:release, git_client: git_client) }

  describe "#data_for_influx" do
    it "returns an array of pull request data formatted for influx" do
      pr1 = build(:pull_request, number: 1, release: release)
      pr2 = build(:pull_request, number: 3, release: release)

      allow_any_instance_of(ReleaseAnalyser).to receive(:get_pull_requests).and_return([pr1, pr2])

      result = [{
        name: "deployment",
        tags: {
          project: release.project,
          env: release.env,
          pr: "1",
          deploy_sha: release.head_sha
        },
        fields: {
          seconds_since_first_commit: release.deploy_time.to_i - pr1.started_time.to_i,
          seconds_since_pr_opened: release.deploy_time.to_i - pr1.opened_time.to_i,
          seconds_since_pr_merged: release.deploy_time.to_i - pr1.merged_time.to_i,
          number_of_commits_in_pr: pr1.number_of_commits,
          total_line_changes_in_pr: pr1.total_line_changes,
          average_changes_per_commit_in_pr: (pr1.total_line_changes / pr1.number_of_commits),
          number_of_reviews_on_pr: pr1.number_of_reviews,
          number_of_comments_on_pr: pr1.number_of_comments
        },
        time: release.deploy_time.to_i
      },
        {
          name: "deployment",
          tags: {
            project: release.project,
            env: release.env,
            pr: "3",
            deploy_sha: release.head_sha
          },
          fields: {
            seconds_since_first_commit: release.deploy_time.to_i - pr2.started_time.to_i,
            seconds_since_pr_opened: release.deploy_time.to_i - pr2.opened_time.to_i,
            seconds_since_pr_merged: release.deploy_time.to_i - pr2.merged_time.to_i,
            number_of_commits_in_pr: pr2.number_of_commits,
            total_line_changes_in_pr: pr2.total_line_changes,
            average_changes_per_commit_in_pr: (pr2.total_line_changes / pr2.number_of_commits),
            number_of_reviews_on_pr: pr2.number_of_reviews,
            number_of_comments_on_pr: pr2.number_of_comments
          },
          time: release.deploy_time.to_i
        }]

      expect(release.data_for_influx).to eq(result)
    end
  end
end
