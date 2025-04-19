#!/bin/bash
# Utility script to build and run the AgencyStack Docker-in-Docker dev environment
# Usage: scripts/utils/create_base_docker_dev.sh [--build-only|--run-only]

set -euo pipefail

IMAGE_NAME="agencystack-dev"
DOCKERFILE="Dockerfile.dev"
CONTEXT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../" && pwd)"
CONTAINER_NAME="agencystack-dev"
SSH_PORT=2222

# Resource defaults (overridable via env)
DEV_RAM="${AGENCYSTACK_DEV_RAM:-4g}"
DEV_CPUS="${AGENCYSTACK_DEV_CPUS:-2}"
DEV_DISK="${AGENCYSTACK_DEV_DISK:-}" # Not directly supported; see notes below

build_image() {
  echo "[+] Building $IMAGE_NAME from $DOCKERFILE in $CONTEXT ..."
  docker build -f "$CONTEXT/$DOCKERFILE" -t "$IMAGE_NAME" "$CONTEXT"
}

run_container() {
  echo "[+] Running $CONTAINER_NAME with Docker-in-Docker, SSH port $SSH_PORT, RAM $DEV_RAM, CPUs $DEV_CPUS ..."
  # Warn if Docker Desktop
  if grep -q docker-desktop /proc/1/cgroup 2>/dev/null; then
    echo "[!] WARNING: You're running Docker Desktop. Resource limits are controlled in Docker Desktop settings, not per container!"
  fi
  # Remove any existing container first
  docker rm -f "$CONTAINER_NAME" 2>/dev/null || true
  # Run container with resource limits
  docker run --privileged -d \
    --name "$CONTAINER_NAME" \
    -p "$SSH_PORT:22" \
    --memory="$DEV_RAM" \
    --cpus="$DEV_CPUS" \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v "$CONTEXT:/home/developer/agency-stack" \
    "$IMAGE_NAME" \
    /entrypoint.sh
  echo "[+] Container started. SSH: ssh developer@localhost -p $SSH_PORT (password: agencystack)"
  echo "[i] RAM: $DEV_RAM | CPUs: $DEV_CPUS"
}

case "${1:-}" in
  --build-only)
    build_image
    ;;
  --run-only)
    run_container
    ;;
  *)
    build_image
    run_container
    ;;
esac
