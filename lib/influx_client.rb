require "influxdb-client"

def influx_client
  influx_api_token = ENV["INFLUX_API_TOKEN"]
  influx_url = ENV["INFLUX_URL"]
  influx_bucket_name = ENV["INFLUX_BUCKET_NAME"]
  influx_organisation_name = ENV["INFLUX_ORGANISATION_NAME"]

  InfluxDB2::Client.new(influx_url, influx_api_token,
    org: influx_organisation_name,
    precision: InfluxDB2::WritePrecision::SECOND)
end

def send_data_to_influx(write_api, data, bucket:)
  write_api.write(data: data, bucket: bucket)
end
