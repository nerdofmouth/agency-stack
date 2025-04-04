#!/bin/bash
# dashboard_enable.sh - Enable AgencyStack Dashboard
# https://stack.nerdofmouth.com

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color
BOLD='\033[1m'

echo -e "${BLUE}${BOLD}🚀 Enabling AgencyStack Dashboard${NC}"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Error: This script must be run as root${NC}"
  exit 1
fi

# Run dashboard setup
bash "$(dirname "$0")/dashboard_setup.sh"

# Add dashboard component to installed components
INSTALLED_COMPONENTS_FILE="/opt/agency_stack/installed_components.txt"
if [ -f "$INSTALLED_COMPONENTS_FILE" ]; then
  if ! grep -q "Dashboard" "$INSTALLED_COMPONENTS_FILE"; then
    echo "Dashboard" >> "$INSTALLED_COMPONENTS_FILE"
    echo -e "${GREEN}Added Dashboard to installed components list${NC}"
  fi
fi

echo -e "${GREEN}${BOLD}Dashboard is now enabled!${NC}"
