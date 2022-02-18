require 'octokit'
require 'optparse'
require 'optparse/time'
require 'date'

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
#
class PullRequest

  attr_reader :commits

  def initialize(repo_path, commit_hashes)
    @commits = commit_hashes.map do |hash|
      Commit.new(repo_path, hash)
    end
  end

  def first_commit
    @commits.first
  end

  def last_commit
    @commits.last
  end

  def number_of_commits
    @commits.length
  end

  def total_changes
    commits.map(&:lines_changed).sum
  end

  def changes_per_commit
    return 0 if number_of_commits == 0

    total_changes / number_of_commits
  end

  def stats
    {
      total_changes: total_changes,
      changes_per_commit: changes_per_commit,
      number_of_commits: number_of_commits
    }
  end
end

class Commit

  attr_reader :files_changed, :insertions, :deletions

  def initialize(repo_path, commit_hash)
    stats = `cd #{repo_path} && git show --format="" --shortstat #{commit_hash}`

    @files_changed = /(\d)+ files changed/.match(stats)&.captures&.fetch(0).to_i || 0
    @insertions = /(\d)+ insertions/.match(stats)&.captures&.fetch(0).to_i || 0
    @deletions = /(\d)+ deletions/.match(stats)&.captures&.fetch(0).to_i || 0
  end

  def lines_changed
    insertions + deletions
  end

end

def clone(repo_name)
  repo_path = "tmp/repos/#{repo_name}"

  `rm -r -f tmp`

  `git clone "https://github.com/#{repo_name}" #{repo_path}`

  repo_path
end

options = {}
OptionParser.new do |opts|
  opts.on("-r", "--repository URL") do |arg|
    options[:repository] = arg
  end

  opts.on("-p", "--path PATH") do |arg|
    options[:path] = arg
  end

  opts.on("--start", "--start-date DATE", Time) do |arg|
    options[:start_date] = arg
  end

  opts.on("--end", "--end-date DATE", Time) do |arg|
    options[:end_date] = arg
  end

  opts.on("--state STATE") do |arg|
    options[:state] = arg || 'open'
  end

  opts.on("--drafts DRAFTS", FalseClass) do |arg|
    options[:drafts] = arg
  end

  opts.on("--bots BOTS", FalseClass) do |arg|
    options[:bots] = arg
  end
end.parse!

repository = options[:repository]

repo_path = if options[:path]
  options[:path]
else
  clone(repository)
end

client = Octokit::Client.new()

pull_requests = client.pull_requests(repository, state: options[:state])

# Reject drafts
pull_requests = pull_requests.reject(&:draft) unless options[:drafts]

# Limit to date range
pull_requests = pull_requests.select { |pr| options[:start_date] <= pr.created_at } if options[:start_date]
pull_requests = pull_requests.select { |pr| options[:end_date] >= pr.created_at } if options[:end_date]

output = {}

pull_requests.map(&:number).each do |prn|
  commits = client.pull_request_commits(repository, prn)

  commits = commits.select { |c| c.author.type == 'User' } unless options[:bots]

  commit_hashes = commits.map(&:sha)

  pr = PullRequest.new(repo_path, commit_hashes)

  output[prn] = pr.stats.values.join(",")
end

puts output.values.join("\n")
