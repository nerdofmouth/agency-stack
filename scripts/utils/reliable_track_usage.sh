#!/bin/bash
# reliable_track_usage.sh - Enhanced Script Usage Tracker
# [https://stack.nerdofmouth.com](https://stack.nerdofmouth.com)
#
# Analyzes script usage across the AgencyStack codebase
# Tags scripts as: used, likely_used, possibly_unused, not_used
# Generates JSON and human-readable reports
#
# Author: AgencyStack Team
# Version: 2.0.0

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
GRAY='\033[0;37m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
LOG_DIR="/var/log/agency_stack"
AUDIT_LOG_DIR="${LOG_DIR}/audit"
TEMP_DIR="/tmp/agency_stack_audit_$(date +%s)"
VERBOSE=false
SKIP_DOCS=false
SKIP_MAKEFILE=false
DAYS_THRESHOLD=90
JSON_OUTPUT=true

# Script tag categories
declare -a SCRIPT_FILES=()
declare -a USED_SCRIPTS=()
declare -a LIKELY_USED_SCRIPTS=()
declare -a POSSIBLY_UNUSED_SCRIPTS=()
declare -a NOT_USED_SCRIPTS=()
declare -a IGNORED_SCRIPTS=()

# Setup
mkdir -p "${AUDIT_LOG_DIR}"
mkdir -p "${TEMP_DIR}"
mkdir -p "${TEMP_DIR}/tags/used"
mkdir -p "${TEMP_DIR}/tags/likely_used"
mkdir -p "${TEMP_DIR}/tags/possibly_unused"
mkdir -p "${TEMP_DIR}/tags/not_used"
mkdir -p "${TEMP_DIR}/tags/ignored"

echo -e "${BOLD}${MAGENTA}AgencyStack Script Usage Tracker${NC}"
echo -e "${BOLD}-----------------------------${NC}"

# Step 1: Find all scripts
echo -e "${CYAN}Step 1/5: Finding scripts...${NC}"
echo "# Script paths" > "${TEMP_DIR}/all_scripts.txt"

# Find all shell scripts
echo -e "  ${CYAN}Finding shell scripts...${NC}"
find "${ROOT_DIR}/scripts" -type f -name "*.sh" | while read -r script; do
  SCRIPT_FILES+=("$script")
  echo "$script" >> "${TEMP_DIR}/all_scripts.txt"
done

# Find JavaScript scripts
echo -e "  ${CYAN}Finding JavaScript scripts...${NC}"
find "${ROOT_DIR}/scripts" -type f -name "*.js" | while read -r script; do
  SCRIPT_FILES+=("$script")
  echo "$script" >> "${TEMP_DIR}/all_scripts.txt"
done

# Count scripts
SCRIPT_COUNT=$(wc -l < "${TEMP_DIR}/all_scripts.txt")
echo -e "  ${GREEN}Found ${SCRIPT_COUNT} script files${NC}"

# Step 2: Analyze Makefile references
echo -e "${CYAN}Step 2/5: Analyzing Makefile references...${NC}"
MAKEFILE="${ROOT_DIR}/Makefile"

if [ -f "$MAKEFILE" ]; then
  # Extract Makefile targets
  grep -E '^[a-zA-Z0-9_-]+:' "$MAKEFILE" | sed 's/:.*//' > "${TEMP_DIR}/makefile_targets.txt"
  TARGET_COUNT=$(wc -l < "${TEMP_DIR}/makefile_targets.txt")
  echo -e "  ${CYAN}Found ${TARGET_COUNT} Makefile targets${NC}"
  
  # Extract script references from Makefile
  grep -E '\.sh' "$MAKEFILE" | grep -oE '[a-zA-Z0-9_/-]+\.sh' | sort | uniq > "${TEMP_DIR}/makefile_refs.txt"
  MAKE_REF_COUNT=$(wc -l < "${TEMP_DIR}/makefile_refs.txt")
  echo -e "  ${CYAN}Found ${MAKE_REF_COUNT} script references in Makefile${NC}"
else
  echo -e "  ${YELLOW}Makefile not found at $MAKEFILE${NC}"
  touch "${TEMP_DIR}/makefile_refs.txt"
fi

# Step 3: Detect dynamic references
echo -e "${CYAN}Step 3/5: Analyzing dynamic script references...${NC}"

# Look for dynamic references in key files
echo -e "  ${CYAN}Searching for dynamic references...${NC}"
touch "${TEMP_DIR}/dynamic_patterns.txt"

# Check install_all.sh for dynamic patterns
INSTALL_ALL="${ROOT_DIR}/scripts/install_all.sh"
if [ -f "$INSTALL_ALL" ]; then
  # Check for dynamic patterns like ${COMPONENT}
  grep -E '\$\{.*\}\.sh|\$\(.*\)\.sh|\$[A-Za-z0-9_]+\.sh' "$INSTALL_ALL" > "${TEMP_DIR}/dynamic_refs.txt" 2>/dev/null || true
  
  # Extract components that might be used in dynamic references
  grep -E 'components=|COMPONENTS=|component_list=|COMPONENT_LIST=' "$INSTALL_ALL" > "${TEMP_DIR}/component_vars.txt" 2>/dev/null || true
fi

# Step 4: Check documentation references
echo -e "${CYAN}Step 4/5: Analyzing documentation references...${NC}"
DOCS_DIR="${ROOT_DIR}/docs"

if [ -d "$DOCS_DIR" ]; then
  # Find all script references in markdown docs
  find "$DOCS_DIR" -type f -name "*.md" -exec grep -o '[a-zA-Z0-9_/-]\+\.sh' {} \; | sort | uniq > "${TEMP_DIR}/doc_refs.txt"
  DOC_REF_COUNT=$(wc -l < "${TEMP_DIR}/doc_refs.txt")
  echo -e "  ${CYAN}Found ${DOC_REF_COUNT} script references in documentation${NC}"
else
  echo -e "  ${YELLOW}Documentation directory not found at $DOCS_DIR${NC}"
  touch "${TEMP_DIR}/doc_refs.txt"
fi

# Step 5: Tag scripts
echo -e "${CYAN}Step 5/5: Tagging scripts...${NC}"

# Tag a script
tag_script() {
  local script="$1"
  local category="$2"
  local reason="$3"
  local rel_path="${script#$ROOT_DIR/}"
  
  # Ensure parent directory exists
  mkdir -p "${TEMP_DIR}/tags/${category}/$(dirname "$rel_path")"
  
  # Store the tag
  echo "$reason" > "${TEMP_DIR}/tags/${category}/${rel_path}"
}

# Check if .trackignore exists
TRACKIGNORE="${ROOT_DIR}/.trackignore"
TRACKIGNORE_PATTERNS=()
if [ -f "$TRACKIGNORE" ]; then
  while IFS= read -r pattern; do
    # Skip comments and empty lines
    if [[ -n "$pattern" && ! "$pattern" =~ ^# ]]; then
      TRACKIGNORE_PATTERNS+=("$pattern")
    fi
  done < "$TRACKIGNORE"
  echo -e "  ${CYAN}Found ${#TRACKIGNORE_PATTERNS[@]} patterns in .trackignore${NC}"
fi

# Create arrays to store script categories
IFS=$'\n' read -d '' -r -a ALL_SCRIPTS < "${TEMP_DIR}/all_scripts.txt" || true

for script in "${ALL_SCRIPTS[@]}"; do
  # Skip empty lines
  if [[ -z "$script" || "$script" =~ ^# ]]; then
    continue
  fi
  
  REL_PATH="${script#$ROOT_DIR/}"
  SCRIPT_BASENAME=$(basename "$script")
  
  # Check for trackignore patterns
  IS_IGNORED=false
  for pattern in "${TRACKIGNORE_PATTERNS[@]}"; do
    if [[ "$REL_PATH" == $pattern ]]; then
      IS_IGNORED=true
      tag_script "$script" "ignored" "in_trackignore"
      IGNORED_SCRIPTS+=("$script")
      break
    fi
  done
  
  # Continue if ignored
  if [ "$IS_IGNORED" = true ]; then
    continue
  fi
  
  # Check if it's a utility script (always considered used)
  if [[ "$REL_PATH" == *"/utils/"* || "$REL_PATH" == *"/lib/"* || 
        "$SCRIPT_BASENAME" == *"common.sh"* || "$SCRIPT_BASENAME" == *"utils.sh"* ||
        "$SCRIPT_BASENAME" == *"helper"* || "$SCRIPT_BASENAME" == *"template"* ]]; then
    tag_script "$script" "used" "core_utility"
    USED_SCRIPTS+=("$script")
    continue
  fi
  
  # Check for direct references in Makefile
  if grep -q "$SCRIPT_BASENAME" "${TEMP_DIR}/makefile_refs.txt" 2>/dev/null; then
    tag_script "$script" "used" "makefile_reference"
    USED_SCRIPTS+=("$script")
    continue
  fi
  
  # Check for direct references in documentation
  if grep -q "$SCRIPT_BASENAME" "${TEMP_DIR}/doc_refs.txt" 2>/dev/null; then
    tag_script "$script" "used" "documentation_reference"
    USED_SCRIPTS+=("$script")
    continue
  fi
  
  # Check for install_*.sh pattern (likely dynamically used)
  if [[ "$SCRIPT_BASENAME" == install_*.sh ]]; then
    tag_script "$script" "likely_used" "potential_dynamic_reference"
    LIKELY_USED_SCRIPTS+=("$script")
    continue
  fi
  
  # Check for recent Git activity
  if command -v git &> /dev/null && [ -d "${ROOT_DIR}/.git" ]; then
    LAST_COMMIT=$(cd "${ROOT_DIR}" && git log -1 --format="%at" -- "$REL_PATH" 2>/dev/null || echo "0")
    if [ "$LAST_COMMIT" != "0" ]; then
      DAYS_SINCE=$(($(date +%s) - LAST_COMMIT))
      DAYS_SINCE=$((DAYS_SINCE / 86400))
      
      if [ "$DAYS_SINCE" -lt "$DAYS_THRESHOLD" ]; then
        tag_script "$script" "possibly_unused" "recent_git_activity"
        POSSIBLY_UNUSED_SCRIPTS+=("$script")
        continue
      fi
    fi
  fi
  
  # Nothing else matched, so it's not used
  tag_script "$script" "not_used" "no_references_found"
  NOT_USED_SCRIPTS+=("$script")
done

# Generate summary table
USED_COUNT=${#USED_SCRIPTS[@]}
LIKELY_COUNT=${#LIKELY_USED_SCRIPTS[@]}
POSSIBLY_COUNT=${#POSSIBLY_UNUSED_SCRIPTS[@]}
NOT_USED_COUNT=${#NOT_USED_SCRIPTS[@]}
IGNORED_COUNT=${#IGNORED_SCRIPTS[@]}
TOTAL_COUNT=$((USED_COUNT + LIKELY_COUNT + POSSIBLY_COUNT + NOT_USED_COUNT + IGNORED_COUNT))

# Calculate percentages
USED_PCT=$((USED_COUNT * 100 / TOTAL_COUNT))
LIKELY_PCT=$((LIKELY_COUNT * 100 / TOTAL_COUNT))
POSSIBLY_PCT=$((POSSIBLY_COUNT * 100 / TOTAL_COUNT))
NOT_USED_PCT=$((NOT_USED_COUNT * 100 / TOTAL_COUNT))
IGNORED_PCT=$((IGNORED_COUNT * 100 / TOTAL_COUNT))

# Create summary report
SUMMARY_FILE="${AUDIT_LOG_DIR}/usage_summary.txt"
cat > "$SUMMARY_FILE" << EOF
+------------------------------------------------------------------------------+
|                     AGENCYSTACK SCRIPT USAGE SUMMARY                         |
+------------------------------------------------------------------------------+
| Category          | Count | Percentage | Description                         |
+------------------+-------+------------+-------------------------------------+
| Used              | ${USED_COUNT} | ${USED_PCT}% | Directly referenced scripts               |
| Likely Used       | ${LIKELY_COUNT} | ${LIKELY_PCT}% | Potentially used via dynamic references  |
| Possibly Unused   | ${POSSIBLY_COUNT} | ${POSSIBLY_PCT}% | Not referenced but has recent activity  |
| Not Used          | ${NOT_USED_COUNT} | ${NOT_USED_PCT}% | No references found                     |
| Ignored           | ${IGNORED_COUNT} | ${IGNORED_PCT}% | Excluded from analysis                  |
+------------------+-------+------------+-------------------------------------+
| TOTAL             | ${TOTAL_COUNT} | 100% |                                     |
+------------------+-------+------------+-------------------------------------+

EXPLANATION OF CATEGORIES:
-------------------------
* Used: Scripts that are directly referenced in the codebase (Makefile, docs, other scripts)
* Likely Used: Scripts that are potentially used through dynamic references (variable expansions)
* Possibly Unused: Scripts with no direct references but have recent Git activity
* Not Used: Scripts with no references and no recent activity
* Ignored: Scripts excluded from analysis via .trackignore file

RECOMMENDATIONS:
--------------
1. Review 'Not Used' scripts for cleanup opportunities
2. Examine 'Possibly Unused' scripts to confirm their status
3. Consider adding important 'Likely Used' scripts to documentation
4. Maintain .trackignore file for special scripts that should be excluded from analysis
EOF

# Generate JSON report
JSON_REPORT="${AUDIT_LOG_DIR}/script_usage_report.json"
echo "{" > "$JSON_REPORT"
echo "  \"generated_at\": \"$(date -Iseconds)\"," >> "$JSON_REPORT"
echo "  \"repository\": \"${ROOT_DIR}\"," >> "$JSON_REPORT"
echo "  \"script_count\": ${TOTAL_COUNT}," >> "$JSON_REPORT"
echo "  \"summary\": {" >> "$JSON_REPORT"
echo "    \"used\": ${USED_COUNT}," >> "$JSON_REPORT"
echo "    \"likely_used\": ${LIKELY_COUNT}," >> "$JSON_REPORT"
echo "    \"possibly_unused\": ${POSSIBLY_COUNT}," >> "$JSON_REPORT"
echo "    \"not_used\": ${NOT_USED_COUNT}," >> "$JSON_REPORT"
echo "    \"ignored\": ${IGNORED_COUNT}" >> "$JSON_REPORT"
echo "  }," >> "$JSON_REPORT"
echo "  \"scripts\": [" >> "$JSON_REPORT"

# Helper function to add scripts to JSON
add_scripts_to_json() {
  local category="$1"
  local script_array=("${!2}")
  local first="$3"
  
  for script in "${script_array[@]}"; do
    local rel_path="${script#$ROOT_DIR/}"
    
    if [ "$first" = true ]; then
      first=false
    else
      echo "," >> "$JSON_REPORT"
    fi
    
    echo "    {" >> "$JSON_REPORT"
    echo "      \"path\": \"$rel_path\"," >> "$JSON_REPORT"
    echo "      \"tag\": \"$category\"," >> "$JSON_REPORT"
    echo "      \"last_modified\": \"$(date -r "$script" -Iseconds 2>/dev/null || echo "unknown")\"" >> "$JSON_REPORT"
    echo -n "    }" >> "$JSON_REPORT"
  done
  
  echo "$first"
}

# Add all script categories to JSON
FIRST=true
FIRST=$(add_scripts_to_json "used" "USED_SCRIPTS[@]" "$FIRST")
FIRST=$(add_scripts_to_json "likely_used" "LIKELY_USED_SCRIPTS[@]" "$FIRST")
FIRST=$(add_scripts_to_json "possibly_unused" "POSSIBLY_UNUSED_SCRIPTS[@]" "$FIRST")
FIRST=$(add_scripts_to_json "not_used" "NOT_USED_SCRIPTS[@]" "$FIRST")
FIRST=$(add_scripts_to_json "ignored" "IGNORED_SCRIPTS[@]" "$FIRST")

echo "" >> "$JSON_REPORT"
echo "  ]" >> "$JSON_REPORT"
echo "}" >> "$JSON_REPORT"

# Display summary
echo -e "\n${BOLD}${MAGENTA}SCRIPT USAGE SUMMARY${NC}"
echo -e "${BOLD}------------------${NC}"
echo -e "${GREEN}Used scripts:${NC} $USED_COUNT ($USED_PCT%)"
echo -e "${CYAN}Likely used:${NC} $LIKELY_COUNT ($LIKELY_PCT%)"
echo -e "${YELLOW}Possibly unused:${NC} $POSSIBLY_COUNT ($POSSIBLY_PCT%)"
echo -e "${RED}Not used:${NC} $NOT_USED_COUNT ($NOT_USED_PCT%)"
echo -e "${GRAY}Ignored:${NC} $IGNORED_COUNT ($IGNORED_PCT%)"
echo -e "${BOLD}------------------${NC}"
echo -e "${BOLD}Total scripts:${NC} $TOTAL_COUNT"

echo -e "\n${BOLD}Reports generated:${NC}"
echo -e "  ${YELLOW}Summary report:${NC} $SUMMARY_FILE"
echo -e "  ${YELLOW}JSON report:${NC} $JSON_REPORT"

echo -e "\n${GREEN}Script usage analysis completed successfully.${NC}"

# Clean up temp files
rm -rf "$TEMP_DIR"

exit 0
