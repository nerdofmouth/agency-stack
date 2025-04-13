#!/bin/bash
# AgencyStack - SSH Setup Script for proto002.alpha.nerdofmouth.com
# This script configures password-free SSH access to the VM

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

# VM details
VM_HOST="agency.proto002.nerdofmouth.com"
SSH_USER=${1:-"ubuntu"}  # Default to ubuntu, but allow override
SSH_KEY_PATH="${HOME}/.ssh/id_rsa_agencystack"

# Ensure SSH directory exists
mkdir -p ${HOME}/.ssh
chmod 700 ${HOME}/.ssh

echo -e "${MAGENTA}${BOLD}🔑 Setting up SSH for ${VM_HOST}${NC}"
echo -e "${BLUE}This will configure password-free SSH access to your new VM${NC}"
echo -e "${YELLOW}Using key: ${SSH_KEY_PATH}${NC}"
echo ""

# Create SSH config entry if it doesn't exist
if ! grep -q "Host ${VM_HOST}" ${HOME}/.ssh/config 2>/dev/null; then
  echo -e "${CYAN}Creating SSH config entry for ${VM_HOST}...${NC}"
  cat >> ${HOME}/.ssh/config << EOF

# AgencyStack VM - proto002
Host ${VM_HOST}
  HostName ${VM_HOST}
  User ${SSH_USER}
  IdentityFile ${SSH_KEY_PATH}
  ForwardAgent yes
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null
EOF
  echo -e "${GREEN}✓ SSH config entry created${NC}"
else
  echo -e "${YELLOW}SSH config entry for ${VM_HOST} already exists${NC}"
fi

echo ""
echo -e "${CYAN}SSH Key to copy to your VM:${NC}"
cat ${SSH_KEY_PATH}.pub
echo ""

echo -e "${MAGENTA}${BOLD}📋 Instructions:${NC}"
echo -e "${BLUE}1. When your new VM is ready, copy the SSH key above${NC}"
echo -e "${BLUE}2. Add it to the authorized_keys file on your VM:${NC}"
echo -e "   ${CYAN}mkdir -p ~/.ssh && chmod 700 ~/.ssh${NC}"
echo -e "   ${CYAN}echo 'YOUR_SSH_KEY_HERE' >> ~/.ssh/authorized_keys${NC}"
echo -e "   ${CYAN}chmod 600 ~/.ssh/authorized_keys${NC}"
echo ""
echo -e "${BLUE}3. Test the connection:${NC}"
echo -e "   ${CYAN}ssh ${VM_HOST}${NC}"
echo ""
echo -e "${YELLOW}Alternatively, you can use ssh-copy-id to copy your key to the VM:${NC}"
echo -e "   ${CYAN}ssh-copy-id -i ${SSH_KEY_PATH} ${SSH_USER}@${VM_HOST}${NC}"
echo ""
echo -e "${GREEN}${BOLD}Once complete, you'll be able to SSH without a password and use the stack-connect utility${NC}"
