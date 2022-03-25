import { InfluxDB, Point } from "@influxdata/influxdb-client";

export default class HistoricalDataWriter {
  deployments;
  writeApi;

  constructor(deployments, influxDbConfig) {
    this.deployments = deployments;
    this.writeApi = new InfluxDB({
      url: influxDbConfig.url,
      token: influxDbConfig.token,
    }).getWriteApi(influxDbConfig.org, influxDbConfig.bucket, "ns");
  }

  async write() {
    await this.deployments.forEach((deployment) => {
      Object.entries(deployment.tags).forEach(([tagName, value]) => {
        const point = new Point("deployment").tag(tagName, value);
        this.writeApi.writePoint(point);
      });

      Object.entries(deployment.fields.strings).forEach(
        ([fieldName, value]) => {
          const point = new Point("deployment").stringField(fieldName, value);
          this.writeApi.writePoint(point);
        }
      );

      Object.entries(deployment.fields.integers).forEach(
        ([fieldName, value]) => {
          const point = new Point("deployment").intField(fieldName, value);
          this.writeApi.writePoint(point);
        }
      );
    });

    this.writeApi
      .close()
      .then(() => {
        console.log("FINISHED");
      })
      .catch((e) => {
        console.error(e);
        console.log("Finished ERROR");
      });
  }
}
