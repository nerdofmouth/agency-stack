#!/bin/bash
# AgencyStack VM Reinstallation Script
# This script should be run on the target VM to perform a clean installation
# following the AgencyStack Alpha Phase Directives

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Log file setup
LOGDIR="/var/log/agency_stack"
mkdir -p "$LOGDIR"
LOGFILE="$LOGDIR/vm_reinstall-$(date +%Y%m%d-%H%M%S).log"

# Logging function
log() {
  echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOGFILE"
}

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Please run as root or with sudo${NC}"
  exit 1
fi

# Configure noninteractive mode for apt
export DEBIAN_FRONTEND=noninteractive

# Header
log "${MAGENTA}${BOLD}🚀 AgencyStack VM Reinstallation Script${NC}"
log "${BLUE}Following Alpha Phase Directives for client deployment${NC}"
log "${YELLOW}This will perform a clean installation of AgencyStack on this VM${NC}"
log ""

# Step 1: Update system packages
log "${CYAN}Step 1: Updating system packages...${NC}"
apt-get update -y && apt-get upgrade -y
log "${GREEN}✓ System packages updated${NC}"

# Step 2: Install git and other dependencies
log "${CYAN}Step 2: Installing git and dependencies...${NC}"
apt-get install -y git curl wget jq make sudo
log "${GREEN}✓ Git and dependencies installed${NC}"

# Step 3: Create installation directory
log "${CYAN}Step 3: Creating installation directory...${NC}"
mkdir -p /opt/agency_stack
cd /opt/agency_stack
log "${GREEN}✓ Installation directory created${NC}"

# Step 4: Clone repository
log "${CYAN}Step 4: Cloning AgencyStack repository...${NC}"
if [ -d "/opt/agency_stack/agency-stack" ]; then
  log "${YELLOW}Repository already exists. Removing...${NC}"
  rm -rf /opt/agency_stack/agency-stack
fi

git clone https://github.com/nerdofmouth/agency-stack.git
cd agency-stack
log "${GREEN}✓ Repository cloned${NC}"

# Step 5: Checkout the correct branch
log "${CYAN}Step 5: Checking out prototype-phase-client branch...${NC}"
git checkout prototype-phase-client
log "${GREEN}✓ Branch checked out${NC}"

# Step 6: Run validation check
log "${CYAN}Step 6: Running alpha-check validation...${NC}"
make alpha-check
log "${GREEN}✓ Alpha check completed${NC}"

# Step 7: Install infrastructure components
log "${CYAN}Step 7: Installing infrastructure components...${NC}"
make docker
make docker-compose
make traefik_ssl
log "${GREEN}✓ Infrastructure components installed${NC}"

# Step 8: Install SSO components
log "${CYAN}Step 8: Installing SSO components...${NC}"
make keycloak
log "${GREEN}✓ SSO components installed${NC}"

# Step 9: Install dashboard with SSO
log "${CYAN}Step 9: Installing dashboard with SSO integration...${NC}"
make dashboard --enable-keycloak
log "${GREEN}✓ Dashboard installed with SSO${NC}"

# Step 10: Install pgvector for AI readiness
log "${CYAN}Step 10: Installing pgvector for AI Agent Backend Readiness...${NC}"
make pgvector
log "${GREEN}✓ pgvector installed${NC}"

# Step 11: Install Cryptosync Vaults
log "${CYAN}Step 11: Setting up Cryptosync Vaults...${NC}"
make cryptosync
log "${GREEN}✓ Cryptosync Vaults installed${NC}"

# Step 12: Install core communication components
log "${CYAN}Step 12: Installing core communication components...${NC}"
make mailu
log "${GREEN}✓ Communication components installed${NC}"

# Step 13: Run full installation validation
log "${CYAN}Step 13: Running full validation checks...${NC}"
make vm-test-rich
log "${GREEN}✓ Validation checks completed${NC}"

# Final status report
log ""
log "${MAGENTA}${BOLD}🎉 AgencyStack VM Installation Completed${NC}"
log "${BLUE}Installation logs are available at: ${LOGFILE}${NC}"
log "${YELLOW}Use 'make dashboard-open' to access the AgencyStack dashboard${NC}"
