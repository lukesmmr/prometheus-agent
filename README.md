# Lightweight Logging & Metrics Agent

This repository provides a simple, lightweight logging and metrics agent to run on an AWS EC2 Ubuntu instance. The agent runs three Docker containers:

1. **node-exporter**  
   Collects host-level metrics on port 9101. Very low memory and CPU usage.

2. **promtail**  
   Reads Docker container logs and system logs, forwarding them to your main logging instance through a direct HTTP connection over private IP.

3. **ping-agent**  
   Monitors connectivity to the main instance via private IP.

## Architecture Overview

- **Metrics Collection**: node_exporter exposes host metrics on port 9101
- **Log Collection**: promtail automatically detects and collects logs from:
  - Docker containers (using container name pattern matching)
  - System logs (/var/log)
- **Authentication**: Handled by your reverse proxy on the main instance
- **Communication**: All traffic stays within your private VPC network

## Container Log Collection

The agent automatically detects and collects logs from Docker containers based on pattern matching. Each container's logs are labeled based on its type:

### Built-in Container Types

1. **Web Applications** (`app: webapp`)
   ```env
   WEBAPP_CONTAINER_PATTERN=node-app.*|.*express.*
   WEBAPP_PORT=3001
   ```

2. **Web Servers** (`app: webserver`)
   ```env
   WEBSERVER_CONTAINER_PATTERN=.*reverse_proxy.*|caddy.*|nginx.*
   WEBSERVER_PORT=8443
   ```

3. **Databases** (`app: database`)
   ```env
   DATABASE_CONTAINER_PATTERN=mongodb|mongo.*|.*db.*
   DATABASE_PORT=27117
   ```

### Custom Container Support

Define custom containers using the format: `NAME_PATTERN|LABEL_APP|LABEL_SERVICE|PORT`

Examples:
```env
# Redis cache
CUSTOM_CONTAINER_1="redis.*|cache|redis|6379"

# Elasticsearch
CUSTOM_CONTAINER_2="elastic.*|search|elasticsearch|9200"
```

## Setup Instructions

1. **Clone the Repository**
   ```bash
   git clone <your-repo-url>
   cd <your-repo-directory>
   ```

2. **Configure Environment**
   ```bash
   # Copy the template
   cp .env.template .env

   # Set the hostname (required for proper log identification)
   echo "HOSTNAME=$(hostname)" >> .env
   ```

   Edit `.env` with your configuration:
   ```env
   # Instance identification
   HOSTNAME=your-instance-hostname  # Added automatically by setup command
   MAIN_INSTANCE_PRIVATE_IP=10.0.1.5

   # Container patterns for your setup
   WEBAPP_CONTAINER_PATTERN=your-webapp-container
   WEBSERVER_CONTAINER_PATTERN=your-webserver-container
   DATABASE_CONTAINER_PATTERN=your-database-container

   # Service ports
   WEBAPP_PORT=<your-webapp-port>
   WEBSERVER_PORT=<your-webserver-port>
   DATABASE_PORT=<your-database-port>
   ```

3. **Start the Agent**
   ```bash
   chmod +x agent-control.sh
   ./agent-control.sh start
   ```

## Agent Control Script

The `agent-control.sh` script manages the agent services:

```bash
# Start services
./agent-control.sh start

# Stop services
./agent-control.sh stop

# Restart services
./agent-control.sh restart

# Check status
./agent-control.sh status

# Test locally with mock IP
./agent-control.sh start --mock
```

## Querying Logs in Grafana

Use these label selectors to query your logs:

```logql
# All web application logs
{app="webapp"}

# All database logs
{app="database"}

# All web server logs
{app="webserver"}

# Specific container logs
{container_name=~".*webapp.*"}

# Specific host's logs
{host="your-hostname"}

# Combine selectors
{app="webapp", host="your-hostname"}

## Security Considerations

1. **Network Security**:
   - Deploy only within a private VPC network
   - Use security groups to restrict access:
     - Allow node-exporter (9101) access only from Prometheus
     - Allow Loki push access only to your main instance
     - Allow ICMP for ping-agent

2. **Container Access**:
   - All container logs are mounted read-only
   - System logs are mounted read-only
   - Promtail runs without privileged access

## Troubleshooting

1. **Check Container Logs**
   ```bash
   # Check Promtail logs
   docker logs promtail

   # Check node-exporter metrics
   curl http://localhost:9101/metrics

   # Check ping-agent connectivity
   docker logs ping_agent
   ```

2. **Verify Log Collection**
   ```bash
   # List detected containers
   docker logs promtail | grep "container_name"

   # Check Promtail targets
   curl http://localhost:9080/targets
   ```

3. **Common Issues**:
   - If logs aren't showing up, check:
     - Container name patterns match your containers
     - Main instance IP is correct
     - Security group rules allow traffic
     - Reverse proxy is properly configured

## Best Practices

1. **Container Naming**:
   - Use consistent naming patterns for containers
   - Document patterns in your `.env` file
   - Use specific patterns to avoid false matches

2. **Pattern Matching**:
   - Start with exact matches for known containers
   - Use wildcards carefully to avoid matching unwanted containers
   - Test patterns with your actual container names

3. **Custom Containers**:
   - Use custom container definitions for specialized services
   - Document the purpose of each custom pattern
   - Keep pattern matching as specific as possible
