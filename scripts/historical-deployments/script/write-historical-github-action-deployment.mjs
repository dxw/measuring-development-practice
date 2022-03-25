#!/usr/bin/env node

import HistoricalDataFetcher from "../src/historical-data-fetcher.mjs";
import HistoricalDataWriter from "../src/historical-data-writer.mjs";

const [repo, owner, hostingEnvironment] = process.argv.slice(2);

const influxDbConfig = {
  token: process.env.INFLUX_DB_TOKEN,
  org: process.env.INFLUX_DB_ORG,
  bucket: process.env.INFLUX_DB_BUCKET,
  url: process.env.INFLUX_DB_URL,
};

const historicalDataFetcher = new HistoricalDataFetcher(
  repo,
  owner,
  hostingEnvironment
);

const deployments = await historicalDataFetcher.getGitHubActionsDeployments(
  "master"
);

const influxDbWriter = new HistoricalDataWriter(deployments, influxDbConfig);

influxDbWriter.write();
