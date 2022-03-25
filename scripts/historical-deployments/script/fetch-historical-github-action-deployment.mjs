#!/usr/bin/env node

import HistoricalDataFetcher from "../src/historical-data-fetcher.mjs";

const [repo, owner, hostingEnvironment] = process.argv.slice(2);

const historicalDataFetcher = new HistoricalDataFetcher(
  repo,
  owner,
  hostingEnvironment
);

const deployments = await historicalDataFetcher.getGitHubActionsDeployments(
  "master"
);

console.dir(deployments, { depth: null });
