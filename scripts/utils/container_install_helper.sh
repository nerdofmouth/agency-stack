#!/bin/bash
# container_install_helper.sh - Repository-aligned container installation helper
# Following AgencyStack Charter v1.0.3 Repository Integrity Policy

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

# Validate component script exists in repository
SCRIPT_PATH="scripts/components/install_${COMPONENT}.sh"
if [ ! -f "$SCRIPT_PATH" ]; then
  echo -e "${RED}Error: Component installation script $SCRIPT_PATH not found in repository${NC}"
  exit 1
fi

echo -e "${BLUE}=== AgencyStack Repository-Aligned Container Installation ===${NC}"
echo -e "${BLUE}Following Charter v1.0.3 Repository Integrity Policy${NC}"
echo -e "${BLUE}Container: ${CYAN}${CONTAINER_NAME}${NC}"
echo -e "${BLUE}Component: ${CYAN}${COMPONENT}${NC}"
echo -e "${BLUE}Script: ${CYAN}${SCRIPT_PATH}${NC}"

# Step 1: Create temp directory in container
echo -e "${YELLOW}Creating temporary installation directory in container...${NC}"
docker exec "$CONTAINER_NAME" bash -c "mkdir -p /tmp/home/developer/agency-stack_install"

# Step 2: Copy necessary files from repository to container
echo -e "${YELLOW}Copying installation scripts to container...${NC}"

# First, copy the component script itself
docker cp "$SCRIPT_PATH" "$CONTAINER_NAME:/tmp/home/developer/agency-stack_install/$(basename "$SCRIPT_PATH")"

# Copy common utilities that might be needed
if [ -f "scripts/utils/common.sh" ]; then
  docker cp "scripts/utils/common.sh" "$CONTAINER_NAME:/tmp/home/developer/agency-stack_install/common.sh"
fi

# Copy component registry utilities if they exist
if [ -f "scripts/utils/update_component_registry.sh" ]; then
  docker cp "scripts/utils/update_component_registry.sh" "$CONTAINER_NAME:/tmp/home/developer/agency-stack_install/update_component_registry.sh"
fi

# Step 3: Create necessary directories in container
echo -e "${YELLOW}Creating necessary installation directories...${NC}"
docker exec "$CONTAINER_NAME" bash -c "mkdir -p /opt/home/developer/agency-stack/clients/default"
docker exec "$CONTAINER_NAME" bash -c "mkdir -p /var/log/home/developer/agency-stack/components"

# Step 4: Execute installation
echo -e "${YELLOW}Executing installation command...${NC}"
docker exec -t "$CONTAINER_NAME" bash -c "cd /tmp/home/developer/agency-stack_install && sudo bash $(basename "$SCRIPT_PATH") $EXTRA_ARGS"
EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
  echo -e "${GREEN}✓ Installation completed successfully${NC}"
else
  echo -e "${RED}✗ Installation failed with exit code ${EXIT_CODE}${NC}"
fi

# Step 5: Cleanup
echo -e "${YELLOW}Cleaning up temporary files...${NC}"
docker exec "$CONTAINER_NAME" bash -c "rm -rf /tmp/home/developer/agency-stack_install"

exit $EXIT_CODE
