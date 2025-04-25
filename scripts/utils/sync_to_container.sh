#!/bin/bash
# sync_to_container.sh - One-way sync from host repository to container
# Implements the Repository Mounting Strategy from the AgencyStack Charter
#
# Author: AgencyStack Team
# Date: 2025-04-25

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
CONTAINER_NAME="agencystack-dev"
REPO_VOLUME="${CONTAINER_NAME}_repo"

# Ensure we're running from the repository root
if [ ! -f "${REPO_ROOT}/Makefile" ]; then
  echo "[!] Error: This script must be run from the repository root"
  echo "    Current directory: $(pwd)"
  echo "    Expected Makefile at: ${REPO_ROOT}/Makefile"
  exit 1
fi

# Function to sync all files
sync_all() {
  echo "[+] Syncing all files from host repository to container volume..."
  
  docker run --rm \
    -v "${REPO_ROOT}:/host-repo:ro" \
    -v "${REPO_VOLUME}:/container-repo" \
    alpine:latest \
    /bin/sh -c "cp -ru /host-repo/. /container-repo/ && echo '[+] Repository sync complete'"
    
  echo "[+] Sync complete. You can now exec into the container to see changes."
  echo "    docker exec -it --user developer ${CONTAINER_NAME} zsh"
}

# Function to sync specific files
sync_files() {
  local files=("$@")
  
  echo "[+] Syncing specific files from host repository to container volume..."
  
  for file in "${files[@]}"; do
    relative_path="${file#${REPO_ROOT}/}"
    
    # Create parent directories in container if needed
    parent_dir="$(dirname "${relative_path}")"
    docker run --rm \
      -v "${REPO_VOLUME}:/container-repo" \
      alpine:latest \
      /bin/sh -c "mkdir -p /container-repo/${parent_dir}"
    
    # Copy the file with preserved permissions
    docker run --rm \
      -v "${REPO_ROOT}:/host-repo:ro" \
      -v "${REPO_VOLUME}:/container-repo" \
      alpine:latest \
      /bin/sh -c "cp -p /host-repo/${relative_path} /container-repo/${relative_path} && echo '[+] Synced: ${relative_path}'"
  done
  
  echo "[+] Sync complete. You can now exec into the container to see changes."
  echo "    docker exec -it --user developer ${CONTAINER_NAME} zsh"
}

# Parse arguments
if [ $# -eq 0 ]; then
  # No arguments, sync everything
  sync_all
else
  # Sync specific files
  sync_files "$@"
fi

exit 0
