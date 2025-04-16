#!/bin/bash
# audit.sh - Audit AgencyStack components status
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
COMPONENTS_FILE="/opt/agency_stack/installed_components.txt"
LOG_DIR="/var/log/agency_stack"
LOG_FILE="${LOG_DIR}/audit-$(date +%Y%m%d-%H%M%S).log"

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

# Header
log "${MAGENTA}${BOLD}🔍 AgencyStack System Audit${NC}"
log "========================================"
log "$(date)"
log "Server: $(hostname)"
log ""

# Table header
log "┌──────────────────────────────────┬─────────┬─────────────────────────────┐"
log "│ ${BOLD}Component${NC}                       │ ${BOLD}Status${NC}  │ ${BOLD}Details${NC}                    │"
log "├──────────────────────────────────┼─────────┼─────────────────────────────┤"

# Get active Docker containers
ACTIVE_CONTAINERS=$(docker ps --format "{{.Names}}" 2>/dev/null || echo "")

# Check each installed component
if [ -f "$COMPONENTS_FILE" ]; then
  ACTIVE_COUNT=0
  FAILED_COUNT=0
  
  while IFS= read -r component; do
    # Skip empty lines
    [ -z "$component" ] && continue
    
    # Normalize container name
    CONTAINER_NAME="agency_stack_$(echo "$component" | tr '[:upper:]' '[:lower:]' | tr ' ' '_')"
    
    # Handle special cases
    if [[ "$component" == "Traefik" ]]; then
      CONTAINER_NAME="agency_stack_traefik"
    elif [[ "$component" == "Mailu" ]]; then
      CONTAINER_NAME="mailu-front"
    elif [[ "$component" == "Netmaker" ]]; then
      CONTAINER_NAME="netmaker"
    elif [[ "$component" == "Drone CI" ]]; then
      CONTAINER_NAME="agency_stack_drone_server"
    elif [[ "$component" == "Fail2Ban" ]]; then
      # Check system service instead
      if systemctl is-active --quiet fail2ban; then
        STATUS="${GREEN}✅ Active${NC}"
        DETAILS="System service"
        ACTIVE_COUNT=$((ACTIVE_COUNT + 1))
      else
        STATUS="${RED}❌ Failed${NC}"
        DETAILS="Service not running"
        FAILED_COUNT=$((FAILED_COUNT + 1))
      fi
      
      # Print status and continue to next component
      printf "│ %-32s │ %-7s │ %-27s │\n" "$component" "$STATUS" "$DETAILS" | tee -a "$LOG_FILE"
      continue
    fi
    
    # Check if container exists at all
    if docker ps -a --format "{{.Names}}" | grep -q "$CONTAINER_NAME"; then
      # Check if container is running
      if echo "$ACTIVE_CONTAINERS" | grep -q "$CONTAINER_NAME"; then
        STATUS="${GREEN}✅ Active${NC}"
        
        # Get container details
        UPTIME=$(docker inspect --format='{{.State.StartedAt}}' "$CONTAINER_NAME" | xargs -I{} date -d {} +"%d days %H hours")
        if [[ "$uptime" == *"hours"* ]]; then
          UPTIME=$(echo "$UPTIME" | sed 's/0 days //')
        fi
        
        DETAILS="Running for $UPTIME"
        ACTIVE_COUNT=$((ACTIVE_COUNT + 1))
      else
        STATUS="${RED}❌ Stopped${NC}"
        DETAILS="Container exists but not running"
        FAILED_COUNT=$((FAILED_COUNT + 1))
      fi
    else
      STATUS="${RED}❌ Missing${NC}"
      DETAILS="Container not found"
      FAILED_COUNT=$((FAILED_COUNT + 1))
    fi
    
    # Print status
    printf "│ %-32s │ %-7s │ %-27s │\n" "$component" "$STATUS" "$DETAILS" | tee -a "$LOG_FILE"
  done < "$COMPONENTS_FILE"
  
  # Table footer
  log "├──────────────────────────────────┴─────────┴─────────────────────────────┤"
  log "│ ${BOLD}Summary:${NC} $ACTIVE_COUNT active components, $FAILED_COUNT failed components                        │"
  log "└────────────────────────────────────────────────────────────────────────┘"
  
  # System health status
  log ""
  if [ $FAILED_COUNT -eq 0 ]; then
    log "${GREEN}${BOLD}✅ All components are running properly${NC}"
  elif [ $FAILED_COUNT -lt 3 ]; then
    log "${YELLOW}${BOLD}⚠️ Some components are not running properly${NC}"
    log "${YELLOW}Run 'make health-check' for detailed diagnostics${NC}"
  else
    log "${RED}${BOLD}❌ Multiple components are failing${NC}"
    log "${RED}Run 'make health-check' for detailed diagnostics${NC}"
    log "${RED}Consider reviewing logs with 'make logs'${NC}"
  fi
  
  # System resources
  log ""
  log "${CYAN}${BOLD}System Resources:${NC}"
  log "├─ ${CYAN}Disk Usage:${NC} $(df -h / | awk 'NR==2 {print $5 " used (" $3 " of " $2 ")"}')${NC}"
  log "├─ ${CYAN}Memory:${NC} $(free -h | awk 'NR==2 {printf "%s used (%s of %s)", $3, $3, $2}')${NC}"
  log "├─ ${CYAN}CPU Load:${NC} $(cat /proc/loadavg | awk '{print $1 ", " $2 ", " $3}')${NC}"
  log "└─ ${CYAN}Containers:${NC} $(docker ps -q | wc -l) running / $(docker ps -a -q | wc -l) total${NC}"
  
  # Check for updates available
  log ""
  log "${CYAN}${BOLD}Available Updates:${NC}"
  if [ -x "$(command -v apt)" ]; then
    UPDATE_COUNT=$(apt list --upgradable 2>/dev/null | grep -c -v "Listing...")
    if [ $UPDATE_COUNT -gt 0 ]; then
      log "${YELLOW}⚠️ $UPDATE_COUNT package updates available${NC}"
      log "${YELLOW}Run 'sudo apt update && sudo apt upgrade' to apply updates${NC}"
    else
      log "${GREEN}✅ System is up to date${NC}"
    fi
  else
    log "${YELLOW}⚠️ Unable to check for updates${NC}"
  fi
  
  # Last health check
  LAST_HEALTH_CHECK=$(ls -t "$LOG_DIR"/health_check-*.log 2>/dev/null | head -1)
  if [ -n "$LAST_HEALTH_CHECK" ]; then
    HEALTH_CHECK_TIME=$(stat -c '%y' "$LAST_HEALTH_CHECK" | cut -d. -f1)
    ERRORS=$(grep -c "❌" "$LAST_HEALTH_CHECK")
    WARNINGS=$(grep -c "⚠️" "$LAST_HEALTH_CHECK")
    
    log ""
    log "${CYAN}${BOLD}Last Health Check:${NC} $HEALTH_CHECK_TIME${NC}"
    if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
      log "${GREEN}✅ No issues detected${NC}"
    else
      log "${YELLOW}⚠️ $ERRORS errors, $WARNINGS warnings${NC}"
      log "${YELLOW}Review with 'cat $LAST_HEALTH_CHECK'${NC}"
    fi
  fi
else
  log "│ ${YELLOW}No components installed yet${NC}           │           │                             │"
  log "└──────────────────────────────────┴─────────┴─────────────────────────────┘"
fi

exit 0
