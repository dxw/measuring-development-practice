require 'influxdb-client'
require 'dotenv/load'
require "optparse"

# You can generate a Token from the "Tokens Tab" in the UI
token = ENV['INFLUX_API_TOKEN']
org = ENV['INFLUX_ORG']
bucket = ENV['INFLUX_BUCKET']

options = {}

parser = OptionParser.new { |opts|
  opts.banner = "Send deployment information to influxdb"

  opts.on("--started_at timestamp", "start time as epoch") do |o|
    options[:started_at] = o
  end

  opts.on("--finished_at timestamp", "start time as epoch") do |o|
    options[:finished_at] = o
  end

  opts.on("--status status", "success") do |o|
    options[:status] = o
  end

  opts.on("--commit_sha commit sha", "commit sha") do |o|
    options[:commit_sha] = o
  end

  opts.on("--project_name project name", "project name") do |o|
    options[:project_name] = o
  end

  opts.on("--branch_name branch name", "branch name") do |o|
    options[:branch_name] = o
  end

  opts.on("--repository_url repository url", "repository url") do |o|
    options[:repository_url] = o
  end

  opts.on("--environment environment", "environment") do |o|
    options[:environment] = o
  end

  opts.on("--hosting_environment hosting environment", "hosting environment") do |o|
    options[:hosting_environment] = o
  end

  opts.on("--deployment_id deployment id", "deployment id") do |o|
    options[:deployment_id] = o
  end

  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end
}

parser.parse!

duration = (options[:finished_at].to_i)-(options[:started_at].to_i)

client = InfluxDB2::Client.new('https://eu-central-1-1.aws.cloud2.influxdata.com', token,
  precision: InfluxDB2::WritePrecision::NANOSECOND)

  write_api = client.create_write_api

  hash = {name: 'deployment_frequency',
    tags: {
      status: options[:status],
      commit_sha: options[:commit_sha],
      project_name: options[:project_name],
      branch_name: options[:branch_name],
      repository_url: options[:repository_url],
      environment: options[:environment],
      hosting_environment: options[:hosting_environment],
      deployment_id: options[:deployment_id]
    },
    fields: {
      started_at: options[:started_at],
      finished_at: options[:finished_at],
      duration: "#{duration}"
    },
    time: Time.now.utc}

  write_api.write(data: hash, bucket: bucket, org: org)


