#!/bin/bash
# welcome.sh - Displays the Launchbox welcome message
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
echo -e "${CYAN}Version: $(cat /opt/launchbox/version 2>/dev/null || echo "1.0.0")${NC}"
echo -e "${GREEN}${BOLD}https://nerdofmouth.com/launchbox${NC}\n"

# Display random motto
SCRIPT_PATH="$(dirname "$(realpath "$0")")"
if [ -f "$SCRIPT_PATH/motto.sh" ]; then
    source "$SCRIPT_PATH/motto.sh" && random_motto
    echo ""
fi

# Check Launchbox status if it's installed
if [ -d "/opt/launchbox" ]; then
    # Count running containers
    RUNNING_CONTAINERS=$(docker ps -q 2>/dev/null | wc -l)
    TOTAL_CONTAINERS=$(docker ps -a -q 2>/dev/null | wc -l)
    
    echo -e "${YELLOW}System Status:${NC}"
    echo -e " • ${CYAN}Running containers:${NC} $RUNNING_CONTAINERS of $TOTAL_CONTAINERS"
    
    # Check if Launchpad Dashboard is running
    if docker ps 2>/dev/null | grep -q "launchpad_dashboard"; then
        echo -e " • ${CYAN}Launchbox Dashboard:${NC} ${GREEN}Online${NC}"
        # Get dashboard URL
        DASHBOARD_URL=$(grep "dashboard" /opt/launchbox/config.env 2>/dev/null | cut -d'=' -f2)
        [ -n "$DASHBOARD_URL" ] && echo -e " • ${CYAN}Control Panel:${NC} ${GREEN}https://$DASHBOARD_URL${NC}"
    else
        echo -e " • ${CYAN}Launchbox Dashboard:${NC} ${RED}Offline${NC}"
    fi
    
    # Show client count
    CLIENT_COUNT=$(find /opt/launchbox/clients -maxdepth 1 -type d | wc -l)
    [ "$CLIENT_COUNT" -gt 1 ] && echo -e " • ${CYAN}Active clients:${NC} $(($CLIENT_COUNT - 1))"
    
    echo -e "\n${MAGENTA}${BOLD}Commands:${NC}"
    echo -e " • ${YELLOW}launchbox status${NC} - Check system status"
    echo -e " • ${YELLOW}launchbox install${NC} - Run installer"
    echo -e " • ${YELLOW}launchbox client${NC} - Create new client"
    echo -e " • ${YELLOW}launchbox help${NC} - Show help"
fi

echo -e "\nWelcome to ${BOLD}Launchbox${NC} powered by NerdofMouth.com"
