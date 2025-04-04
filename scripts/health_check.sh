#!/bin/bash
# health_check.sh - Verify all AgencyStack components are working
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

# Log file
LOG_DIR="/var/log/agency_stack"
LOG_FILE="${LOG_DIR}/health-check-$(date +%Y%m%d-%H%M%S).log"
REPORT_FILE="/tmp/agency_stack_health_report.html"

# Status tracking
ERRORS=0
ERROR_MESSAGES=""
WARNINGS=0
WARNING_MESSAGES=""

# Create log directory if it doesn't exist
mkdir -p "$LOG_DIR"

# Logging function
log() {
  echo -e "$1" | tee -a "$LOG_FILE"
}

# Alert functions
add_error() {
  local message="$1"
  ERRORS=$((ERRORS + 1))
  ERROR_MESSAGES="${ERROR_MESSAGES}⛔ ${message}\n"
  log "${RED}❌ $message${NC}"
}

add_warning() {
  local message="$1"
  WARNINGS=$((WARNINGS + 1))
  WARNING_MESSAGES="${WARNING_MESSAGES}⚠️ ${message}\n"
  log "${YELLOW}⚠️ $message${NC}"
}

add_success() {
  local message="$1"
  log "${GREEN}✅ $message${NC}"
}

# Alerting functions
send_email_alert() {
  local subject="$1"
  local message="$2"
  
  if [ -f "/opt/agency_stack/config.env" ]; then
    source "/opt/agency_stack/config.env"
    
    if [[ "$SMTP_ENABLED" == "true" ]]; then
      log "${BLUE}Sending email alert...${NC}"
      
      # Create email content
      local email_file=$(mktemp)
      cat > "$email_file" << EOL
From: AgencyStack Monitoring <$SMTP_FROM>
To: $ALERT_EMAIL_RECIPIENT
Subject: $subject
Content-Type: text/plain; charset=UTF-8

$message

Time: $(date)
Server: $(hostname)
---
AgencyStack Monitoring System
EOL
      
      # Send email using curl
      if curl --url "smtp://${SMTP_HOST}:${SMTP_PORT}" \
         --ssl-reqd \
         --mail-from "${SMTP_FROM}" \
         --mail-rcpt "${ALERT_EMAIL_RECIPIENT}" \
         --upload-file "$email_file" \
         --user "${SMTP_USERNAME}:${SMTP_PASSWORD}" \
         --silent --show-error --fail; then
        log "${GREEN}Email alert sent successfully${NC}"
      else
        log "${RED}Failed to send email alert${NC}"
      fi
      
      # Clean up
      rm -f "$email_file"
    else
      log "${YELLOW}Email alerts disabled (SMTP_ENABLED is not true)${NC}"
    fi
  else
    log "${RED}Cannot send email alert: config.env not found${NC}"
  fi
}

send_telegram_alert() {
  local subject="$1"
  local message="$2"
  
  if [ -f "/opt/agency_stack/config.env" ]; then
    source "/opt/agency_stack/config.env"
    
    if [[ -n "$TELEGRAM_BOT_TOKEN" && -n "$TELEGRAM_CHAT_ID" ]]; then
      log "${BLUE}Sending Telegram alert...${NC}"
      
      # Format message
      local formatted_message="*${subject}*\n\n${message}\n\nTime: $(date)\nServer: $(hostname)"
      
      # Send to Telegram
      if curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
         -d chat_id="${TELEGRAM_CHAT_ID}" \
         -d text="${formatted_message}" \
         -d parse_mode="Markdown" \
         --silent --show-error --fail; then
        log "${GREEN}Telegram alert sent successfully${NC}"
      else
        log "${RED}Failed to send Telegram alert${NC}"
      fi
    else
      log "${YELLOW}Telegram alerts disabled (bot token or chat ID not configured)${NC}"
    fi
  else
    log "${RED}Cannot send Telegram alert: config.env not found${NC}"
  fi
}

send_webhook_alert() {
  local subject="$1"
  local message="$2"
  
  if [ -f "/opt/agency_stack/config.env" ]; then
    source "/opt/agency_stack/config.env"
    
    if [[ -n "$WEBHOOK_URL" ]]; then
      log "${BLUE}Sending webhook alert...${NC}"
      
      # Create JSON payload
      local json_payload=$(cat << EOL
{
  "title": "${subject}",
  "message": $(echo "${message}" | jq -Rs .),
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "hostname": "$(hostname)",
  "severity": "error",
  "num_errors": $ERRORS,
  "num_warnings": $WARNINGS
}
EOL
)
      
      # Send to webhook
      if curl -s -X POST "${WEBHOOK_URL}" \
         -H "Content-Type: application/json" \
         -d "${json_payload}" \
         --silent --show-error --fail; then
        log "${GREEN}Webhook alert sent successfully${NC}"
      else
        log "${RED}Failed to send webhook alert${NC}"
      fi
    else
      log "${YELLOW}Webhook alerts disabled (URL not configured)${NC}"
    fi
  else
    log "${RED}Cannot send webhook alert: config.env not found${NC}"
  fi
}

# Master alert function that determines which channels to use
send_alerts() {
  local subject="[ALERT] AgencyStack Health Check Failure on $(hostname)"
  local message="Health check detected issues:\n\n"
  
  if [ $ERRORS -gt 0 ]; then
    message="${message}${ERROR_MESSAGES}\n"
  fi
  
  if [ $WARNINGS -gt 0 ]; then
    message="${message}${WARNING_MESSAGES}\n"
  fi
  
  message="${message}\nFull report available at: ${LOG_FILE}\n"
  
  # Load config if exists
  if [ -f "/opt/agency_stack/config.env" ]; then
    source "/opt/agency_stack/config.env"
  fi
  
  # Send alerts based on configuration
  if [[ "$ALERT_EMAIL_ENABLED" == "true" ]]; then
    send_email_alert "$subject" "$message"
  fi
  
  if [[ "$ALERT_TELEGRAM_ENABLED" == "true" ]]; then
    send_telegram_alert "$subject" "$message"
  fi
  
  if [[ "$ALERT_WEBHOOK_ENABLED" == "true" ]]; then
    send_webhook_alert "$subject" "$message"
  fi
}

log "${MAGENTA}${BOLD}🩺 AgencyStack Health Check${NC}"
log "======================================="
log "$(date)"
log "Server: $(hostname)"
log ""

# Function to check a component's health
check_component() {
  local name="$1"
  local check_command="$2"
  local success_msg="$3"
  local failure_msg="$4"
  
  log "${BLUE}Checking ${name}...${NC}"
  
  if eval "$check_command"; then
    add_success "$success_msg"
    return 0
  else
    add_error "$failure_msg"
    return 1
  fi
}

# Check if Docker is running
check_component "Docker" \
  "docker info &>/dev/null" \
  "Docker is running" \
  "Docker is not running"

# Check if Traefik is running
check_component "Traefik" \
  "docker ps | grep -q traefik" \
  "Traefik is running" \
  "Traefik is not running"

# Check if config.env exists
check_component "Configuration" \
  "[ -f /opt/agency_stack/config.env ]" \
  "Configuration file exists" \
  "Configuration file not found"

# If config.env exists, load it
if [ -f /opt/agency_stack/config.env ]; then
  source /opt/agency_stack/config.env
  
  # Check all installed components
  if [ -f /opt/agency_stack/installed_components.txt ]; then
    log "${CYAN}${BOLD}Checking installed components:${NC}"
    
    while IFS= read -r component; do
      container_name=$(echo "$component" | tr '[:upper:]' '[:lower:]' | tr ' ' '_')
      check_component "$component" \
        "docker ps | grep -q $container_name" \
        "$component is running" \
        "$component is not running"
    done < /opt/agency_stack/installed_components.txt
  else
    log "${YELLOW}No components list found${NC}"
  fi
  
  # Check domain connectivity
  if [ -n "$PRIMARY_DOMAIN" ]; then
    log "${CYAN}${BOLD}Checking domain connectivity:${NC}"
    check_component "Primary domain ($PRIMARY_DOMAIN)" \
      "curl -s -o /dev/null -w '%{http_code}' https://$PRIMARY_DOMAIN | grep -q '200\|302\|301\|307\|308'" \
      "Primary domain is accessible" \
      "Cannot access primary domain"
  fi
  
  # Check Mailu if installed
  if docker ps | grep -q "mailu"; then
    log "${CYAN}${BOLD}Checking Mailu:${NC}"
    
    # Check if SMTP port is open
    check_component "SMTP port" \
      "nc -z localhost 25" \
      "SMTP port is open" \
      "SMTP port is closed"
    
    # Check if IMAP port is open
    check_component "IMAP port" \
      "nc -z localhost 143" \
      "IMAP port is open" \
      "IMAP port is closed"
    
    # Check if Admin interface is running
    if [ -n "$ADMIN_DOMAIN" ]; then
      check_component "Admin interface" \
        "curl -s -o /dev/null -w '%{http_code}' https://$ADMIN_DOMAIN | grep -q '200\|302\|301\|307\|308'" \
        "Admin interface is accessible" \
        "Cannot access admin interface"
    fi
  fi
  
  # Check Keycloak if installed
  check_keycloak() {
    if ! grep -q "Keycloak" /opt/agency_stack/installed_components.txt 2>/dev/null; then
      return
    fi
    
    # Check if variables are defined in config.env
    if [ -z "$KEYCLOAK_DOMAIN" ] || [ -z "$KEYCLOAK_ADMIN_PASSWORD" ]; then
      log "${RED}❌ Keycloak configuration is incomplete${NC}"
      return
    fi
    
    log "${BLUE}Checking Keycloak service...${NC}"
    
    # Check if Keycloak is accessible
    local status_code=$(curl -s -o /dev/null -w "%{http_code}" -L "https://${KEYCLOAK_DOMAIN}/auth/")
    
    if [ "$status_code" -eq 200 ] || [ "$status_code" -eq 302 ]; then
      log "${GREEN}✅ Keycloak service is accessible${NC}"
      
      # Check if realm exists by trying to get token
      local realm_status=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "client_id=admin-cli" \
        -d "username=admin" \
        -d "password=${KEYCLOAK_ADMIN_PASSWORD}" \
        -d "grant_type=password" \
        "https://${KEYCLOAK_DOMAIN}/auth/realms/master/protocol/openid-connect/token")
      
      if [ "$realm_status" -eq 200 ]; then
        log "${GREEN}✅ Keycloak realm is properly configured${NC}"
      else
        log "${RED}❌ Keycloak realm authentication failed (status: ${realm_status})${NC}"
        ERRORS=$((ERRORS + 1))
      fi
      
      # Check if AgencyStack realm exists
      local agencystack_status=$(curl -s -o /dev/null -w "%{http_code}" \
        "https://${KEYCLOAK_DOMAIN}/auth/realms/agencystack")
      
      if [ "$agencystack_status" -eq 200 ] || [ "$agencystack_status" -eq 302 ]; then
        log "${GREEN}✅ Keycloak AgencyStack realm exists${NC}"
      else
        log "${YELLOW}⚠️ Keycloak AgencyStack realm not found (status: ${agencystack_status})${NC}"
        log "${YELLOW}⚠️ Run 'make integrate-keycloak' to set up SSO integration${NC}"
        WARNINGS=$((WARNINGS + 1))
      fi
    else
      log "${RED}❌ Keycloak service is not accessible (status: ${status_code})${NC}"
      ERRORS=$((ERRORS + 1))
    fi
  }
  
  check_keycloak
  
  # Check Traefik Auth if installed
  check_traefik_auth() {
    if [ ! -d "/opt/agency_stack/traefik-auth" ]; then
      return
    fi
    
    log "${BLUE}Checking Traefik Forward Auth service...${NC}"
    
    # Check if the container is running
    if docker ps | grep -q "agency_stack_traefik_auth"; then
      log "${GREEN}✅ Traefik Forward Auth container is running${NC}"
      
      # Check if auth domain is accessible
      if [ -n "$PRIMARY_DOMAIN" ]; then
        local status_code=$(curl -s -o /dev/null -w "%{http_code}" -L "https://auth.${PRIMARY_DOMAIN}/_ping")
        
        if [ "$status_code" -eq 200 ]; then
          log "${GREEN}✅ Traefik Forward Auth endpoint is accessible${NC}"
        else
          log "${YELLOW}⚠️ Traefik Forward Auth endpoint is not accessible (status: ${status_code})${NC}"
          WARNINGS=$((WARNINGS + 1))
        fi
      fi
    else
      log "${RED}❌ Traefik Forward Auth container is not running${NC}"
      ERRORS=$((ERRORS + 1))
    fi
  }
  
  check_traefik_auth
fi

# Check disk space
log "${CYAN}${BOLD}Checking system resources:${NC}"
disk_used=$(df -h /opt | awk 'NR==2 {print $5}' | tr -d '%')
if [ "$disk_used" -gt 90 ]; then
  add_error "Disk space critical: ${disk_used}% used"
else
  add_success "Disk space OK: ${disk_used}% used"
fi

# Check memory
mem_used=$(free | grep Mem | awk '{print int($3/$2 * 100.0)}')
if [ "$mem_used" -gt 90 ]; then
  add_error "Memory usage critical: ${mem_used}% used"
else
  add_success "Memory usage OK: ${mem_used}% used"
fi

# Check CPU load
load=$(cat /proc/loadavg | awk '{print $1}')
cores=$(nproc)
load_per_core=$(awk "BEGIN {print $load / $cores}")
if (( $(echo "$load_per_core > 1.5" | bc -l) )); then
  add_error "CPU load high: $load (${load_per_core} per core)"
else
  add_success "CPU load OK: $load (${load_per_core} per core)"
fi

# Check security
log "${CYAN}${BOLD}Checking security:${NC}"

# Check if firewall is enabled
if command -v ufw &>/dev/null; then
  if ufw status | grep -q "Status: active"; then
    add_success "Firewall is active"
  else
    add_error "Firewall is inactive"
  fi
fi

# Check for important security updates
if command -v apt &>/dev/null; then
  security_updates=$(apt list --upgradable 2>/dev/null | grep -i security | wc -l)
  if [ "$security_updates" -gt 0 ]; then
    add_error "$security_updates security updates available"
  else
    add_success "No security updates pending"
  fi
fi

# Send alerts if there are errors
if [ $ERRORS -gt 0 ]; then
  send_alerts
fi

# Generate HTML report
cat > "$REPORT_FILE" << EOL
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>AgencyStack Health Report</title>
  <style>
    body { font-family: Arial, sans-serif; margin: 20px; }
    h1 { color: #333; }
    .healthy { color: green; }
    .warning { color: orange; }
    .critical { color: red; }
    pre { background: #f5f5f5; padding: 10px; border-radius: 5px; overflow-x: auto; }
  </style>
</head>
<body>
  <h1>AgencyStack Health Report</h1>
  <p>Generated: $(date)</p>
  <p>Server: $(hostname)</p>
  
  <h2>Health Check Results</h2>
  <pre>$(cat "$LOG_FILE" | sed 's/\x1b\[[0-9;]*m//g')</pre>
  
  <h2>System Information</h2>
  <pre>$(uname -a)</pre>
  
  <h2>Disk Usage</h2>
  <pre>$(df -h)</pre>
  
  <h2>Memory Usage</h2>
  <pre>$(free -h)</pre>
  
  <h2>Running Containers</h2>
  <pre>$(docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || echo "Docker not running")</pre>
</body>
</html>
EOL

log ""
log "${GREEN}${BOLD}Health check complete!${NC}"
log "Log saved to: $LOG_FILE"
log "HTML report generated: $REPORT_FILE"
log ""
log "To view a detailed HTML report, run:"
log "  firefox $REPORT_FILE"
