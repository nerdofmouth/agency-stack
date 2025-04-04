#!/bin/bash
# welcome.sh - Displays the AgencyStack welcome message
# Add this to /etc/profile.d/ to display on login

# Colors
BLUE='\033[0;34m'
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Display header
cat << "EOF"
██╗      █████╗ ██╗   ██╗███╗   ██╗ ██████╗██╗  ██╗██████╗  ██████╗ ██╗  ██╗
██║     ██╔══██╗██║   ██║████╗  ██║██╔════╝██║  ██║██╔══██╗██╔═══██╗╚██╗██╔╝
██║     ███████║██║   ██║██╔██╗ ██║██║     ███████║██████╔╝██║   ██║ ╚███╔╝ 
██║     ██╔══██║██║   ██║██║╚██╗██║██║     ██╔══██║██╔══██╗██║   ██║ ██╔██╗ 
███████╗██║  ██║╚██████╔╝██║ ╚████║╚██████╗██║  ██║██████╔╝╚██████╔╝██╔╝ ██╗
╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═══╝ ╚═════╝╚═╝  ╚═╝╚═════╝  ╚═════╝ ╚═╝  ╚═╝
EOF

echo -e "${BLUE}${BOLD}Open Source Freedom Stack for Agencies & Enterprises${NC}"
echo -e "${CYAN}Version: $(cat /opt/agency_stack/version 2>/dev/null || echo "1.0.0")${NC}"
echo -e "${GREEN}${BOLD}https://stack.nerdofmouth.com${NC}\n"

# Display random motto
SCRIPT_PATH="$(dirname "$(realpath "$0")")"
if [ -f "$SCRIPT_PATH/motto.sh" ]; then
    source "$SCRIPT_PATH/motto.sh" && random_motto
    echo ""
fi

# Check AgencyStack status if it's installed
if [ -d "/opt/agency_stack" ]; then
    echo -e "${BLUE}${BOLD}System Status:${NC}"
    
    # Check if Traefik is running
    if docker ps 2>/dev/null | grep -q "traefik"; then
        echo -e " • ${CYAN}Traefik Proxy:${NC} ${GREEN}Online${NC}"
    else
        echo -e " • ${CYAN}Traefik Proxy:${NC} ${RED}Offline${NC}"
    fi
    
    # Check if Dashboard is running
    if docker ps 2>/dev/null | grep -q "dashboard"; then
        echo -e " • ${CYAN}AgencyStack Dashboard:${NC} ${GREEN}Online${NC}"
        
        DASHBOARD_URL=$(grep "dashboard" /opt/agency_stack/config.env 2>/dev/null | cut -d'=' -f2)
        echo -e "   ${GREEN}${DASHBOARD_URL:-https://dashboard.yourdomain.com}${NC}"
    else
        echo -e " • ${CYAN}AgencyStack Dashboard:${NC} ${RED}Offline${NC}"
    fi
    
    # Show client count
    CLIENT_COUNT=$(find /opt/agency_stack/clients -maxdepth 1 -type d | wc -l)
    CLIENT_COUNT=$((CLIENT_COUNT-1)) # Subtract the parent directory
    echo -e " • ${CYAN}Active Clients:${NC} ${YELLOW}${CLIENT_COUNT:-0}${NC}"
    
    echo -e "\n${BLUE}${BOLD}Command Reference:${NC}"
    echo -e " • ${YELLOW}agency_stack status${NC} - Check system status"
    echo -e " • ${YELLOW}agency_stack install${NC} - Run installer"
    echo -e " • ${YELLOW}agency_stack client${NC} - Create new client"
    echo -e " • ${YELLOW}agency_stack help${NC} - Show help"
fi

echo -e "\nWelcome to ${BOLD}AgencyStack${NC} powered by NerdofMouth.com"
