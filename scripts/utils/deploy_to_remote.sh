#!/bin/bash
# deploy_to_remote.sh - Deploy AgencyStack changes to remote VM
# Script follows the Repository Integrity Policy by ensuring all changes
# are in the repository before deploying to remote VMs

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

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
REMOTE_HOST=""
REMOTE_USER="root"
SSH_KEY=""
SSH_PORT="22"
COMPONENT=""
FORCE=false
VERBOSE=false
REMOTE_DIR="/opt/agency_stack"

# Show help
show_help() {
  echo -e "${MAGENTA}${BOLD}AgencyStack Remote Deployment${NC}"
  echo -e "=============================="
  echo -e "This script deploys AgencyStack changes to a remote VM."
  echo -e ""
  echo -e "${CYAN}Usage:${NC}"
  echo -e "  $0 [options]"
  echo -e ""
  echo -e "${CYAN}Options:${NC}"
  echo -e "  ${BOLD}--remote-host${NC} <hostname>  Remote hostname (required)"
  echo -e "  ${BOLD}--remote-user${NC} <user>      Remote username (default: root)"
  echo -e "  ${BOLD}--ssh-key${NC} <path>          Path to SSH key"
  echo -e "  ${BOLD}--ssh-port${NC} <port>         SSH port (default: 22)"
  echo -e "  ${BOLD}--component${NC} <name>        Component to deploy (e.g., keycloak)"
  echo -e "  ${BOLD}--force${NC}                   Force deployment"
  echo -e "  ${BOLD}--verbose${NC}                 Show verbose output"
  echo -e "  ${BOLD}--help${NC}                    Show this help message"
  echo -e ""
  echo -e "${CYAN}Example:${NC}"
  echo -e "  $0 --remote-host proto002.alpha.nerdofmouth.com --component keycloak"
  exit 0
}

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    --remote-host)
      REMOTE_HOST="$2"
      shift 2
      ;;
    --remote-user)
      REMOTE_USER="$2"
      shift 2
      ;;
    --ssh-key)
      SSH_KEY="$2"
      shift 2
      ;;
    --ssh-port)
      SSH_PORT="$2"
      shift 2
      ;;
    --component)
      COMPONENT="$2"
      shift 2
      ;;
    --force)
      FORCE=true
      shift
      ;;
    --verbose)
      VERBOSE=true
      shift
      ;;
    --help|-h)
      show_help
      ;;
    *)
      echo -e "${RED}Unknown option: $key${NC}"
      show_help
      ;;
  esac
done

# Validate required parameters
if [ -z "$REMOTE_HOST" ]; then
  echo -e "${RED}Error: --remote-host is required${NC}"
  show_help
fi

# Prepare SSH command
SSH_CMD="ssh"
if [ -n "$SSH_KEY" ]; then
  SSH_CMD="$SSH_CMD -i $SSH_KEY"
fi
SSH_CMD="$SSH_CMD -p $SSH_PORT $REMOTE_USER@$REMOTE_HOST"

# Check git status
echo -e "${BLUE}Checking git status...${NC}"
if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
  echo -e "${RED}Error: Not in a git repository. All changes must be tracked in git.${NC}"
  exit 1
fi

# Check for uncommitted changes
if [ "$(git status --porcelain | wc -l)" -ne 0 ]; then
  echo -e "${YELLOW}Warning: You have uncommitted changes:${NC}"
  git status --short
  echo
  if [ "$FORCE" != "true" ]; then
    read -p "Do you want to continue deployment without committing these changes? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      echo -e "${RED}Deployment aborted.${NC}"
      exit 1
    fi
  fi
fi

# Check connectivity to remote host
echo -e "${BLUE}Checking connectivity to $REMOTE_HOST...${NC}"
if ! $SSH_CMD "echo Connection successful" > /dev/null 2>&1; then
  echo -e "${RED}Error: Cannot connect to $REMOTE_HOST${NC}"
  exit 1
fi

# Get repository name and current branch
REPO_NAME=$(basename -s .git $(git config --get remote.origin.url))
BRANCH=$(git rev-parse --abbrev-ref HEAD)
echo -e "${BLUE}Deploying $REPO_NAME from branch $BRANCH to $REMOTE_HOST${NC}"

# Determine what to deploy
if [ -n "$COMPONENT" ]; then
  echo -e "${BLUE}Deploying component: $COMPONENT${NC}"
  
  # Component-specific deployment logic
  case $COMPONENT in
    keycloak)
      # Ensure remote directories exist
      $SSH_CMD "mkdir -p $REMOTE_DIR/scripts/components $REMOTE_DIR/scripts/utils $REMOTE_DIR/scripts/mock $REMOTE_DIR/docs/pages/components"
      
      # Copy updated Keycloak files
      echo -e "${BLUE}Copying Keycloak installation script...${NC}"
      scp -P $SSH_PORT scripts/components/install_keycloak.sh $REMOTE_USER@$REMOTE_HOST:$REMOTE_DIR/scripts/components/
      
      echo -e "${BLUE}Copying Keycloak utilities...${NC}"
      scp -P $SSH_PORT scripts/components/check_keycloak_idp_status.sh $REMOTE_USER@$REMOTE_HOST:$REMOTE_DIR/scripts/components/
      scp -P $SSH_PORT scripts/components/test_keycloak_idp.sh $REMOTE_USER@$REMOTE_HOST:$REMOTE_DIR/scripts/components/
      scp -P $SSH_PORT scripts/mock/mock_keycloak_idp.sh $REMOTE_USER@$REMOTE_HOST:$REMOTE_DIR/scripts/mock/
      
      echo -e "${BLUE}Copying Keycloak documentation...${NC}"
      scp -P $SSH_PORT docs/pages/components/keycloak.md $REMOTE_USER@$REMOTE_HOST:$REMOTE_DIR/docs/pages/components/
      
      echo -e "${BLUE}Copying updated Makefile...${NC}"
      scp -P $SSH_PORT Makefile $REMOTE_USER@$REMOTE_HOST:$REMOTE_DIR/
      ;;
    *)
      echo -e "${RED}Error: Unknown component $COMPONENT${NC}"
      exit 1
      ;;
  esac
else
  # Full repository deployment
  echo -e "${BLUE}Performing full repository deployment${NC}"
  
  # Check if repo exists on remote
  if ! $SSH_CMD "[ -d $REMOTE_DIR/.git ]"; then
    echo -e "${BLUE}Initializing repository on remote...${NC}"
    $SSH_CMD "mkdir -p $REMOTE_DIR && cd $REMOTE_DIR && git init"
  fi
  
  # Set up git remote on the server if needed
  REMOTE_URL="ssh://$REMOTE_USER@$REMOTE_HOST:$SSH_PORT$REMOTE_DIR"
  if ! git remote | grep -q "^remote-deploy$"; then
    echo -e "${BLUE}Adding remote-deploy remote...${NC}"
    git remote add remote-deploy $REMOTE_URL
  else
    echo -e "${BLUE}Updating remote-deploy URL...${NC}"
    git remote set-url remote-deploy $REMOTE_URL
  fi
  
  # Push to remote
  echo -e "${BLUE}Pushing changes to remote...${NC}"
  git push remote-deploy $BRANCH
  
  # Pull on remote
  echo -e "${BLUE}Pulling changes on remote...${NC}"
  $SSH_CMD "cd $REMOTE_DIR && git fetch && git checkout $BRANCH && git pull"
fi

echo -e "${GREEN}Deployment completed successfully!${NC}"
echo -e "${BLUE}Additional steps:${NC}"
echo -e "1. SSH into the remote VM: ssh $REMOTE_USER@$REMOTE_HOST -p $SSH_PORT"
echo -e "2. Navigate to the repository: cd $REMOTE_DIR"
echo -e "3. Run any necessary installation or update commands"

exit 0
