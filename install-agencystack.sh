#!/bin/bash
# install-agencystack.sh - One-line installer for AgencyStack
# https://nerdofmouth.com/stack

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Display header
clear
echo -e "${MAGENTA}${BOLD}"
cat << "EOF"
    _                            ____  _             _    
   / \   __ _  ___ _ __   ___ _/ ___|| |_ __ _  ___| | __
  / _ \ / _` |/ _ \ '_ \ / __| \___ \| __/ _` |/ __| |/ /
 / ___ \ (_| |  __/ | | | (__| |___) | || (_| | (__|   < 
/_/   \_\__, |\___|_| |_|\___|_|____/ \__\__,_|\___|_|\_\
        |___/                                            
EOF
echo -e "${NC}"
echo -e "${BLUE}${BOLD}One-Line Installer${NC}"
echo -e "${CYAN}By Nerd of Mouth - Deploy Smart. Speak Nerd.${NC}"
echo -e "${GREEN}https://nerdofmouth.com/stack${NC}\n"

# Display random tagline from a small set
taglines=(
    "Run your agency. Reclaim your agency."
    "Tools for freedom, proof of power."
    "From Zero to Sovereign."
    "CLI-tested. Compliance-detested."
)
index=$((RANDOM % ${#taglines[@]}))
echo -e "${MAGENTA}${BOLD}\"${taglines[$index]}\"${NC}\n"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}${BOLD}Error:${NC} This script must be run as root"
    echo "Please run with: sudo bash install-agencystack.sh"
    exit 1
fi

# Check system compatibility
echo -e "${BLUE}${BOLD}Checking system compatibility...${NC}"
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$NAME
    VER=$VERSION_ID
    echo -e "  ${GREEN}✓${NC} Detected: $OS $VER"
else
    echo -e "${YELLOW}Warning:${NC} Could not determine OS version"
    echo "Installation may not work correctly on unsupported systems."
fi

# Check minimum requirements
echo -e "${BLUE}${BOLD}Checking minimum requirements...${NC}"
# Check CPU
CPU_CORES=$(grep -c processor /proc/cpuinfo)
if [ "$CPU_CORES" -lt 2 ]; then
    echo -e "  ${YELLOW}⚠️${NC} CPU: $CPU_CORES cores detected (minimum 2 recommended)"
else
    echo -e "  ${GREEN}✓${NC} CPU: $CPU_CORES cores detected"
fi

# Check RAM
TOTAL_RAM=$(free -m | awk '/^Mem:/{print $2}')
if [ "$TOTAL_RAM" -lt 4000 ]; then
    echo -e "  ${YELLOW}⚠️${NC} RAM: ${TOTAL_RAM}MB detected (minimum 4GB recommended)"
else
    echo -e "  ${GREEN}✓${NC} RAM: ${TOTAL_RAM}MB detected"
fi

# Check disk space
ROOT_DISK=$(df -h / | awk 'NR==2 {print $4}')
echo -e "  ${GREEN}✓${NC} Disk: $ROOT_DISK available on root partition"

echo -e "\n${BLUE}${BOLD}Installing dependencies...${NC}"
apt-get update
apt-get install -y git make curl wget jq

# Create installation directory
INSTALL_DIR="/opt/agency_stack"
echo -e "\n${BLUE}${BOLD}Creating installation directory...${NC}"
mkdir -p $INSTALL_DIR
cd $INSTALL_DIR

# Clone repository
echo -e "\n${BLUE}${BOLD}Cloning AgencyStack repository...${NC}"
if [ -d "$INSTALL_DIR/.git" ]; then
    echo -e "  ${YELLOW}⚠️${NC} Git repository already exists, pulling latest changes"
    git pull
else
    echo -e "  ${GREEN}✓${NC} Cloning fresh repository"
    git clone https://github.com/nerdofmouth/agency-stack.git .
fi

# Set permissions
echo -e "\n${BLUE}${BOLD}Setting permissions...${NC}"
chmod +x scripts/*.sh
chmod +x scripts/agency_stack_bootstrap_bundle_v10/*.sh

# Start the installation
echo -e "\n${BLUE}${BOLD}Starting AgencyStack installation...${NC}"
echo -e "${YELLOW}NOTE: The installation will prompt you for configuration options${NC}"
echo -e "${YELLOW}You can also press Ctrl+C now and run 'make help' for more options${NC}\n"

# Check if Makefile exists
if [ -f "Makefile" ]; then
    echo -e "Would you like to proceed with installation now? [Y/n] "
    read -r response
    if [[ "$response" =~ ^([nN][oO]|[nN])$ ]]; then
        echo -e "\n${CYAN}${BOLD}Installation paused.${NC}"
        echo -e "To continue later, navigate to $INSTALL_DIR and run:"
        echo -e "  ${GREEN}make install${NC} - For full installation"
        echo -e "  ${GREEN}make help${NC} - To see all options\n"
    else
        make install
    fi
else
    echo -e "${RED}${BOLD}Error:${NC} Makefile not found"
    echo "Please check the repository and try again"
    exit 1
fi

echo -e "\n${MAGENTA}${BOLD}AgencyStack setup complete!${NC}"
echo -e "${CYAN}For more information and documentation, visit:${NC}"
echo -e "${GREEN}https://nerdofmouth.com/stack${NC}\n"
