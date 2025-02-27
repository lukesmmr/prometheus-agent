# Lightweight Logging & Metrics Agent

This repository provides a simple, lightweight logging and metrics agent to run on an AWS EC2 Ubuntu instance. The agent runs three Docker containers:

1. **node-exporter**  
   Collects host-level metrics. The service is very low on memory and CPU usage.

2. **promtail**  
   Reads log files (both system logs and Docker container logs) and forwards them to your main EC2 instance running a Grafana custom instance (with a Loki data source configured) through a secure HTTPS connection.

3. **ping-agent**  
   Pings the main EC2 instance via its private IP every 60 seconds to ensure that the connection is up.

## Environment Configuration

This project uses environment variables to configure connections. The values are read from a `.env` file located at the repo root.

### Setup .env

1. Copy the `.env.template` file to `.env`:
   ```bash
   cp .env.template .env
   ```

2. Open the `.env` file and update with your values:
   ```env
   MAIN_INSTANCE_PRIVATE_IP=10.0.1.5
   DOMAIN_ROOT=your-grafana-domain.example.com
   LOKI_BASIC_AUTH_USER=your-username
   LOKI_BASIC_AUTH_PW=your-secure-password
   ```

### Usage in Configurations

- **Promtail Configuration:**  
  In `promtail-config.yaml`, the Loki push client URL is configured to use HTTPS with your domain:
  ```
  https://${DOMAIN_ROOT}/loki/api/v1/push
  ```
  This allows secure log transmission through a reverse proxy with TLS, instead of direct IP access.

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
  [promtail](https://grafana.com/docs/loki/latest/clients/promtail/) tails system logs (from \`/var/log\`) and Docker container logs (from \`/var/lib/docker/containers\`). It then pushes them securely over HTTPS to a Loki endpoint running behind a reverse proxy. Authentication is handled via basic auth.

- **Connectivity Checker:**  
  A simple Alpine-based container pings your main instance's private IP periodically. This is useful for alerting if network connectivity fails.

## Prerequisites

- An **Ubuntu EC2 instance** with Docker and Docker Compose installed.
- Ensure that your AWS security groups allow communication from the agent instance to the main EC2 instance over the required ports:
  - For **node_exporter**: TCP port 9101 (if your aggregator/prometheus needs to scrape metrics).
  - For **promtail**: HTTPS (port 443) to your domain with reverse proxy.
  - For **ping-agent**: ICMP must be allowed.
- A main EC2 instance running Grafana with a **Loki** (or compatible) log ingestion endpoint behind a reverse proxy with TLS.

## Setup Instructions

1. **Clone the Repository**

   ```bash
   git clone <your-repo-url>
   cd <your-repo-directory>
   ```

2. **Configure the Environment**

   Copy the environment template and update the values:
   ```bash
   cp .env.template .env
   # Then edit the .env file to specify your MAIN_INSTANCE_PRIVATE_IP, DOMAIN_ROOT, and LOKI_BASIC_AUTH_USER and LOKI_BASIC_AUTH_PW values.
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

   - In your Grafana custom instance on the main EC2 instance, ensure your Loki data source is properly configured.
   - Set up your reverse proxy to forward requests from `https://your-domain.com/loki/api/v1/push` to your Loki instance.
   - Configure basic authentication in your reverse proxy to match the credentials used in the promtail configuration.
   - Also add your node-exporter endpoints (using the private IPs of your agents) as metrics sources if needed.

## Notes & Considerations

- **Simplicity:** This solution emphasizes a simple codebase to reduce overhead and maintenance complexity.
- **Security:** Logs are transmitted securely over HTTPS with basic authentication.
- **Security Groups:** Double-check that the security groups for your EC2 instances allow the required traffic between agents and the main Grafana/Loki instance.
- **Customization:** Feel free to expand the promtail \`scrape_configs\` if you need to include additional log paths.
- **Environment Variable Processing:** Promtail is configured with `-config.expand-env=true` to support environment variable substitution.

## Troubleshooting

- If logs are not showing up in Grafana, ensure that:
  - Your reverse proxy is correctly forwarding requests to Loki
  - The basic auth credentials are correct
  - Your domain is properly configured with valid TLS certificates
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
     This uses the environment variables defined in your `.env` file.
     ```bash
     ./agent-control.sh start
     ```
     
   - **Mock Mode:**  
     For local testing, you can override the environment with mock values using the `--mock` flag.
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
- The `--mock` flag is especially helpful for local testing, allowing you to simulate the environment without affecting the production setup by overriding the environment variables.

By integrating this script into your workflow, you can easily manage your logging agent services both in production and for local testing.

## Security Considerations

This logging and metrics agent is designed to operate within a private network environment (such as AWS VPC) and relies on proper network security controls to maintain its security posture. Please review the following security considerations before deployment:

### Network Security Requirements

- **Private Network Operation**: This solution should only be deployed within a private network (e.g., AWS VPC) where agents and the main instance communicate over private IP addresses.

- **Secure Log Transmission**: Logs are transmitted securely over HTTPS with basic authentication to prevent unauthorized access.

- **Security Group Configuration**: Properly configure security groups or firewall rules to:
  - Allow only the main Grafana/Loki instance to access the node-exporter metrics endpoint (port 9101)
  - Allow only necessary communication between agent instances and the main instance
  - Restrict all other inbound traffic to these services

- **No Public Exposure**: Never expose the node-exporter or promtail endpoints to the public internet

To enhance the security of this solution one could:

1. **Container Hardening**: Add user specifications and capability restrictions to the Docker Compose file
2. **Network Segmentation**: Use AWS security groups to strictly control traffic between components
3. **Persistent Storage**: Move the positions file from `/tmp` to a persistent, secure location
4. **Credential Management**: Use a secure vault solution for managing the basic auth credentials
