FactoryBot.define do
  factory :release do
    repo { "dxw/test-repo" }
    project { "a project" }
    env { "test" }
    deploy_time { Time.now }
    head_sha { "a1b2c3" }
    starting_sha { "z9y8x7" }
    git_client { "" }

    initialize_with { new(repo: repo, project: project, env: env, deploy_time: deploy_time, head_sha: head_sha, starting_sha: starting_sha, git_client: git_client) }
  end
end
