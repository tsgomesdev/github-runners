#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# Fix Docker socket permissions if it exists
if [ -S /var/run/docker.sock ]; then
  echo "Docker socket found. Adjusting permissions..."
  sudo chmod 666 /var/run/docker.sock
fi

# Check for required environment variables
if [ -z "$ORGANIZATION" ] || [ -z "$ACCESS_TOKEN" ]; then
  echo "Error: ORGANIZATION and ACCESS_TOKEN environment variables must be set."
  exit 1
fi

echo "Attempting to retrieve registration token for organization: ${ORGANIZATION}"

# Fetch the registration token from the GitHub API
REG_TOKEN=$(curl -sX POST -H "Authorization: token ${ACCESS_TOKEN}" "https://api.github.com/orgs/${ORGANIZATION}/actions/runners/registration-token" | jq .token --raw-output)

# Validate the token
if [ -z "$REG_TOKEN" ] || [ "$REG_TOKEN" == "null" ]; then
  echo "Error: Failed to get registration token. Check your ORGANIZATION and ACCESS_TOKEN (it must have 'admin:org' scope)."
  exit 1
fi

echo "Successfully retrieved registration token."

cd /home/docker/actions-runner

# Configure the runner, adding --unattended and --replace for better automation
./config.sh --url "https://github.com/${ORGANIZATION}" --token "${REG_TOKEN}" --unattended --replace

cleanup() {
    echo "Removing runner..."
    # Use the Personal Access Token (ACCESS_TOKEN) to remove the runner
    ./config.sh remove --token "${ACCESS_TOKEN}"
}

# Trap signals for cleanup
trap 'cleanup; exit 130' INT
trap 'cleanup; exit 143' TERM

# Start the runner and wait for it to exit
echo "Starting the runner..."
./run.sh & wait $!
