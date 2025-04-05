#!/bin/bash
# quick_audit.sh - AgencyStack Quick Repository Audit Utility
# [https://stack.nerdofmouth.com](https://stack.nerdofmouth.com)
#
# Provides a fast diagnostic scan of the AgencyStack repository
# Identifies potential stale scripts and resources
#
# Author: AgencyStack Team
# Version: 1.0.0

# Colors for prettier output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
TEMP_DIR="/tmp/agency_stack_audit_$(date +%s)"
OUTPUT_FILE="${TEMP_DIR}/quick_audit_report.txt"
LOG_DIR="/var/log/agency_stack"
AUDIT_LOG_DIR="${LOG_DIR}/audit"
DAYS_THRESHOLD=90
VERBOSE=false
SCRIPT_DIRS=("${ROOT_DIR}/scripts")
INCLUDE_DOCS=false

# Create necessary directories
mkdir -p "${TEMP_DIR}"
mkdir -p "${AUDIT_LOG_DIR}"

# Display banner
echo -e "${CYAN}${BOLD}=====================================================${NC}"
echo -e "${CYAN}${BOLD}         AgencyStack Quick Repository Audit          ${NC}"
echo -e "${CYAN}${BOLD}=====================================================${NC}"
echo -e "${CYAN}Date: $(date)${NC}"
echo -e "${CYAN}Repository: ${ROOT_DIR}${NC}"
echo -e "${CYAN}=====================================================${NC}\n"

# Process command line arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    --days)
      DAYS_THRESHOLD="$2"
      shift
      shift
      ;;
    --include-dir)
      SCRIPT_DIRS+=("$2")
      shift
      shift
      ;;
    --include-docs)
      INCLUDE_DOCS=true
      shift
      ;;
    --verbose)
      VERBOSE=true
      shift
      ;;
    --help|-h)
      echo "Usage: quick_audit.sh [OPTIONS]"
      echo "Options:"
      echo "  --days DAYS          Age threshold in days (default: 90)"
      echo "  --include-dir DIR    Additional directory to scan"
      echo "  --include-docs       Include documentation analysis"
      echo "  --verbose            Show verbose output"
      echo "  --help, -h           Show this help message"
      exit 0
      ;;
    *)
      echo -e "${RED}Unknown option: $key${NC}"
      exit 1
      ;;
  esac
done

# Initialize report
cat > "${OUTPUT_FILE}" << EOF
AGENCYSTACK QUICK AUDIT REPORT
==============================
Generated: $(date)
Repository: ${ROOT_DIR}
Days threshold: ${DAYS_THRESHOLD}

EOF

echo -e "${CYAN}Step 1/4: Finding all scripts in the repository...${NC}"

# Find all scripts and count them
total_scripts=0
for dir in "${SCRIPT_DIRS[@]}"; do
  echo -e "  ${CYAN}Scanning directory: ${dir}${NC}"
  
  # Find shell scripts
  shell_scripts=$(find "${dir}" -type f -name "*.sh" 2>/dev/null | wc -l)
  echo -e "  ${CYAN}→ Shell scripts (.sh): ${shell_scripts}${NC}"
  ((total_scripts += shell_scripts))
  
  # Find Python scripts
  python_scripts=$(find "${dir}" -type f -name "*.py" 2>/dev/null | wc -l)
  echo -e "  ${CYAN}→ Python scripts (.py): ${python_scripts}${NC}"
  ((total_scripts += python_scripts))
  
  # Find JavaScript scripts
  js_scripts=$(find "${dir}" -type f -name "*.js" 2>/dev/null | wc -l)
  echo -e "  ${CYAN}→ JavaScript scripts (.js): ${js_scripts}${NC}"
  ((total_scripts += js_scripts))
done

echo -e "  ${GREEN}Total scripts found: ${total_scripts}${NC}"

# Add to report
cat >> "${OUTPUT_FILE}" << EOF
SCRIPT STATISTICS
----------------
Total scripts found: ${total_scripts}
EOF

echo -e "\n${CYAN}Step 2/4: Finding stale scripts (not modified in ${DAYS_THRESHOLD} days)...${NC}"

# Find old scripts
echo -e "  ${CYAN}Searching for scripts not modified in ${DAYS_THRESHOLD} days...${NC}"
old_scripts=0
old_script_list=""

for dir in "${SCRIPT_DIRS[@]}"; do
  while IFS= read -r script; do
    if [[ -n "$script" ]]; then
      ((old_scripts++))
      # Get relative path for cleaner output
      rel_path="${script#$ROOT_DIR/}"
      old_script_list+="  - ${rel_path} ($(stat -c %y "${script}" | cut -d' ' -f1))\n"
    fi
  done < <(find "${dir}" -type f \( -name "*.sh" -o -name "*.py" -o -name "*.js" \) -mtime +${DAYS_THRESHOLD} 2>/dev/null)
done

echo -e "  ${YELLOW}Found ${old_scripts} scripts not modified in ${DAYS_THRESHOLD} days${NC}"

# Add to report
cat >> "${OUTPUT_FILE}" << EOF

STALE SCRIPTS
------------
Scripts not modified in ${DAYS_THRESHOLD} days: ${old_scripts}
EOF

if [[ "${old_scripts}" -gt 0 ]]; then
  echo -e "${old_script_list}" >> "${OUTPUT_FILE}"
fi

echo -e "\n${CYAN}Step 3/4: Checking for potential unused scripts...${NC}"

# Quick reference check (not comprehensive but fast)
echo -e "  ${CYAN}Performing quick reference check...${NC}"
potential_unused=0
unused_script_list=""

for dir in "${SCRIPT_DIRS[@]}"; do
  while IFS= read -r script; do
    if [[ -n "$script" ]]; then
      # Get script basename
      script_basename=$(basename "${script}")
      
      # Skip common script names that might give false positives
      if [[ "${script_basename}" == "setup.sh" || "${script_basename}" == "init.sh" || 
            "${script_basename}" == "config.sh" || "${script_basename}" == "common.sh" ||
            "${script_basename}" == "utils.sh" || "${script_basename}" == "helpers.sh" ]]; then
        continue
      fi
      
      # Check if script is referenced in the codebase
      references=$(grep -r --include="*.sh" --include="*.py" --include="*.js" --include="Makefile" \
                      --include="*.md" "${script_basename}" "${ROOT_DIR}" 2>/dev/null | 
                  grep -v "${script}" | wc -l)
      
      if [[ "${references}" -eq 0 ]]; then
        ((potential_unused++))
        # Get relative path for cleaner output
        rel_path="${script#$ROOT_DIR/}"
        unused_script_list+="  - ${rel_path}\n"
        
        # Log potential unused script
        echo "[WARNING] Potential unused script: ${rel_path}" >> "${AUDIT_LOG_DIR}/potential_unused_scripts.log"
      fi
    fi
  done < <(find "${dir}" -type f -name "*.sh" 2>/dev/null)
done

echo -e "  ${YELLOW}Found ${potential_unused} potentially unused scripts${NC}"

# Add to report
cat >> "${OUTPUT_FILE}" << EOF

POTENTIALLY UNUSED SCRIPTS
-------------------------
Scripts with no apparent references: ${potential_unused}
EOF

if [[ "${potential_unused}" -gt 0 ]]; then
  echo -e "${unused_script_list}" >> "${OUTPUT_FILE}"
fi

echo -e "\n${CYAN}Step 4/4: Checking for documentation consistency...${NC}"

# Only perform this check if requested
if [[ "${INCLUDE_DOCS}" == "true" ]]; then
  echo -e "  ${CYAN}Analyzing documentation...${NC}"
  
  # Find all documentation files
  doc_files=$(find "${ROOT_DIR}/docs" -type f -name "*.md" 2>/dev/null)
  doc_count=$(echo "${doc_files}" | wc -l)
  
  echo -e "  ${CYAN}Found ${doc_count} documentation files${NC}"
  
  # Check for scripts mentioned in docs but not in codebase
  doc_inconsistencies=0
  inconsistency_list=""
  
  for doc in ${doc_files}; do
    # Extract script names from markdown code blocks
    script_mentions=$(grep -o '`[^`]*\.sh`' "${doc}" | tr -d '`' 2>/dev/null)
    
    for mention in ${script_mentions}; do
      # Check if script exists
      if ! find "${ROOT_DIR}" -name "${mention}" -type f 2>/dev/null | grep -q .; then
        ((doc_inconsistencies++))
        doc_rel_path="${doc#$ROOT_DIR/}"
        inconsistency_list+="  - ${doc_rel_path} references non-existent script: ${mention}\n"
        
        # Log documentation inconsistency
        echo "[WARNING] Doc inconsistency: ${doc_rel_path} references non-existent script: ${mention}" >> "${AUDIT_LOG_DIR}/doc_inconsistencies.log"
      fi
    done
  done
  
  echo -e "  ${YELLOW}Found ${doc_inconsistencies} documentation inconsistencies${NC}"
  
  # Add to report
  cat >> "${OUTPUT_FILE}" << EOF

DOCUMENTATION CONSISTENCY
-----------------------
Documentation files: ${doc_count}
Inconsistencies found: ${doc_inconsistencies}
EOF

  if [[ "${doc_inconsistencies}" -gt 0 ]]; then
    echo -e "${inconsistency_list}" >> "${OUTPUT_FILE}"
  fi
else
  echo -e "  ${YELLOW}Documentation analysis skipped (use --include-docs to enable)${NC}"
  
  cat >> "${OUTPUT_FILE}" << EOF

DOCUMENTATION CONSISTENCY
-----------------------
Documentation analysis skipped (use --include-docs to enable)
EOF
fi

# Generate recommendations
cat >> "${OUTPUT_FILE}" << EOF

RECOMMENDATIONS
-------------
1. Review the potentially unused scripts for actual usage
2. Consider archiving or removing scripts not modified in ${DAYS_THRESHOLD} days
3. Update documentation to reflect the current state of the codebase
4. Run a full audit with 'make audit' for more comprehensive analysis
EOF

# Display summary
echo -e "\n${GREEN}${BOLD}Quick Audit Complete!${NC}"
echo -e "${CYAN}------------------------------------------${NC}"
echo -e "${CYAN}Total scripts: ${total_scripts}${NC}"
echo -e "${YELLOW}Stale scripts: ${old_scripts}${NC}"
echo -e "${YELLOW}Potentially unused scripts: ${potential_unused}${NC}"
if [[ "${INCLUDE_DOCS}" == "true" ]]; then
  echo -e "${YELLOW}Documentation inconsistencies: ${doc_inconsistencies}${NC}"
fi
echo -e "${CYAN}------------------------------------------${NC}"

# Copy report to audit log directory
cp "${OUTPUT_FILE}" "${AUDIT_LOG_DIR}/quick_audit_$(date +%Y%m%d).txt"
echo -e "${GREEN}Report saved to: ${AUDIT_LOG_DIR}/quick_audit_$(date +%Y%m%d).txt${NC}"

# Clean up
rm -rf "${TEMP_DIR}"

exit 0
