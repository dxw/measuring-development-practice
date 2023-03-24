require "net/http"
require "octokit"
require "pp"

require "dotenv"
Dotenv.load
STDOUT.sync = true

def topics(repo_name)
  topics = @git_client.topics(repo_name, {accept: Octokit::Preview::PREVIEW_TYPES[:topics]})
  return [] if topics.nil? || topics == {}

  topics[:names]
end

def all_repos
  page = 1
  repos = []

  # repos = @git_client.organization_repositories("dxw", per_page: 100, page: page).reject(&:archived?)

  while true
    puts "Fetching page #{page}..."
    page_repos = @git_client.organization_repositories("dxw", per_page: 100, page: page)
    break if page_repos.empty?

    repos += page_repos.reject(&:archived?)
    page +=1
  end
  repos
end

@git_client = Octokit::Client.new(access_token: ENV["GITHUB_ACCESS_TOKEN"])

repos_without_tech_team = []
private_repos_without_staff_team = []
repos_unknown_teams = []

all_repos.each do |repo|
  print "."

  begin
    teams = @git_client.teams(repo.full_name).map(&:slug)

    if !teams.include?("technology-team") && !topics(repo.full_name).include?("govpress")
      repos_without_tech_team << repo.full_name
    end

    if repo.private? && !teams.include?("staff") && !topics(repo.full_name).include?("govpress")
      private_repos_without_staff_team << repo.full_name
    end
  rescue Octokit::Forbidden
    repos_unknown_teams << repo.full_name
  end
end

unless repos_without_tech_team.empty?
  puts "The following repositories do not give access to the 'technology-team' team:"
  puts "\t#{repos_without_tech_team.join("\n\t")}"
  puts "Contact the repository owners or a dxw GitHub admin if you think the tech team should have access."
end

unless private_repos_without_staff_team.empty?
  puts "The following private repositories do not give access to the 'staff' team:"
  puts "\t#{private_repos_without_staff_team.join("\n\t")}"
  puts "Contact the repository owners or a dxw GitHub admin if you think the staff team should have access."
end

unless repos_unknown_teams.empty?
  puts "The script did not have permission to see who can access these repositories:"
  puts "\t#{repos_unknown_teams.join("\n\t")}"
  puts "Contact the repository owners or a dxw GitHub admin if you think the tech and/or staff teams should have access."
end
