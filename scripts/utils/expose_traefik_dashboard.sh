#!/bin/bash
# expose_traefik_dashboard.sh
# A utility script to expose the Traefik dashboard from the development container
# This follows the AgencyStack Repository Integrity Policy

# ANSI colors
GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[0;33m"
BLUE="\033[0;34m"
RESET="\033[0m"

# Default values
DASHBOARD_PORT="${1:-8080}"
CLIENT_ID="${CLIENT_ID:-default}"

echo -e "${BLUE}============================================${RESET}"
echo -e "${BLUE}  TRAEFIK DASHBOARD PORT FORWARDING        ${RESET}"
echo -e "${BLUE}============================================${RESET}"
echo ""

# Check if we're running this on the host
if [[ ! -f /.dockerenv ]]; then
  echo -e "${YELLOW}Running on host system.${RESET}"
  
  # Create SSH port forwarding from host to development container
  echo -e "${YELLOW}Setting up port forwarding from host to container...${RESET}"
  echo -e "Port forwarding: localhost:${DASHBOARD_PORT} -> agencystack-dev:${DASHBOARD_PORT}"
  
  # Kill any existing processes using the port
  if pgrep -f "ssh.*:${DASHBOARD_PORT}:localhost:${DASHBOARD_PORT}" > /dev/null; then
    echo -e "${YELLOW}Stopping existing port forwarding...${RESET}"
    pkill -f "ssh.*:${DASHBOARD_PORT}:localhost:${DASHBOARD_PORT}"
  fi
  
  # Start forwarding in background, timeout after 8 hours for safety
  ssh -o StrictHostKeyChecking=no -p 2222 -L ${DASHBOARD_PORT}:localhost:${DASHBOARD_PORT} -N developer@localhost &
  SSH_PID=$!
  
  # Check if forwarding was successful
  sleep 2
  if kill -0 $SSH_PID 2>/dev/null; then
    echo -e "${GREEN}Port forwarding active!${RESET}"
    echo -e "Dashboard URL: ${GREEN}http://localhost:${DASHBOARD_PORT}/dashboard/${RESET}"
    echo -e "This will remain active until this terminal is closed or the process is killed."
    echo -e "Process ID: ${SSH_PID}"
  else
    echo -e "${RED}Port forwarding failed.${RESET}"
  fi
  
else
  # We're inside the Docker container
  echo -e "${YELLOW}Running inside development container.${RESET}"
  echo -e "You need to run this script on the host system, not inside the container."
  echo -e "Exit the container and run: ${GREEN}bash scripts/utils/expose_traefik_dashboard.sh${RESET}"
fi

echo ""
echo -e "${BLUE}============================================${RESET}"
echo -e "${BLUE}  TRAEFIK ACCESS INSTRUCTIONS              ${RESET}"
echo -e "${BLUE}============================================${RESET}"
echo ""
echo -e "To view Traefik dashboard:"
echo -e "1. Keep this terminal window open"
echo -e "2. Open your browser to: ${GREEN}http://localhost:${DASHBOARD_PORT}/dashboard/${RESET}"
echo -e "3. No authentication is required (development mode)"
echo ""
echo -e "To stop port forwarding:"
echo -e "- Close this terminal window, or"
echo -e "- Run: ${YELLOW}pkill -f \"ssh.*:${DASHBOARD_PORT}:localhost:${DASHBOARD_PORT}\"${RESET}"
echo ""
