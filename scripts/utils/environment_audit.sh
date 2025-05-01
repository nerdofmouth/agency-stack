#!/bin/bash
# AgencyStack Environment Audit Script
# Enforces Charter v1.0.3 principles of repository integrity and containerization
# This script checks for compliance with proper environment validation

set -euo pipefail

# Define colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$(dirname "${SCRIPT_DIR}")")"

echo -e "${BLUE}${BOLD}🔍 AgencyStack Environment Audit${NC}"
echo -e "${BLUE}Running compliance checks against Charter v1.0.3 principles...${NC}"
echo ""

ERRORS=0
WARNINGS=0

# Function to log audit findings
log_audit_issue() {
  local severity="$1"
  local message="$2"
  local file="${3:-}"
  
  if [ "$severity" = "ERROR" ]; then
    echo -e "${RED}ERROR: ${message}${NC}"
    if [ -n "$file" ]; then
      echo -e "${YELLOW}  File: ${file}${NC}"
    fi
    ERRORS=$((ERRORS+1))
  elif [ "$severity" = "WARNING" ]; then
    echo -e "${YELLOW}WARNING: ${message}${NC}"
    if [ -n "$file" ]; then
      echo -e "${YELLOW}  File: ${file}${NC}"
    fi
    WARNINGS=$((WARNINGS+1))
  else
    echo -e "${GREEN}INFO: ${message}${NC}"
  fi
}

# Check for improper writes to system directories
echo -e "${BOLD}Checking for improper system directory writes...${NC}"
SYSTEM_DIRS=("/usr" "$HOME" "/etc")

for dir in "${SYSTEM_DIRS[@]}"; do
  echo -n "Checking for direct writes to ${dir}... "
  IMPROPER_WRITES=$(grep -r --include="*.sh" "mkdir -p ${dir}" "${REPO_ROOT}" 2>/dev/null || true)
  
  if [ -n "$IMPROPER_WRITES" ]; then
    echo -e "${RED}DETECTED${NC}"
    echo "$IMPROPER_WRITES" | while IFS= read -r line; do
      file=$(echo "$line" | cut -d: -f1)
      log_audit_issue "ERROR" "Direct write to ${dir} detected" "$file"
    done
  else
    echo -e "${GREEN}CLEAN${NC}"
  fi
done

# Check for host environment validation
echo -e "\n${BOLD}Checking for environment validation in scripts...${NC}"
for script in "${REPO_ROOT}/scripts/components"/*.sh; do
  if [ -f "$script" ]; then
    script_name=$(basename "$script")
    echo -n "Checking ${script_name}... "
    
    if ! grep -q "exit_with_warning_if_host" "$script"; then
      echo -e "${RED}MISSING${NC}"
      log_audit_issue "ERROR" "Missing exit_with_warning_if_host validation" "$script"
    else
      echo -e "${GREEN}VALIDATED${NC}"
    fi
  fi
done

# Check for .env files for each component
echo -e "\n${BOLD}Checking for .env files in component installations...${NC}"
for component_dir in /opt/agency_stack/clients/*/*/; do
  if [ -d "$component_dir" ]; then
    component_name=$(basename "$component_dir")
    client_id=$(basename "$(dirname "$component_dir")")
    env_file="${component_dir}/.env"
    
    echo -n "Checking ${client_id}/${component_name}... "
    
    if [ ! -f "$env_file" ]; then
      echo -e "${YELLOW}NO .ENV${NC}"
      log_audit_issue "WARNING" "Missing .env file for ${client_id}/${component_name}" "$component_dir"
    else
      echo -e "${GREEN}FOUND${NC}"
    fi
  fi
done

# Check for Makefile targets for components
echo -e "\n${BOLD}Checking for standard Makefile targets...${NC}"
for script in "${REPO_ROOT}/scripts/components"/*.sh; do
  if [ -f "$script" ]; then
    script_name=$(basename "$script")
    component_name=${script_name#install_}
    component_name=${component_name%.sh}
    
    echo -n "Checking Makefile targets for ${component_name}... "
    
    # Check for main installation target
    if ! grep -q "^${component_name}:" "${REPO_ROOT}/Makefile" && ! grep -q "^${component_name}:" "${REPO_ROOT}/makefiles/components/"*.mk 2>/dev/null; then
      echo -e "${YELLOW}MISSING${NC}"
      log_audit_issue "WARNING" "Missing main Makefile target for ${component_name}"
    else
      # Check for standard targets (status, logs, restart)
      missing_targets=()
      
      if ! grep -q "^${component_name}-status:" "${REPO_ROOT}/Makefile" && ! grep -q "^${component_name}-status:" "${REPO_ROOT}/makefiles/components/"*.mk 2>/dev/null; then
        missing_targets+=("${component_name}-status")
      fi
      
      if ! grep -q "^${component_name}-logs:" "${REPO_ROOT}/Makefile" && ! grep -q "^${component_name}-logs:" "${REPO_ROOT}/makefiles/components/"*.mk 2>/dev/null; then
        missing_targets+=("${component_name}-logs")
      fi
      
      if ! grep -q "^${component_name}-restart:" "${REPO_ROOT}/Makefile" && ! grep -q "^${component_name}-restart:" "${REPO_ROOT}/makefiles/components/"*.mk 2>/dev/null; then
        missing_targets+=("${component_name}-restart")
      fi
      
      if [ ${#missing_targets[@]} -eq 0 ]; then
        echo -e "${GREEN}COMPLETE${NC}"
      else
        echo -e "${YELLOW}PARTIAL${NC}"
        log_audit_issue "WARNING" "Missing standard targets: ${missing_targets[*]}"
      fi
    fi
  fi
done

# Summary
echo -e "\n${BOLD}Audit Summary:${NC}"
if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
  echo -e "${GREEN}✅ All checks passed! Environment is compliant with AgencyStack Charter v1.0.3.${NC}"
  exit 0
elif [ $ERRORS -eq 0 ]; then
  echo -e "${YELLOW}⚠️ Found ${WARNINGS} warnings but no critical errors. Address warnings to improve Charter compliance.${NC}"
  exit 0
else
  echo -e "${RED}❌ Found ${ERRORS} critical errors and ${WARNINGS} warnings. Environment violates AgencyStack Charter v1.0.3.${NC}"
  exit 1
fi
