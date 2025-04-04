#!/bin/bash
# FOSS Server Stack Installer Helper Script
# This script helps manage the installation of the FOSS server stack components

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Location of the installation scripts
SCRIPT_DIR="$(dirname "$0")/agency_stack_bootstrap_bundle_v10"

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Please run as root or with sudo${NC}"
  exit 1
fi

# Display header
echo -e "${BLUE}==============================================${NC}"
echo -e "${BLUE}       FOSS Server Stack Installer           ${NC}"
echo -e "${BLUE}==============================================${NC}"
echo ""

# Function to display available components
show_components() {
  echo -e "${YELLOW}Available Components:${NC}"
  echo "1.  Prerequisites (basic system packages)"
  echo "2.  Docker"
  echo "3.  Docker Compose"
  echo "4.  Traefik SSL (reverse proxy)"
  echo "5.  Portainer (container management)"
  echo "6.  ERPNext (ERP system)"
  echo "7.  PeerTube (video platform)"
  echo "8.  WordPress Module"
  echo "9.  Focalboard (project management)"
  echo "10. Listmonk (newsletter service)"
  echo "11. Cal.com (scheduling system)"
  echo "12. n8n (workflow automation)"
  echo "13. OpenIntegrationHub (integration platform)"
  echo "14. TaskWarrior/Calcure (task management)"
  echo "15. PostHog (analytics)"
  echo "16. KillBill (billing system)"
  echo "17. VoIP"
  echo "18. Seafile (file sharing)"
  echo "19. Documenso (document signing)"
  echo "20. WebPush (push notifications)"
  echo "21. Netdata (monitoring)"
  echo "22. Fail2ban (security)"
  echo "23. Security (additional security measures)"
  echo "24. All Components"
  echo "0.  Exit"
  echo ""
}

# Function to install a component
install_component() {
  local component=$1
  local script=""
  
  case $component in
    1) script="install_prerequisites.sh" ;;
    2) script="install_docker.sh" ;;
    3) script="install_docker_compose.sh" ;;
    4) script="install_traefik_ssl.sh" ;;
    5) script="install_portainer.sh" ;;
    6) script="install_erpnext.sh" ;;
    7) script="install_peertube.sh" ;;
    8) script="install_wordpress_module.sh" ;;
    9) script="install_focalboard.sh" ;;
    10) script="install_listmonk.sh" ;;
    11) script="install_calcom.sh" ;;
    12) script="install_n8n.sh" ;;
    13) script="install_openintegrationhub.sh" ;;
    14) script="install_taskwarrior_calcure.sh" ;;
    15) script="install_posthog.sh" ;;
    16) script="install_killbill.sh" ;;
    17) script="install_voip.sh" ;;
    18) script="install_seafile.sh" ;;
    19) script="install_documenso.sh" ;;
    20) script="install_webpush.sh" ;;
    21) script="install_netdata.sh" ;;
    22) script="install_fail2ban.sh" ;;
    23) script="install_security.sh" ;;
    24) script="install_all.sh" ;;
    *) echo -e "${RED}Invalid option${NC}"; return 1 ;;
  esac
  
  echo -e "${GREEN}Installing component: $script ${NC}"
  if [ -f "$SCRIPT_DIR/$script" ]; then
    bash "$SCRIPT_DIR/$script"
    echo -e "${GREEN}Installation of $script completed${NC}"
    return 0
  else
    echo -e "${RED}Script not found: $script${NC}"
    return 1
  fi
}

# Main menu
main_menu() {
  local choice
  
  while true; do
    show_components
    read -p "Enter your choice (0-24): " choice
    
    if [ "$choice" -eq 0 ]; then
      echo -e "${BLUE}Exiting installer. Thank you!${NC}"
      exit 0
    elif [ "$choice" -ge 1 ] && [ "$choice" -le 24 ]; then
      install_component $choice
      echo ""
      read -p "Press enter to continue..."
    else
      echo -e "${RED}Invalid choice. Please try again.${NC}"
    fi
    
    echo ""
  done
}

# Start the main menu
main_menu
