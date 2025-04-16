#!/bin/bash
# dashboard.sh - Open AgencyStack Dashboard
# https://stack.nerdofmouth.com

# Colors
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Variables
CONFIG_ENV="/opt/agency_stack/config.env"

# Check if config.env exists and source it
if [ -f "$CONFIG_ENV" ]; then
  source "$CONFIG_ENV"
else
  echo -e "${YELLOW}Warning: config.env not found, using default domain${NC}"
  PRIMARY_DOMAIN="example.com"
fi

# Check if the dashboard container is running
if docker ps --format '{{.Names}}' | grep -q "agency_stack_dashboard"; then
  echo -e "${GREEN}Dashboard is running${NC}"
  
  # Get system default browser
  if command -v xdg-open &> /dev/null; then
    BROWSER="xdg-open"
  elif command -v open &> /dev/null; then
    BROWSER="open"
  else
    BROWSER=""
  fi
  
  # Open dashboard in browser if possible
  if [ -n "$BROWSER" ]; then
    echo -e "${BLUE}Opening dashboard in browser...${NC}"
    $BROWSER "https://dashboard.${PRIMARY_DOMAIN}"
  else
    echo -e "${GREEN}${BOLD}Dashboard URL: https://dashboard.${PRIMARY_DOMAIN}${NC}"
    echo -e "Copy and paste this URL into your browser to access the dashboard."
  fi
else
  echo -e "${YELLOW}Dashboard is not running. Would you like to enable it now? (y/n)${NC}"
  read -r answer
  
  if [[ "$answer" =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}Enabling dashboard...${NC}"
    bash "$(dirname "$0")/dashboard_enable.sh"
  else
    echo -e "${YELLOW}Dashboard not enabled. Run 'make dashboard-enable' to set it up.${NC}"
  fi
fi
