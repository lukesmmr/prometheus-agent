#!/bin/bash
# agent-control.sh: A control script for the logging agent Docker services.
#
# Usage:
#   ./agent-control.sh {start|stop|restart|status} [--mock]
#
# If the --mock flag is provided, the script will override the MAIN_INSTANCE_PRIVATE_IP
# environment variable with 127.0.0.1 to allow local testing.
#
# Examples:
#   # Start agent:
#   ./agent-control.sh start
#
#   # Test locally with mock configuration:
#   ./agent-control.sh start --mock

set -e

usage() {
    echo "Usage: $0 {start|stop|restart|status} [--mock]" >&2
    echo "" >&2
    echo "Options:" >&2
    echo "  --mock              Use mock mode for local testing" >&2
    echo "" >&2
    echo "Examples:" >&2
    echo "  # Start agent:" >&2
    echo "  $0 start" >&2
    echo "" >&2
    echo "  # Test locally:" >&2
    echo "  $0 start --mock" >&2
    exit 1
}

# Ensure proper usage
if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
    usage
fi

ACTION=$1
MOCK_MODE=0

# Parse arguments
shift
while [ "$#" -gt 0 ]; do
    case "$1" in
        --mock)
            MOCK_MODE=1
            ;;
        *)
            usage
            ;;
    esac
    shift
done

# If in mock mode, override environment variables with local values
if [ "$MOCK_MODE" -eq 1 ]; then
    echo "Running in MOCK mode. Overriding environment variables for local testing."
    export MAIN_INSTANCE_PRIVATE_IP=127.0.0.1
    # Keep the password as-is for authentication testing
fi

# Use docker compose commands for service control
DOCKER_COMPOSE="docker compose"

case "$ACTION" in
    start)
        echo "Starting logging agent services..."
        $DOCKER_COMPOSE up -d
        ;;
    stop)
        echo "Stopping logging agent services..."
        $DOCKER_COMPOSE down
        ;;
    restart)
        echo "Restarting logging agent services..."
        $DOCKER_COMPOSE down
        $DOCKER_COMPOSE up -d
        ;;
    status)
        echo "Checking status of logging agent services..."
        $DOCKER_COMPOSE ps
        ;;
    *)
        usage
        ;;
esac

exit 0 