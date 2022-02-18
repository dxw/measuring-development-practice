# To measure:
# - code changes count
#   - lines added
#   - lines removed
#   - files modified
# - length of commit message
# - file changes count
#   - created
#   - deleted
#   - renamed
# - number of merge commits
class PullRequest

  attr_reader :commits

  def initialize(repo_path, commit_hashes)
    @commits = commit_hashes.map do |hash|
      Commit.new(repo_path, hash)
    end
  end

  def total_changes
    commits.map(&:lines_changed).reduce(0, &:+)
  end

  def changes_per_commit
    return 0 if number_of_commits == 0

    total_changes / number_of_commits
  end

  def number_of_commits
    commits.length
  end

  def stats
    {
      total_changes: total_changes,
      changes_per_commit: changes_per_commit,
      number_of_commits: number_of_commits
    }
  end
end
