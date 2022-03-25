import dotenv from "dotenv";
import { Octokit } from "@octokit/rest";

dotenv.config();

const octokit = new Octokit({
  auth: process.env.AUTH_TOKEN,
});

export default class HistoricalDataFetcher {
  repo;
  owner;
  hostingEnvironment;

  constructor(repo, owner, hostingEnvironment) {
    this.repo = repo;
    this.owner = owner;
    this.hostingEnvironment = hostingEnvironment;
  }

  async getGitHubActionsDeployments(branch) {
    const actions = await octokit.paginate(
      `GET /repos/${this.owner}/${this.repo}/actions/runs`,
      {
        headers: {
          accept: "application/vnd.github.v3+json",
        },
        branch,
        event: "push",
        name: "Deploy",
      }
    );

    const deployments = actions.filter((run) => run.name === "Deploy");

    return this._formatDeployments(deployments);
  }

  _formatDeployments(deployments) {
    return deployments.map((deployment) => {
      const started_at = new Date(deployment.created_at).getTime();
      const finished_at = new Date(deployment.updated_at).getTime();

      return {
        fields: {
          integers: {
            duration: (finished_at - started_at) / 1000,
          },
          strings: {
            finished_at: finished_at,
            started_at: started_at,
          },
        },
        tags: {
          head_sha: deployment.head_sha,
          project_name: this.repo,
          status: deployment.status,
          branch_name: deployment.head_branch,
          repository_url: deployment.head_repository.html_url,
          environment: deployment.head_branch,
          hosting_environment: this.hostingEnvironment,
          deployment_id: deployment.id,
        },
      };
    });
  }
}
