#!/bin/bash
# dashboard_refresh.sh - Refresh AgencyStack Dashboard
# https://stack.nerdofmouth.com

# Colors
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Run service status generator
echo -e "${BLUE}Generating service status...${NC}"
bash "$(dirname "$0")/generate_service_status.sh"

echo -e "${GREEN}${BOLD}Dashboard refreshed!${NC}"
