#!/bin/bash
# AgencyStack One-Line Installer
# https://stack.nerdofmouth.com
# Bootstraps the environment and prepares for component installation

# Detect if script is being run via curl one-liner
ONE_LINE_MODE=false
if [ ! -t 0 ]; then
  # If standard input is not a terminal, we're being piped to
  ONE_LINE_MODE=true
fi

# Force non-interactive mode when being piped
if [ "$ONE_LINE_MODE" = true ]; then
  export DEBIAN_FRONTEND=noninteractive
  # Force git to be non-interactive too
  export GIT_TERMINAL_PROMPT=0
  # Prevent any other tools from prompting
  export APT_LISTCHANGES_FRONTEND=none
  export APT_LISTBUGS_FRONTEND=none
fi

# Define absolute paths - never rely on relative paths
AGENCY_ROOT="/opt/agency_stack"
AGENCY_LOG_DIR="/var/log/agency_stack"
AGENCY_BACKUP_DIR="/opt/agency_stack_backup"
TIMESTAMP=$(date +%Y%m%d%H%M%S)
INSTALL_LOG="${AGENCY_LOG_DIR}/install-${TIMESTAMP}.log"

# Ensure log directory exists
mkdir -p "${AGENCY_LOG_DIR}"
touch "${INSTALL_LOG}" || { echo "Failed to create log file. Please run with sudo."; exit 1; }

# Logging function
log() {
  local level="$1"
  local message="$2"
  local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  echo -e "[$timestamp] [AgencyStack-Bootstrap] [$level] $message" | tee -a "${INSTALL_LOG}"
  
  if [ -n "${3:-}" ]; then
    echo -e "$3" | tee -a "${INSTALL_LOG}"
  fi
}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Default to prepare-only mode
PREPARE_ONLY=true
AUTO_INSTALL=false
FORCE_MODE=false

# Parse command line arguments
for arg in "$@"; do
  case "$arg" in
    --auto-install)
      PREPARE_ONLY=false
      AUTO_INSTALL=true
      log "INFO" "Auto-install mode enabled" "${YELLOW}Auto-install mode enabled (will install components after preparation)${NC}"
      ;;
    --prepare-only)
      PREPARE_ONLY=true
      AUTO_INSTALL=false
      log "INFO" "Prepare-only mode explicitly enabled" "${BLUE}Prepare-only mode explicitly enabled (default)${NC}"
      ;;
    --force)
      FORCE_MODE=true
      log "INFO" "Force mode enabled" "${YELLOW}Force mode enabled (will reinstall even if already installed)${NC}"
      ;;
    *)
      log "WARN" "Unknown argument: $arg" "${YELLOW}Unknown argument: $arg${NC}"
      ;;
  esac
done

# Set non-interactive environment variables
# These ensure no user prompts during the installation process
export DEBIAN_FRONTEND=noninteractive
export GIT_TERMINAL_PROMPT=0
export APT_LISTCHANGES_FRONTEND=none
export APT_LISTBUGS_FRONTEND=none
export NEEDRESTART_MODE=a
export NEEDRESTART_SUSPEND=1

# Random tagline
taglines=(
    "Run your agency. Reclaim your agency."
    "Tools for freedom, proof of power."
    "The Agency Project: Metal + Meaning."
    "Don't just deploy. Declare independence."
    "Freedom starts with a shell prompt."
    "From Zero to Sovereign."
    "CLI-tested. Compliance-detested."
    "An agency stack with an agenda: yours."
    "Stack sovereignty starts here."
)
random_index=$((RANDOM % ${#taglines[@]}))

echo -e "${MAGENTA}${BOLD} "
echo -e "${MAGENTA}${BOLD}   ____   ____    ___  ____     __  __ __  _____ ______   ____    __  __  _ "
echo -e "${MAGENTA}${BOLD}  /    | /    |  /  _]|    \   /  ]|  |  |/ ___/|      | /    |  /  ]|  |/ ]"
echo -e "${MAGENTA}${BOLD} |  o  ||   __| /  [_ |  _  | /  / |  |  (   \_ |      ||  o  | /  / |  ' / "
echo -e "${MAGENTA}${BOLD} |     ||  |  ||    _]|  |  |/  /  |  ~  |\__  ||_|  |_||     |/  /  |    \ "
echo -e "${MAGENTA}${BOLD} |  _  ||  |_ ||   [_ |  |  /   \_ |___, |/  \ |  |  |  |  _  /   \_ |     |"
echo -e "${MAGENTA}${BOLD} |  |  ||     ||     ||  |  \     ||     |\    |  |  |  |  |  \     ||  .  |"
echo -e "${MAGENTA}${BOLD} |__|__||___,_||_____||__|__|\____||____/  \___|  |__|  |__|__|\____||__|\_|"
echo -e "${MAGENTA}${BOLD}                                                                            "
echo -e "${MAGENTA}${BOLD} "
echo -e "${NC}"
echo -e "${BLUE}${BOLD}One-Line Installer${NC}"
echo -e "${CYAN}By Nerd of Mouth - Deploy Smart. Speak Nerd.${NC}"
echo -e "${GREEN}https://stack.nerdofmouth.com${NC}\n"

echo -e "${YELLOW}\"${taglines[$random_index]}\"${NC}\n"

log "INFO" "Starting AgencyStack environment preparation" "${BLUE}Starting environment preparation...${NC}"

# Check for root
if [ "$(id -u)" -ne 0 ]; then
    log "ERROR" "This script must be run as root" "${RED}Error: This script must be run as root${NC}"
    echo -e "Please run with sudo or as root user."
    exit 1
fi

# System check
log "INFO" "Performing system checks" "${BLUE}Performing system checks...${NC}"

# Check OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    if [ "$ID" != "debian" ] && [ "$ID" != "ubuntu" ]; then
        log "WARN" "Non-recommended OS detected: $PRETTY_NAME" "${YELLOW}Warning: This script is optimized for Debian/Ubuntu systems. Your system is $PRETTY_NAME.${NC}"
    else
        if [ "$ID" = "debian" ]; then
            log "INFO" "Recommended OS detected: $PRETTY_NAME" "${GREEN}✓ Detected $PRETTY_NAME - Recommended OS${NC}"
        else
            log "INFO" "Supported OS detected: $PRETTY_NAME" "${GREEN}✓ Detected $PRETTY_NAME - Supported OS${NC}"
        fi
    fi
else
    log "WARN" "Could not determine OS distribution" "${YELLOW}Warning: Could not determine your OS distribution.${NC}"
fi

log "INFO" "System checks completed" "${GREEN}System checks completed.${NC}\n"

# Install dependencies
log "INFO" "Installing required dependencies" "${BLUE}Installing required dependencies...${NC}"

# Try to use our dedicated prerequisites component installer if it's available
if [ -f "$(dirname "$0")/../scripts/components/install_prerequisites.sh" ]; then
  log "INFO" "Using dedicated prerequisites component installer" "${BLUE}Using dedicated prerequisites component installer...${NC}"
  
  # Check if prerequisites have already been installed
  if [ -f "${AGENCY_ROOT}/.prerequisites_ok" ]; then
    log "INFO" "Prerequisites already installed" "${GREEN}✅ Prerequisites already installed, skipping...${NC}"
  else
    bash "$(dirname "$0")/../scripts/components/install_prerequisites.sh" || {
      log "WARN" "Prerequisites installer failed, falling back to basic installation" "${YELLOW}Prerequisites installer failed, using fallback method...${NC}"
      # Fallback installation
      apt-get update -q
      apt-get install -y curl git make wget jq bc openssl unzip procps
    }
  fi
else
  # Fallback for one-line installer without repo access yet
  log "INFO" "Prerequisites component not available yet, using basic installation" "${YELLOW}Prerequisites component not available yet, using basic installation...${NC}"
  apt-get update -q
  apt-get install -y curl git make wget jq bc openssl unzip procps
fi

# Create essential directories - BEFORE any operations
mkdir -p "${AGENCY_ROOT}/clients/default"
mkdir -p "${AGENCY_ROOT}/secrets"
mkdir -p "${AGENCY_ROOT}/repo"
mkdir -p "${AGENCY_LOG_DIR}/clients"
mkdir -p "${AGENCY_LOG_DIR}/components"
mkdir -p "${AGENCY_LOG_DIR}/integrations"

# Save original directory
ORIGINAL_DIR="$(pwd)"

# Check for existing installation
if [ -d "${AGENCY_ROOT}" ]; then
    log "WARN" "Existing installation found at ${AGENCY_ROOT}" "${YELLOW}WARNING: Existing installation found at ${AGENCY_ROOT}${NC}"
    
    # Check for recovery situation vs. complete installation
    if [ ! -f "${AGENCY_ROOT}/.installed_ok" ] || [ "$FORCE_MODE" = true ]; then
        # If force mode or partial installation
        if [ "$FORCE_MODE" = true ] && [ -f "${AGENCY_ROOT}/.installed_ok" ]; then
            log "WARN" "Force reinstall requested of complete installation" "${YELLOW}Force reinstall requested of complete installation${NC}"
        else
            log "WARN" "Detected partial installation, will attempt recovery" "${YELLOW}Detected partial/incomplete installation, will attempt recovery...${NC}"
        fi
        
        # Create backup of partial installation
        BACKUP_DIR="${AGENCY_BACKUP_DIR}_${TIMESTAMP}"
        log "INFO" "Creating backup of partial installation at ${BACKUP_DIR}" "${BLUE}Creating backup of partial installation at ${BACKUP_DIR}...${NC}"
        mkdir -p "${BACKUP_DIR}"
        cp -r "${AGENCY_ROOT}"/* "${BACKUP_DIR}/" 2>/dev/null || true
        log "INFO" "Backup created successfully" "${GREEN}Backup created successfully${NC}"
        
        # Clean up the partial installation but preserve logs
        log "INFO" "Preparing clean environment" "${BLUE}Preparing clean environment...${NC}"
        find "${AGENCY_ROOT}" -mindepth 1 -not -path "${AGENCY_ROOT}/logs*" -not -path "${AGENCY_ROOT}/.prerequisites_ok" -delete 2>/dev/null || true
    else
        log "INFO" "Complete installation already exists" "${GREEN}Complete installation already exists at ${AGENCY_ROOT}${NC}"
        
        # If auto-install and we're already installed, we can just exit
        if [ "$AUTO_INSTALL" = true ]; then
            log "INFO" "Skipping installation as it's already complete" "${GREEN}Installation is already complete. Use --force to reinstall.${NC}"
            
            cat << EOF
${GREEN}${BOLD}✅ AgencyStack is already installed!${NC}

${CYAN}To manage your installation:${NC}
${YELLOW}
1. To run the interactive installer:
   sudo bash ${AGENCY_ROOT}/repo/scripts/install.sh
   
2. To check system status:
   cd ${AGENCY_ROOT}/repo && sudo make status
${NC}

Documentation: ${GREEN}https://stack.nerdofmouth.com${NC}
EOF
            exit 0
        fi
        
        # If non-auto-install and interactive mode, ask user what to do
        if [ "$ONE_LINE_MODE" = false ]; then
            echo -e "What would you like to do?"
            echo -e "  1. Backup and reinstall (recommended)"
            echo -e "  2. Remove and reinstall (data will be lost)"
            echo -e "  3. Exit installation"
            read -p "Enter choice [1-3]: " choice
            
            case $choice in
                1)
                    BACKUP_DIR="${AGENCY_BACKUP_DIR}_${TIMESTAMP}"
                    mkdir -p "${BACKUP_DIR}"
                    cp -r "${AGENCY_ROOT}"/* "${BACKUP_DIR}/" 2>/dev/null || true
                    rm -rf "${AGENCY_ROOT}/repo"
                    log "INFO" "Created backup at ${BACKUP_DIR}" "${GREEN}Created backup at ${BACKUP_DIR}${NC}"
                    ;;
                2)
                    rm -rf "${AGENCY_ROOT}/repo"
                    log "INFO" "Removed existing repository for fresh install"
                    ;;
                3)
                    log "INFO" "User chose to exit installation" "${YELLOW}Installation aborted by user.${NC}"
                    exit 0
                    ;;
                *)
                    log "ERROR" "Invalid choice. Exiting." "${RED}Invalid choice. Exiting.${NC}"
                    exit 1
                    ;;
            esac
        fi
    fi
fi

# Change to a safe directory before clone - avoids working directory issues
cd /tmp || cd /

log "INFO" "Cloning AgencyStack repository" "${BLUE}Cloning AgencyStack repository...${NC}"

# Clone repo with retry logic
MAX_RETRIES=3
SUCCESS=false

for i in $(seq 1 $MAX_RETRIES); do
    if git clone https://github.com/nerdofmouth/agency-stack.git "${AGENCY_ROOT}/repo"; then
        SUCCESS=true
        break
    else
        log "WARN" "Git clone failed, attempt $i of $MAX_RETRIES" "${YELLOW}Git clone failed, attempt $i of $MAX_RETRIES${NC}"
        sleep 2
    fi
done

if [ "$SUCCESS" != true ]; then
    log "ERROR" "Failed to clone repository after $MAX_RETRIES attempts" "${RED}Failed to clone repository after $MAX_RETRIES attempts.${NC}"
    log "ERROR" "Please check your network connection and try again" "${YELLOW}Please check your network connection and try again.${NC}"
    exit 1
fi

# Now that we have the repository, run the prerequisites component with absolute path
if [ -f "${AGENCY_ROOT}/repo/scripts/components/install_prerequisites.sh" ]; then
  log "INFO" "Running prerequisites component with full repository" "${BLUE}Running prerequisites component with full repository...${NC}"
  
  # Check if prerequisites have already been installed
  if [ -f "${AGENCY_ROOT}/.prerequisites_ok" ]; then
    log "INFO" "Prerequisites already installed" "${GREEN}✅ Prerequisites already installed, skipping...${NC}"
  else
    bash "${AGENCY_ROOT}/repo/scripts/components/install_prerequisites.sh" || {
      log "WARN" "Prerequisites component returned non-zero, continuing with installation" "${YELLOW}Prerequisites component returned non-zero, continuing with installation...${NC}"
    }
  fi
fi

log "INFO" "Repository cloned successfully" "${GREEN}Repository cloned successfully${NC}"

# Change to repository directory using absolute path
cd "${AGENCY_ROOT}/repo" || {
    log "ERROR" "Failed to change to repository directory" "${RED}Failed to change to repository directory${NC}"
    exit 1
}

# Create installed_ok marker file to indicate successful preparation
touch "${AGENCY_ROOT}/.installed_ok"
log "INFO" "Environment preparation completed" "${GREEN}Environment preparation completed successfully!${NC}"

# Run the installer if auto-install was requested
if [ "$AUTO_INSTALL" = true ]; then
    log "INFO" "Auto-installing components as requested" "${BLUE}Auto-installing components as requested...${NC}"
    cd "${AGENCY_ROOT}/repo" && bash scripts/install.sh --auto-install
else
    # Show clear next steps
    cat << EOF
${GREEN}${BOLD}✅ AgencyStack environment is ready!${NC}

${CYAN}Next steps:${NC}
${YELLOW}
1. To run the interactive installer and select components:
   sudo bash ${AGENCY_ROOT}/repo/scripts/install.sh

2. To install specific components:
   cd ${AGENCY_ROOT}/repo && sudo make <component>
   
3. To install core components only:
   cd ${AGENCY_ROOT}/repo && sudo make core-components
   
4. To check system status:
   cd ${AGENCY_ROOT}/repo && sudo make status
${NC}

Documentation: ${GREEN}https://stack.nerdofmouth.com${NC}
EOF
fi

log "INFO" "One-Line Installer completed successfully" "${GREEN}${BOLD}AgencyStack bootstrap completed!${NC}"
