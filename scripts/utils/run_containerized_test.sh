#!/bin/bash

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/common.sh" ]]; then
  source "${SCRIPT_DIR}/common.sh"
fi

# Enforce Charter v1.0.3 principles
# This script runs a specified test script in a containerized environment

log_info "Running test in containerized environment per AgencyStack Charter v1.0.3"

# Default values
TEST_SCRIPT=""
TEST_ARGS=""
IMAGE="ubuntu:20.04"
NETWORK_MODE="host"
MOUNT_REPO=true

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --test-script) TEST_SCRIPT="$2"; shift ;;
    --test-args) TEST_ARGS="$2"; shift ;;
    --image) IMAGE="$2"; shift ;;
    --network) NETWORK_MODE="$2"; shift ;;
    --no-mount-repo) MOUNT_REPO=false; shift; continue ;;
    --help) 
      echo "Usage: $0 --test-script path/to/script.sh [--test-args \"arg1 arg2\"] [--image ubuntu:20.04] [--network host] [--no-mount-repo]"
      exit 0 
      ;;
    *) log_error "Unknown parameter: $1"; exit 1 ;;
  esac
  shift
done

# Validate required parameters
if [ -z "$TEST_SCRIPT" ]; then
  log_error "No test script specified. Use --test-script parameter."
  exit 1
fi

if [ ! -f "$TEST_SCRIPT" ]; then
  log_error "Test script not found: $TEST_SCRIPT"
  exit 1
fi

# Get repository root
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Make test script executable
chmod +x "$TEST_SCRIPT"

# Prepare mount options
MOUNT_OPTIONS=""
if [ "$MOUNT_REPO" = true ]; then
  MOUNT_OPTIONS="-v ${REPO_ROOT}:${REPO_ROOT}"
fi

# Run test in container
log_info "Running test script: $TEST_SCRIPT"
log_info "Arguments: $TEST_ARGS"
log_info "Docker image: $IMAGE"

DOCKER_CMD="docker run --rm ${MOUNT_OPTIONS} -v /var/run/docker.sock:/var/run/docker.sock --network=${NETWORK_MODE} ${IMAGE} bash -c"
SETUP_CMD="apt-get update && apt-get install -y docker.io curl jq"
TEST_CMD="${TEST_SCRIPT} ${TEST_ARGS}"

log_info "Executing: ${DOCKER_CMD} \"${SETUP_CMD} && ${TEST_CMD}\""
$DOCKER_CMD "${SETUP_CMD} && ${TEST_CMD}"

EXIT_CODE=$?
if [ $EXIT_CODE -eq 0 ]; then
  log_success "Test completed successfully (containerized execution)"
else
  log_error "Test failed with exit code: $EXIT_CODE"
fi

exit $EXIT_CODE
