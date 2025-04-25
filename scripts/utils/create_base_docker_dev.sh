#!/bin/bash
# Utility script to build and run the AgencyStack Docker-in-Docker dev environment
# Usage: scripts/utils/create_base_docker_dev.sh [--build-only|--run-only|--sync]

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

# Named volume for repository persistence
REPO_VOLUME="${CONTAINER_NAME}_repo"

build_image() {
  echo "[+] Building $IMAGE_NAME from $DOCKERFILE in $CONTEXT ..."
  docker build -f "$CONTEXT/$DOCKERFILE" -t "$IMAGE_NAME" "$CONTEXT"
}

initialize_volume() {
  echo "[+] Initializing repository volume $REPO_VOLUME with one-way sync from host ..."
  
  # Create the volume if it doesn't exist
  docker volume create "$REPO_VOLUME"
  
  # Use a temporary container to sync the data
  echo "[+] Initial sync from host repository to volume..."
  docker run --rm \
    -v "$CONTEXT:/host-repo:ro" \
    -v "$REPO_VOLUME:/container-repo" \
    alpine:latest \
    /bin/sh -c "cp -r /host-repo/. /container-repo/ && echo '[+] Initial repository sync complete'"
}

sync_to_container() {
  echo "[+] Syncing changes from host repository to container volume..."
  
  # Use rsync-like behavior to only update changed files
  docker run --rm \
    -v "$CONTEXT:/host-repo:ro" \
    -v "$REPO_VOLUME:/container-repo" \
    alpine:latest \
    /bin/sh -c "cp -ru /host-repo/. /container-repo/ && echo '[+] Repository sync complete'"
}

run_container() {
  echo "[+] Running $CONTAINER_NAME with Docker-in-Docker, SSH port $SSH_PORT, RAM $DEV_RAM, CPUs $DEV_CPUS ..."
  # Warn if Docker Desktop
  if grep -q docker-desktop /proc/1/cgroup 2>/dev/null; then
    echo "[!] WARNING: You're running Docker Desktop. Resource limits are controlled in Docker Desktop settings, not per container!"
  fi
  # Remove any existing container first
  docker rm -f "$CONTAINER_NAME" 2>/dev/null || true
  
  # Run container with resource limits and named volume for repository
  docker run --privileged -d \
    --name "$CONTAINER_NAME" \
    -p "$SSH_PORT:22" \
    --memory="$DEV_RAM" \
    --cpus="$DEV_CPUS" \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v "$REPO_VOLUME:/home/developer/agency-stack" \
    "$IMAGE_NAME" \
    /entrypoint.sh
    
  echo "[+] Container started. SSH: ssh developer@localhost -p $SSH_PORT (password: agencystack)"
  echo "[i] RAM: $DEV_RAM | CPUs: $DEV_CPUS"
  echo "[i] Repository mounted as named volume with one-way sync from host"
  echo "[i] To sync changes from host to container: $0 --sync"
}

case "${1:-}" in
  --build-only)
    build_image
    ;;
  --run-only)
    run_container
    ;;
  --sync)
    sync_to_container
    ;;
  *)
    build_image
    initialize_volume
    run_container
    ;;
esac
