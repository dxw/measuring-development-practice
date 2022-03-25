# Historical Deployments Fetcher

## What is this?

A script for fetching historical data from GitHub Actions deployments (currently) and writing that data into InfluxDB. We plan to use it to provide more useful insight into our deployment frequency.

## Usage

### Getting started

To install dependencies required to run the script, run:

`npm install`

You'll also need to create a local `.env` file following the `.env.example` file. Credentials can be obtained from your InfluxDB account, while you'll need to use your GitHub auth token for the `AUTH_TOKEN` credential.

You'll need to create a bucket on InfluxDB to write this data to, if you haven't got one set up already.

### Running the scripts

#### To write data to InfluxDB

From this directory (`/historical-deployments`) run:

`./script/write-historical-github-action-deployment.mjs [REPOSITORY_NAME] [REPOSITORY_OWNER] [HOSTING_ENVIRONMENT]`

#### To print data from InfluxDB

From this directory (`/historical-deployments`) run:

`./script/fetch-historical-github-action-deployment.mjs [REPOSITORY_NAME] [REPOSITORY_OWNER] [HOSTING_ENVIRONMENT]`

Where `[HOSTING_ENVIRONMENT]` is "staging" or "production".
