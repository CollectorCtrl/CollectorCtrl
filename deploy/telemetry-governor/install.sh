#!/bin/bash
set -e

echo "=== Deploying Telemetry Governor Engine ==="

# Check if Docker is installed
if ! [ -x "$(command -v docker)" ]; then
  echo "Error: docker is not installed. Please install Docker first." >&2
  exit 1
fi

# Check if Docker Compose is installed
if ! [ -x "$(command -v docker-compose)" ] && ! docker compose version &>/dev/null; then
  echo "Error: docker-compose is not installed. Please install docker-compose first." >&2
  exit 1
fi

# Run docker-compose
echo "Starting ClickHouse and OTel Collector containers..."
if [ -x "$(command -v docker-compose)" ]; then
  docker-compose up -d
else
  docker compose up -d
fi

echo "=================================================="
echo "Telemetry Governor Engine is now starting up!"
echo "- ClickHouse TCP: 9000"
echo "- ClickHouse HTTP: 8123"
echo "- OTel Collector gRPC: 4317"
echo "- OTel Collector HTTP: 4318"
echo "=================================================="
