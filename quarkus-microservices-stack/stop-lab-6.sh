#!/bin/bash
echo "Stopping and removing lab pods..."

POD_NAME="quarkus-lab-6"

echo "Stopping and removing '$POD_NAME' pod..."
podman pod stop -f $POD_NAME 2>/dev/null
podman pod rm -f $POD_NAME 2>/dev/null

echo "Cleanup complete."
