#!/bin/bash
# remote_installer.sh - Utility for executing installation operations remotely
# Following AgencyStack Charter v1.0.3 Remote Operation Imperatives
# 
# This script automates the execution of installation scripts inside containers
# or remote VMs while maintaining repository integrity.

set -e

# Define colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Script directory and root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

# Source common utilities if available
if [ -f "$REPO_ROOT/scripts/utils/common.sh" ]; then
  source "$REPO_ROOT/scripts/utils/common.sh"
else
  log() {
    local level="$1"
    local message="$2"
    local color_message="${3:-$message}"
    echo -e "${color_message}"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [$level] $message" >> "/var/log/agency_stack/remote_installer.log"
  }
fi

# Default values
CONTAINER_NAME=""
SSH_HOST=""
SSH_PORT="22"
SSH_USER="root"
COMPONENT=""
TIMEOUT=300
WORKDIR=""
EXTRA_ARGS=""
DRY_RUN=false
VERBOSE=false

# Help function
usage() {
  echo "Usage: $0 [OPTIONS] --component COMPONENT [--args \"EXTRA_ARGS\"]"
  echo ""
  echo "Executes installation operations remotely following AgencyStack Charter v1.0.3"
  echo ""
  echo "Options:"
  echo "  --container CONTAINER_NAME   Execute in Docker container"
  echo "  --ssh-host HOST              Execute via SSH on remote host"
  echo "  --ssh-port PORT              SSH port (default: 22)"
  echo "  --ssh-user USER              SSH user (default: root)"
  echo "  --component COMPONENT        Component to install (required)"
  echo "  --workdir DIR                Working directory (default: repository root)"
  echo "  --args \"ARGS\"                Extra arguments to pass to installation script"
  echo "  --timeout SECONDS            Command timeout in seconds (default: 300)"
  echo "  --dry-run                    Print command but don't execute"
  echo "  --verbose                    Print detailed information"
  echo "  --help                       Show this help message"
  exit 1
}

# Process command-line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --container)
      CONTAINER_NAME="$2"
      shift 2
      ;;
    --ssh-host)
      SSH_HOST="$2"
      shift 2
      ;;
    --ssh-port)
      SSH_PORT="$2"
      shift 2
      ;;
    --ssh-user)
      SSH_USER="$2"
      shift 2
      ;;
    --component)
      COMPONENT="$2"
      shift 2
      ;;
    --workdir)
      WORKDIR="$2"
      shift 2
      ;;
    --args)
      EXTRA_ARGS="$2"
      shift 2
      ;;
    --timeout)
      TIMEOUT="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --verbose)
      VERBOSE=true
      shift
      ;;
    --help)
      usage
      ;;
    *)
      echo "Unknown option: $1"
      usage
      ;;
  esac
done

# Validate required parameters
if [[ -z "$COMPONENT" ]]; then
  log "ERROR" "Component parameter is required" "${RED}ERROR: Component parameter is required${NC}"
  usage
fi

if [[ -z "$CONTAINER_NAME" && -z "$SSH_HOST" ]]; then
  log "ERROR" "Either --container or --ssh-host is required" "${RED}ERROR: Either --container or --ssh-host is required${NC}"
  usage
fi

if [[ -n "$CONTAINER_NAME" && -n "$SSH_HOST" ]]; then
  log "ERROR" "Cannot specify both --container and --ssh-host" "${RED}ERROR: Cannot specify both --container and --ssh-host${NC}"
  usage
fi

# Set default working directory if not specified
if [[ -z "$WORKDIR" ]]; then
  if [[ -n "$CONTAINER_NAME" ]]; then
    # For containers, assume repository is at /home/developer/agency-stack
    WORKDIR="/home/developer/agency-stack"
  else
    # For SSH, use current repo root
    WORKDIR="$REPO_ROOT"
  fi
fi

# Construct installation command
INSTALL_CMD="cd $WORKDIR && sudo bash scripts/components/install_${COMPONENT}.sh $EXTRA_ARGS"

# Execution function for Docker container
exec_in_container() {
  log "INFO" "Executing in container: $CONTAINER_NAME" "${BLUE}Executing in container: $CONTAINER_NAME${NC}"
  log "INFO" "Command: $INSTALL_CMD" "${CYAN}Command: $INSTALL_CMD${NC}"
  
  if [[ "$DRY_RUN" == "true" ]]; then
    log "INFO" "DRY RUN - Command would be: docker exec -t $CONTAINER_NAME bash -c \"$INSTALL_CMD\"" "${YELLOW}DRY RUN - Command would be: docker exec -t $CONTAINER_NAME bash -c \"$INSTALL_CMD\"${NC}"
    return 0
  fi

  # Validate container exists
  if ! docker ps -q -f name="$CONTAINER_NAME" | grep -q .; then
    log "ERROR" "Container $CONTAINER_NAME does not exist or is not running" "${RED}ERROR: Container $CONTAINER_NAME does not exist or is not running${NC}"
    return 1
  fi

  # Execute with timeout
  log "INFO" "Starting execution with $TIMEOUT second timeout" "${BLUE}Starting execution with $TIMEOUT second timeout${NC}"
  timeout $TIMEOUT docker exec -t "$CONTAINER_NAME" bash -c "$INSTALL_CMD"
  EXIT_CODE=$?
  
  if [[ $EXIT_CODE -eq 124 ]]; then
    log "ERROR" "Command timed out after $TIMEOUT seconds" "${RED}ERROR: Command timed out after $TIMEOUT seconds${NC}"
    return 1
  elif [[ $EXIT_CODE -ne 0 ]]; then
    log "ERROR" "Command failed with exit code $EXIT_CODE" "${RED}ERROR: Command failed with exit code $EXIT_CODE${NC}"
    return $EXIT_CODE
  fi
  
  log "SUCCESS" "Command completed successfully" "${GREEN}SUCCESS: Command completed successfully${NC}"
  return 0
}

# Execution function for SSH
exec_via_ssh() {
  log "INFO" "Executing via SSH: $SSH_USER@$SSH_HOST:$SSH_PORT" "${BLUE}Executing via SSH: $SSH_USER@$SSH_HOST:$SSH_PORT${NC}"
  log "INFO" "Command: $INSTALL_CMD" "${CYAN}Command: $INSTALL_CMD${NC}"
  
  if [[ "$DRY_RUN" == "true" ]]; then
    log "INFO" "DRY RUN - Command would be: ssh -p $SSH_PORT $SSH_USER@$SSH_HOST \"$INSTALL_CMD\"" "${YELLOW}DRY RUN - Command would be: ssh -p $SSH_PORT $SSH_USER@$SSH_HOST \"$INSTALL_CMD\"${NC}"
    return 0
  fi

  # Execute with timeout
  log "INFO" "Starting execution with $TIMEOUT second timeout" "${BLUE}Starting execution with $TIMEOUT second timeout${NC}"
  timeout $TIMEOUT ssh -p "$SSH_PORT" "$SSH_USER@$SSH_HOST" "$INSTALL_CMD"
  EXIT_CODE=$?
  
  if [[ $EXIT_CODE -eq 124 ]]; then
    log "ERROR" "Command timed out after $TIMEOUT seconds" "${RED}ERROR: Command timed out after $TIMEOUT seconds${NC}"
    return 1
  elif [[ $EXIT_CODE -ne 0 ]]; then
    log "ERROR" "Command failed with exit code $EXIT_CODE" "${RED}ERROR: Command failed with exit code $EXIT_CODE${NC}"
    return $EXIT_CODE
  fi
  
  log "SUCCESS" "Command completed successfully" "${GREEN}SUCCESS: Command completed successfully${NC}"
  return 0
}

# Main execution
log "INFO" "=== AgencyStack Remote Installer ==="
log "INFO" "Component: $COMPONENT"
log "INFO" "Following Charter v1.0.3 Remote Operation Imperatives"

if [[ -n "$CONTAINER_NAME" ]]; then
  exec_in_container
  EXIT_CODE=$?
else
  exec_via_ssh
  EXIT_CODE=$?
fi

exit $EXIT_CODE
