def pull_request_data_for_influx(pr_number:, release:, started_time:, merged_time:)
   {
    name: "pull_requests",
    tags: {
      project: release[:project],
      env: release[:env]
    },
    fields: {
      pr: pr_number,
      work_started_at: started_time,
      work_merged_at: merged_time,
      work_deployed_at: release[:deploy_time],
      time_to_merge: (merged_time.to_i - started_time.to_i),
      time_to_deploy: (release[:deploy_time].to_i - started_time.to_i), # nanoseconds
      deploy_sha: release[:ending_sha]
    },
    time: started_time.to_i
  }
end

def analyse_work_between(git_client:, release:)
  repo = release[:repo]
  commits_between = git_client.compare(repo, release[:starting_sha], release[:ending_sha]).commits

  pull_requests = {}

  commits_between.each do |commit|
    # PR that this individual commit is part of
    # ASSUMPTION: the last will be the merged one in case of a commit having been in multiple PRs
    pull_request = git_client.commit_pulls(repo, commit.sha).last
    # merge commits are not the result of PRs
    next if pull_request.nil?

    pr_number = pull_request.number.to_s
    if pull_requests[pr_number].nil?
      pull_requests[pr_number] = { commits: [commit], merged_time: pull_request.merged_at }
    else
      pull_requests[pr_number][:commits] << commit
    end
  end

  pull_requests.each do |pr_number, pr_data|
    # the oldest authored time of all commits in the PR (rebasing could have rearranged them non-chronologically)
    pull_requests[pr_number][:started_time] = pr_data[:commits].map { |c| c.commit.author.date }.min
  end

  pull_requests.map do |pr_number, pr_data|
    pull_request_data_for_influx(
      pr_number: pr_number,
      started_time: pr_data[:started_time],
      merged_time: pr_data[:merged_time],
      release: release
    )
  end
end
