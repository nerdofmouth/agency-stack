#!/bin/bash
# AgencyStack One-Line Installer
# https://stack.nerdofmouth.com
# Redirects to the main installer script

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
    if [ "$ID" != "ubuntu" ] && [ "$ID" != "debian" ]; then
        echo -e "${YELLOW}Warning: This script is optimized for Ubuntu/Debian systems. Your system is $PRETTY_NAME.${NC}"
        echo -e "Proceeding anyway, but you may encounter issues."
    fi
else
    echo -e "${YELLOW}Warning: Could not determine your OS distribution.${NC}"
    echo -e "Proceeding anyway, but you may encounter issues."
fi

# Check RAM
total_ram=$(free -m | awk '/^Mem:/{print $2}')
if [ "$total_ram" -lt 4000 ]; then
    echo -e "${YELLOW}Warning: Low memory detected ($total_ram MB). Recommended: 4GB+${NC}"
    echo -e "Proceeding anyway, but you may encounter performance issues."
fi

# Check disk space
free_space=$(df -m / | awk 'NR==2 {print $4}')
if [ "$free_space" -lt 20000 ]; then
    echo -e "${YELLOW}Warning: Low disk space detected ($free_space MB free). Recommended: 20GB+${NC}"
    echo -e "Proceeding anyway, but you may encounter storage issues."
fi

echo -e "${GREEN}System checks completed.${NC}\n"

# Install dependencies
echo -e "${BLUE}Installing required dependencies...${NC}"
apt-get update -q
apt-get install -y curl git make wget jq

# Download and execute the main installer
echo -e "\n${BLUE}Downloading and executing the main AgencyStack installer...${NC}"
echo -e "${CYAN}This may take a few minutes. Please be patient.${NC}\n"

# Clone the repository
echo -e "${BLUE}Cloning AgencyStack repository...${NC}"
if [ -d "/opt/agency-stack" ]; then
    echo -e "${YELLOW}WARNING: Existing installation found at /opt/agency-stack${NC}"
    echo -e "What would you like to do?"
    echo -e "  1. Backup and reinstall (recommended)"
    echo -e "  2. Remove and reinstall (data will be lost)"
    echo -e "  3. Exit installation"
    read -p "Enter your choice [1-3]: " choice
    
    case $choice in
        1)
            echo -e "${BLUE}Backing up existing installation...${NC}"
            timestamp=$(date +%Y%m%d-%H%M%S)
            backup_dir="/opt/agency-stack-backup-$timestamp"
            cp -r /opt/agency-stack "$backup_dir"
            echo -e "${GREEN}Backup created at $backup_dir${NC}"
            rm -rf /opt/agency-stack
            ;;
        2)
            echo -e "${YELLOW}Removing existing installation...${NC}"
            rm -rf /opt/agency-stack
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

# Clone the repository and run the installer
git clone https://github.com/nerdofmouth/agency-stack.git /opt/agency-stack
cd /opt/agency-stack

# Make scripts executable
chmod +x scripts/*.sh
if [ -d "scripts/agency_stack_bootstrap_bundle_v10" ]; then
    chmod +x scripts/agency_stack_bootstrap_bundle_v10/*.sh
fi

# Run the installer
echo -e "\n${BLUE}Running AgencyStack installer...${NC}"
make install

# Final message
echo -e "\n${MAGENTA}${BOLD}AgencyStack installation complete!${NC}"
echo -e "${CYAN}For documentation and more information, visit:${NC}"
echo -e "${GREEN}https://stack.nerdofmouth.com${NC}\n"
