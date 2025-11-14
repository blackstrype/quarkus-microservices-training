#!/bin/bash

POD_NAME="quarkus-lab-6"

# Configure for intermittent latence and failure in the station-service. You can adjust these values as needed by setting the environment variables before running this script.
SIMULATED_WAIT_MILLIS=${SIMULATED_WAIT_MILLIS:-5000}
SIMULATED_FAIL_RATE=${SIMULATED_FAIL_RATE:-.70}

echo "SIMULATED_WAIT_MILLIS=$SIMULATED_WAIT_MILLIS"
echo "SIMULATED_FAIL_RATE=$SIMULATED_FAIL_RATE"

if podman pod exists $POD_NAME; then
  echo "Lab 6 environment pod '$POD_NAME' is already running. Run './stop-lab-6.sh' first."
  exit 0
fi

echo "Creating the '$POD_NAME' pod..."
podman pod create --name $POD_NAME \
  -p 5432:5432 \
  -p 8081:8080

echo "Starting Postgres..."
podman run -d --pod $POD_NAME --name postgres-lab \
  -e POSTGRES_USER=user \
  -e POSTGRES_PASSWORD=quarkus \
  -e POSTGRES_DB=trainline_db \
  postgres:16

echo "Starting Station Service..."
podman run -d --pod $POD_NAME --name station-service-lab \
  --pull=always \
  -e SIMULATED_WAIT_MILLIS=$SIMULATED_WAIT_MILLIS \
  -e SIMULATED_FAIL_RATE=$SIMULATED_FAIL_RATE \
  quay.io/blackstrype/station-service:insecure

echo "Lab 6 environment is running."

