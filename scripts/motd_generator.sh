#!/bin/bash
# motd_generator.sh - Create Message Of The Day for AgencyStack
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
CONFIG_ENV="/opt/agency_stack/config.env"
MOTD_FILE="/etc/motd"
MOTD_TEMP=$(mktemp)
LOG_DIR="/var/log/agency_stack"
LOG_FILE="${LOG_DIR}/motd_generator-$(date +%Y%m%d-%H%M%S).log"

# Create log directory if it doesn't exist
mkdir -p "$LOG_DIR"

# Non-interactive mode flag
AUTO_MODE=false

# Check command-line arguments
for arg in "$@"; do
  case $arg in
    --yes|--auto)
      AUTO_MODE=true
      ;;
    *)
      # Unknown argument
      ;;
  esac
done

# Logging function
log() {
  echo -e "$1" | tee -a "$LOG_FILE"
}

# Check if AgencyStack is installed
if [ ! -f "$CONFIG_ENV" ]; then
  log "${RED}Error: AgencyStack is not installed${NC}"
  log "Please run the AgencyStack installation first"
  exit 1
fi

# Source environment variables
source "$CONFIG_ENV"

# Get system information
HOSTNAME=$(hostname)
PRIMARY_DOMAIN=${PRIMARY_DOMAIN:-"Not configured"}
UPTIME=$(uptime -p)
IP_ADDR=$(hostname -I | awk '{print $1}')
COMPONENTS_FILE="/opt/agency_stack/installed_components.txt"
DISK_USAGE=$(df -h / | awk 'NR==2 {print $5 " used (" $3 " of " $2 ")"}')
MEMORY_USAGE=$(free -h | awk 'NR==2 {printf "%s used (%s of %s)", $3, $3, $2}')
LOAD_AVG=$(cat /proc/loadavg | awk '{print $1 ", " $2 ", " $3}')

# Create MOTD header
cat > "$MOTD_TEMP" << EOL
${BLUE}╔════════════════════════════════════════════════════════════════════════════╗${NC}
${BLUE}║                                                                            ║${NC}
${BLUE}║  ${BOLD}${CYAN}    _                            _____  _             _                   ${BLUE}  ║${NC}
${BLUE}║  ${BOLD}${CYAN}   / \\   __ _  ___ _ __   ___ _  \\_   \\| |_ __ _  ___| | __               ${BLUE} ║${NC}
${BLUE}║  ${BOLD}${CYAN}  / _ \\ / _\` |/ _ \\ '_ \\ / __| | / /\\/ | __/ _\` |/ __| |/ /               ${BLUE} ║${NC}
${BLUE}║  ${BOLD}${CYAN} / ___ \\ (_| |  __/ | | | (__| |/ /  | | || (_| | (__|   <                ${BLUE} ║${NC}
${BLUE}║  ${BOLD}${CYAN}/_/   \\_\\__, |\\___|_| |_|\\___|_/\\/   |_|\\__\\__,_|\\___|_|\\_\\               ${BLUE} ║${NC}
${BLUE}║  ${BOLD}${CYAN}        |___/                                                             ${BLUE} ║${NC}
${BLUE}║                                                                            ║${NC}
${BLUE}╠════════════════════════════════════════════════════════════════════════════╣${NC}
${BLUE}║                                                                            ║${NC}
${BLUE}║  ${GREEN}Host:${NC} $HOSTNAME                                                     ${BLUE}║${NC}
${BLUE}║  ${GREEN}Domain:${NC} $PRIMARY_DOMAIN                                              ${BLUE}║${NC}
${BLUE}║  ${GREEN}IP Address:${NC} $IP_ADDR                                                 ${BLUE}║${NC}
${BLUE}║  ${GREEN}System Uptime:${NC} $UPTIME                                               ${BLUE}║${NC}
${BLUE}║  ${GREEN}Disk Usage:${NC} $DISK_USAGE                                              ${BLUE}║${NC}
${BLUE}║  ${GREEN}Memory:${NC} $MEMORY_USAGE                                                ${BLUE}║${NC}
${BLUE}║  ${GREEN}Load Average:${NC} $LOAD_AVG                                              ${BLUE}║${NC}
${BLUE}║                                                                            ║${NC}
${BLUE}╠════════════════════════════════════════════════════════════════════════════╣${NC}
${BLUE}║  ${BOLD}${CYAN}Installed Components:${NC}                                                 ${BLUE}║${NC}
EOL

# Add installed components
if [ -f "$COMPONENTS_FILE" ]; then
  COMPONENTS=()
  while IFS= read -r component; do
    COMPONENTS+=("$component")
  done < "$COMPONENTS_FILE"
  
  # Check if components are running
  for i in "${!COMPONENTS[@]}"; do
    COMPONENT="${COMPONENTS[$i]}"
    CONTAINER_NAME="agency_stack_$(echo "$COMPONENT" | tr '[:upper:]' '[:lower:]' | tr ' ' '_')"
    
    # Handle special cases
    if [[ "$COMPONENT" == "Traefik" ]]; then
      CONTAINER_NAME="agency_stack_traefik"
    elif [[ "$COMPONENT" == "Mailu" ]]; then
      CONTAINER_NAME="mailu-front"
    fi
    
    # Check if container is running
    if docker ps --format "{{.Names}}" | grep -q "$CONTAINER_NAME"; then
      echo "${BLUE}║  ${GREEN}✅ ${COMPONENT}${NC}" >> "$MOTD_TEMP"
    else
      echo "${BLUE}║  ${RED}❌ ${COMPONENT}${NC}" >> "$MOTD_TEMP"
    fi
  done
else
  echo "${BLUE}║  ${YELLOW}No components installed yet${NC}" >> "$MOTD_TEMP"
fi

# Add footer
cat >> "$MOTD_TEMP" << EOL
${BLUE}║                                                                            ║${NC}
${BLUE}╠════════════════════════════════════════════════════════════════════════════╣${NC}
${BLUE}║  ${CYAN}Documentation:${NC} https://stack.nerdofmouth.com                          ${BLUE}║${NC}
${BLUE}║  ${CYAN}Health Check:${NC} make health-check                                       ${BLUE}║${NC}
${BLUE}║  ${CYAN}Monitoring:${NC} https://grafana.${PRIMARY_DOMAIN}                         ${BLUE}║${NC}
${BLUE}║  ${CYAN}System Audit:${NC} make audit                                              ${BLUE}║${NC}
${BLUE}║                                                                            ║${NC}
${BLUE}╚════════════════════════════════════════════════════════════════════════════╝${NC}
EOL

# Ask for confirmation if not in auto mode
if [ "$AUTO_MODE" = false ]; then
  log "Generated MOTD preview:"
  log "================================"
  cat "$MOTD_TEMP"
  log "================================"
  
  read -p "Install this MOTD? (y/n): " confirm
  if [[ "$confirm" != "y" ]]; then
    log "${YELLOW}MOTD installation cancelled${NC}"
    rm "$MOTD_TEMP"
    exit 0
  fi
fi

# Install MOTD
sudo mv "$MOTD_TEMP" "$MOTD_FILE"
sudo chmod 644 "$MOTD_FILE"

log "${GREEN}✅ MOTD has been installed at ${MOTD_FILE}${NC}"
log "${GREEN}✅ It will be displayed on next login${NC}"

# Also register in update-motd.d for Ubuntu systems
if [ -d "/etc/update-motd.d" ]; then
  MOTD_SCRIPT="/etc/update-motd.d/99-agencystack"
  
  cat > "$MOTD_TEMP" << EOL
#!/bin/bash
cat /etc/motd
EOL
  
  sudo mv "$MOTD_TEMP" "$MOTD_SCRIPT"
  sudo chmod 755 "$MOTD_SCRIPT"
  
  log "${GREEN}✅ MOTD script installed at ${MOTD_SCRIPT}${NC}"
  log "${GREEN}✅ It will be updated automatically${NC}"
fi

exit 0
