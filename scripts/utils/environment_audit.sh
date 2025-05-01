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
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$(dirname "${SCRIPT_DIR}")")"
COMPONENTS_DIR="${REPO_ROOT}/scripts/components"
DOCS_DIR="${REPO_ROOT}/docs"
PORTS_DOC="${DOCS_DIR}/pages/ports.md"
REGISTRY_FILE="${REPO_ROOT}/component_registry.json"

echo -e "${BLUE}${BOLD}🔍 AgencyStack Environment Audit${NC}"
echo -e "${BLUE}Running comprehensive compliance checks against Charter v1.0.3 principles...${NC}"
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

# Comprehensive component script validation
echo -e "\n${BOLD}Running comprehensive component script validation...${NC}"
find "${COMPONENTS_DIR}" -name "install_*.sh" | while read -r script; do
  component_name=$(basename "$script" | sed 's/^install_//;s/\.sh$//')
  echo -e "${CYAN}Validating component: ${component_name}${NC}"
  
  # Check essential script requirements
  echo -n "  - Sources common.sh: "
  if grep -q "source.*utils/common.sh" "$script"; then
    echo -e "${GREEN}YES${NC}"
  else
    echo -e "${RED}NO${NC}"
    log_audit_issue "ERROR" "Missing common.sh sourcing" "$script"
  fi
  
  echo -n "  - Calls exit_with_warning_if_host: "
  if grep -q "exit_with_warning_if_host" "$script"; then
    echo -e "${GREEN}YES${NC}"
  else
    echo -e "${RED}NO${NC}"
    log_audit_issue "ERROR" "Missing exit_with_warning_if_host check" "$script"
  fi
  
  echo -n "  - Uses proper logging: "
  if grep -q "log_info\|log_error\|log_warning\|log_success" "$script"; then
    echo -e "${GREEN}YES${NC}"
  else
    echo -e "${RED}NO${NC}"
    log_audit_issue "ERROR" "Missing standard logging functions" "$script"
  fi
  
  # Check for .env.example
  env_example="${COMPONENTS_DIR}/templates/${component_name}.env.example"
  if [ ! -f "$env_example" ]; then
    env_example="${REPO_ROOT}/templates/${component_name}.env.example"
  fi
  
  echo -n "  - Has .env.example: "
  if [ -f "$env_example" ]; then
    echo -e "${GREEN}YES${NC}"
  else
    echo -e "${YELLOW}NO${NC}"
    log_audit_issue "WARNING" "Missing .env.example file" "$env_example"
  fi
  
  # Check component registry entry
  echo -n "  - Has registry entry: "
  if [ -f "$REGISTRY_FILE" ]; then
    if grep -q "\"name\": *\"${component_name}\"" "$REGISTRY_FILE"; then
      echo -e "${GREEN}YES${NC}"
    else
      echo -e "${YELLOW}NO${NC}"
      log_audit_issue "WARNING" "Missing entry in component registry" "$REGISTRY_FILE"
    fi
  else
    echo -e "${YELLOW}N/A (registry not found)${NC}"
    log_audit_issue "WARNING" "Component registry file not found" "$REGISTRY_FILE"
  fi
  
  # Check port documentation
  echo -n "  - Has port documentation: "
  if [ -f "$PORTS_DOC" ]; then
    if grep -q -i "${component_name}" "$PORTS_DOC"; then
      echo -e "${GREEN}YES${NC}"
    else
      # Only warn if the component likely has a port
      if grep -q "PORT=\|--port" "$script"; then
        echo -e "${YELLOW}NO${NC}"
        log_audit_issue "WARNING" "Component uses ports but isn't documented" "$PORTS_DOC"
      else
        echo -e "${CYAN}N/A${NC}"
      fi
    fi
  else
    echo -e "${YELLOW}N/A (ports doc not found)${NC}"
    log_audit_issue "WARNING" "Ports documentation file not found" "$PORTS_DOC"
  fi
  
  echo ""
done

# Check README_AGENT.md presence in key directories
echo -e "${BOLD}Checking for README_AGENT.md files...${NC}"
KEY_DIRS=(
  "${REPO_ROOT}"
  "${REPO_ROOT}/scripts"
  "${REPO_ROOT}/scripts/utils"
  "${REPO_ROOT}/docs"
  "${REPO_ROOT}/clients"
)

for dir in "${KEY_DIRS[@]}"; do
  if [ -d "$dir" ]; then
    dir_name=$(basename "$dir")
    if [ "$dir" = "$REPO_ROOT" ]; then
      dir_name="root"
    fi
    
    echo -n "Checking $dir_name directory... "
    readme_file="${dir}/README_AGENT.md"
    
    if [ -f "$readme_file" ]; then
      # Check it's not empty and references the Charter
      if [ -s "$readme_file" ] && grep -q "Charter" "$readme_file"; then
        echo -e "${GREEN}VALID${NC}"
      else
        echo -e "${YELLOW}INCOMPLETE${NC}"
        log_audit_issue "WARNING" "README_AGENT.md exists but may be incomplete" "$readme_file"
      fi
    else
      echo -e "${RED}MISSING${NC}"
      log_audit_issue "ERROR" "Missing README_AGENT.md" "$dir"
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
