#!/bin/bash
# Launchbox Full Installation Script
# https://nerdofmouth.com/launchbox

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Initialize port management
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
echo -e "${BLUE}${BOLD}🔌 Initializing Launchbox installation...${NC}"

# Display header
echo -e "${MAGENTA}${BOLD}"
cat << "EOF"
 _                           _     _                
| |                         | |   | |               
| |     __ _ _   _ _ __   ___| |__ | |__   _____  __
| |    / _` | | | | '_ \ / __| '_ \| '_ \ / _ \ \/ /
| |___| (_| | |_| | | | | (__| | | | |_) | (_) >  < 
|______\__,_|\__,_|_| |_|\___|_| |_|_.__/ \___/_/\_\
EOF
echo -e "${NC}"

# Show motto
MOTTO_PATH="$SCRIPT_DIR/../../scripts/motto.sh"
if [ -f "$MOTTO_PATH" ]; then
  source "$MOTTO_PATH" && random_motto
  echo ""
fi

echo -e "${CYAN}🔌 Initializing port management system...${NC}"
source "$SCRIPT_DIR/../../scripts/port_manager.sh"
echo -e "${GREEN}✅ Port management system initialized.${NC}"

bash install_prerequisites.sh
bash install_docker.sh
bash install_docker_compose.sh
bash install_traefik_ssl.sh
bash install_portainer.sh
bash install_erpnext.sh
bash install_peertube.sh
bash install_wordpress_module.sh
bash install_focalboard.sh
bash install_listmonk.sh
bash install_calcom.sh
bash install_n8n.sh
bash install_openintegrationhub.sh
bash install_taskwarrior_calcure.sh
bash install_posthog.sh
bash install_killbill.sh
bash install_voip.sh
bash install_seafile.sh
bash install_documenso.sh
bash install_webpush.sh
bash install_netdata.sh
bash install_fail2ban.sh
bash install_security.sh

# Newly added components
bash install_keycloak.sh
bash install_tailscale.sh
bash install_signing_timestamps.sh
bash install_backup_strategy.sh
bash install_markdown_lexical.sh
bash install_launchpad_dashboard.sh

echo -e "${GREEN}✅ FOSS Server Stack installation completed!${NC}"
echo -e "${CYAN}🚀 Access your services through the Launchpad Dashboard${NC}"
echo ""
echo -e "${YELLOW}📊 Port allocation summary:${NC}"
"$SCRIPT_DIR/../../scripts/port_manager.sh" list

# Show final motto after successful installation
if [ -f "$MOTTO_PATH" ]; then
  echo ""
  source "$MOTTO_PATH" && random_motto
  echo -e "\n${CYAN}Thank you for choosing Launchbox!${NC}"
fi
