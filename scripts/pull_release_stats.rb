require 'octokit'
require 'optparse'
require 'optparse/time'
require 'date'
require './scripts/commit-measure.rb'

options = {}
OptionParser.new do |opts|
  opts.on("-r", "--repository URL") do |arg|
    options[:repository] = arg
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
