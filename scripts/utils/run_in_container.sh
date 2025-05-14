#!/bin/bash
# run_in_container.sh - Run AgencyStack scripts in Docker container
# Following AgencyStack Charter v1.0.3 principles:
# - Strict Containerization
# - Repository as Source of Truth
# - Proper Change Workflow

# Default values
CONTAINER_IMAGE="debian:12-slim"
SCRIPT_PATH=""
SCRIPT_ARGS=""
MOUNT_REPO=true
MOUNT_LOGS=true
MOUNT_DATA=true
CLIENT_ID="peacefestivalusa"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --image)
      CONTAINER_IMAGE="$2"
      shift
      ;;
    --script)
      SCRIPT_PATH="$2"
      shift
      ;;
    --args)
      SCRIPT_ARGS="$2"
      shift
      ;;
    --client-id)
      CLIENT_ID="$2"
      shift
      ;;
    --no-repo-mount)
      MOUNT_REPO=false
      ;;
    --no-logs-mount)
      MOUNT_LOGS=false
      ;;
    --no-data-mount)
      MOUNT_DATA=false
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
  shift
done

# Validate script path
if [ -z "$SCRIPT_PATH" ]; then
  echo "ERROR: Script path is required (--script)"
  exit 1
fi

# Get full paths
REPO_ROOT="$(cd "$(dirname "$(dirname "$(dirname "${BASH_SOURCE[0]}")")")" && pwd)"
SCRIPT_FULL_PATH="${REPO_ROOT}/${SCRIPT_PATH#/}"

if [ ! -f "$SCRIPT_FULL_PATH" ]; then
  echo "ERROR: Script not found: $SCRIPT_FULL_PATH"
  exit 1
fi

# Define mounting options
MOUNTS=""
if [ "$MOUNT_REPO" = true ]; then
  MOUNTS="$MOUNTS -v ${REPO_ROOT}:/agency_stack"
fi

if [ "$MOUNT_LOGS" = true ]; then
  MOUNTS="$MOUNTS -v /var/log/agency_stack:/var/log/agency_stack"
fi

if [ "$MOUNT_DATA" = true ]; then
  MOUNTS="$MOUNTS -v /opt/agency_stack:/opt/agency_stack"
fi

# Docker in Docker support
MOUNTS="$MOUNTS -v /var/run/docker.sock:/var/run/docker.sock"

# Echo the command for debugging
echo "Running: docker run -it --rm $MOUNTS $CONTAINER_IMAGE /bin/bash -c \"cd /agency_stack && $SCRIPT_PATH $SCRIPT_ARGS\""

# Run the script in a container
docker run -it --rm \
  $MOUNTS \
  --network host \
  "$CONTAINER_IMAGE" \
  /bin/bash -c "cd /agency_stack && apt-get update && apt-get install -y curl docker.io && $SCRIPT_PATH $SCRIPT_ARGS"
