#!/bin/bash
# docker_prune_all.sh - Safely prune all Docker containers, networks, images, and optionally volumes
# AgencyStack Utility | Logs to /var/log/agency_stack/components/docker_prune.log
#
# Usage:
#   ./docker_prune_all.sh [--force] [--with-volumes]
#
# - Stops and removes all containers
# - Removes all unused networks and images
# - Removes volumes only if --with-volumes is specified
# - Prompts for confirmation unless --force is given
# - Logs to /var/log/agency_stack/components/docker_prune.log
#
# Follows AgencyStack repository integrity and auditability standards.

set -euo pipefail

LOG_FILE="/var/log/agency_stack/components/docker_prune.log"
FORCE=false
WITH_VOLUMES=false

# Parse arguments
for arg in "$@"; do
  case $arg in
    --force)
      FORCE=true
      ;;
    --with-volumes)
      WITH_VOLUMES=true
      ;;
    *)
      echo "Unknown argument: $arg"
      exit 1
      ;;
  esac
done

# Ensure log directory exists
mkdir -p "$(dirname "$LOG_FILE")"

log() {
  echo -e "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

confirm() {
  if [ "$FORCE" = true ]; then
    return 0
  fi
  echo "WARNING: This will stop and remove ALL Docker containers, networks, and images." >&2
  if [ "$WITH_VOLUMES" = true ]; then
    echo "It will also REMOVE ALL DOCKER VOLUMES (data will be lost)." >&2
  fi
  read -p "Are you sure you want to proceed? (y/N): " confirm
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
  fi
}

main() {
  confirm
  log "Stopping all running containers..."
  docker ps -q | xargs -r docker stop | tee -a "$LOG_FILE"

  log "Removing all containers..."
  docker ps -aq | xargs -r docker rm | tee -a "$LOG_FILE"

  log "Pruning unused networks..."
  docker network prune -f | tee -a "$LOG_FILE"

  log "Pruning unused images..."
  docker image prune -a -f | tee -a "$LOG_FILE"

  if [ "$WITH_VOLUMES" = true ]; then
    log "Pruning unused volumes... (ALL DATA WILL BE LOST)"
    docker volume prune -f | tee -a "$LOG_FILE"
  else
    log "Skipped volume prune (use --with-volumes to enable)"
  fi

  log "Docker cleanup complete."
}

main
