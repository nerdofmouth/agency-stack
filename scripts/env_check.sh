#!/bin/bash
# AgencyStack - Environment Variable Checker
# Verifies that all required environment variables are set correctly

# Colors
BOLD="\033[1m"
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
MAGENTA="\033[35m"
CYAN="\033[36m"
RESET="\033[0m"

# File paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/../.env"
ENV_EXAMPLE_FILE="${SCRIPT_DIR}/../.env.example"

# Logging
LOG_FILE="/var/log/agency_stack/env_check.log"
mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true

# Required variables by category
BASIC_REQUIRED=(
  "DOMAIN"
  "CLIENT_ID"
  "ADMIN_EMAIL"
  "ADMIN_PASSWORD"
)

SECURITY_REQUIRED=(
  "SECRET_KEY"
  "JWT_SECRET"
)

DB_REQUIRED=(
  "DB_HOST"
  "DB_PORT"
  "DB_USER"
  "DB_PASSWORD"
  "DB_NAME"
)

# Check if .env file exists
check_env_file() {
  if [ ! -f "$ENV_FILE" ]; then
    echo -e "${RED}${BOLD}Error: .env file not found at $ENV_FILE${RESET}"
    echo -e "${YELLOW}Please copy .env.example to .env and configure it:${RESET}"
    echo -e "cp $ENV_EXAMPLE_FILE $ENV_FILE"
    echo "$(date): .env file not found" >> "$LOG_FILE"
    return 1
  fi
  
  return 0
}

# Load environment variables
load_env() {
  if [ -f "$ENV_FILE" ]; then
    source "$ENV_FILE"
  fi
}

# Check required variables
check_required_vars() {
  local missing=0
  local category=$1
  shift
  local vars=("$@")
  
  echo -e "${CYAN}${BOLD}Checking $category variables...${RESET}"
  
  for var in "${vars[@]}"; do
    if [ -z "${!var}" ]; then
      echo -e "${RED}❌ $var is not set${RESET}"
      echo "$(date): Required variable $var is not set" >> "$LOG_FILE"
      missing=$((missing + 1))
    else
      echo -e "${GREEN}✓ $var is set${RESET}"
    fi
  done
  
  return $missing
}

# Check conditional variables
check_conditional_vars() {
  local missing=0
  
  # Check SSO variables if enabled
  if [ "$ENABLE_SSO" = "true" ]; then
    echo -e "${CYAN}${BOLD}Checking SSO variables (ENABLE_SSO=true)...${RESET}"
    
    for var in "KEYCLOAK_URL" "KEYCLOAK_REALM" "KEYCLOAK_CLIENT_ID" "KEYCLOAK_CLIENT_SECRET"; do
      if [ -z "${!var}" ]; then
        echo -e "${RED}❌ $var is required when SSO is enabled${RESET}"
        echo "$(date): Conditional variable $var is required but not set" >> "$LOG_FILE"
        missing=$((missing + 1))
      else
        echo -e "${GREEN}✓ $var is set${RESET}"
      fi
    done
  fi
  
  # Check Email variables if Mailu is enabled
  if grep -q "mailu" /opt/agency_stack/installed_components.txt 2>/dev/null; then
    echo -e "${CYAN}${BOLD}Checking Email variables (Mailu is installed)...${RESET}"
    
    for var in "MAIL_SERVER" "POSTMASTER" "MAIL_DOMAIN"; do
      if [ -z "${!var}" ]; then
        echo -e "${RED}❌ $var is required for Mailu${RESET}"
        echo "$(date): Conditional variable $var is required for Mailu but not set" >> "$LOG_FILE"
        missing=$((missing + 1))
      else
        echo -e "${GREEN}✓ $var is set${RESET}"
      fi
    done
  fi
  
  # Check OpenAI API key if enabled
  if [ "$ENABLE_OPENAI" = "true" ]; then
    echo -e "${CYAN}${BOLD}Checking OpenAI variables (ENABLE_OPENAI=true)...${RESET}"
    
    if [ -z "$OPENAI_API_KEY" ]; then
      echo -e "${RED}❌ OPENAI_API_KEY is required when ENABLE_OPENAI is true${RESET}"
      echo "$(date): OPENAI_API_KEY is required but not set" >> "$LOG_FILE"
      missing=$((missing + 1))
    else
      echo -e "${GREEN}✓ OPENAI_API_KEY is set${RESET}"
    fi
  fi
  
  return $missing
}

# Check for insecure default values
check_insecure_defaults() {
  local insecure=0
  
  echo -e "${CYAN}${BOLD}Checking for insecure default values...${RESET}"
  
  # Check for default/example values
  if [ "$ADMIN_PASSWORD" = "changeme_immediately" ]; then
    echo -e "${RED}❌ ADMIN_PASSWORD is set to the default value${RESET}"
    echo "$(date): ADMIN_PASSWORD is set to default value" >> "$LOG_FILE"
    insecure=$((insecure + 1))
  fi
  
  if [ "$SECRET_KEY" = "change_this_random_string" ]; then
    echo -e "${RED}❌ SECRET_KEY is set to the default value${RESET}"
    echo "$(date): SECRET_KEY is set to default value" >> "$LOG_FILE"
    insecure=$((insecure + 1))
  fi
  
  if [ "$JWT_SECRET" = "change_this_random_string_too" ]; then
    echo -e "${RED}❌ JWT_SECRET is set to the default value${RESET}"
    echo "$(date): JWT_SECRET is set to default value" >> "$LOG_FILE"
    insecure=$((insecure + 1))
  fi
  
  if [ "$DB_PASSWORD" = "change_this_db_password" ]; then
    echo -e "${RED}❌ DB_PASSWORD is set to the default value${RESET}"
    echo "$(date): DB_PASSWORD is set to default value" >> "$LOG_FILE"
    insecure=$((insecure + 1))
  fi
  
  # Check for sample domain
  if [ "$DOMAIN" = "agency.example.com" ]; then
    echo -e "${YELLOW}⚠️ DOMAIN is set to the example value${RESET}"
    echo "$(date): DOMAIN is set to example value" >> "$LOG_FILE"
    insecure=$((insecure + 1))
  fi
  
  return $insecure
}

# Check domain DNS configuration
check_dns() {
  local dns_issues=0
  
  echo -e "${CYAN}${BOLD}Validating DNS configuration for $DOMAIN...${RESET}"
  
  # Skip if domain is not set or is example domain
  if [ -z "$DOMAIN" ] || [ "$DOMAIN" = "agency.example.com" ]; then
    echo -e "${YELLOW}⚠️ Skipping DNS checks (domain not properly configured)${RESET}"
    return 0
  fi
  
  # Check if domain resolves
  if ! host "$DOMAIN" >/dev/null 2>&1; then
    echo -e "${RED}❌ $DOMAIN does not resolve to an IP address${RESET}"
    echo "$(date): Domain $DOMAIN does not resolve" >> "$LOG_FILE"
    dns_issues=$((dns_issues + 1))
  else
    echo -e "${GREEN}✓ $DOMAIN resolves to an IP address${RESET}"
  fi
  
  # Check if mail domain has MX records (if mail is configured)
  if [ ! -z "$MAIL_DOMAIN" ] && [ "$MAIL_DOMAIN" != "agency.example.com" ]; then
    if ! host -t MX "$MAIL_DOMAIN" >/dev/null 2>&1; then
      echo -e "${YELLOW}⚠️ No MX records found for $MAIL_DOMAIN${RESET}"
      echo "$(date): No MX records for $MAIL_DOMAIN" >> "$LOG_FILE"
      dns_issues=$((dns_issues + 1))
    else
      echo -e "${GREEN}✓ MX records found for $MAIL_DOMAIN${RESET}"
    fi
  fi
  
  return $dns_issues
}

# Main function
main() {
  local exit_code=0
  
  echo -e "${MAGENTA}${BOLD}🔍 AgencyStack Environment Validator${RESET}"
  echo -e "${BLUE}Checking environment configuration...${RESET}"
  echo ""
  
  # Check if .env file exists
  if ! check_env_file; then
    return 1
  fi
  
  # Load environment variables
  load_env
  
  # Check all required variables
  basic_missing=0
  check_required_vars "Basic Configuration" "${BASIC_REQUIRED[@]}"
  basic_missing=$?
  
  security_missing=0
  check_required_vars "Security Configuration" "${SECURITY_REQUIRED[@]}"
  security_missing=$?
  
  db_missing=0
  check_required_vars "Database Configuration" "${DB_REQUIRED[@]}"
  db_missing=$?
  
  conditional_missing=0
  check_conditional_vars
  conditional_missing=$?
  
  insecure=0
  check_insecure_defaults
  insecure=$?
  
  dns_issues=0
  # Only run DNS check if no critical variables are missing
  if [ $basic_missing -eq 0 ]; then
    check_dns
    dns_issues=$?
  fi
  
  total_issues=$((basic_missing + security_missing + db_missing + conditional_missing + insecure + dns_issues))
  
  echo ""
  if [ $total_issues -eq 0 ]; then
    echo -e "${GREEN}${BOLD}✓ Environment configuration validated successfully!${RESET}"
    echo "$(date): Environment check passed" >> "$LOG_FILE"
    exit_code=0
  else
    echo -e "${RED}${BOLD}❌ Found $total_issues issues with your environment configuration${RESET}"
    echo "$(date): Environment check failed with $total_issues issues" >> "$LOG_FILE"
    
    if [ $insecure -gt 0 ]; then
      echo -e "${YELLOW}⚠️ Please address the insecure default values before proceeding.${RESET}"
    fi
    
    if [ $basic_missing -gt 0 ] || [ $security_missing -gt 0 ] || [ $db_missing -gt 0 ] || [ $conditional_missing -gt 0 ]; then
      echo -e "${YELLOW}⚠️ Please set all required environment variables in your .env file.${RESET}"
    fi
    
    if [ $dns_issues -gt 0 ]; then
      echo -e "${YELLOW}⚠️ Please check your DNS configuration.${RESET}"
    fi
    
    exit_code=1
  fi
  
  return $exit_code
}

# Run main function
main "$@"
exit $?
