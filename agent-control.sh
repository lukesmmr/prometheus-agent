#!/bin/bash
# agent-control.sh: A control script for the logging agent Docker services.
#
# Usage:
#   ./agent-control.sh {start|stop|restart|status} [--mock] [--roles ROLE1,ROLE2,...]
#
# If the --mock flag is provided, the script will override the MAIN_INSTANCE_PRIVATE_IP
# environment variable with 127.0.0.1 to allow local testing.
#
# If the --roles flag is provided, the script will set the INSTANCE_ROLES
# environment variable to the specified comma-separated list of roles.
#
# Available roles:
#   webapp    - For Node.js application (pnm-server-app)
#   webserver - For Caddy reverse proxy
#   database  - For MongoDB instance
#
# Examples:
#   # Start agent on app server (Node.js + Caddy):
#   ./agent-control.sh start --roles webapp,webserver
#
#   # Start agent on database server (MongoDB):
#   ./agent-control.sh start --roles database
#
#   # Test locally with mock configuration:
#   ./agent-control.sh start --mock --roles webapp,webserver

set -e

usage() {
    echo "Usage: $0 {start|stop|restart|status} [--mock] [--roles ROLE1,ROLE2,...]" >&2
    echo "" >&2
    echo "Options:" >&2
    echo "  --mock              Use mock mode for local testing" >&2
    echo "  --roles ROLES       Set instance roles (comma-separated)" >&2
    echo "" >&2
    echo "Available roles:" >&2
    echo "  webapp              Node.js application (pnm-server-app)" >&2
    echo "  webserver          Caddy reverse proxy" >&2
    echo "  database           MongoDB instance" >&2
    echo "" >&2
    echo "Examples:" >&2
    echo "  # Start agent on app server:" >&2
    echo "  $0 start --roles webapp,webserver" >&2
    echo "" >&2
    echo "  # Start agent on database server:" >&2
    echo "  $0 start --roles database" >&2
    exit 1
}

# Ensure proper usage
if [ "$#" -lt 1 ] || [ "$#" -gt 4 ]; then
    usage
fi

ACTION=$1
MOCK_MODE=0
ROLES=""

# Parse arguments
shift
while [ "$#" -gt 0 ]; do
    case "$1" in
        --mock)
            MOCK_MODE=1
            ;;
        --roles)
            if [ "$#" -lt 2 ]; then
                echo "Error: --roles requires an argument" >&2
                usage
            fi
            ROLES="$2"
            shift
            ;;
        --role) # For backward compatibility
            if [ "$#" -lt 2 ]; then
                echo "Error: --role requires an argument" >&2
                usage
            fi
            ROLES="$2"
            echo "Warning: --role is deprecated, use --roles instead" >&2
            shift
            ;;
        *)
            usage
            ;;
    esac
    shift
done

# Validate roles if provided
if [ -n "$ROLES" ]; then
    # Convert comma-separated string to array
    IFS=',' read -ra ROLE_ARRAY <<< "$ROLES"
    for ROLE in "${ROLE_ARRAY[@]}"; do
        case "$ROLE" in
            webapp|webserver|database)
                continue
                ;;
            *)
                echo "Error: Invalid role '$ROLE'" >&2
                echo "Valid roles are: webapp, webserver, database" >&2
                exit 1
                ;;
        esac
    done
fi

# If in mock mode, override environment variables with local values
if [ "$MOCK_MODE" -eq 1 ]; then
    echo "Running in MOCK mode. Overriding environment variables for local testing."
    export MAIN_INSTANCE_PRIVATE_IP=127.0.0.1
    # Keep the password as-is for authentication testing
fi

# If roles are specified, set the INSTANCE_ROLES environment variable
if [ -n "$ROLES" ]; then
    echo "Setting instance roles to: $ROLES"
    export INSTANCE_ROLES="$ROLES"
fi

# Check if INSTANCE_ROLES is set, either from environment or from --roles flag
if [ -z "${INSTANCE_ROLES}" ]; then
    echo "Warning: INSTANCE_ROLES is not set. Using 'unknown' as default."
    export INSTANCE_ROLES="unknown"
fi

# Use docker compose commands for service control
DOCKER_COMPOSE="docker compose"

case "$ACTION" in
    start)
        echo "Starting logging agent services for roles: ${INSTANCE_ROLES}..."
        $DOCKER_COMPOSE up -d
        ;;
    stop)
        echo "Stopping logging agent services..."
        $DOCKER_COMPOSE down
        ;;
    restart)
        echo "Restarting logging agent services for roles: ${INSTANCE_ROLES}..."
        $DOCKER_COMPOSE down
        $DOCKER_COMPOSE up -d
        ;;
    status)
        echo "Checking status of logging agent services (roles: ${INSTANCE_ROLES})..."
        $DOCKER_COMPOSE ps
        ;;
    *)
        usage
        ;;
esac

exit 0 