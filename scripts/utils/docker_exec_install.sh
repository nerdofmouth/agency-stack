#!/bin/bash
# docker_exec_install.sh - Simple utility for executing installation commands in Docker containers
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
COMPONENT=""
EXTRA_ARGS=""
DRY_RUN=false

# Process arguments
if [ $# -lt 2 ]; then
  echo -e "${RED}Usage: $0 CONTAINER_NAME COMPONENT [EXTRA_ARGS]${NC}"
  echo -e "${BLUE}Example: $0 agencystack-dev wordpress \"--force --domain localhost\"${NC}"
  exit 1
fi

CONTAINER_NAME="$1"
COMPONENT="$2"
if [ $# -gt 2 ]; then
  EXTRA_ARGS="$3"
fi

# Validate container exists and is running
if ! docker ps -q -f name="$CONTAINER_NAME" | grep -q .; then
  echo -e "${RED}Error: Container $CONTAINER_NAME does not exist or is not running${NC}"
  exit 1
fi

# Define command to execute inside container
CMD="cd /home/developer/agency-stack && sudo bash scripts/components/install_${COMPONENT}.sh ${EXTRA_ARGS}"

# Display information
echo -e "${BLUE}=== AgencyStack Remote Installer ===${NC}"
echo -e "${BLUE}Following Charter v1.0.3 Remote Operation Imperatives${NC}"
echo -e "${BLUE}Container: ${CYAN}${CONTAINER_NAME}${NC}"
echo -e "${BLUE}Component: ${CYAN}${COMPONENT}${NC}"
echo -e "${BLUE}Command: ${CYAN}${CMD}${NC}"

# Execute command
echo -e "${YELLOW}Executing installation command...${NC}"
docker exec -t "$CONTAINER_NAME" bash -c "$CMD"
EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
  echo -e "${GREEN}Success: Installation completed successfully${NC}"
else
  echo -e "${RED}Error: Installation failed with exit code ${EXIT_CODE}${NC}"
fi

exit $EXIT_CODE
