#!/bin/bash
# config_snapshot.sh - Git-based configuration management for AgencyStack
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
CONFIG_REPO_DIR="/opt/agency_config"
CONFIG_SRC_DIR="/opt/agency_stack"
LOG_DIR="/var/log/agency_stack"
LOG_FILE="${LOG_DIR}/config_snapshot-$(date +%Y%m%d-%H%M%S).log"

# Create log directory if it doesn't exist
mkdir -p "$LOG_DIR"

# Logging function
log() {
  echo -e "$1" | tee -a "$LOG_FILE"
}

# Check dependencies
check_dependencies() {
  local missing_deps=0
  
  # Check for git
  if ! command -v git &> /dev/null; then
    log "${RED}Error: git is not installed${NC}"
    log "Please install git: apt-get install -y git"
    missing_deps=1
  fi
  
  # Check for necessary commands
  for cmd in find mkdir cp awk grep; do
    if ! command -v $cmd &> /dev/null; then
      log "${RED}Error: $cmd is not installed${NC}"
      missing_deps=1
    fi
  done
  
  # Check if we have write access to the config directory
  if [ ! -w "/opt" ]; then
    log "${RED}Error: No write permission to /opt${NC}"
    log "Please run this script with sudo"
    missing_deps=1
  fi
  
  # Check if AgencyStack is installed
  if [ ! -d "$CONFIG_SRC_DIR" ]; then
    log "${RED}Error: AgencyStack installation directory not found: $CONFIG_SRC_DIR${NC}"
    log "Please ensure AgencyStack is installed"
    missing_deps=1
  fi
  
  if [ $missing_deps -eq 1 ]; then
    return 1
  fi
  
  return 0
}

# Function to initialize the git repository
init_repo() {
  log "${BLUE}Initializing git repository for configuration management...${NC}"
  
  # Create directory if it doesn't exist
  mkdir -p "$CONFIG_REPO_DIR"
  
  # Initialize git repo if not already done
  if [ ! -d "$CONFIG_REPO_DIR/.git" ]; then
    cd "$CONFIG_REPO_DIR"
    git init
    git config user.name "AgencyStack Config Manager"
    git config user.email "noreply@agencystack.local"
    echo "# AgencyStack Configuration Repository" > README.md
    echo "This repository contains configuration snapshots for AgencyStack." >> README.md
    echo "Created: $(date)" >> README.md
    echo "Server: $(hostname)" >> README.md
    echo "" >> README.md
    echo "## Structure" >> README.md
    echo "- config/ - Contains all configuration files" >> README.md
    echo "- .env - Environment variables" >> README.md
    echo "- docker-compose.yml - Docker Compose configurations" >> README.md
    git add README.md
    git commit -m "Initial commit"
    log "${GREEN}Repository initialized successfully${NC}"
  else
    log "${YELLOW}Repository already initialized${NC}"
  fi
}

# Function to take a snapshot of the current configuration
take_snapshot() {
  local message="$1"
  
  # Default commit message if not provided
  if [ -z "$message" ]; then
    message="Configuration snapshot taken on $(date)"
  fi
  
  log "${BLUE}Taking configuration snapshot...${NC}"
  
  # Create config directories
  mkdir -p "$CONFIG_REPO_DIR/config"
  mkdir -p "$CONFIG_REPO_DIR/data-structure"
  
  # Copy all configuration files
  log "${BLUE}Copying configuration files...${NC}"
  
  # Copy .env files
  find "$CONFIG_SRC_DIR" -name "*.env" -type f -not -path "*/\.*" | while read -r file; do
    rel_path="${file#$CONFIG_SRC_DIR/}"
    target_dir="$(dirname "$CONFIG_REPO_DIR/$rel_path")"
    mkdir -p "$target_dir"
    cp "$file" "$CONFIG_REPO_DIR/$rel_path"
    log "${CYAN}Copied: $rel_path${NC}"
  done
  
  # Copy docker-compose files
  find "$CONFIG_SRC_DIR" -name "docker-compose*.yml" -type f -not -path "*/\.*" | while read -r file; do
    rel_path="${file#$CONFIG_SRC_DIR/}"
    target_dir="$(dirname "$CONFIG_REPO_DIR/$rel_path")"
    mkdir -p "$target_dir"
    cp "$file" "$CONFIG_REPO_DIR/$rel_path"
    log "${CYAN}Copied: $rel_path${NC}"
  done
  
  # Copy traefik configuration
  if [ -d "$CONFIG_SRC_DIR/config/traefik" ]; then
    mkdir -p "$CONFIG_REPO_DIR/config/traefik"
    cp -r "$CONFIG_SRC_DIR/config/traefik"/* "$CONFIG_REPO_DIR/config/traefik/"
    log "${CYAN}Copied: traefik configuration${NC}"
  fi
  
  # Copy other important configuration files
  for dir in config/nginx config/loki config/grafana config/mailu; do
    if [ -d "$CONFIG_SRC_DIR/$dir" ]; then
      mkdir -p "$CONFIG_REPO_DIR/$dir"
      cp -r "$CONFIG_SRC_DIR/$dir"/*.{yml,yaml,conf,json,toml} "$CONFIG_REPO_DIR/$dir/" 2>/dev/null || true
      log "${CYAN}Copied: $dir configuration${NC}"
    fi
  done
  
  # Create a data structure overview (don't copy actual data, just structure)
  find "$CONFIG_SRC_DIR/data" -type d -not -path "*/\.*" | sort | while read -r dir; do
    rel_path="${dir#$CONFIG_SRC_DIR/}"
    echo "$rel_path" >> "$CONFIG_REPO_DIR/data-structure/directories.txt"
  done
  log "${CYAN}Created data directory structure overview${NC}"
  
  # Copy installed_components.txt if it exists
  if [ -f "$CONFIG_SRC_DIR/installed_components.txt" ]; then
    cp "$CONFIG_SRC_DIR/installed_components.txt" "$CONFIG_REPO_DIR/"
    log "${CYAN}Copied: installed_components.txt${NC}"
  fi
  
  # Copy scripts directory structure (but not the scripts themselves to keep the repo small)
  find "$CONFIG_SRC_DIR/scripts" -type d -not -path "*/\.*" | sort | while read -r dir; do
    rel_path="${dir#$CONFIG_SRC_DIR/}"
    echo "$rel_path" >> "$CONFIG_REPO_DIR/data-structure/scripts.txt"
  done
  
  # Commit changes
  cd "$CONFIG_REPO_DIR"
  git add .
  
  # Check if there are changes to commit
  if git diff-index --quiet HEAD --; then
    log "${YELLOW}No changes detected since last snapshot${NC}"
  else
    git commit -m "$message"
    log "${GREEN}✅ Snapshot committed successfully:${NC} $message"
    
    # Show changes
    log "${BLUE}Changes in this snapshot:${NC}"
    git show --name-status HEAD | tee -a "$LOG_FILE"
  fi
}

# Function to list available snapshots
list_snapshots() {
  if [ ! -d "$CONFIG_REPO_DIR/.git" ]; then
    log "${RED}No configuration repository found.${NC}"
    log "Run 'make config-snapshot' first to create one."
    return 1
  fi
  
  log "${BLUE}Available configuration snapshots:${NC}"
  cd "$CONFIG_REPO_DIR"
  git log --pretty=format:"%h - %cd - %s" --date=format:"%Y-%m-%d %H:%M:%S" | tee -a "$LOG_FILE"
}

# Function to show diff between snapshots
show_diff() {
  local commit1="$1"
  local commit2="$2"
  
  if [ ! -d "$CONFIG_REPO_DIR/.git" ]; then
    log "${RED}No configuration repository found.${NC}"
    log "Run 'make config-snapshot' first to create one."
    return 1
  fi
  
  if [ -z "$commit1" ]; then
    log "${RED}Error: Commit hash required${NC}"
    log "Usage: $0 diff <commit1> [commit2]"
    return 1
  fi
  
  cd "$CONFIG_REPO_DIR"
  
  if [ -z "$commit2" ]; then
    log "${BLUE}Showing changes in commit $commit1:${NC}"
    git show "$commit1" | tee -a "$LOG_FILE"
  else
    log "${BLUE}Showing differences between $commit1 and $commit2:${NC}"
    git diff "$commit1" "$commit2" | tee -a "$LOG_FILE"
  fi
}

# Function to rollback to a specific commit
rollback() {
  local commit="$1"
  
  if [ ! -d "$CONFIG_REPO_DIR/.git" ]; then
    log "${RED}No configuration repository found.${NC}"
    log "Run 'make config-snapshot' first to create one."
    return 1
  fi
  
  if [ -z "$commit" ]; then
    log "${RED}Error: Commit hash required${NC}"
    log "Usage: $0 rollback <commit>"
    return 1
  fi
  
  log "${YELLOW}WARNING: You are about to roll back the configuration to a previous state.${NC}"
  log "${YELLOW}This will overwrite your current configuration files.${NC}"
  read -p "Are you sure you want to continue? [y/N] " -n 1 -r
  echo
  
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log "${YELLOW}Rollback cancelled${NC}"
    return 1
  fi
  
  cd "$CONFIG_REPO_DIR"
  
  # Verify commit exists
  if ! git cat-file -e "$commit^{commit}" 2>/dev/null; then
    log "${RED}Error: Commit $commit does not exist${NC}"
    return 1
  fi
  
  # Create backup of current state
  take_snapshot "Automatic snapshot before rollback to $commit"
  
  log "${BLUE}Rolling back to $commit...${NC}"
  
  # Check out the specific commit to a temporary branch
  git checkout -b temp-rollback "$commit"
  
  # Copy files back to the original location
  log "${BLUE}Restoring configuration files...${NC}"
  
  # Copy .env files
  find "$CONFIG_REPO_DIR" -name "*.env" -type f -not -path "*/\.*" | while read -r file; do
    rel_path="${file#$CONFIG_REPO_DIR/}"
    target_file="$CONFIG_SRC_DIR/$rel_path"
    target_dir="$(dirname "$target_file")"
    mkdir -p "$target_dir"
    cp "$file" "$target_file"
    log "${CYAN}Restored: $rel_path${NC}"
  done
  
  # Copy docker-compose files
  find "$CONFIG_REPO_DIR" -name "docker-compose*.yml" -type f -not -path "*/\.*" | while read -r file; do
    rel_path="${file#$CONFIG_REPO_DIR/}"
    target_file="$CONFIG_SRC_DIR/$rel_path"
    target_dir="$(dirname "$target_file")"
    mkdir -p "$target_dir"
    cp "$file" "$target_file"
    log "${CYAN}Restored: $rel_path${NC}"
  done
  
  # Copy traefik configuration if it exists
  if [ -d "$CONFIG_REPO_DIR/config/traefik" ]; then
    mkdir -p "$CONFIG_SRC_DIR/config/traefik"
    cp -r "$CONFIG_REPO_DIR/config/traefik"/* "$CONFIG_SRC_DIR/config/traefik/"
    log "${CYAN}Restored: traefik configuration${NC}"
  fi
  
  # Copy other configuration directories if they exist
  for dir in config/nginx config/loki config/grafana config/mailu; do
    if [ -d "$CONFIG_REPO_DIR/$dir" ]; then
      mkdir -p "$CONFIG_SRC_DIR/$dir"
      cp -r "$CONFIG_REPO_DIR/$dir"/* "$CONFIG_SRC_DIR/$dir/" 2>/dev/null || true
      log "${CYAN}Restored: $dir configuration${NC}"
    fi
  done
  
  # Copy installed_components.txt if it exists
  if [ -f "$CONFIG_REPO_DIR/installed_components.txt" ]; then
    cp "$CONFIG_REPO_DIR/installed_components.txt" "$CONFIG_SRC_DIR/"
    log "${CYAN}Restored: installed_components.txt${NC}"
  fi
  
  # Go back to the main branch
  git checkout master || git checkout main
  git branch -D temp-rollback
  
  log "${GREEN}✅ Configuration rolled back successfully to commit: $commit${NC}"
  log "${YELLOW}You may need to restart services for the configuration changes to take effect${NC}"
  log "${YELLOW}Consider running: docker-compose restart${NC}"
}

# Main function
main() {
  check_dependencies
  
  if [ $? -ne 0 ]; then
    exit 1
  fi
  
  local command="$1"
  shift
  
  case "$command" in
    init)
      init_repo
      ;;
    snapshot)
      # Check if repo exists, initialize if not
      if [ ! -d "$CONFIG_REPO_DIR/.git" ]; then
        init_repo
      fi
      take_snapshot "$1"
      ;;
    list)
      list_snapshots
      ;;
    diff)
      show_diff "$1" "$2"
      ;;
    rollback)
      rollback "$1"
      ;;
    *)
      echo "Usage: $0 <command> [options]"
      echo
      echo "Commands:"
      echo "  init            Initialize configuration repository"
      echo "  snapshot [msg]  Take a snapshot of current configuration"
      echo "  list            List available snapshots"
      echo "  diff <hash>     Show changes in a specific commit"
      echo "  diff <h1> <h2>  Show differences between two commits"
      echo "  rollback <hash> Rollback to a specific configuration snapshot"
      exit 1
      ;;
  esac
}

# Run the main function with all arguments
main "$@"
