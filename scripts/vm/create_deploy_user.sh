#!/bin/bash
# AgencyStack - Deploy User Creation Script
# This script creates a dedicated deployment user with proper permissions
# Run this as root on your new VM

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

# Configuration
DEPLOY_USER="deploy"
DEPLOY_GROUP="deploy"
SSH_DIR="/home/${DEPLOY_USER}/.ssh"
SUDO_NOPASSWD=true  # Set to false if you want to require password for sudo

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
  echo -e "${RED}${BOLD}Error: This script must be run as root${NC}"
  exit 1
fi

echo -e "${MAGENTA}${BOLD}🔧 Creating AgencyStack Deploy User${NC}"
echo -e "${BLUE}This script will create a dedicated user for AgencyStack deployment${NC}"
echo ""

# Create deploy group if it doesn't exist
if ! getent group ${DEPLOY_GROUP} > /dev/null; then
  echo -e "${CYAN}Creating ${DEPLOY_GROUP} group...${NC}"
  groupadd ${DEPLOY_GROUP}
  echo -e "${GREEN}✓ Group created${NC}"
else
  echo -e "${YELLOW}${DEPLOY_GROUP} group already exists${NC}"
fi

# Create deploy user if it doesn't exist
if ! id -u ${DEPLOY_USER} > /dev/null 2>&1; then
  echo -e "${CYAN}Creating ${DEPLOY_USER} user...${NC}"
  useradd -m -g ${DEPLOY_GROUP} -s /bin/bash ${DEPLOY_USER}
  echo -e "${GREEN}✓ User created${NC}"
else
  echo -e "${YELLOW}${DEPLOY_USER} user already exists${NC}"
fi

# Configure sudo access
if [ "${SUDO_NOPASSWD}" = true ]; then
  echo -e "${CYAN}Configuring passwordless sudo access...${NC}"
  echo "${DEPLOY_USER} ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/${DEPLOY_USER}
  chmod 0440 /etc/sudoers.d/${DEPLOY_USER}
  echo -e "${GREEN}✓ Passwordless sudo configured${NC}"
else
  echo -e "${CYAN}Configuring sudo access (password required)...${NC}"
  echo "${DEPLOY_USER} ALL=(ALL) ALL" > /etc/sudoers.d/${DEPLOY_USER}
  chmod 0440 /etc/sudoers.d/${DEPLOY_USER}
  echo -e "${GREEN}✓ Sudo access configured${NC}"
fi

# Create SSH directory if it doesn't exist
echo -e "${CYAN}Setting up SSH directory...${NC}"
mkdir -p ${SSH_DIR}
chmod 700 ${SSH_DIR}
touch ${SSH_DIR}/authorized_keys
chmod 600 ${SSH_DIR}/authorized_keys
chown -R ${DEPLOY_USER}:${DEPLOY_GROUP} ${SSH_DIR}
echo -e "${GREEN}✓ SSH directory configured${NC}"

# Add the SSH key
echo -e "${CYAN}Please paste your SSH public key (or press Enter to skip):${NC}"
read -r SSH_KEY

if [ -n "${SSH_KEY}" ]; then
  echo "${SSH_KEY}" >> ${SSH_DIR}/authorized_keys
  echo -e "${GREEN}✓ SSH key added${NC}"
else
  echo -e "${YELLOW}No SSH key provided. You'll need to add it manually:${NC}"
  echo -e "  ${CYAN}echo 'YOUR_SSH_KEY' >> ${SSH_DIR}/authorized_keys${NC}"
fi

# Set proper ownership for home directory
echo -e "${CYAN}Setting proper permissions...${NC}"
chown -R ${DEPLOY_USER}:${DEPLOY_GROUP} /home/${DEPLOY_USER}
echo -e "${GREEN}✓ Permissions set${NC}"

echo ""
echo -e "${MAGENTA}${BOLD}🎉 Deploy User Setup Complete${NC}"
echo -e "${BLUE}You can now SSH to this server as: ${DEPLOY_USER}@$(hostname -f)${NC}"
echo -e "${YELLOW}Use this account for all AgencyStack deployment operations${NC}"

# Print SSH connection command
echo ""
echo -e "${CYAN}SSH connection command:${NC}"
echo -e "  ssh ${DEPLOY_USER}@$(hostname -f)"

# Instructions for running the one-liner installer
echo ""
echo -e "${MAGENTA}${BOLD}Next Steps:${NC}"
echo -e "${BLUE}1. SSH into the server as the deploy user${NC}"
echo -e "${BLUE}2. Run the AgencyStack one-liner installer:${NC}"
echo -e "   ${CYAN}curl -sSL https://stack.nerdofmouth.com/install.sh | sudo bash${NC}"
