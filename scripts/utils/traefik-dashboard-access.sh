#!/bin/bash
# traefik-dashboard-access.sh - Host-side script to test Traefik dashboard access
# This script executes tests both on the host and in the container

# ANSI color codes
GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[0;33m"
BLUE="\033[0;34m"
RESET="\033[0m"

echo -e "${BLUE}============================================${RESET}"
echo -e "${BLUE}  TRAEFIK DASHBOARD ACCESS DIAGNOSTICS      ${RESET}"
echo -e "${BLUE}============================================${RESET}"
echo ""

# Test host-side access
echo -e "${YELLOW}Testing access from host system:${RESET}"
echo -e "${YELLOW}------------------------------${RESET}"

# Test direct access on port 8080
echo -e "Direct access (port 8080): "
if curl -s --head --fail http://localhost:8080/dashboard/ > /dev/null; then
  echo -e "${GREEN}✓ Success${RESET}"
else
  echo -e "${RED}✗ Failed${RESET}"
fi

# Test port-forwarded access on port 80
echo -e "Port-forwarded access (port 80): "
if curl -s --head --fail http://localhost/dashboard/ > /dev/null; then
  echo -e "${GREEN}✓ Success${RESET}"
else
  echo -e "${RED}✗ Failed${RESET}"
fi
echo ""

# Test container-side access
echo -e "${YELLOW}Testing access from within container:${RESET}"
echo -e "${YELLOW}-----------------------------------${RESET}"
echo -e "Running tests inside container..."
docker exec -it --user developer agencystack-dev zsh -c "cd /home/developer/agency-stack && bash /opt/agency_stack/clients/default/traefik/test-connection.sh" || echo -e "${RED}Failed to run tests in container${RESET}"

echo ""
echo -e "${BLUE}============================================${RESET}"
echo -e "${BLUE}  DASHBOARD ACCESS INSTRUCTIONS            ${RESET}"
echo -e "${BLUE}============================================${RESET}"
echo ""
echo -e "Access the Traefik dashboard using either:"
echo -e "  1. ${YELLOW}http://localhost:8080/dashboard/${RESET} (direct port)"
echo -e "  2. ${YELLOW}http://localhost/dashboard/${RESET} (port forwarded)"
echo ""
echo -e "If one method doesn't work, try the other."
echo ""
echo -e "${YELLOW}Note:${RESET} The dashboard requires no authentication (development mode)"
echo ""
