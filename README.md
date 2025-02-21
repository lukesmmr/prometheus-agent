# Lightweight Logging & Metrics Agent

This repository provides a simple, lightweight logging and metrics agent to run on an AWS EC2 Ubuntu instance. The agent runs three Docker containers:

1. **node-exporter**  
   Collects host-level metrics. The service is very low on memory and CPU usage.

2. **promtail**  
   Reads log files (both system logs and Docker container logs) and forwards them to your main EC2 instance running a Grafana custom instance (with a Loki data source configured). It pulls the MAIN instance IP from an environment file.

3. **ping-agent**  
   Pings the main EC2 instance via its private IP every 60 seconds to ensure that the connection is up.

## Environment Configuration

This project now uses environment variables to configure the main instance's private IP. The value is read from a `.env` file located at the repo root.

### Setup .env

1. Copy the `.env.template` file to `.env`:
   ```bash
   cp .env.template .env
   ```

2. Open the `.env` file and replace the placeholder with your main instance's private IP:
   ```env
   MAIN_INSTANCE_PRIVATE_IP=10.0.1.5
   ```

### Usage in Configurations

- **Promtail Configuration:**  
  In `promtail-config.yaml`, the Loki push client URL is configured to use the `MAIN_INSTANCE_PRIVATE_IP` variable:
  \[
  "http://${MAIN_INSTANCE_PRIVATE_IP}:3100/loki/api/v1/push"
  \]
  If not already part of your container image, you may need to run a substitution step (e.g., with `envsubst`) to generate the final config file before launching promtail.

- **Ping Agent (Docker Compose):**  
  The `ping-agent` service in the `docker-compose.yml` file uses:
  \[
  ping -c 1 \${MAIN_INSTANCE_PRIVATE_IP}
  \]
  so that the ping command always targets the IP defined in your `.env` file.

## Architecture Overview

- **Metrics Collection:**  
  [node_exporter](https://github.com/prometheus/node_exporter) runs in a container using host networking and exports metrics (e.g., from \`/proc\` and \`/sys\`) on port 9100. Your main instance (or Prometheus) can scrape these metrics.

- **Log Collection:**  
  [promtail](https://grafana.com/docs/loki/latest/clients/promtail/) tails system logs (from \`/var/log\`) and Docker container logs (from \`/var/lib/docker/containers\`). It then pushes them to a Loki endpoint running on your main EC2 instance. (Make sure your Grafana Loki—or other log ingress service—is configured to accept logs from this agent.)

- **Connectivity Checker:**  
  A simple Alpine-based container pings your main instance's private IP periodically. This is useful for alerting if network connectivity fails.

## Prerequisites

- An **Ubuntu EC2 instance** with Docker and Docker Compose installed.
- Ensure that your AWS security groups allow communication from the agent instance to the main EC2 instance over the required ports:
  - For **node_exporter**: TCP port 9101 (if your aggregator/prometheus needs to scrape metrics).
  - For **promtail**: TCP port 3100 (or whichever port your Loki endpoint listens on).
  - For **ping-agent**: ICMP must be allowed.
- A main EC2 instance running Grafana with a **Loki** (or compatible) log ingestion endpoint. (In the promtail config, update the \`clients.url\` accordingly.)

## Setup Instructions

1. **Clone the Repository**

   ```bash
   git clone <your-repo-url>
   cd <your-repo-directory>
   ```

2. **Configure the Environment**

   Copy the environment template and update the MAIN instance's IP:
   ```bash
   cp .env.template .env
   # Then edit the .env file to specify your MAIN_INSTANCE_PRIVATE_IP value.
   ```

3. **Launch the Agent via Docker Compose**

   From the directory containing your files, run:
   ```bash
   docker compose up -d
   ```
   This will start the three services in detached mode.

4. **Verify the Setup**

   - Check that **node-exporter** is running and accessible on port 9101:
     ```bash
     curl http://localhost:9101/metrics
     ```
   - Review the logs of the **promtail** service to ensure it's tailing files and pushing logs:
     ```bash
     docker logs promtail
     ```
   - Confirm that **ping-agent** shows continuous pings (you can inspect its logs):
     ```bash
     docker logs ping-agent
     ```

5. **Configure Grafana**

   - In your Grafana custom instance on the main EC2 instance, add a new data source pointing to the Loki endpoint (e.g., \`http://10.0.1.5:3100\`) so that logs from the agents are visible.
   - Also add your node-exporter endpoints (using the private IPs of your agents) as metrics sources if needed.

## Notes & Considerations

- **Simplicity:** This solution emphasizes a simple codebase to reduce overhead and maintenance complexity.
- **Security Groups:** Double-check that the security groups for your EC2 instances allow the required traffic between agents and the main Grafana/Loki instance.
- **Customization:** Feel free to expand the promtail \`scrape_configs\` if you need to include additional log paths.
- **Environment Variable Processing:**  
  Ensure that if your Promtail container does not support environment variable substitution natively, you preprocess `promtail-config.yaml` using a tool like `envsubst`.

## Troubleshooting

- If logs are not showing up in Grafana, first ensure that the main instance's Loki endpoint is accessible from the agent (try curling \`http://<MAIN_INSTANCE_PRIVATE_IP>:3100/loki/api/v1/push\` from the agent).
- Use \`docker logs\` to review individual service logs.  
- Verify that Docker volumes are correctly mounted and that your log paths exist on the host.

Happy monitoring!

## Agent Control Script

To simplify managing the logging agent's Docker services (i.e., **node-exporter**, **promtail**, and **ping-agent**), this repository includes a control script named `agent-control.sh`. This script allows you to start, stop, restart, and check the status of your services with a single command.

### Usage

1. **Give the Script Execution Permission:**

   ```bash
   chmod +x agent-control.sh
   ```

2. **Starting the Services:**

   - **Normal Mode:**  
     This uses the `MAIN_INSTANCE_PRIVATE_IP` defined in your `.env` file.
     ```bash
     ./agent-control.sh start
     ```
     
   - **Mock Mode:**  
     For local testing, you can override the `MAIN_INSTANCE_PRIVATE_IP` environment variable with `127.0.0.1` using the `--mock` flag.
     ```bash
     ./agent-control.sh start --mock
     ```

3. **Stopping the Services:**

   ```bash
   ./agent-control.sh stop
   ```

4. **Restarting the Services:**

   - **Normal Mode:**
     ```bash
     ./agent-control.sh restart
     ```
   
   - **Mock Mode:**
     ```bash
     ./agent-control.sh restart --mock
     ```

5. **Checking Service Status:**

   ```bash
   ./agent-control.sh status
   ```

### Notes

- The control script utilizes `docker compose` under the hood, so ensure that Docker Compose is installed and the `docker-compose.yml` file is present in your project directory.
- The `--mock` flag is especially helpful for local testing, allowing you to simulate the environment without affecting the production setup by overriding the main instance IP.

By integrating this script into your workflow, you can easily manage your logging agent services both in production and for local testing. 