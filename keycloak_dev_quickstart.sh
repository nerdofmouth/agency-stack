#!/bin/bash
# keycloak_dev_quickstart.sh - Complete rebuild and Keycloak setup
# Follows AgencyStack Repository Integrity Policy

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color
BOLD='\033[1m'

echo -e "${BLUE}${BOLD}==================================================================${NC}"
echo -e "${BLUE}${BOLD}   AgencyStack Keycloak Development Container Quickstart          ${NC}"
echo -e "${BLUE}${BOLD}   Following Repository Integrity Policy Guidelines               ${NC}"
echo -e "${BLUE}${BOLD}==================================================================${NC}"

# Check if there are uncommitted changes
if [[ -n $(git status -s) ]]; then
  echo -e "${YELLOW}WARNING: You have uncommitted changes.${NC}"
  echo -e "Following the Repository Integrity Policy, all changes should be committed."
  read -p "Commit these changes before proceeding? (y/n): " COMMIT_CHANGES
  
  if [[ "$COMMIT_CHANGES" =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}Committing changes...${NC}"
    git add .
    read -p "Enter commit message: " COMMIT_MSG
    git commit -m "$COMMIT_MSG"
    
    echo -e "${BLUE}Pushing changes to remote repository...${NC}"
    git push origin main
  else
    echo -e "${YELLOW}Proceeding without committing changes.${NC}"
    echo -e "${YELLOW}Note: This deviates from best practices in the Repository Integrity Policy.${NC}"
  fi
fi

# Step 1: Destroy the existing container
echo -e "${BLUE}Step 1/5: Cleaning up existing container...${NC}"
docker stop agencystack-dev 2>/dev/null || true
docker rm agencystack-dev 2>/dev/null || true
docker rmi agencystack-dev-image 2>/dev/null || true

# Step 2: Run the container setup script
echo -e "${BLUE}Step 2/5: Starting fresh development container...${NC}"
./run_dev_container.sh

# Step 3: Wait for the container to be fully up
echo -e "${BLUE}Step 3/5: Waiting for container to initialize...${NC}"
sleep 5

# Step 4: Generate SSH commands to setup Keycloak
echo -e "${BLUE}Step 4/5: Preparing Keycloak setup...${NC}"
SSH_KEYCLOAK_SETUP="cd ~/projects/agency-stack && bash /home/developer/shared_data/setup_keycloak_dev.sh"

# Display SSH command to run manually
echo -e "${GREEN}${BOLD}==================================================================${NC}"
echo -e "${GREEN}${BOLD}   Development container is ready!                                ${NC}"
echo -e "${GREEN}${BOLD}==================================================================${NC}"
echo -e "${YELLOW}To complete Keycloak setup, SSH into the container and run:${NC}"
echo -e ""
echo -e "   ${BLUE}ssh developer@localhost -p 2222${NC} # Password: agencystack"
echo -e "   ${BLUE}$SSH_KEYCLOAK_SETUP${NC}"
echo -e ""
echo -e "${YELLOW}Once setup is complete, access Keycloak at:${NC}"
echo -e "   ${BLUE}http://localhost.test/auth/${NC} or ${BLUE}http://localhost:8080/auth/${NC}"
echo -e ""
echo -e "${GREEN}${BOLD}==================================================================${NC}"
echo -e "${GREEN}${BOLD}   Repository Integrity Policy Reminder:                          ${NC}"
echo -e "${GREEN}${BOLD}==================================================================${NC}"
echo -e "   ${YELLOW}1. Make changes to local repo only${NC}"
echo -e "   ${YELLOW}2. Commit and push changes to remote repo${NC}"
echo -e "   ${YELLOW}3. Pull changes inside the container${NC}"
echo -e "   ${YELLOW}4. Test with make commands${NC}"
echo -e "${GREEN}${BOLD}==================================================================${NC}"
