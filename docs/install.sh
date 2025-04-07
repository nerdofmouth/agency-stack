#!/bin/bash
# AgencyStack One-Line Installer
# https://stack.nerdofmouth.com
# Redirects to the main installer script

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

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m' # No Color

echo -e "${MAGENTA}${BOLD}"
echo -e "   _____                             _____ __             __  "
echo -e "  /  _  \   ____   ____   ____     / ___// /_____ ______/ /__"
echo -e " /  /_\  \ / ___\ /    \_/ __ \    \__ \/ __/ __ \/ ___/ //_/"
echo -e "/    |    / /_/  >   |  \  ___/   ___/ / /_/ /_/ / /__/ ,<   "
echo -e "\____|__  \___  /|___|  /\___  > /____/\__/\__,_/\___/_/|_|  "
echo -e "        \/_____/      \/     \/                              "
echo -e "${NC}"
echo -e "${BLUE}${BOLD}One-Line Installer${NC}"
echo -e "${CYAN}By Nerd of Mouth - Deploy Smart. Speak Nerd.${NC}"
echo -e "${GREEN}https://stack.nerdofmouth.com${NC}\n"

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
echo -e "${YELLOW}\"${taglines[$random_index]}\"${NC}\n"

echo -e "${BLUE}Starting installation...${NC}"
echo -e "${CYAN}This installer will download and execute the main AgencyStack installer.${NC}\n"

# Compatibility check
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}Error: This script must be run as root${NC}"
    echo -e "Please run with sudo or as root user."
    exit 1
fi

# System check
echo -e "${BLUE}Performing system checks...${NC}"

# Check OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    if [ "$ID" != "debian" ] && [ "$ID" != "ubuntu" ]; then
        echo -e "${YELLOW}Warning: This script is optimized for Debian/Ubuntu systems. Your system is $PRETTY_NAME.${NC}"
        echo -e "Proceeding anyway, but you may encounter issues."
    else
        if [ "$ID" = "debian" ]; then
            echo -e "${GREEN}✓ Detected $PRETTY_NAME - Recommended OS${NC}"
        else
            echo -e "${GREEN}✓ Detected $PRETTY_NAME - Supported OS${NC}"
        fi
    fi
else
    echo -e "${YELLOW}Warning: Could not determine your OS distribution.${NC}"
    echo -e "Proceeding anyway, but you may encounter issues."
fi

echo -e "${GREEN}System checks completed.${NC}\n"

# Install dependencies
echo -e "${BLUE}Installing required dependencies...${NC}"
apt-get update -q
apt-get install -y curl git make wget jq bc openssl unzip procps

# Setup logging directory
mkdir -p /var/log/agency_stack

# Download and execute the main installer
echo -e "\n${BLUE}Downloading and executing the main AgencyStack installer...${NC}"
echo -e "${CYAN}This may take a few minutes. Please be patient.${NC}\n"

# Clone the repository
echo -e "${BLUE}Cloning AgencyStack repository...${NC}"

# Save and restore directory handling
ORIGINAL_DIR="$(pwd)"

if [ -d "/opt/agency_stack" ]; then
    echo -e "${YELLOW}WARNING: Existing installation found at /opt/agency_stack${NC}"
    
    # Auto-backup in non-interactive mode
    if [ "$ONE_LINE_MODE" = true ]; then
        timestamp=$(date +%Y%m%d%H%M%S)
        backup_dir="/opt/agency_stack_backup_${timestamp}"
        
        echo -e "${BLUE}Creating backup at $backup_dir...${NC}"
        mkdir -p "$backup_dir"
        cp -r /opt/agency_stack/* "$backup_dir/" 2>/dev/null || true
        
        echo -e "${GREEN}Backup created successfully${NC}"
        
        # Remove only the repo to allow fresh clone
        if [ -d "/opt/agency_stack/repo" ]; then
            rm -rf /opt/agency_stack/repo
        fi
    else
        # Interactive mode - show options
        echo -e "What would you like to do?"
        echo -e "  1. Backup and reinstall (recommended)"
        echo -e "  2. Remove and reinstall (data will be lost)"
        echo -e "  3. Exit installation"
        read -p "Enter choice [1-3]: " choice
        
        case $choice in
            1)
                timestamp=$(date +%Y%m%d%H%M%S)
                backup_dir="/opt/agency_stack_backup_${timestamp}"
                mkdir -p "$backup_dir"
                cp -r /opt/agency_stack/* "$backup_dir/" 2>/dev/null || true
                rm -rf /opt/agency_stack/repo
                echo -e "${GREEN}Created backup at $backup_dir${NC}"
                ;;
            2)
                rm -rf /opt/agency_stack/repo
                ;;
            3)
                echo -e "${YELLOW}Installation aborted by user.${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid choice. Exiting.${NC}"
                exit 1
                ;;
        esac
    fi
fi

# Create essential directories - BEFORE changing directory
mkdir -p /opt/agency_stack/clients/default
mkdir -p /opt/agency_stack/secrets
mkdir -p /var/log/agency_stack/clients
mkdir -p /var/log/agency_stack/components

# Change to a safe directory before clone - avoids working directory issues
cd /tmp || cd /

# Clone repo with retry logic
MAX_RETRIES=3
SUCCESS=false

for i in $(seq 1 $MAX_RETRIES); do
    if git clone https://github.com/nerdofmouth/agency-stack.git /opt/agency_stack/repo; then
        SUCCESS=true
        break
    else
        echo -e "${YELLOW}Git clone failed, attempt $i of $MAX_RETRIES${NC}"
        sleep 2
    fi
done

if [ "$SUCCESS" != true ]; then
    echo -e "${RED}Failed to clone repository after $MAX_RETRIES attempts.${NC}"
    echo -e "${YELLOW}Please check your network connection and try again.${NC}"
    exit 1
fi

# Always use absolute paths from now on - avoid relative path issues
cd /opt/agency_stack/repo || {
    echo -e "${RED}Failed to change to repository directory${NC}"
    exit 1
}

# Make scripts executable
chmod +x scripts/*.sh
if [ -d "scripts/agency_stack_bootstrap_bundle_v10" ]; then
    chmod +x scripts/agency_stack_bootstrap_bundle_v10/*.sh
fi

# Run prep-dirs if Makefile exists
if [ -f "Makefile" ]; then
    echo -e "${BLUE}Running make prep-dirs...${NC}"
    make prep-dirs || echo -e "${YELLOW}make prep-dirs encountered issues, continuing...${NC}"
    
    echo -e "${BLUE}Running environment check...${NC}"
    make env-check || echo -e "${YELLOW}Environment check reported issues, continuing...${NC}"
fi

# Check for --prepare-only flag
PREPARE_ONLY=false
for arg in "$@"; do
  if [ "$arg" = "--prepare-only" ]; then
    PREPARE_ONLY=true
  fi
done

# Run the installer
echo -e "\n${BLUE}Running AgencyStack installer...${NC}"
if [ "$PREPARE_ONLY" = true ]; then
  echo -e "${GREEN}Preparation completed!${NC}"
  echo -e "${CYAN}You can now run the interactive installer with:${NC}"
  echo -e "${YELLOW}  sudo bash /opt/agency_stack/repo/scripts/install.sh${NC}\n"
else
  bash scripts/install.sh
fi

# Final message
echo -e "\n${MAGENTA}${BOLD}AgencyStack installation process completed!${NC}"
echo -e "${CYAN}For documentation and more information, visit:${NC}"
echo -e "${GREEN}https://stack.nerdofmouth.com${NC}\n"
