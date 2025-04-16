#!/bin/bash
# dashboard_setup.sh - Setup AgencyStack Dashboard
# https://stack.nerdofmouth.com

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Variables
CONFIG_ENV="/opt/agency_stack/config.env"
LOG_DIR="/var/log/agency_stack"
LOG_FILE="${LOG_DIR}/dashboard_setup-$(date +%Y%m%d-%H%M%S).log"
DASHBOARD_DIR="/opt/agency_stack/dashboard"
DASHBOARD_SRC_DIR="/home/revelationx/CascadeProjects/foss-server-stack/scripts/dashboard"

# Create log directory if it doesn't exist
mkdir -p "$LOG_DIR"

# Logging function
log() {
  echo -e "$1" | tee -a "$LOG_FILE"
}

log "${MAGENTA}${BOLD}🚀 AgencyStack Dashboard Setup${NC}"
log "========================================"
log "$(date)"
log "Server: $(hostname)"
log ""

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
  log "${RED}Error: Docker is not installed${NC}"
  exit 1
fi

# Check if config.env exists and source it
if [ -f "$CONFIG_ENV" ]; then
  source "$CONFIG_ENV"
else
  log "${YELLOW}Warning: config.env not found, some features may not work correctly${NC}"
  log "Creating default config.env with PRIMARY_DOMAIN=example.com"
  
  mkdir -p /opt/agency_stack
  echo "PRIMARY_DOMAIN=example.com" > "$CONFIG_ENV"
  source "$CONFIG_ENV"
fi

# Create dashboard directory
log "${BLUE}Creating dashboard directory...${NC}"
mkdir -p "$DASHBOARD_DIR"

# Copy dashboard files
log "${BLUE}Copying dashboard files...${NC}"
cp -r "$DASHBOARD_SRC_DIR"/* "$DASHBOARD_DIR/"

# Run service status generator
log "${BLUE}Generating service status...${NC}"
bash "/home/revelationx/CascadeProjects/foss-server-stack/scripts/generate_service_status.sh"

# Check if agency_stack_network exists, create if it doesn't
if ! docker network inspect agency_stack_network &>/dev/null; then
  log "${BLUE}Creating agency_stack_network...${NC}"
  docker network create agency_stack_network
fi

# Deploy dashboard container
log "${BLUE}Deploying dashboard container...${NC}"
cd /home/revelationx/CascadeProjects/foss-server-stack

# Set environment variable for docker-compose
export PRIMARY_DOMAIN="${PRIMARY_DOMAIN}"

# Stop existing container if running
if docker ps -a --format '{{.Names}}' | grep -q "agency_stack_dashboard"; then
  log "${BLUE}Stopping existing dashboard container...${NC}"
  docker-compose -f docker-compose.dashboard.yml down
fi

# Start dashboard container
log "${BLUE}Starting dashboard container...${NC}"
docker-compose -f docker-compose.dashboard.yml up -d

# Check if container is running
if docker ps --format '{{.Names}}' | grep -q "agency_stack_dashboard"; then
  log "${GREEN}Dashboard container is running${NC}"
  log "${GREEN}Dashboard is available at: https://dashboard.${PRIMARY_DOMAIN}${NC}"
else
  log "${RED}Failed to start dashboard container${NC}"
  exit 1
fi

log ""
log "${GREEN}${BOLD}Dashboard setup complete!${NC}"
log "Dashboard URL: https://dashboard.${PRIMARY_DOMAIN}"
log "You may need to wait a few moments for Traefik to provision the SSL certificate."
