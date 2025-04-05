#!/bin/bash
# validate_system.sh - Validate baseline system readiness for AgencyStack installation
# https://stack.nerdofmouth.com
#
# This script performs comprehensive validation of system requirements for AgencyStack:
# - Docker and Docker Compose availability and versions
# - Required directories existence
# - Available disk space and memory
# - Docker networks and volumes
# - User permissions
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
LOG_DIR="/var/log/agency_stack"
VAL_LOG="${LOG_DIR}/validation.log"
VERBOSE=false
REPORT_FILE="/tmp/agency_stack_validation_report.txt"
MIN_DISK_SPACE_GB=10
MIN_MEMORY_GB=4

# Show help message
show_help() {
  echo -e "${MAGENTA}${BOLD}AgencyStack System Validation${NC}"
  echo -e "==============================="
  echo -e "This script validates system readiness for AgencyStack installation."
  echo -e ""
  echo -e "${CYAN}Usage:${NC}"
  echo -e "  $0 [options]"
  echo -e ""
  echo -e "${CYAN}Options:${NC}"
  echo -e "  ${BOLD}--verbose${NC}           Show detailed output during validation"
  echo -e "  ${BOLD}--report${NC}            Generate a detailed report file at ${REPORT_FILE}"
  echo -e "  ${BOLD}--help${NC}              Show this help message and exit"
  echo -e ""
  echo -e "${CYAN}Example:${NC}"
  echo -e "  $0 --verbose --report"
  echo -e ""
  echo -e "${CYAN}Notes:${NC}"
  echo -e "  - Log file is saved to: ${VAL_LOG}"
  exit 0
}

# Parse arguments
GENERATE_REPORT=false

while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    --verbose)
      VERBOSE=true
      shift
      ;;
    --report)
      GENERATE_REPORT=true
      shift
      ;;
    --help|-h)
      show_help
      ;;
    *)
      echo -e "${RED}Unknown option: $key${NC}"
      echo -e "Use --help for usage information"
      exit 1
      ;;
  esac
done

# Welcome message
echo -e "${MAGENTA}${BOLD}AgencyStack System Validation${NC}"
echo -e "==============================="

# Create log directory if it doesn't exist
mkdir -p "$LOG_DIR"
touch "$VAL_LOG"

# Log function
log() {
  echo "$(date +"%Y-%m-%d %H:%M:%S") - $1" >> "$VAL_LOG"
  if [ "$VERBOSE" = true ]; then
    echo -e "$1"
  else
    echo -e "$2"
  fi
}

# Initialize report if requested
if [ "$GENERATE_REPORT" = true ]; then
  cat > "$REPORT_FILE" <<EOF
=========================================
AgencyStack System Validation Report
=========================================
Generated on: $(date)
Hostname: $(hostname)
User: $(whoami)

=========================================

EOF
  log "INFO: Generating validation report at $REPORT_FILE" "${CYAN}Generating validation report at $REPORT_FILE${NC}"
fi

# Add to report function
add_to_report() {
  if [ "$GENERATE_REPORT" = true ]; then
    echo "$1" >> "$REPORT_FILE"
  fi
}

#######################
# SYSTEM CHECKS
#######################

echo -e "${BLUE}${BOLD}🔍 Checking system prerequisites...${NC}"
add_to_report "SYSTEM PREREQUISITES:"

# Check running as root
if [ "$EUID" -ne 0 ]; then
  log "WARNING: Not running as root. Some checks may not work correctly." "${YELLOW}⚠️ Not running as root. Some checks may not work correctly.${NC}"
  add_to_report "⚠️ Not running as root. Some checks may require elevated privileges."
else
  log "INFO: Running as root. All checks will be performed." "${GREEN}✅ Running as root. All checks will be performed.${NC}"
  add_to_report "✅ Running as root."
fi

# Check OS
OS_TYPE=$(uname -s)
OS_VERSION=$(cat /etc/os-release | grep "PRETTY_NAME" | cut -d '"' -f 2)
log "INFO: Operating system: $OS_TYPE - $OS_VERSION" "${BLUE}📊 Operating system: $OS_TYPE - $OS_VERSION${NC}"
add_to_report "📊 Operating system: $OS_TYPE - $OS_VERSION"

#######################
# DOCKER CHECKS
#######################

echo -e "${BLUE}${BOLD}🐳 Checking Docker installation...${NC}"
add_to_report "\nDOCKER INSTALLATION:"

# Check Docker
if command -v docker &> /dev/null; then
  DOCKER_VERSION=$(docker --version)
  log "INFO: Docker is installed - $DOCKER_VERSION" "${GREEN}✅ Docker is installed - $DOCKER_VERSION${NC}"
  add_to_report "✅ Docker is installed: $DOCKER_VERSION"
  
  # Check if Docker is running
  if docker info &> /dev/null; then
    log "INFO: Docker daemon is running" "${GREEN}✅ Docker daemon is running${NC}"
    add_to_report "✅ Docker daemon is running"
  else
    log "ERROR: Docker is installed but not running" "${RED}❌ Docker is installed but not running${NC}"
    add_to_report "❌ Docker is installed but not running"
  fi
  
  # Check Docker permissions
  if docker ps &> /dev/null; then
    log "INFO: Current user can run Docker commands" "${GREEN}✅ Current user can run Docker commands${NC}"
    add_to_report "✅ Current user can run Docker commands"
  else
    log "ERROR: Current user cannot run Docker commands" "${RED}❌ Current user cannot run Docker commands${NC}"
    add_to_report "❌ Current user cannot run Docker commands. Try 'sudo usermod -aG docker $(whoami)'"
  fi
else
  log "ERROR: Docker is not installed" "${RED}❌ Docker is not installed${NC}"
  add_to_report "❌ Docker is not installed - REQUIRED"
  echo -e "${YELLOW}⚠️ To install Docker, run:${NC}"
  echo -e "${CYAN}   make install-infrastructure${NC}"
fi

# Check Docker Compose
if command -v docker-compose &> /dev/null; then
  COMPOSE_VERSION=$(docker-compose --version)
  log "INFO: Docker Compose is installed - $COMPOSE_VERSION" "${GREEN}✅ Docker Compose is installed - $COMPOSE_VERSION${NC}"
  add_to_report "✅ Docker Compose is installed: $COMPOSE_VERSION"
else
  log "ERROR: Docker Compose is not installed" "${RED}❌ Docker Compose is not installed${NC}"
  add_to_report "❌ Docker Compose is not installed - REQUIRED"
  echo -e "${YELLOW}⚠️ To install Docker Compose, run:${NC}"
  echo -e "${CYAN}   make install-infrastructure${NC}"
fi

#######################
# DIRECTORY CHECKS
#######################

echo -e "${BLUE}${BOLD}📁 Checking required directories...${NC}"
add_to_report "\nREQUIRED DIRECTORIES:"

# Required directories
REQUIRED_DIRS=(
  "/opt/agency_stack"
  "/opt/agency_stack/clients"
  "/opt/agency_stack/secrets"
  "/var/log/agency_stack"
  "/var/log/agency_stack/clients"
  "/var/log/agency_stack/components"
  "/var/log/agency_stack/integrations"
)

for dir in "${REQUIRED_DIRS[@]}"; do
  if [ -d "$dir" ]; then
    # Check permissions
    PERM=$(stat -c "%a" "$dir")
    OWNER=$(stat -c "%U" "$dir")
    
    log "INFO: Directory exists: $dir (permissions: $PERM, owner: $OWNER)" "${GREEN}✅ Directory exists: $dir${NC}"
    add_to_report "✅ Directory exists: $dir (permissions: $PERM, owner: $OWNER)"
    
    # Check if directory has proper permissions (should be at least 700)
    if [[ $PERM -lt 700 ]]; then
      log "WARNING: Permissions too restrictive for $dir: $PERM" "${YELLOW}⚠️ Permissions too restrictive for $dir: $PERM${NC}"
      add_to_report "⚠️ Permissions too restrictive for $dir: $PERM"
    fi
  else
    log "ERROR: Missing required directory: $dir" "${RED}❌ Missing required directory: $dir${NC}"
    add_to_report "❌ Missing required directory: $dir"
  fi
done

#######################
# NETWORK CHECKS
#######################

echo -e "${BLUE}${BOLD}🌐 Checking Docker networks...${NC}"
add_to_report "\nDOCKER NETWORKS:"

# Expected networks
EXPECTED_NETWORKS=(
  "agency-network"
  "traefik"
)

if command -v docker &> /dev/null && docker info &> /dev/null; then
  for net in "${EXPECTED_NETWORKS[@]}"; do
    if docker network inspect "$net" &> /dev/null; then
      log "INFO: Docker network '$net' exists" "${GREEN}✅ Docker network '$net' exists${NC}"
      add_to_report "✅ Docker network '$net' exists"
    else
      log "WARNING: Docker network '$net' not found" "${YELLOW}⚠️ Docker network '$net' not found${NC}"
      add_to_report "⚠️ Docker network '$net' not found"
    fi
  done
else
  log "ERROR: Cannot check Docker networks (Docker not running)" "${RED}❌ Cannot check Docker networks (Docker not running)${NC}"
  add_to_report "❌ Cannot check Docker networks (Docker not running)"
fi

#######################
# RESOURCE CHECKS
#######################

echo -e "${BLUE}${BOLD}💾 Checking system resources...${NC}"
add_to_report "\nSYSTEM RESOURCES:"

# Check disk space
DISK_SPACE_KB=$(df -k / | awk 'NR==2 {print $4}')
DISK_SPACE_GB=$(echo "scale=2; $DISK_SPACE_KB/1024/1024" | bc)
DISK_SPACE_HUMAN=$(df -h / | awk 'NR==2 {print $4}')

log "INFO: Available disk space: $DISK_SPACE_HUMAN ($DISK_SPACE_GB GB)" "${BLUE}📊 Available disk space: $DISK_SPACE_HUMAN${NC}"
add_to_report "📊 Available disk space: $DISK_SPACE_HUMAN ($DISK_SPACE_GB GB)"

if (( $(echo "$DISK_SPACE_GB < $MIN_DISK_SPACE_GB" | bc -l) )); then
  log "ERROR: Insufficient disk space. Minimum required: $MIN_DISK_SPACE_GB GB" "${RED}❌ Insufficient disk space. Minimum required: $MIN_DISK_SPACE_GB GB${NC}"
  add_to_report "❌ Insufficient disk space. Minimum required: $MIN_DISK_SPACE_GB GB"
else
  log "INFO: Sufficient disk space" "${GREEN}✅ Sufficient disk space${NC}"
  add_to_report "✅ Sufficient disk space"
fi

# Check memory
MEM_TOTAL_KB=$(free | awk '/^Mem:/ {print $2}')
MEM_TOTAL_GB=$(echo "scale=2; $MEM_TOTAL_KB/1024/1024" | bc)
MEM_TOTAL_HUMAN=$(free -h | awk '/^Mem:/ {print $2}')

log "INFO: Total memory: $MEM_TOTAL_HUMAN ($MEM_TOTAL_GB GB)" "${BLUE}📊 Total memory: $MEM_TOTAL_HUMAN${NC}"
add_to_report "📊 Total memory: $MEM_TOTAL_HUMAN ($MEM_TOTAL_GB GB)"

if (( $(echo "$MEM_TOTAL_GB < $MIN_MEMORY_GB" | bc -l) )); then
  log "ERROR: Insufficient memory. Minimum required: $MIN_MEMORY_GB GB" "${RED}❌ Insufficient memory. Minimum required: $MIN_MEMORY_GB GB${NC}"
  add_to_report "❌ Insufficient memory. Minimum required: $MIN_MEMORY_GB GB"
else
  log "INFO: Sufficient memory" "${GREEN}✅ Sufficient memory${NC}"
  add_to_report "✅ Sufficient memory"
fi

#######################
# COMPONENT CHECKS
#######################

echo -e "${BLUE}${BOLD}🧩 Checking installed components...${NC}"
add_to_report "\nINSTALLED COMPONENTS:"

# Check installed components
COMPONENTS_FILE="${CONFIG_DIR}/installed_components.txt"
if [ -f "$COMPONENTS_FILE" ]; then
  COMPONENTS=$(grep -v "^component|" "$COMPONENTS_FILE" | wc -l)
  log "INFO: Found $COMPONENTS installed components" "${GREEN}✅ Found $COMPONENTS installed components${NC}"
  add_to_report "✅ Found $COMPONENTS installed components"
  
  if [ "$VERBOSE" = true ] || [ "$GENERATE_REPORT" = true ]; then
    ACTIVE_COMPONENTS=$(grep "|active$" "$COMPONENTS_FILE" | wc -l)
    log "INFO: $ACTIVE_COMPONENTS active components" "${BLUE}📊 $ACTIVE_COMPONENTS active components${NC}"
    add_to_report "📊 $ACTIVE_COMPONENTS active components"
    
    if [ "$GENERATE_REPORT" = true ]; then
      echo -e "\nDetailed component list:" >> "$REPORT_FILE"
      cat "$COMPONENTS_FILE" >> "$REPORT_FILE"
    fi
  fi
else
  log "INFO: No installed components found" "${YELLOW}⚠️ No installed components found${NC}"
  add_to_report "⚠️ No installed components found"
fi

#######################
# CONTAINER CHECKS
#######################

echo -e "${BLUE}${BOLD}🧮 Checking running containers...${NC}"
add_to_report "\nRUNNING CONTAINERS:"

# Check Docker containers
if command -v docker &> /dev/null && docker info &> /dev/null; then
  CONTAINERS=$(docker ps --format '{{.Names}}' | wc -l)
  log "INFO: Found $CONTAINERS running containers" "${BLUE}📊 Found $CONTAINERS running containers${NC}"
  add_to_report "📊 Found $CONTAINERS running containers"
  
  # Check expected critical containers
  CRITICAL_CONTAINERS=(
    "traefik"
  )
  
  for container in "${CRITICAL_CONTAINERS[@]}"; do
    if docker ps --format '{{.Names}}' | grep -q "$container"; then
      log "INFO: Critical container '$container' is running" "${GREEN}✅ Critical container '$container' is running${NC}"
      add_to_report "✅ Critical container '$container' is running"
    else
      log "WARNING: Critical container '$container' is not running" "${YELLOW}⚠️ Critical container '$container' is not running${NC}"
      add_to_report "⚠️ Critical container '$container' is not running"
    fi
  done
  
  if [ "$VERBOSE" = true ] || [ "$GENERATE_REPORT" = true ]; then
    log "INFO: Listing all running containers" "${BLUE}📊 Listing all running containers:${NC}"
    add_to_report "\nAll running containers:"
    
    CONTAINER_LIST=$(docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}')
    echo "$CONTAINER_LIST" | while read -r line; do
      if [ "$VERBOSE" = true ]; then
        echo -e "${CYAN}$line${NC}"
      fi
      if [ "$GENERATE_REPORT" = true ]; then
        echo "$line" >> "$REPORT_FILE"
      fi
    done
  fi
else
  log "ERROR: Cannot check Docker containers (Docker not running)" "${RED}❌ Cannot check Docker containers (Docker not running)${NC}"
  add_to_report "❌ Cannot check Docker containers (Docker not running)"
fi

#######################
# SUMMARY
#######################

echo -e "\n${BLUE}${BOLD}📋 System Validation Summary${NC}"
add_to_report "\n\nSYSTEM VALIDATION SUMMARY:"

# Count issues
ERROR_COUNT=$(grep -c "ERROR" "$VAL_LOG")
WARNING_COUNT=$(grep -c "WARNING" "$VAL_LOG")

if [ $ERROR_COUNT -eq 0 ] && [ $WARNING_COUNT -eq 0 ]; then
  log "INFO: Validation completed successfully with no issues" "${GREEN}${BOLD}✅ Validation completed successfully with no issues!${NC}"
  add_to_report "✅ Validation completed successfully with no issues!"
  echo -e "${GREEN}${BOLD}🚀 System is ready for AgencyStack!${NC}"
  add_to_report "🚀 System is ready for AgencyStack!"
  
  exit 0
elif [ $ERROR_COUNT -eq 0 ]; then
  log "INFO: Validation completed with $WARNING_COUNT warnings" "${YELLOW}${BOLD}⚠️ Validation completed with $WARNING_COUNT warnings${NC}"
  add_to_report "⚠️ Validation completed with $WARNING_COUNT warnings"
  echo -e "${YELLOW}${BOLD}🚧 System can run AgencyStack, but there are some warnings to address${NC}"
  add_to_report "🚧 System can run AgencyStack, but there are some warnings to address"
  
  exit 0
else
  log "ERROR: Validation failed with $ERROR_COUNT errors and $WARNING_COUNT warnings" "${RED}${BOLD}❌ Validation failed with $ERROR_COUNT errors and $WARNING_COUNT warnings${NC}"
  add_to_report "❌ Validation failed with $ERROR_COUNT errors and $WARNING_COUNT warnings"
  echo -e "${RED}${BOLD}🛑 System is not ready for AgencyStack. Please fix the errors and try again${NC}"
  add_to_report "🛑 System is not ready for AgencyStack. Please fix the errors and try again"
  
  exit 1
fi
