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

# Create log directory if it doesn't exist
mkdir -p "$LOG_DIR"

# Logging function
log() {
  echo -e "$1" | tee -a "$LOG_FILE"
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
    log "${GREEN}✅ $success_msg${NC}"
    return 0
  else
    log "${RED}❌ $failure_msg${NC}"
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
fi

# Check disk space
log "${CYAN}${BOLD}Checking system resources:${NC}"
disk_used=$(df -h /opt | awk 'NR==2 {print $5}' | tr -d '%')
if [ "$disk_used" -gt 90 ]; then
  log "${RED}❌ Disk space critical: ${disk_used}% used${NC}"
else
  log "${GREEN}✅ Disk space OK: ${disk_used}% used${NC}"
fi

# Check memory
mem_used=$(free | grep Mem | awk '{print int($3/$2 * 100.0)}')
if [ "$mem_used" -gt 90 ]; then
  log "${RED}❌ Memory usage critical: ${mem_used}% used${NC}"
else
  log "${GREEN}✅ Memory usage OK: ${mem_used}% used${NC}"
fi

# Check CPU load
load=$(cat /proc/loadavg | awk '{print $1}')
cores=$(nproc)
load_per_core=$(awk "BEGIN {print $load / $cores}")
if (( $(echo "$load_per_core > 1.5" | bc -l) )); then
  log "${RED}❌ CPU load high: $load (${load_per_core} per core)${NC}"
else
  log "${GREEN}✅ CPU load OK: $load (${load_per_core} per core)${NC}"
fi

# Check security
log "${CYAN}${BOLD}Checking security:${NC}"

# Check if firewall is enabled
if command -v ufw &>/dev/null; then
  if ufw status | grep -q "Status: active"; then
    log "${GREEN}✅ Firewall is active${NC}"
  else
    log "${RED}❌ Firewall is inactive${NC}"
  fi
fi

# Check for important security updates
if command -v apt &>/dev/null; then
  security_updates=$(apt list --upgradable 2>/dev/null | grep -i security | wc -l)
  if [ "$security_updates" -gt 0 ]; then
    log "${RED}❌ $security_updates security updates available${NC}"
  else
    log "${GREEN}✅ No security updates pending${NC}"
  fi
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
