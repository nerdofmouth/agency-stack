#!/bin/bash
# container_repo_init.sh - Initialize repository inside container
# Following AgencyStack Charter v1.0.3 Remote Operation Imperatives

set -e

# Define colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default values
CONTAINER_NAME=""
REPO_URL="https://github.com/nerdofmouth/agency-stack.git"
BRANCH="main"
USE_LOCAL=true

# Process arguments
if [ $# -lt 1 ]; then
  echo -e "${RED}Usage: $0 CONTAINER_NAME [REPO_URL] [BRANCH]${NC}"
  echo -e "${BLUE}Example: $0 agencystack-dev${NC}"
  exit 1
fi

CONTAINER_NAME="$1"
if [ $# -gt 1 ]; then
  REPO_URL="$2"
fi
if [ $# -gt 2 ]; then
  BRANCH="$3"
fi

# Validate container exists and is running
if ! docker ps -q -f name="$CONTAINER_NAME" | grep -q .; then
  echo -e "${RED}Error: Container $CONTAINER_NAME does not exist or is not running${NC}"
  exit 1
fi

echo -e "${BLUE}=== AgencyStack Container Repository Initialization ===${NC}"
echo -e "${BLUE}Following Charter v1.0.3 Repository Integrity Policy${NC}"
echo -e "${BLUE}Container: ${CYAN}${CONTAINER_NAME}${NC}"

# Step 1: Check if repository already exists in container
echo -e "${YELLOW}Checking if repository already exists in container...${NC}"
if docker exec "$CONTAINER_NAME" bash -c "[ -d /home/developer/agency-stack ] && [ -d /home/developer/agency-stack/.git ]"; then
  echo -e "${YELLOW}Repository already exists. Updating...${NC}"
  
  # Update repository
  echo -e "${YELLOW}Pulling latest changes...${NC}"
  docker exec -t "$CONTAINER_NAME" bash -c "cd /home/developer/agency-stack && git pull"
  
else
  echo -e "${YELLOW}Repository not found. Cloning...${NC}"
  
  # Clone repository
  docker exec -t "$CONTAINER_NAME" bash -c "cd /home/developer && git clone $REPO_URL agency-stack"
  docker exec -t "$CONTAINER_NAME" bash -c "cd /home/developer/agency-stack && git checkout $BRANCH"
  
  # Set proper permissions
  docker exec -t "$CONTAINER_NAME" bash -c "chown -R developer:developer /home/developer/agency-stack"
  
  echo -e "${GREEN}Repository successfully cloned.${NC}"
fi

# Step 2: Transfer recent local changes if using local repo sync
if [ "$USE_LOCAL" = true ]; then
  echo -e "${YELLOW}Syncing recent local changes to container...${NC}"
  
  # Create a temporary patch of uncommitted changes
  TEMP_PATCH=$(mktemp)
  git -C "$(dirname "$0")/../.." diff > "$TEMP_PATCH"
  
  # Copy patch to container and apply if not empty
  if [ -s "$TEMP_PATCH" ]; then
    echo -e "${YELLOW}Applying uncommitted local changes...${NC}"
    docker cp "$TEMP_PATCH" "$CONTAINER_NAME:/tmp/local_changes.patch"
    docker exec -t "$CONTAINER_NAME" bash -c "cd /home/developer/agency-stack && git apply /tmp/local_changes.patch || echo 'Some changes could not be applied'"
  else
    echo -e "${YELLOW}No uncommitted local changes to sync.${NC}"
  fi
  
  # Clean up
  rm "$TEMP_PATCH"
fi

echo -e "${GREEN}✓ Repository initialization complete.${NC}"
echo -e "${BLUE}You can now use docker_exec_install.sh to install components.${NC}"
exit 0
