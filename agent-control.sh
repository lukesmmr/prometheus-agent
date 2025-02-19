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
#   ./agent-control.sh start
#   ./agent-control.sh restart --mock

set -e

usage() {
    echo "Usage: $0 {start|stop|restart|status} [--mock]" >&2
    exit 1
}

# Ensure proper usage
if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
    usage
fi

ACTION=$1
MOCK_MODE=0

if [ "$#" -eq 2 ]; then
    if [ "$2" == "--mock" ]; then
        MOCK_MODE=1
    else
        usage
    fi
fi

# If in mock mode, override MAIN_INSTANCE_PRIVATE_IP with a local address
if [ "$MOCK_MODE" -eq 1 ]; then
    echo "Running in MOCK mode. Overriding MAIN_INSTANCE_PRIVATE_IP to 127.0.0.1."
    export MAIN_INSTANCE_PRIVATE_IP=127.0.0.1
fi

# Use docker-compose commands for service control
DOCKER_COMPOSE="docker-compose"

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