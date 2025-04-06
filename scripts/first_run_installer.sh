#!/bin/bash
# AgencyStack First-Run Installer
# This script handles initial environment setup to ensure first-run installation works smoothly
# It's designed to be used via curl piping for one-line installation

set -e

# Colors for output
BOLD="\033[1m"
GREEN="\033[32m"
YELLOW="\033[33m"
RED="\033[31m"
BLUE="\033[34m"
MAGENTA="\033[35m"
CYAN="\033[36m"
RESET="\033[0m"

# Banner
echo -e "${MAGENTA}${BOLD}"
echo "   _____                             _____ __             __  "
echo "  /  _  \   ____   ____   ____     / ___// /_____ ______/ /__"
echo " /  /_\  \ / ___\ /    \_/ __ \    \__ \/ __/ __ \/ ___/ //_/"
echo "/    |    / /_/  >   |  \  ___/   ___/ / /_/ /_/ / /__/ ,<   "
echo "\____|__  \___  /|___|  /\___  > /____/\__/\__,_/\___/_/|_|  "
echo "        \/_____/      \/     \/                              "
echo -e "${RESET}"

echo -e "${CYAN}One-Line Installer${RESET}"
echo "By Nerd of Mouth - Deploy Smart. Speak Nerd."
echo "https://stack.nerdofmouth.com"
echo ""
echo "\"The Agency Project: Metal + Meaning.\""
echo ""

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}Error: This script must be run as root${RESET}"
    echo "Please run with sudo or as the root user"
    exit 1
fi

setup_logging() {
    LOGDIR="/var/log/agency_stack"
    mkdir -p "$LOGDIR"
    DATE=$(date +%Y%m%d-%H%M%S)
    LOGFILE="$LOGDIR/first_run-$DATE.log"
    touch "$LOGFILE" || { echo "Failed to create log file. Please run with sudo."; exit 1; }
    
    # Logging function
    log() {
        local level="$1"
        local message="$2"
        local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
        echo -e "[$timestamp] [AgencyStack] [$level] $message" | tee -a "$LOGFILE"
    }
    
    echo -e "${CYAN}Logging to: $LOGFILE${RESET}"
    log "INFO" "Starting AgencyStack First-Run Installer"
}

# Set up logging
setup_logging

# System check
echo "Performing system checks..."
OS=$(grep -oP '(?<=^ID=).+' /etc/os-release | tr -d '"')
VERSION=$(grep -oP '(?<=^VERSION_ID=).+' /etc/os-release | tr -d '"')
PRETTY_NAME=$(grep -oP '(?<=^PRETTY_NAME=).+' /etc/os-release | tr -d '"')

if [[ "$OS" == "debian" || "$OS" == "ubuntu" ]]; then
    echo -e "✓ Detected ${GREEN}$PRETTY_NAME${RESET} - Recommended OS"
else
    echo -e "${YELLOW}⚠️ Detected $PRETTY_NAME - Not officially supported but will attempt installation${RESET}"
fi
log "INFO" "System check completed: $PRETTY_NAME detected"

# Install essential dependencies
echo -e "${BOLD}Installing required dependencies...${RESET}"
apt-get update
log "INFO" "System package repositories updated"

# Install basic utilities required for the installer
echo -e "${BLUE}Installing basic utilities...${RESET}"
apt-get install -y curl git wget make jq bc htop procps unzip

# Install Docker if not present
if ! command -v docker &> /dev/null; then
    echo -e "${YELLOW}Docker not found. Installing Docker...${RESET}"
    log "INFO" "Installing Docker"
    
    # Install prerequisites
    apt-get install -y apt-transport-https ca-certificates gnupg lsb-release
    
    # Add Docker's official GPG key
    curl -fsSL https://download.docker.com/linux/$OS/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    
    # Set up the stable repository
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/$OS $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io
    
    # Start and enable Docker
    systemctl start docker
    systemctl enable docker
    
    echo -e "${GREEN}Docker installed successfully${RESET}"
    log "INFO" "Docker installed successfully"
else
    echo -e "${GREEN}Docker is already installed${RESET}"
    
    # Make sure Docker is running
    if ! docker info &>/dev/null; then
        echo -e "${YELLOW}Docker is installed but not running. Starting Docker...${RESET}"
        systemctl start docker
        log "INFO" "Started Docker service"
    fi
fi

# Install Docker Compose if not present
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo -e "${YELLOW}Docker Compose not found. Installing Docker Compose...${RESET}"
    log "INFO" "Installing Docker Compose"
    
    # Get latest Docker Compose release
    COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    
    # Install Docker Compose
    curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    
    echo -e "${GREEN}Docker Compose installed successfully${RESET}"
    log "INFO" "Docker Compose installed successfully"
else
    echo -e "${GREEN}Docker Compose is already installed${RESET}"
fi

setup_directory_structure() {
    echo -e "${BOLD}Setting up required directory structure...${RESET}"
    log "INFO" "Setting up required directory structure"
    
    # Create base directories
    mkdir -p /opt/agency_stack/clients/default
    mkdir -p /opt/agency_stack/secrets
    mkdir -p /var/log/agency_stack/clients
    mkdir -p /var/log/agency_stack/components
    mkdir -p /var/log/agency_stack/integrations
    
    log "INFO" "Base directory structure created"
}

# Set up directory structure
setup_directory_structure

# Clone or update repository
echo -e "${BOLD}Setting up AgencyStack repository...${RESET}"
if [ ! -d "/opt/agency_stack/repo" ]; then
    echo "Cloning AgencyStack repository..."
    log "INFO" "Cloning AgencyStack repository"
    git clone https://github.com/nerdofmouth/agency-stack.git /opt/agency_stack/repo
else
    echo "Repository already exists. Updating..."
    log "INFO" "Updating existing AgencyStack repository"
    cd /opt/agency_stack/repo
    git pull
fi

# Change to the repository directory
cd /opt/agency_stack/repo

# Run prep-dirs target
echo -e "${BOLD}Running prep-dirs target...${RESET}"
log "INFO" "Running make prep-dirs to set up component directories"
make prep-dirs || { 
    echo -e "${RED}Failed to run prep-dirs target. This might be non-critical, continuing...${RESET}"; 
    log "WARN" "Failed to run prep-dirs target, continuing anyway"
}

# Run env-check
echo -e "${BOLD}Checking environment configuration...${RESET}"
log "INFO" "Running make env-check to validate environment"
make env-check || {
    echo -e "${YELLOW}Environment check reported issues. We'll fix these in the next steps.${RESET}"
    log "WARN" "Environment check reported issues, proceeding with fixes"
}

# Install infrastructure
echo -e "${BOLD}Installing core infrastructure components...${RESET}"
log "INFO" "Running make install-infrastructure to set up core components"
make install-infrastructure || {
    echo -e "${RED}Failed to install infrastructure components.${RESET}"
    log "ERROR" "Failed to install infrastructure components"
    exit 1
}

# Re-check environment
echo -e "${BOLD}Re-checking environment after infrastructure setup...${RESET}"
log "INFO" "Running make env-check again after infrastructure setup"
make env-check

# Launch the main installer
echo -e "${GREEN}${BOLD}First-run preparation complete!${RESET}"
echo -e "${CYAN}Launching the main AgencyStack installer...${RESET}"
log "INFO" "First-run preparation complete, launching main installer"

# Run the main installer script
if [ -f "./scripts/install.sh" ]; then
    bash ./scripts/install.sh
else
    echo -e "${RED}Main installer script not found.${RESET}"
    log "ERROR" "Main installer script not found at ./scripts/install.sh"
    echo "Please navigate to /opt/agency_stack/repo and run 'make install-all' or individual component targets."
    exit 1
fi

echo -e "${GREEN}${BOLD}AgencyStack setup completed!${RESET}"
echo "For documentation and more information, visit:"
echo "https://stack.nerdofmouth.com"
log "INFO" "AgencyStack one-line installation process completed"
