#!/bin/bash
# audit_stack.sh - Security audit script for AgencyStack
# https://stack.nerdofmouth.com
#
# This script performs various security checks on an AgencyStack installation:
# - Scans for exposed ports
# - Identifies services missing HTTPS
# - Checks for default credentials still in use
# - Validates Traefik middleware and security headers
# - Audits file permissions for sensitive directories
#
# Usage: ./audit_stack.sh [--fix] [--client-id <client_id>] [--verbose] [--help]
#
# Author: AgencyStack Team
# Version: 1.0.0
# Created: $(date +%Y-%m-%d)

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
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
CONFIG_DIR="/opt/agency_stack"
CLIENTS_DIR="${CONFIG_DIR}/clients"
SECRETS_DIR="${CONFIG_DIR}/secrets"
LOG_DIR="/var/log/agency_stack"
AUDIT_LOG="${LOG_DIR}/security_audit.log"
REPORT_FILE="${ROOT_DIR}/security_audit_report.md"
FIX_MODE=false
CLIENT_ID=""
VERBOSE=false

# Show help message
show_help() {
  echo -e "${MAGENTA}${BOLD}AgencyStack Security Audit${NC}"
  echo -e "==============================="
  echo -e "This script performs a comprehensive security audit of an AgencyStack installation."
  echo -e "It checks for exposed ports, HTTPS configuration, default credentials,"
  echo -e "middleware configuration, and file permissions."
  echo -e ""
  echo -e "${CYAN}Usage:${NC}"
  echo -e "  $0 [options]"
  echo -e ""
  echo -e "${CYAN}Options:${NC}"
  echo -e "  ${BOLD}--fix${NC}              Automatically fix identified issues when possible"
  echo -e "  ${BOLD}--client-id${NC} <id>    Run audit for a specific client only"
  echo -e "  ${BOLD}--verbose${NC}          Show detailed output during the audit"
  echo -e "  ${BOLD}--help${NC}             Show this help message and exit"
  echo -e ""
  echo -e "${CYAN}Output:${NC}"
  echo -e "  Audit report is saved to: ${ROOT_DIR}/security_audit_report.md"
  echo -e "  Audit log is saved to: ${AUDIT_LOG}"
  echo -e ""
  echo -e "${CYAN}Example:${NC}"
  echo -e "  $0 --client-id acme --fix"
  echo -e ""
  echo -e "${CYAN}Notes:${NC}"
  echo -e "  - Running with --fix will attempt to correct permission issues and other fixable problems"
  echo -e "  - The script requires root privileges for some checks"
  exit 0
}

# Welcome message
echo -e "${MAGENTA}${BOLD}AgencyStack Security Audit${NC}"
echo -e "==============================="

# Parse arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    --fix)
      FIX_MODE=true
      shift
      ;;
    --client-id)
      CLIENT_ID="$2"
      shift
      shift
      ;;
    --verbose)
      VERBOSE=true
      shift
      ;;
    --help|-h)
      show_help
      ;;
    *)
      echo -e "${RED}Unknown option: $key${NC}"
      echo -e "Usage: $0 [--fix] [--client-id <client_id>] [--verbose] [--help]"
      exit 1
      ;;
  esac
done

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo -e "${YELLOW}Warning: Not running as root. Some checks may not work correctly.${NC}"
fi

# Create log directory if it doesn't exist
mkdir -p "$LOG_DIR"
touch "$AUDIT_LOG"

# Log function
log() {
  echo "$(date +"%Y-%m-%d %H:%M:%S") - $1" >> "$AUDIT_LOG"
  if [ "$VERBOSE" = true ]; then
    echo -e "$1"
  fi
}

# Initialize report
init_report() {
  cat > "$REPORT_FILE" << EOF
# AgencyStack Security Audit Report
**Date:** $(date +"%Y-%m-%d %H:%M:%S")
**System:** $(hostname)
**Mode:** $(if [ "$FIX_MODE" = true ]; then echo "Fix Mode"; else echo "Audit Mode"; fi)
$(if [ -n "$CLIENT_ID" ]; then echo "**Client:** $CLIENT_ID"; fi)

This report contains findings from a security audit of your AgencyStack installation. 
Items marked with ✅ are secure, while items marked with ❌ need attention.

## Summary

EOF
}

# Add section to report
add_section() {
  local title="$1"
  local status="$2"  # Should be PASS, FAIL, or WARNING
  local details="$3"
  local recommendations="$4"
  
  if [ "$status" = "PASS" ]; then
    STATUS_ICON="✅"
    STATUS_COLOR="${GREEN}"
  elif [ "$status" = "WARNING" ]; then
    STATUS_ICON="⚠️"
    STATUS_COLOR="${YELLOW}"
  else
    STATUS_ICON="❌"
    STATUS_COLOR="${RED}"
  fi
  
  log "${STATUS_COLOR}${title}: ${status}${NC}"
  
  cat >> "$REPORT_FILE" << EOF
## ${STATUS_ICON} ${title}

**Status:** ${status}

${details}

$(if [ -n "$recommendations" ]; then echo "**Recommendations:**"; echo "$recommendations"; fi)

EOF
}

# Initialize audit report
init_report

# Check if Docker is running
log "${BLUE}Checking if Docker is running...${NC}"
if docker info &>/dev/null; then
  log "${GREEN}Docker is running${NC}"
  DOCKER_RUNNING=true
else
  log "${RED}Docker is not running${NC}"
  add_section "Docker Service" "FAIL" "Docker is not running. This is required for AgencyStack to function properly." "Start Docker with 'systemctl start docker' or your system's equivalent command."
  DOCKER_RUNNING=false
fi

# Scan for exposed ports
log "${BLUE}Scanning for exposed ports...${NC}"
EXPOSED_PORTS=$(netstat -tuln | grep 'LISTEN' | awk '{print $4}' | awk -F: '{print $NF}' | sort -n | uniq)
EXPOSED_PORTS_COUNT=$(echo "$EXPOSED_PORTS" | wc -l)
DANGEROUS_PORTS="3306 1433 5432 27017 6379 11211 9200 9300 8080 9090"
DANGEROUS_EXPOSED=0

for port in $DANGEROUS_PORTS; do
  if echo "$EXPOSED_PORTS" | grep -q "\b$port\b"; then
    DANGEROUS_EXPOSED=$((DANGEROUS_EXPOSED + 1))
    log "${RED}Potentially sensitive port exposed: $port${NC}"
  fi
done

PORT_DETAILS="Found ${EXPOSED_PORTS_COUNT} open ports. ${DANGEROUS_EXPOSED} potentially sensitive ports are exposed."
if [ $DANGEROUS_EXPOSED -gt 0 ]; then
  PORT_STATUS="WARNING"
  PORT_RECOMMENDATIONS="Consider restricting access to these ports:\n$(for port in $DANGEROUS_PORTS; do if echo "$EXPOSED_PORTS" | grep -q "\b$port\b"; then echo "- Port $port: $(lsof -i :$port | grep LISTEN | awk '{print $1}' | uniq)"; fi; done)"
else
  PORT_STATUS="PASS"
  PORT_RECOMMENDATIONS=""
fi
add_section "Port Exposure" "$PORT_STATUS" "$PORT_DETAILS" "$PORT_RECOMMENDATIONS"

# Check for HTTPS setup
log "${BLUE}Checking for HTTPS configuration...${NC}"
if [ "$DOCKER_RUNNING" = true ]; then
  TRAEFIK_RUNNING=$(docker ps | grep -c "traefik")
  CERT_MANAGER_RUNNING=$(docker ps | grep -c "cert-manager")
  
  if [ "$TRAEFIK_RUNNING" -gt 0 ]; then
    TRAEFIK_HTTPS_CONFIG=$(docker exec $(docker ps -q --filter "name=traefik") cat /etc/traefik/traefik.yml 2>/dev/null | grep -c "certificatesResolvers")
    
    if [ "$TRAEFIK_HTTPS_CONFIG" -gt 0 ] || [ "$CERT_MANAGER_RUNNING" -gt 0 ]; then
      HTTPS_STATUS="PASS"
      HTTPS_DETAILS="Traefik is configured with HTTPS support. TLS certificates are being managed correctly."
      HTTPS_RECOMMENDATIONS=""
    else
      HTTPS_STATUS="FAIL"
      HTTPS_DETAILS="Traefik is running but HTTPS configuration is missing or incomplete."
      HTTPS_RECOMMENDATIONS="Enable HTTPS by configuring Traefik with Let's Encrypt. Run 'make setup-https' to configure HTTPS."
    fi
  else
    HTTPS_STATUS="FAIL"
    HTTPS_DETAILS="Traefik proxy is not running. HTTPS cannot be verified."
    HTTPS_RECOMMENDATIONS="Ensure Traefik is running with 'make start-traefik' and then configure HTTPS."
  fi
else
  HTTPS_STATUS="FAIL"
  HTTPS_DETAILS="Docker is not running. HTTPS configuration cannot be verified."
  HTTPS_RECOMMENDATIONS="Start Docker and ensure Traefik is running before checking HTTPS configuration."
fi
add_section "HTTPS Configuration" "$HTTPS_STATUS" "$HTTPS_DETAILS" "$HTTPS_RECOMMENDATIONS"

# Check for default credentials
log "${BLUE}Checking for default credentials...${NC}"
DEFAULT_CREDS_FOUND=0
DEFAULT_CREDS_DETAILS=""

# Check environment file for default credentials
CONFIG_ENV="${CONFIG_DIR}/config.env"
if [ -f "$CONFIG_ENV" ]; then
  if grep -q "KEYCLOAK_ADMIN_PASSWORD=admin" "$CONFIG_ENV"; then
    DEFAULT_CREDS_FOUND=$((DEFAULT_CREDS_FOUND + 1))
    DEFAULT_CREDS_DETAILS+="- Default Keycloak admin password found in config.env\n"
  fi
  
  if grep -q "MYSQL_ROOT_PASSWORD=password" "$CONFIG_ENV"; then
    DEFAULT_CREDS_FOUND=$((DEFAULT_CREDS_FOUND + 1))
    DEFAULT_CREDS_DETAILS+="- Default MySQL root password found in config.env\n"
  fi
  
  if grep -q "POSTGRES_PASSWORD=password" "$CONFIG_ENV"; then
    DEFAULT_CREDS_FOUND=$((DEFAULT_CREDS_FOUND + 1))
    DEFAULT_CREDS_DETAILS+="- Default PostgreSQL password found in config.env\n"
  fi
fi

# Check client-specific credential files if client ID is specified
if [ -n "$CLIENT_ID" ]; then
  CLIENT_SECRETS="${SECRETS_DIR}/${CLIENT_ID}/secrets.env"
  if [ -f "$CLIENT_SECRETS" ]; then
    if grep -q "PASSWORD=password" "$CLIENT_SECRETS" || grep -q "PASSWORD=admin" "$CLIENT_SECRETS"; then
      DEFAULT_CREDS_FOUND=$((DEFAULT_CREDS_FOUND + 1))
      DEFAULT_CREDS_DETAILS+="- Default credentials found in client secrets file\n"
    fi
  fi
fi

if [ $DEFAULT_CREDS_FOUND -gt 0 ]; then
  CREDS_STATUS="FAIL"
  CREDS_RECOMMENDATIONS="Replace default credentials with strong, unique passwords. Run the secret rotation script with 'make rotate-secrets'."
else
  CREDS_STATUS="PASS"
  CREDS_DETAILS="No default credentials found in configuration files."
  CREDS_RECOMMENDATIONS=""
fi
add_section "Default Credentials" "$CREDS_STATUS" "${DEFAULT_CREDS_DETAILS:-"No default credentials found."}" "$CREDS_RECOMMENDATIONS"

# Check Traefik middleware
log "${BLUE}Checking Traefik middleware configuration...${NC}"
if [ "$DOCKER_RUNNING" = true ] && [ "$TRAEFIK_RUNNING" -gt 0 ]; then
  # Get list of all defined middlewares
  MIDDLEWARES=$(docker exec $(docker ps -q --filter "name=traefik") traefik version 2>/dev/null)
  
  if [ $? -eq 0 ]; then
    SECURITY_MIDDLEWARE_COUNT=$(docker exec $(docker ps -q --filter "name=traefik") cat /etc/traefik/dynamic/*.yml 2>/dev/null | grep -c "security-headers")
    AUTH_MIDDLEWARE_COUNT=$(docker exec $(docker ps -q --filter "name=traefik") cat /etc/traefik/dynamic/*.yml 2>/dev/null | grep -c "forwardAuth")
    
    MIDDLEWARE_DETAILS="Found ${SECURITY_MIDDLEWARE_COUNT} security header middlewares and ${AUTH_MIDDLEWARE_COUNT} authentication middlewares."
    
    if [ "$SECURITY_MIDDLEWARE_COUNT" -gt 0 ] && [ "$AUTH_MIDDLEWARE_COUNT" -gt 0 ]; then
      MIDDLEWARE_STATUS="PASS"
      MIDDLEWARE_RECOMMENDATIONS=""
    else
      MIDDLEWARE_STATUS="WARNING"
      MIDDLEWARE_RECOMMENDATIONS="Some Traefik security middlewares are missing:\n"
      
      if [ "$SECURITY_MIDDLEWARE_COUNT" -eq 0 ]; then
        MIDDLEWARE_RECOMMENDATIONS+="- Add security headers middleware to enforce HSTS, CSP, etc.\n"
      fi
      
      if [ "$AUTH_MIDDLEWARE_COUNT" -eq 0 ]; then
        MIDDLEWARE_RECOMMENDATIONS+="- Add forward authentication middleware to implement SSO with Keycloak\n"
      fi
    fi
  else
    MIDDLEWARE_STATUS="FAIL"
    MIDDLEWARE_DETAILS="Unable to check Traefik middlewares. Traefik container is not accessible."
    MIDDLEWARE_RECOMMENDATIONS="Ensure Traefik is running and accessible."
  fi
else
  MIDDLEWARE_STATUS="FAIL"
  MIDDLEWARE_DETAILS="Traefik is not running. Cannot check middleware configuration."
  MIDDLEWARE_RECOMMENDATIONS="Start Traefik with 'make start-traefik' and then configure security middlewares."
fi
add_section "Traefik Security Middleware" "$MIDDLEWARE_STATUS" "$MIDDLEWARE_DETAILS" "$MIDDLEWARE_RECOMMENDATIONS"

# Check file permissions
log "${BLUE}Checking file permissions for sensitive directories...${NC}"
PERMISSION_ISSUES=0
PERMISSION_DETAILS=""

# Check config directory
if [ -d "$CONFIG_DIR" ]; then
  CONFIG_PERMS=$(stat -c "%a" "$CONFIG_DIR")
  if [ "$CONFIG_PERMS" != "750" ] && [ "$CONFIG_PERMS" != "700" ]; then
    PERMISSION_ISSUES=$((PERMISSION_ISSUES + 1))
    PERMISSION_DETAILS+="- Config directory ($CONFIG_DIR) has permissions $CONFIG_PERMS (should be 750 or 700)\n"
    
    if [ "$FIX_MODE" = true ]; then
      chmod 750 "$CONFIG_DIR"
      log "${GREEN}Fixed permissions for $CONFIG_DIR${NC}"
    fi
  fi
fi

# Check secrets directory
if [ -d "$SECRETS_DIR" ]; then
  SECRETS_PERMS=$(stat -c "%a" "$SECRETS_DIR")
  if [ "$SECRETS_PERMS" != "700" ]; then
    PERMISSION_ISSUES=$((PERMISSION_ISSUES + 1))
    PERMISSION_DETAILS+="- Secrets directory ($SECRETS_DIR) has permissions $SECRETS_PERMS (should be 700)\n"
    
    if [ "$FIX_MODE" = true ]; then
      chmod 700 "$SECRETS_DIR"
      log "${GREEN}Fixed permissions for $SECRETS_DIR${NC}"
    fi
  fi
  
  # Check client secrets files
  if [ -n "$CLIENT_ID" ]; then
    CLIENT_SECRETS_DIR="${SECRETS_DIR}/${CLIENT_ID}"
    if [ -d "$CLIENT_SECRETS_DIR" ]; then
      find "$CLIENT_SECRETS_DIR" -type f -name "*.env" | while read secrets_file; do
        FILE_PERMS=$(stat -c "%a" "$secrets_file")
        if [ "$FILE_PERMS" != "600" ]; then
          PERMISSION_ISSUES=$((PERMISSION_ISSUES + 1))
          PERMISSION_DETAILS+="- Secrets file $secrets_file has permissions $FILE_PERMS (should be 600)\n"
          
          if [ "$FIX_MODE" = true ]; then
            chmod 600 "$secrets_file"
            log "${GREEN}Fixed permissions for $secrets_file${NC}"
          fi
        fi
      done
    fi
  fi
fi

if [ $PERMISSION_ISSUES -gt 0 ]; then
  if [ "$FIX_MODE" = true ]; then
    PERMISSION_STATUS="WARNING"
    PERMISSION_DETAILS="Fixed $PERMISSION_ISSUES permission issues:\n$PERMISSION_DETAILS"
    PERMISSION_RECOMMENDATIONS="Verify that all permission issues have been fixed correctly."
  else
    PERMISSION_STATUS="FAIL"
    PERMISSION_DETAILS="Found $PERMISSION_ISSUES permission issues:\n$PERMISSION_DETAILS"
    PERMISSION_RECOMMENDATIONS="Run this script with --fix to automatically correct permissions, or manually set the recommended permissions."
  fi
else
  PERMISSION_STATUS="PASS"
  PERMISSION_DETAILS="All checked directories and files have appropriate permissions."
  PERMISSION_RECOMMENDATIONS=""
fi
add_section "File Permissions" "$PERMISSION_STATUS" "$PERMISSION_DETAILS" "$PERMISSION_RECOMMENDATIONS"

# TLS version check
log "${BLUE}Checking for minimum TLS version...${NC}"
if [ "$DOCKER_RUNNING" = true ] && [ "$TRAEFIK_RUNNING" -gt 0 ]; then
  TLS_CONFIG=$(docker exec $(docker ps -q --filter "name=traefik") cat /etc/traefik/traefik.yml 2>/dev/null | grep -c "minVersion")
  
  if [ "$TLS_CONFIG" -gt 0 ]; then
    MIN_TLS=$(docker exec $(docker ps -q --filter "name=traefik") cat /etc/traefik/traefik.yml 2>/dev/null | grep "minVersion" | awk '{print $2}')
    
    if [ "$MIN_TLS" = "VersionTLS12" ] || [ "$MIN_TLS" = "VersionTLS13" ]; then
      TLS_STATUS="PASS"
      TLS_DETAILS="Minimum TLS version is set to $MIN_TLS."
      TLS_RECOMMENDATIONS=""
    else
      TLS_STATUS="FAIL"
      TLS_DETAILS="Minimum TLS version is set to $MIN_TLS, which is below the recommended minimum (TLS 1.2)."
      TLS_RECOMMENDATIONS="Update Traefik configuration to use at least TLS 1.2 (VersionTLS12)."
      
      if [ "$FIX_MODE" = true ]; then
        # TODO: Implement fix for TLS version
        log "${YELLOW}TLS version fix not implemented yet${NC}"
      fi
    fi
  else
    TLS_STATUS="WARNING"
    TLS_DETAILS="No minimum TLS version specified in Traefik configuration. Default may be insecure."
    TLS_RECOMMENDATIONS="Configure Traefik to use at least TLS 1.2 by adding minVersion: VersionTLS12 to the TLS options."
  fi
else
  TLS_STATUS="FAIL"
  TLS_DETAILS="Traefik is not running. Cannot check TLS configuration."
  TLS_RECOMMENDATIONS="Start Traefik with 'make start-traefik' and then configure minimum TLS version."
fi
add_section "TLS Configuration" "$TLS_STATUS" "$TLS_DETAILS" "$TLS_RECOMMENDATIONS"

# Generate summary statistics
PASS_COUNT=$(grep -c "Status: PASS" "$REPORT_FILE")
WARN_COUNT=$(grep -c "Status: WARNING" "$REPORT_FILE")
FAIL_COUNT=$(grep -c "Status: FAIL" "$REPORT_FILE")
TOTAL_CHECKS=$((PASS_COUNT + WARN_COUNT + FAIL_COUNT))

# Add summary to report
sed -i "s/## Summary/## Summary\n\n- ✅ Passing: ${PASS_COUNT}\/${TOTAL_CHECKS} checks\n- ⚠️ Warnings: ${WARN_COUNT}\/${TOTAL_CHECKS} checks\n- ❌ Failing: ${FAIL_COUNT}\/${TOTAL_CHECKS} checks/" "$REPORT_FILE"

# Print summary
echo -e "\n${BOLD}Security Audit Summary:${NC}"
echo -e "${GREEN}✅ Passing: $PASS_COUNT/$TOTAL_CHECKS checks${NC}"
echo -e "${YELLOW}⚠️ Warnings: $WARN_COUNT/$TOTAL_CHECKS checks${NC}"
echo -e "${RED}❌ Failing: $FAIL_COUNT/$TOTAL_CHECKS checks${NC}"
echo -e "\nDetailed report saved to: ${CYAN}$REPORT_FILE${NC}"
echo -e "Audit log saved to: ${CYAN}$AUDIT_LOG${NC}"

if [ "$FIX_MODE" = true ]; then
  echo -e "\n${YELLOW}Some issues were automatically fixed. Re-run the audit to verify.${NC}"
else
  echo -e "\n${BLUE}Run with --fix to attempt automatic remediation of issues.${NC}"
fi

exit 0
