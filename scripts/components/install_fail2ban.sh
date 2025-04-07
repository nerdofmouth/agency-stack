#!/bin/bash
# install_fail2ban.sh - Intrusion prevention system for AgencyStack
# https://stack.nerdofmouth.com
#
# This script installs and configures Fail2ban with:
# - Optimized security rules
# - Custom jails for AgencyStack services
# - Notification configuration
# - Integration with other security components
#
# Author: AgencyStack Team
# Version: 1.0.0
# Created: 2025-04-07

# Set strict error handling
set -euo pipefail

# Define absolute paths - never rely on relative paths
AGENCY_ROOT="/opt/agency_stack"
AGENCY_LOG_DIR="/var/log/agency_stack"
AGENCY_CLIENTS_DIR="${AGENCY_ROOT}/clients"
AGENCY_SCRIPTS_DIR="${AGENCY_ROOT}/repo/scripts"
AGENCY_UTILS_DIR="${AGENCY_SCRIPTS_DIR}/utils"

# Import common utilities
source "${AGENCY_UTILS_DIR}/common.sh"
source "${AGENCY_UTILS_DIR}/log_helpers.sh"

# Define component-specific variables
COMPONENT="fail2ban"
COMPONENT_DIR="${AGENCY_ROOT}/${COMPONENT}"
COMPONENT_CONFIG_DIR="${COMPONENT_DIR}/config"
COMPONENT_LOG_FILE="${AGENCY_LOG_DIR}/components/${COMPONENT}.log"
COMPONENT_INSTALLED_MARKER="${COMPONENT_DIR}/.installed_ok"

# Default configuration
CLIENT_ID="${CLIENT_ID:-default}"
DOMAIN="${DOMAIN:-localhost}"
ADMIN_EMAIL="${ADMIN_EMAIL:-admin@example.com}"
FORCE=false
WITH_DEPS=false
VERBOSE=false
ENABLE_CLOUD=false
ENABLE_OPENAI=false
USE_GITHUB=false

# Fail2ban specific configuration
BAN_TIME="${BAN_TIME:-3600}"
FIND_TIME="${FIND_TIME:-600}"
MAX_RETRY="${MAX_RETRY:-5}"
IGNORE_IP="${IGNORE_IP:-127.0.0.1/8}"
TEST_MODE=false

# Show help message
show_help() {
  echo -e "${MAGENTA}${BOLD}AgencyStack Fail2ban Setup${NC}"
  echo -e "=============================="
  echo -e "This script installs and configures Fail2ban for intrusion prevention."
  echo -e ""
  echo -e "${CYAN}Usage:${NC}"
  echo -e "  $0 [options]"
  echo -e ""
  echo -e "${CYAN}Options:${NC}"
  echo -e "  ${BOLD}--domain${NC} <domain>        Domain for this installation (default: localhost)"
  echo -e "  ${BOLD}--client-id${NC} <client_id>  Client ID for multi-tenant setup (default: default)"
  echo -e "  ${BOLD}--admin-email${NC} <email>    Admin email for notifications (default: admin@example.com)"
  echo -e "  ${BOLD}--ban-time${NC} <seconds>     Ban duration in seconds (default: 3600)"
  echo -e "  ${BOLD}--find-time${NC} <seconds>    Time window for finding failures (default: 600)"
  echo -e "  ${BOLD}--max-retry${NC} <count>      Maximum number of failures before ban (default: 5)"
  echo -e "  ${BOLD}--ignore-ip${NC} <ip>         IP address to ignore (default: 127.0.0.1/8)"
  echo -e "  ${BOLD}--test-mode${NC}              Enable test mode (increases max retries, adds your IP to whitelist)"
  echo -e "  ${BOLD}--enable-cloud${NC}           Enable cloud service integrations"
  echo -e "  ${BOLD}--enable-openai${NC}          Enable OpenAI integrations"
  echo -e "  ${BOLD}--use-github${NC}             Use GitHub for repositories"
  echo -e "  ${BOLD}--force${NC}                  Force reinstallation even if Fail2ban is already installed"
  echo -e "  ${BOLD}--with-deps${NC}              Automatically install dependencies if missing"
  echo -e "  ${BOLD}--verbose${NC}                Show detailed output during installation"
  echo -e "  ${BOLD}--help${NC}                   Show this help message and exit"
  echo -e ""
  echo -e "${CYAN}Example:${NC}"
  echo -e "  $0 --domain example.com --admin-email admin@example.com --ban-time 7200"
  echo -e ""
  exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    --domain)
      DOMAIN="$2"
      shift 2
      ;;
    --admin-email)
      ADMIN_EMAIL="$2"
      shift 2
      ;;
    --client-id)
      CLIENT_ID="$2"
      shift 2
      ;;
    --ban-time)
      BAN_TIME="$2"
      shift 2
      ;;
    --find-time)
      FIND_TIME="$2"
      shift 2
      ;;
    --max-retry)
      MAX_RETRY="$2"
      shift 2
      ;;
    --ignore-ip)
      IGNORE_IP="$2"
      shift 2
      ;;
    --test-mode)
      TEST_MODE=true
      MAX_RETRY=15  # Increase retry limit to avoid accidental lockouts
      # Get the current SSH IP and add it to the ignore list
      CURRENT_IP=$(who am i | awk '{print $5}' | sed 's/[()]//g' | cut -d':' -f1)
      if [[ -n "$CURRENT_IP" ]] && [[ "$CURRENT_IP" != "127.0.0.1" ]]; then
        if [[ -z "$IGNORE_IP" ]]; then
          IGNORE_IP="$CURRENT_IP"
        else
          IGNORE_IP="$IGNORE_IP $CURRENT_IP"
        fi
      fi
      log "WARNING" "Test mode enabled - Using safer Fail2ban settings" "${YELLOW}⚠️ Test mode enabled - Using safer Fail2ban settings${NC}"
      log "INFO" "SSH IP $CURRENT_IP added to ignore list" "${CYAN}SSH IP $CURRENT_IP added to ignore list${NC}"
      shift
      ;;
    --force)
      FORCE=true
      shift
      ;;
    --with-deps)
      WITH_DEPS=true
      shift
      ;;
    --verbose)
      VERBOSE=true
      shift
      ;;
    --enable-cloud)
      ENABLE_CLOUD=true
      shift
      ;;
    --enable-openai)
      ENABLE_OPENAI=true
      shift
      ;;
    --use-github)
      USE_GITHUB=true
      shift
      ;;
    -h|--help)
      show_help
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      show_help
      exit 1
      ;;
  esac
done

# Setup logging
mkdir -p "$(dirname "${COMPONENT_LOG_FILE}")"
exec &> >(tee -a "${COMPONENT_LOG_FILE}")

# Log function
log() {
  local level="$1"
  local message="$2"
  local display="$3"
  
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message" >> "${COMPONENT_LOG_FILE}"
  if [[ -n "${display}" ]]; then
    echo -e "${display}"
  fi
}

# Integration log function
integration_log() {
  local message="$1"
  local json_data="$2"
  
  echo "{\"timestamp\":\"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\",\"component\":\"${COMPONENT}\",\"message\":\"${message}\",\"data\":${json_data}}" >> "${AGENCY_LOG_DIR}/integration.log"
}

log "INFO" "Starting Fail2ban installation" "${BLUE}Starting Fail2ban installation...${NC}"

# Set up site-specific variables
SITE_NAME=${DOMAIN//./_}
CLIENT_DIR="${AGENCY_CLIENTS_DIR}/${CLIENT_ID}"
INSTALL_DIR="${CLIENT_DIR}/${COMPONENT}"
INSTALL_LOG="${COMPONENT_LOG_FILE}"

# Create necessary directories
mkdir -p "${COMPONENT_DIR}"
mkdir -p "${INSTALL_DIR}"
mkdir -p "${COMPONENT_CONFIG_DIR}"
mkdir -p "${INSTALL_DIR}/jail.d"

# Check for existing Fail2ban installation
if command -v fail2ban-server &> /dev/null && systemctl is-active --quiet fail2ban && [[ "${FORCE}" != "true" ]]; then
  log "INFO" "Fail2ban already installed and running" "${GREEN}✅ Fail2ban already installed and running.${NC}"
  
  # Create installation marker if it doesn't exist
  if [[ ! -f "${COMPONENT_INSTALLED_MARKER}" ]]; then
    touch "${COMPONENT_INSTALLED_MARKER}"
    log "INFO" "Added installation marker for existing Fail2ban" "${CYAN}Added installation marker for existing Fail2ban${NC}"
  fi
  
  # Exit if we're not forcing reinstallation
  if [[ "${FORCE}" != "true" ]]; then
    log "INFO" "Use --force to reinstall" "${CYAN}Use --force to reinstall.${NC}"
    exit 0
  fi
fi

# Install Fail2ban package
log "INFO" "Installing Fail2ban packages" "${CYAN}Installing Fail2ban packages...${NC}"
apt-get update >> "${INSTALL_LOG}" 2>&1
apt-get install -y fail2ban >> "${INSTALL_LOG}" 2>&1

# Backup original configuration
log "INFO" "Backing up original configuration" "${CYAN}Backing up original configuration...${NC}"
if [ -f /etc/fail2ban/jail.conf ]; then
  cp /etc/fail2ban/jail.conf "${COMPONENT_CONFIG_DIR}/jail.conf.original"
fi

# Configure jail.local
log "INFO" "Creating Fail2ban jail configuration" "${CYAN}Creating Fail2ban jail configuration...${NC}"

if [ "$TEST_MODE" = true ]; then
  log "WARNING" "Test mode: Using relaxed settings for testing" "${YELLOW}⚠️ Test mode: Using relaxed settings for testing${NC}"
  cat > /etc/fail2ban/jail.local <<EOL
[DEFAULT]
# "bantime" is the number of seconds that a host is banned.
bantime  = 300
# A host is banned if it has generated "maxretry" during the last "findtime"
# seconds.
findtime  = ${FIND_TIME}
# "maxretry" is the number of failures before a host get banned.
maxretry = ${MAX_RETRY}
# "ignoreip" can be a list of IP addresses, CIDR masks or DNS hosts. Fail2ban
# will not ban a host which matches an address in this list.
ignoreip = ${IGNORE_IP}
# Email settings - only used if action contains email notification
destemail = ${ADMIN_EMAIL}
sender = fail2ban@${DOMAIN}
# Testing mode - reduced severity
action = %(action_)s
EOL
else
  cat > /etc/fail2ban/jail.local <<EOL
[DEFAULT]
# "bantime" is the number of seconds that a host is banned.
bantime  = ${BAN_TIME}
# A host is banned if it has generated "maxretry" during the last "findtime"
# seconds.
findtime  = ${FIND_TIME}
# "maxretry" is the number of failures before a host get banned.
maxretry = ${MAX_RETRY}
# "ignoreip" can be a list of IP addresses, CIDR masks or DNS hosts. Fail2ban
# will not ban a host which matches an address in this list.
ignoreip = ${IGNORE_IP}
# Email settings - only used if action contains email notification
destemail = ${ADMIN_EMAIL}
sender = fail2ban@${DOMAIN}
action = %(action_mwl)s
EOL
fi

# Create SSH jail configuration
log "INFO" "Creating SSH jail configuration" "${CYAN}Creating SSH jail configuration...${NC}"
cat > /etc/fail2ban/jail.d/sshd.conf <<EOL
[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
EOL

# Check if Traefik is installed and create a jail for it
if docker ps --format '{{.Names}}' | grep -q "traefik"; then
  log "INFO" "Creating Traefik jail configuration" "${CYAN}Creating Traefik jail configuration...${NC}"
  cat > /etc/fail2ban/jail.d/traefik.conf <<EOL
[traefik-auth]
enabled = true
port = http,https
filter = traefik-auth
logpath = /var/log/traefik/access.log
maxretry = 5
EOL

  # Create Traefik filter
  cat > /etc/fail2ban/filter.d/traefik-auth.conf <<EOL
[Definition]
failregex = ^.*"[A-Z]+ .*" (401|403) .*$
ignoreregex =
EOL
fi

# Check for Keycloak and add jail if needed
if docker ps --format '{{.Names}}' | grep -q "keycloak"; then
  log "INFO" "Creating Keycloak jail configuration" "${CYAN}Creating Keycloak jail configuration...${NC}"
  cat > /etc/fail2ban/jail.d/keycloak.conf <<EOL
[keycloak]
enabled = true
port = http,https
filter = keycloak
logpath = /opt/agency_stack/clients/${CLIENT_ID}/keycloak/logs/keycloak.log
maxretry = 5
EOL

  # Create Keycloak filter
  cat > /etc/fail2ban/filter.d/keycloak.conf <<EOL
[Definition]
failregex = ^.*Login failed.*username=.*$
ignoreregex =
EOL
fi

# Create a custom status monitoring script
log "INFO" "Creating status monitoring script" "${CYAN}Creating status monitoring script...${NC}"
cat > "${INSTALL_DIR}/fail2ban-status.sh" <<EOL
#!/bin/bash
# Script to check Fail2ban status and banned IPs

echo "Fail2ban Status Report for $(hostname) - $(date)"
echo "==============================================="
echo

echo "Service Status:"
systemctl status fail2ban | grep Active

echo
echo "Currently Banned IPs:"
fail2ban-client status | grep "Jail list" | sed 's/^.*Jail list://' | tr ',' '\n' | while read -r jail; do
  jail=\$(echo \$jail | tr -d ' ')
  if [ -n "\$jail" ]; then
    echo "* \$jail:"
    fail2ban-client status \$jail | grep "Currently banned" | sed 's/^.*Currently banned:/\t/'
    banned=\$(fail2ban-client status \$jail | grep "Currently banned" | sed 's/^.*Currently banned:[ \t]*//')
    if [ "\$banned" -gt 0 ]; then
      echo -e "\tBanned IPs:"
      fail2ban-client status \$jail | grep "Banned IP list" | sed 's/^.*Banned IP list:/\t/' | tr ',' '\n' | sed 's/^/\t\t/'
    fi
  fi
done

echo
echo "Recent Actions (last 10):"
grep "Ban " /var/log/fail2ban.log | tail -10
EOL

chmod +x "${INSTALL_DIR}/fail2ban-status.sh"

# Create a notification script for email alerts
log "INFO" "Creating email notification script" "${CYAN}Creating email notification script...${NC}"
cat > "${INSTALL_DIR}/fail2ban-notify.sh" <<EOL
#!/bin/bash
# Script to send email notifications when IP is banned

# Check arguments
if [ \$# -lt 3 ]; then
  echo "Usage: \$0 <jail> <ip> <failures>"
  exit 1
fi

JAIL="\$1"
IP="\$2"
FAILURES="\$3"
HOSTNAME=\$(hostname)
DATE=\$(date)
ADMIN_EMAIL="${ADMIN_EMAIL}"

# Create email content
SUBJECT="[Fail2Ban] \$JAIL: banned \$IP from \$HOSTNAME"

# Check if whois is installed
if command -v whois &> /dev/null; then
  WHOIS=\$(whois \$IP 2>/dev/null || echo "No whois information available")
else
  WHOIS="whois command not available"
fi

# Send email
cat << EOF | /usr/sbin/sendmail -t
To: \${ADMIN_EMAIL}
From: Fail2Ban <root@\$HOSTNAME>
Subject: \${SUBJECT}

The IP \$IP has been banned by Fail2Ban after \$FAILURES failures.

Date: \$DATE
Hostname: \$HOSTNAME
Jail: \$JAIL

IP Information:
--------------
\$WHOIS

EOF

# Log notification
logger -t fail2ban-notify "Notification sent for IP \$IP banned in jail \$JAIL"
EOL

chmod +x "${INSTALL_DIR}/fail2ban-notify.sh"

# Configure Fail2ban to use our notification script
cat > /etc/fail2ban/action.d/custom-notify.conf <<EOL
[Definition]
actionstart = 
actionstop = 
actioncheck = 
actionban = ${INSTALL_DIR}/fail2ban-notify.sh <name> <ip> <failures>
actionunban = 
EOL

# Add the custom action to the default jail
echo "action = %(action_)s
         custom-notify" >> /etc/fail2ban/jail.local

# Copy the main configuration to component directory
cp -r /etc/fail2ban/jail.d "${COMPONENT_CONFIG_DIR}/"
cp /etc/fail2ban/jail.local "${COMPONENT_CONFIG_DIR}/"

# Restart Fail2ban to apply the changes
log "INFO" "Restarting Fail2ban service" "${CYAN}Restarting Fail2ban service...${NC}"
systemctl enable fail2ban >> "${INSTALL_LOG}" 2>&1
systemctl restart fail2ban >> "${INSTALL_LOG}" 2>&1

# Check if Fail2ban is running
if systemctl is-active --quiet fail2ban; then
  log "SUCCESS" "Fail2ban service is running" "${GREEN}✅ Fail2ban service is running.${NC}"
else
  log "ERROR" "Fail2ban service failed to start" "${RED}❌ Fail2ban service failed to start. Check the logs.${NC}"
  exit 1
fi

# Create installation marker
touch "${COMPONENT_INSTALLED_MARKER}"

# Log integration data
integration_log "Fail2ban installed" "{\"domain\":\"${DOMAIN}\",\"client_id\":\"${CLIENT_ID}\",\"ban_time\":${BAN_TIME},\"max_retry\":${MAX_RETRY}}"

log "SUCCESS" "Fail2ban installation completed" "${GREEN}✅ Fail2ban installation completed!${NC}"
echo
log "INFO" "Fail2ban configuration" "${CYAN}Fail2ban configuration:${NC}"
echo -e "  - Ban time: ${BAN_TIME} seconds"
echo -e "  - Find time: ${FIND_TIME} seconds"
echo -e "  - Max retry: ${MAX_RETRY} attempts"
echo -e "  - Ignored IPs: ${IGNORE_IP}"
echo -e "  - Admin email: ${ADMIN_EMAIL}"
echo
echo -e "${CYAN}Status script: ${INSTALL_DIR}/fail2ban-status.sh${NC}"
echo -e "${CYAN}Configuration backup: ${COMPONENT_CONFIG_DIR}/jail.conf.original${NC}"
echo
echo -e "${GREEN}Fail2ban is now protecting your system against brute force attacks.${NC}"

exit 0
