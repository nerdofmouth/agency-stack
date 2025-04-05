#!/bin/bash
# track_usage.sh - Script Usage Tracking and Analysis Tool
# [https://stack.nerdofmouth.com](https://stack.nerdofmouth.com)
#
# Analyzes script usage across the AgencyStack codebase
# Identifies unused, orphaned, or stale scripts
# Generates reports for audit and cleanup
#
# Author: AgencyStack Team
# Version: 2.0.0

set -euo pipefail

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
CONFIG_DIR="/opt/agency_stack"
LOG_DIR="/var/log/agency_stack"
AUDIT_LOG_DIR="${LOG_DIR}/audit"
UNUSED_SCRIPTS_LOG="${AUDIT_LOG_DIR}/unused_scripts.log"
DOC_INCONSISTENCIES_LOG="${AUDIT_LOG_DIR}/doc_inconsistencies.log"
DYNAMIC_REFS_LOG="${AUDIT_LOG_DIR}/dynamic_references.log"
FULL_REPORT_LOG="${AUDIT_LOG_DIR}/script_tracking.log"
SCRIPT_TAGS_LOG="${AUDIT_LOG_DIR}/script_tags.log"
TEMP_DIR="/tmp/agency_stack_audit_$(date +%s)"
INCLUDE_DIRS=()
EXCLUDE_DIRS=()
VERBOSE=false
QUIET=false
MAX_DEPTH=10
SKIP_DOCS=false
SKIP_MAKEFILE=false
SKIP_DYNAMIC=false
GIT_AWARE=true
DAYS_THRESHOLD=90
JSON_OUTPUT=true
TAGS_DIR="${TEMP_DIR}/tags"

# Script tag categories
declare -a SCRIPT_FILES
declare -a USED_SCRIPTS
declare -a LIKELY_USED_SCRIPTS
declare -a POSSIBLY_UNUSED_SCRIPTS
declare -a NOT_USED_SCRIPTS
declare -a IGNORED_SCRIPTS

# Usage Information
show_help() {
  echo -e "${MAGENTA}${BOLD}AgencyStack Script Usage Tracking Tool${NC}"
  echo -e "============================================"
  echo -e "Tracks and analyzes script usage across the AgencyStack codebase."
  echo -e ""
  echo -e "${CYAN}Usage:${NC}"
  echo -e "  $0 [options]"
  echo -e ""
  echo -e "${CYAN}Options:${NC}"
  echo -e "  ${BOLD}--target-dir${NC} <dir>        Directory to analyze (default: all script directories)"
  echo -e "  ${BOLD}--include-dir${NC} <dir>       Additional directory to include in analysis (can be used multiple times)"
  echo -e "  ${BOLD}--exclude-dir${NC} <dir>       Exclude directory from analysis (can be used multiple times)"
  echo -e "  ${BOLD}--max-depth${NC} <number>      Maximum directory depth to analyze (default: 10)"
  echo -e "  ${BOLD}--output${NC} <format>         Output format: text, json, csv (default: text)"
  echo -e "  ${BOLD}--skip-docs${NC}               Skip documentation analysis"
  echo -e "  ${BOLD}--skip-makefile${NC}          Skip Makefile analysis"
  echo -e "  ${BOLD}--skip-dynamic${NC}           Skip dynamic script reference detection"
  echo -e "  ${BOLD}--verbose${NC}                 Show detailed output"
  echo -e "  ${BOLD}--quiet${NC}                   Suppress all output"
  echo -e "  ${BOLD}--help${NC}                    Show this help message and exit"
  echo -e ""
  echo -e "${CYAN}Examples:${NC}"
  echo -e "  $0 --target-dir /scripts/components"
  echo -e "  $0 --verbose --exclude-dir 'components'"
  echo -e ""
  echo -e "${CYAN}Output:${NC}"
  echo -e "  Results are logged to ${AUDIT_LOG_DIR}/"
  exit 0
}

# Create log directories if they don't exist
setup_environment() {
  mkdir -p "$AUDIT_LOG_DIR"
  mkdir -p "$TEMP_DIR"
  
  # Create empty log files
  : > "${UNUSED_SCRIPTS_LOG}"
  : > "${DOC_INCONSISTENCIES_LOG}"
  : > "${DYNAMIC_REFS_LOG}"
  : > "${FULL_REPORT_LOG}"
  : > "${SCRIPT_TAGS_LOG}"
  
  # Add headers to logs
  echo "# AgencyStack Unused Scripts Report - Generated on $(date)" > "${UNUSED_SCRIPTS_LOG}"
  echo "# AgencyStack Documentation Inconsistencies - Generated on $(date)" > "${DOC_INCONSISTENCIES_LOG}"
  echo "# AgencyStack Dynamic Script References - Generated on $(date)" > "${DYNAMIC_REFS_LOG}"
  echo "# AgencyStack Full Script Tracking Report - Generated on $(date)" > "${FULL_REPORT_LOG}"
  echo "# AgencyStack Script Tags - Generated on $(date)" > "${SCRIPT_TAGS_LOG}"
}

# Log message to both stdout and logfile
log() {
  local level="$1"
  local message="$2"
  local logfile="$3"
  local color=""
  
  case "$level" in
    "INFO") color="$BLUE" ;;
    "SUCCESS") color="$GREEN" ;;
    "WARNING") color="$YELLOW" ;;
    "ERROR") color="$RED" ;;
    *) color="$NC" ;;
  esac
  
  if [ "$QUIET" = false ]; then
    echo -e "${color}[$level] $message${NC}"
  fi
  
  echo "[$level] $message" >> "$logfile"
}

# Find all scripts in the target directories
find_scripts() {
  log "INFO" "Finding all script files..." "$FULL_REPORT_LOG"
  
  # Default to scripts directory if no include dirs specified
  if [ ${#INCLUDE_DIRS[@]} -eq 0 ]; then
    INCLUDE_DIRS+=("${ROOT_DIR}/scripts")
  fi
  
  # Find script files in all include directories
  for dir in "${INCLUDE_DIRS[@]}"; do
    local normalized_dir="${dir}"
    
    # Add ROOT_DIR prefix if relative path
    if [[ ! "$normalized_dir" = /* ]]; then
      normalized_dir="${ROOT_DIR}/${normalized_dir}"
    fi
    
    # Check if directory exists
    if [ ! -d "$normalized_dir" ]; then
      log "WARNING" "Directory not found: $normalized_dir" "$FULL_REPORT_LOG"
      continue
    fi
    
    log "INFO" "Scanning directory: $normalized_dir" "$FULL_REPORT_LOG"
    
    # Find shell scripts
    local find_cmd=("find" "$normalized_dir" "-type" "f")
    
    # Add max depth if specified
    if [ "$MAX_DEPTH" -gt 0 ]; then
      find_cmd+=("-maxdepth" "$MAX_DEPTH")
    fi
    
    # Add exclude directories
    for exclude_dir in "${EXCLUDE_DIRS[@]}"; do
      find_cmd+=("-not" "-path" "*/${exclude_dir}/*")
    done
    
    # Find shell scripts (.sh)
    log "INFO" "Finding shell scripts in $normalized_dir..." "$FULL_REPORT_LOG"
    while IFS= read -r script; do
      if [ -n "$script" ]; then
        SCRIPT_FILES+=("$script")
        echo "$script" >> "${TEMP_DIR}/all_scripts.txt"
        
        if [ "$VERBOSE" = true ]; then
          log "DEBUG" "Found script: $script" "$FULL_REPORT_LOG"
        fi
      fi
    done < <("${find_cmd[@]}" -name "*.sh" 2>/dev/null)
    
    # Find Python scripts (.py)
    log "INFO" "Finding Python scripts in $normalized_dir..." "$FULL_REPORT_LOG"
    while IFS= read -r script; do
      if [ -n "$script" ]; then
        SCRIPT_FILES+=("$script")
        echo "$script" >> "${TEMP_DIR}/all_scripts.txt"
        
        if [ "$VERBOSE" = true ]; then
          log "DEBUG" "Found script: $script" "$FULL_REPORT_LOG"
        fi
      fi
    done < <("${find_cmd[@]}" -name "*.py" 2>/dev/null)
    
    # Find JavaScript scripts (.js)
    log "INFO" "Finding JavaScript scripts in $normalized_dir..." "$FULL_REPORT_LOG"
    while IFS= read -r script; do
      if [ -n "$script" ]; then
        SCRIPT_FILES+=("$script")
        echo "$script" >> "${TEMP_DIR}/all_scripts.txt"
        
        if [ "$VERBOSE" = true ]; then
          log "DEBUG" "Found script: $script" "$FULL_REPORT_LOG"
        fi
      fi
    done < <("${find_cmd[@]}" -name "*.js" 2>/dev/null)
  done
  
  # Count total scripts
  local script_count=${#SCRIPT_FILES[@]}
  log "INFO" "Found $script_count script files" "$FULL_REPORT_LOG"
  echo "$script_count" > "${TEMP_DIR}/script_count.txt"
  
  if [ "$script_count" -eq 0 ]; then
    log "WARNING" "No script files found" "$FULL_REPORT_LOG"
  fi
}

# Detect dynamic script references (with variables)
find_dynamic_references() {
  if [ "$SKIP_DYNAMIC" = true ]; then
    log "INFO" "Skipping dynamic script reference detection" "$FULL_REPORT_LOG"
    return 0
  fi
  
  log "INFO" "Searching for dynamic script references..." "$FULL_REPORT_LOG"
  echo -e "${CYAN}Step 3/7: Analyzing dynamic script references...${NC}"
  
  # Create directory to store dynamic references
  mkdir -p "${TEMP_DIR}/dynamic_refs"
  
  # Make sure the dynamic patterns file exists
  touch "${TEMP_DIR}/dynamic_patterns.txt"
  
  # Patterns to look for
  local patterns=(
    '\$\{.*\}\.sh'                            # ${VAR}.sh style
    '\.\/[a-zA-Z0-9_\-]*\$\{.*\}'             # ./*${VAR} style
    'bash\s+[a-zA-Z0-9_\-]*\$\{.*\}\.sh'      # bash *${VAR}.sh
    'source\s+[a-zA-Z0-9_\-]*\$\{.*\}\.sh'    # source *${VAR}.sh
    'sh\s+[a-zA-Z0-9_\-]*\$\{.*\}\.sh'        # sh *${VAR}.sh
    '\$\([a-zA-Z0-9_\-]*\)\.sh'               # $(VAR).sh style
    '\$[a-zA-Z0-9_\-]*\.sh'                   # $VAR.sh style
  )
  
  # Search in key files first (Makefile and install_all.sh)
  for file in "${ROOT_DIR}/Makefile" $(find "${ROOT_DIR}" -name "install_all.sh" -type f 2>/dev/null); do
    if [ -f "$file" ]; then
      for pattern in "${patterns[@]}"; do
        # Use grep with error suppression
        grep -E "$pattern" "$file" 2>/dev/null | while read -r line; do
          # Extract potential script pattern
          log "INFO" "Found dynamic reference in $file: $line" "$DYNAMIC_REFS_LOG"
          
          # Store dynamic reference pattern
          echo "$line" >> "${TEMP_DIR}/dynamic_refs/$(basename "$file").txt"
          
          # Extract the pattern for later matching (with proper error handling)
          local base_pattern
          base_pattern=$(echo "$line" | grep -o '\$\{[A-Za-z0-9_]*\}\.sh\|\$[A-Za-z0-9_]*\.sh\|\$([A-Za-z0-9_]*)\|\.[a-zA-Z0-9_\-]*\$\{.*\}' 2>/dev/null || echo "")
          if [ -n "$base_pattern" ]; then
            echo "$base_pattern" >> "${TEMP_DIR}/dynamic_patterns.txt"
          fi
        done
      done
    fi
  done
  
  # Then search recursively in all scripts (with a limit to prevent excessive processing)
  local script_count=0
  local max_scripts=50  # Limit number of scripts to process for dynamic references
  
  for script in "${SCRIPT_FILES[@]}"; do
    ((script_count++))
    
    # Limit script processing to avoid performance issues
    if [ "$script_count" -gt "$max_scripts" ]; then
      log "INFO" "Reached maximum script processing limit for dynamic references ($max_scripts scripts)" "$FULL_REPORT_LOG"
      break
    fi
    
    local script_basename=$(basename "$script")
    
    for pattern in "${patterns[@]}"; do
      # Use grep with error suppression
      grep -E "$pattern" "$script" 2>/dev/null | while read -r line; do
        # Skip self-references
        if [[ "$line" == *"$script_basename"* ]]; then
          continue
        fi
        
        # Process and log reference
        log "INFO" "Found dynamic reference in $script: $line" "$DYNAMIC_REFS_LOG"
        
        # Store dynamic reference pattern (ensure directory exists)
        mkdir -p "${TEMP_DIR}/dynamic_refs"
        echo "$line" >> "${TEMP_DIR}/dynamic_refs/${script_basename}.txt"
        
        # Extract the pattern for later matching (with proper error handling)
        local base_pattern
        base_pattern=$(echo "$line" | grep -o '\$\{[A-Za-z0-9_]*\}\.sh\|\$[A-Za-z0-9_]*\.sh\|\$([A-Za-z0-9_]*)\|\.[a-zA-Z0-9_\-]*\$\{.*\}' 2>/dev/null || echo "")
        if [ -n "$base_pattern" ]; then
          echo "$base_pattern" >> "${TEMP_DIR}/dynamic_patterns.txt"
        fi
      done
    done
  done
  
  # Count dynamic references (with error handling)
  local pattern_count
  pattern_count=$(wc -l < "${TEMP_DIR}/dynamic_patterns.txt" 2>/dev/null || echo "0")
  log "INFO" "Found $pattern_count potential dynamic script reference patterns" "$FULL_REPORT_LOG"
  
  if [ "$pattern_count" -gt 0 ] && [ "$VERBOSE" = true ]; then
    log "DEBUG" "Dynamic patterns:" "$FULL_REPORT_LOG"
    cat "${TEMP_DIR}/dynamic_patterns.txt" | while read -r pattern; do
      log "DEBUG" "  - $pattern" "$FULL_REPORT_LOG"
    done
  fi
}

# Process command line arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    --target-dir)
      INCLUDE_DIRS=("$2")
      shift
      shift
      ;;
    --include-dir)
      INCLUDE_DIRS+=("$2")
      shift
      shift
      ;;
    --exclude-dir)
      EXCLUDE_DIRS+=("$2")
      shift
      shift
      ;;
    --max-depth)
      MAX_DEPTH="$2"
      shift
      shift
      ;;
    --output)
      JSON_OUTPUT="$2"
      shift
      shift
      ;;
    --skip-docs)
      SKIP_DOCS=true
      shift
      ;;
    --skip-makefile)
      SKIP_MAKEFILE=true
      shift
      ;;
    --skip-dynamic)
      SKIP_DYNAMIC=true
      shift
      ;;
    --verbose)
      VERBOSE=true
      shift
      ;;
    --quiet)
      QUIET=true
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

# Check if script is in trackignore
is_in_trackignore() {
  local script="$1"
  local rel_path="${script#$ROOT_DIR/}"
  
  # Check if .trackignore exists
  if [ -f "${ROOT_DIR}/.trackignore" ]; then
    if grep -q "^$rel_path$" "${ROOT_DIR}/.trackignore"; then
      log "INFO" "Script in .trackignore: $rel_path" "$FULL_REPORT_LOG"
      return 0
    fi
    
    # Also check for pattern matching
    while IFS= read -r pattern; do
      if [[ -n "$pattern" && ! "$pattern" =~ ^# && "$rel_path" == $pattern ]]; then
        log "INFO" "Script matches pattern in .trackignore: $rel_path (pattern: $pattern)" "$FULL_REPORT_LOG"
        return 0
      fi
    done < "${ROOT_DIR}/.trackignore"
  fi
  
  return 1
}

# Check if script is a core utility or template
is_core_utility() {
  local script="$1"
  local basename=$(basename "$script")
  
  # List of common utility scripts that shouldn't be flagged
  local core_patterns=(
    "utils.sh" 
    "common.sh" 
    "helper.sh" 
    "template.sh" 
    "lib.sh"
    "functions.sh"
    "config.sh"
    "settings.sh"
    "init.sh"
    "setup.sh"
  )
  
  # Check if script is in utils directory
  if [[ "$script" == *"/utils/"* || "$script" == *"/lib/"* ]]; then
    return 0
  fi
  
  # Check core patterns
  for pattern in "${core_patterns[@]}"; do
    if [[ "$basename" == *"$pattern"* ]]; then
      return 0
    fi
  done
  
  return 1
}

# Check if script has direct references
has_direct_references() {
  local script="$1"
  local script_basename=$(basename "$script")
  local ref_count=0
  
  # Check references in Makefile
  if [ -f "${TEMP_DIR}/makefile_script_refs.txt" ]; then
    if grep -q "$script_basename" "${TEMP_DIR}/makefile_script_refs.txt"; then
      ((ref_count++))
    fi
  fi
  
  # Check references in documentation
  if [ -f "${TEMP_DIR}/doc_script_refs_uniq.txt" ]; then
    if grep -q "$script_basename" "${TEMP_DIR}/doc_script_refs_uniq.txt"; then
      ((ref_count++))
    fi
  fi
  
  # Check references in other scripts (excluding self-references)
  local script_refs=$(grep -l "$script_basename" "${SCRIPT_FILES[@]}" 2>/dev/null | 
                     grep -v "$script" | wc -l)
  ref_count=$((ref_count + script_refs))
  
  # Check if script is referenced in install_all.sh
  if [ -f "${ROOT_DIR}/scripts/install_all.sh" ]; then
    if grep -q "$script_basename" "${ROOT_DIR}/scripts/install_all.sh"; then
      ((ref_count++))
    fi
  fi
  
  if [ "$ref_count" -gt 0 ]; then
    return 0
  fi
  
  return 1
}

# Check if script might be dynamically referenced
might_be_dynamically_referenced() {
  local script="$1"
  local script_basename=$(basename "$script")
  local script_prefix="${script_basename%.*}" # Remove extension
  
  # Check for common installation pattern
  if [[ "$script_basename" == install_*.sh ]]; then
    # This is likely used dynamically in install_all.sh
    return 0
  fi
  
  # Check against dynamic patterns
  if [ -f "${TEMP_DIR}/dynamic_patterns.txt" ]; then
    while read -r pattern; do
      # Convert ${VAR} to VAR
      local var_name=$(echo "$pattern" | sed -E 's/\$\{([^}]*)\}.*/\1/g' | sed -E 's/\$\(([^)]*)\).*/\1/g' | sed -E 's/\$([a-zA-Z0-9_]*).*/\1/g')
      
      # Check if script follows a pattern like install_component.sh where "component" could be a variable
      if [[ "$script_basename" =~ ^([a-zA-Z0-9_]+)_.*\.sh$ ]]; then
        local prefix="${BASH_REMATCH[1]}"
        # Look for dynamic patterns with matching prefix
        if grep -q "${prefix}_.*\.sh" "${TEMP_DIR}/dynamic_refs/"*.txt 2>/dev/null; then
          return 0
        fi
      fi
    done < "${TEMP_DIR}/dynamic_patterns.txt"
  fi
  
  return 1
}

# Check if script has recent Git commits
has_recent_git_commits() {
  local script="$1"
  
  # Skip if Git is not available or not a Git repository
  if ! command -v git &> /dev/null || [ ! -d "${ROOT_DIR}/.git" ]; then
    return 1
  fi
  
  # Convert to path relative to repository root for Git
  local rel_path="${script#$ROOT_DIR/}"
  
  # Check last commit date
  local last_commit_date=$(cd "${ROOT_DIR}" && git log -1 --format="%at" -- "$rel_path" 2>/dev/null)
  
  # If no commits for this file or error, return false
  if [ -z "$last_commit_date" ]; then
    return 1
  fi
  
  # Calculate days since last commit
  local now=$(date +%s)
  local days_since_commit=$(( (now - last_commit_date) / 86400 ))
  
  # If committed within the last threshold days, consider it possibly in use
  if [ "$days_since_commit" -lt "$DAYS_THRESHOLD" ]; then
    return 0
  fi
  
  return 1
}

# Tag a script with its usage category
tag_script() {
  local script="$1"
  local tag="$2"
  local reason="${3:-unknown}"
  
  # Create tag directory if it doesn't exist
  mkdir -p "${TAGS_DIR}/${tag}"
  
  # Get relative path for cleaner output
  local rel_path="${script#$ROOT_DIR/}"
  
  # Store the script path and reason in the tag file
  echo "$reason" > "${TAGS_DIR}/${tag}/${rel_path}"
  
  # Log the tagging
  log "INFO" "Tagged script as '$tag': $rel_path (reason: $reason)" "$SCRIPT_TAGS_LOG"
  
  # Add to appropriate array for summary reporting
  case "$tag" in
    "used")
      USED_SCRIPTS+=("$script")
      ;;
    "likely_used")
      LIKELY_USED_SCRIPTS+=("$script")
      ;;
    "possibly_unused")
      POSSIBLY_UNUSED_SCRIPTS+=("$script")
      ;;
    "not_used")
      NOT_USED_SCRIPTS+=("$script")
      ;;
    "ignored")
      IGNORED_SCRIPTS+=("$script")
      ;;
  esac
}

# Tag all scripts based on usage analysis
tag_scripts() {
  log "INFO" "Tagging scripts based on usage patterns..." "$FULL_REPORT_LOG"
  echo -e "${CYAN}Step 6/7: Tagging scripts based on usage patterns...${NC}"
  
  # Create tag directories
  mkdir -p "${TAGS_DIR}/used"
  mkdir -p "${TAGS_DIR}/likely_used"
  mkdir -p "${TAGS_DIR}/possibly_unused"
  mkdir -p "${TAGS_DIR}/not_used"
  mkdir -p "${TAGS_DIR}/ignored"
  
  log "INFO" "Starting script tagging process for ${#SCRIPT_FILES[@]} scripts" "$FULL_REPORT_LOG"
  local tagged_count=0
  
  for script in "${SCRIPT_FILES[@]}"; do
    ((tagged_count++))
    
    # Show progress
    if [ $((tagged_count % 10)) -eq 0 ] || [ "$tagged_count" -eq "${#SCRIPT_FILES[@]}" ]; then
      echo -ne "Tagging scripts: $tagged_count/${#SCRIPT_FILES[@]} ($(( tagged_count * 100 / ${#SCRIPT_FILES[@]} ))%)\r"
    fi
    
    # Skip if in trackignore
    if is_in_trackignore "$script"; then
      tag_script "$script" "ignored" "in_trackignore"
      continue
    fi
    
    # Check if script is a utility or template
    if is_core_utility "$script"; then
      tag_script "$script" "used" "core_utility"
      continue
    fi
    
    # Check direct references
    if has_direct_references "$script"; then
      tag_script "$script" "used" "direct_reference"
      continue
    fi
    
    # Check dynamic references
    if might_be_dynamically_referenced "$script"; then
      tag_script "$script" "likely_used" "dynamic_reference"
      continue
    fi
    
    # Check other heuristics
    if has_recent_git_commits "$script"; then
      tag_script "$script" "possibly_unused" "recent_activity"
      continue
    fi
    
    # Otherwise it's not used
    tag_script "$script" "not_used" "no_references"
    
    # Log unused scripts
    log "WARNING" "Script not referenced: $script" "$UNUSED_SCRIPTS_LOG"
  done
  
  echo "" # Clear progress line
  
  # Update summary counts
  local used_count=${#USED_SCRIPTS[@]}
  local likely_used_count=${#LIKELY_USED_SCRIPTS[@]}
  local possibly_unused_count=${#POSSIBLY_UNUSED_SCRIPTS[@]}
  local not_used_count=${#NOT_USED_SCRIPTS[@]}
  local ignored_count=${#IGNORED_SCRIPTS[@]}
  
  echo "$used_count" > "${TEMP_DIR}/used_count.txt"
  echo "$likely_used_count" > "${TEMP_DIR}/likely_used_count.txt"
  echo "$possibly_unused_count" > "${TEMP_DIR}/possibly_unused_count.txt"
  echo "$not_used_count" > "${TEMP_DIR}/not_used_count.txt"
  echo "$ignored_count" > "${TEMP_DIR}/ignored_count.txt"
  
  log "SUCCESS" "Script tagging completed. Used: $used_count, Likely used: $likely_used_count, Possibly unused: $possibly_unused_count, Not used: $not_used_count, Ignored: $ignored_count" "$FULL_REPORT_LOG"
}

# Generate summary table
generate_summary_table() {
  log "INFO" "Generating summary table..." "$FULL_REPORT_LOG"
  echo -e "${CYAN}Step 7/7: Generating summary table...${NC}"
  
  local summary_file="${AUDIT_LOG_DIR}/usage_summary.txt"
  
  # Load counts
  local used_count=${#USED_SCRIPTS[@]}
  local likely_used_count=${#LIKELY_USED_SCRIPTS[@]}
  local possibly_unused_count=${#POSSIBLY_UNUSED_SCRIPTS[@]}
  local not_used_count=${#NOT_USED_SCRIPTS[@]}
  local ignored_count=${#IGNORED_SCRIPTS[@]}
  local total=$((used_count + likely_used_count + possibly_unused_count + not_used_count + ignored_count))
  
  # Calculate percentages
  local used_pct=0
  local likely_pct=0
  local possibly_pct=0
  local not_used_pct=0
  local ignored_pct=0
  
  if [ "$total" -gt 0 ]; then
    used_pct=$((used_count * 100 / total))
    likely_pct=$((likely_used_count * 100 / total))
    possibly_pct=$((possibly_unused_count * 100 / total))
    not_used_pct=$((not_used_count * 100 / total))
    ignored_pct=$((ignored_count * 100 / total))
  fi
  
  # Create header
  cat > "$summary_file" << EOF
+------------------------------------------------------------------------------+
|                     AGENCYSTACK SCRIPT USAGE SUMMARY                         |
+------------------------------------------------------------------------------+
| Category          | Count | Percentage | Description                         |
+------------------+-------+------------+-------------------------------------+
EOF

  # Add rows
  cat >> "$summary_file" << EOF
| Used              | ${used_count} | ${used_pct}% | Directly referenced scripts               |
| Likely Used       | ${likely_used_count} | ${likely_pct}% | Potentially used via dynamic references  |
| Possibly Unused   | ${possibly_unused_count} | ${possibly_pct}% | Not referenced but has recent activity  |
| Not Used          | ${not_used_count} | ${not_used_pct}% | No references found                     |
| Ignored           | ${ignored_count} | ${ignored_pct}% | Excluded from analysis                  |
+------------------+-------+------------+-------------------------------------+
| TOTAL             | ${total} | 100% |                                     |
+------------------+-------+------------+-------------------------------------+
EOF

  # Add explanations
  cat >> "$summary_file" << EOF

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

  log "SUCCESS" "Summary table generated: $summary_file" "$FULL_REPORT_LOG"
  
  # Display the summary
  echo -e "\n${BOLD}${MAGENTA}SCRIPT USAGE SUMMARY${NC}"
  echo -e "${BOLD}------------------${NC}"
  echo -e "${GREEN}Used scripts:${NC} $used_count ($used_pct%)"
  echo -e "${CYAN}Likely used:${NC} $likely_used_count ($likely_pct%)"
  echo -e "${YELLOW}Possibly unused:${NC} $possibly_unused_count ($possibly_pct%)"
  echo -e "${RED}Not used:${NC} $not_used_count ($not_used_pct%)"
  echo -e "${GRAY}Ignored:${NC} $ignored_count ($ignored_pct%)"
  echo -e "${BOLD}------------------${NC}"
  echo -e "${BOLD}Total scripts:${NC} $total"
}

# Generate JSON report
generate_json_report() {
  if [ "$JSON_OUTPUT" != "true" ]; then
    return 0
  fi
  
  log "INFO" "Generating JSON report..." "$FULL_REPORT_LOG"
  
  local json_report="${AUDIT_LOG_DIR}/script_usage_report.json"
  
  # Start JSON
  echo "{" > "$json_report"
  echo "  \"generated_at\": \"$(date -Iseconds)\"," >> "$json_report"
  echo "  \"repository\": \"${ROOT_DIR}\"," >> "$json_report"
  
  # Add counts for each category
  echo "  \"script_count\": ${#SCRIPT_FILES[@]}," >> "$json_report"
  
  # Add summary
  echo "  \"summary\": {" >> "$json_report"
  echo "    \"used\": ${#USED_SCRIPTS[@]}," >> "$json_report"
  echo "    \"likely_used\": ${#LIKELY_USED_SCRIPTS[@]}," >> "$json_report"
  echo "    \"possibly_unused\": ${#POSSIBLY_UNUSED_SCRIPTS[@]}," >> "$json_report"
  echo "    \"not_used\": ${#NOT_USED_SCRIPTS[@]}," >> "$json_report"
  echo "    \"ignored\": ${#IGNORED_SCRIPTS[@]}" >> "$json_report"
  echo "  }," >> "$json_report"
  
  # Add scripts by category
  echo "  \"scripts\": [" >> "$json_report"
  
  # Process each script
  local first=true
  
  # Function to add scripts from a category to JSON
  add_category_to_json() {
    local category="$1"
    local scripts=("${!2}")
    
    for script in "${scripts[@]}"; do
      local rel_path="${script#$ROOT_DIR/}"
      local reason=$(cat "${TAGS_DIR}/${category}/${rel_path}" 2>/dev/null || echo "unknown")
      local last_modified=$(stat -c %Y "$script" 2>/dev/null || echo "0")
      local last_modified_date=$(date -d "@$last_modified" -Iseconds 2>/dev/null || echo "unknown")
      
      if [ "$first" = true ]; then
        first=false
      else
        echo "," >> "$json_report"
      fi
      
      echo "    {" >> "$json_report"
      echo "      \"path\": \"$rel_path\"," >> "$json_report"
      echo "      \"tag\": \"$category\"," >> "$json_report"
      echo "      \"reason\": \"$reason\"," >> "$json_report"
      echo "      \"last_modified\": \"$last_modified_date\"" >> "$json_report"
      echo -n "    }" >> "$json_report"
    done
  }
  
  # Add each category
  add_category_to_json "used" "USED_SCRIPTS[@]"
  add_category_to_json "likely_used" "LIKELY_USED_SCRIPTS[@]"
  add_category_to_json "possibly_unused" "POSSIBLY_UNUSED_SCRIPTS[@]"
  add_category_to_json "not_used" "NOT_USED_SCRIPTS[@]"
  add_category_to_json "ignored" "IGNORED_SCRIPTS[@]"
  
  echo "" >> "$json_report"
  echo "  ]" >> "$json_report"
  echo "}" >> "$json_report"
  
  log "SUCCESS" "JSON report generated: $json_report" "$FULL_REPORT_LOG"
}

# Main execution
main() {
  echo -e "${BOLD}${MAGENTA}AgencyStack Script Usage Tracker${NC}"
  echo -e "${BOLD}-----------------------------${NC}"
  
  setup_environment
  
  echo -e "${CYAN}Step 1/7: Finding scripts...${NC}"
  find_scripts
  
  echo -e "${CYAN}Step 2/7: Analyzing Makefile...${NC}"
  if [ "$SKIP_MAKEFILE" = false ]; then
    # Analyze Makefile targets and references
    log "INFO" "Analyzing Makefile targets and references..." "$FULL_REPORT_LOG"
    local makefile="${ROOT_DIR}/Makefile"
    
    if [ ! -f "$makefile" ]; then
      log "WARNING" "Makefile not found at $makefile" "$FULL_REPORT_LOG"
    else
      # Extract all targets from Makefile
      log "INFO" "Extracting Makefile targets..." "$FULL_REPORT_LOG"
      grep -E '^[a-zA-Z0-9_-]+:' "$makefile" | sed 's/:.*//' > "${TEMP_DIR}/makefile_targets.txt"
      
      # Extract all script references from Makefile
      log "INFO" "Extracting script references from Makefile..." "$FULL_REPORT_LOG"
      grep -E '\.sh' "$makefile" | grep -oE '[a-zA-Z0-9_/-]+\.sh' | sort | uniq > "${TEMP_DIR}/makefile_script_refs.txt"
      
      log "SUCCESS" "Found $(wc -l < "${TEMP_DIR}/makefile_targets.txt" 2>/dev/null || echo "0") Makefile targets" "$FULL_REPORT_LOG"
      log "SUCCESS" "Found $(wc -l < "${TEMP_DIR}/makefile_script_refs.txt" 2>/dev/null || echo "0") script references in Makefile" "$FULL_REPORT_LOG"
    fi
  else
    echo -e "${CYAN}Step 2/7: Skipping Makefile analysis...${NC}"
  fi
  
  echo -e "${CYAN}Step 3/7: Analyzing dynamic script references...${NC}"
  find_dynamic_references
  
  echo -e "${CYAN}Step 4/7: Analyzing documentation...${NC}"
  if [ "$SKIP_DOCS" = false ]; then
    # Analyze documentation for script references
    log "INFO" "Analyzing documentation for script references..." "$FULL_REPORT_LOG"
    local docs_dir="${ROOT_DIR}/docs"
    
    if [ ! -d "$docs_dir" ]; then
      log "WARNING" "Documentation directory not found at $docs_dir" "$FULL_REPORT_LOG"
    else
      # Find all markdown files
      find "$docs_dir" -type f -name "*.md" > "${TEMP_DIR}/all_docs.txt"
      log "INFO" "Found $(wc -l < "${TEMP_DIR}/all_docs.txt" 2>/dev/null || echo "0") documentation files" "$FULL_REPORT_LOG"
      
      # Extract script references from documentation
      local doc_script_refs="${TEMP_DIR}/doc_script_refs.txt"
      : > "$doc_script_refs"
      
      while read -r doc_file; do
        grep -oE '[a-zA-Z0-9_/-]+\.sh' "$doc_file" | sort | uniq >> "$doc_script_refs"
      done < "${TEMP_DIR}/all_docs.txt"
      
      sort "$doc_script_refs" | uniq > "${TEMP_DIR}/doc_script_refs_uniq.txt"
      log "SUCCESS" "Found $(wc -l < "${TEMP_DIR}/doc_script_refs_uniq.txt" 2>/dev/null || echo "0") unique script references in documentation" "$FULL_REPORT_LOG"
    fi
  else
    echo -e "${CYAN}Step 4/7: Skipping documentation analysis...${NC}"
  fi
  
  echo -e "${CYAN}Step 5/7: Checking script references...${NC}"
  # Check script cross-references
  log "INFO" "Checking script cross-references..." "$FULL_REPORT_LOG"
  local all_scripts="${TEMP_DIR}/all_scripts.txt"
  
  if [ ! -f "$all_scripts" ]; then
    log "ERROR" "Script list not found" "$FULL_REPORT_LOG"
    exit 1
  fi
  
  while read -r script; do
    local script_basename=$(basename "$script")
    local script_refs=0
    
    # Check references in Makefile
    if [ -f "${TEMP_DIR}/makefile_script_refs.txt" ] && grep -q "$script_basename" "${TEMP_DIR}/makefile_script_refs.txt"; then
      ((script_refs++))
    fi
    
    # Check references in documentation
    if [ -f "${TEMP_DIR}/doc_script_refs_uniq.txt" ] && grep -q "$script_basename" "${TEMP_DIR}/doc_script_refs_uniq.txt"; then
      ((script_refs++))
    fi
    
    # Check references in other scripts
    if grep -l "$script_basename" "${SCRIPT_FILES[@]}" 2>/dev/null | grep -v "$script" | grep -q .; then
      ((script_refs++))
    fi
    
    # If no references found, log as unused
    if [ "$script_refs" -eq 0 ]; then
      log "WARNING" "Script not referenced: $script" "$UNUSED_SCRIPTS_LOG"
    fi
  done < "$all_scripts"
  
  # Count unused scripts
  local unused_count=$(grep -c "Script not referenced" "$UNUSED_SCRIPTS_LOG" || echo "0")
  log "WARNING" "Unused scripts: $unused_count" "$FULL_REPORT_LOG"
  
  echo "$unused_count" > "${TEMP_DIR}/unused_count.txt"
  
  # Check for documentation inconsistencies
  log "INFO" "Checking documentation consistency..." "$FULL_REPORT_LOG"
  
  # Compare scripts referenced in docs but not existing
  if [ -f "${TEMP_DIR}/doc_script_refs_uniq.txt" ] && [ -f "$all_scripts" ]; then
    while read -r doc_ref; do
      if ! grep -q "$(basename "$doc_ref")" "$all_scripts"; then
        echo "$doc_ref" >> "$TEMP_DIR/docs_nonexistent_scripts.txt"
      fi
    done < "${TEMP_DIR}/doc_script_refs_uniq.txt"
  fi
  
  # Check for important scripts not in documentation
  if [ -f "${TEMP_DIR}/makefile_script_refs.txt" ] && [ -f "${TEMP_DIR}/doc_script_refs_uniq.txt" ]; then
    while read -r make_ref; do
      if ! grep -q "$(basename "$make_ref")" "${TEMP_DIR}/doc_script_refs_uniq.txt"; then
        echo "$make_ref" >> "$TEMP_DIR/undocumented_scripts.txt"
      fi
    done < "${TEMP_DIR}/makefile_script_refs.txt"
  fi
  
  # Log results
  while read -r script; do
    if [ -n "$script" ]; then
      log "WARNING" "Referenced in docs but doesn't exist: $script" "$DOC_INCONSISTENCIES_LOG"
    fi
  done < "$TEMP_DIR/docs_nonexistent_scripts.txt"
  
  while read -r script; do
    if [ -n "$script" ]; then
      log "WARNING" "Important script not documented: $script" "$DOC_INCONSISTENCIES_LOG"
    fi
  done < "$TEMP_DIR/undocumented_scripts.txt"
  
  # Tag scripts based on usage analysis
  tag_scripts
  
  # Generate summary table and reports
  generate_summary_table
  generate_json_report
  
  # Display final summary
  local script_count=${#SCRIPT_FILES[@]}
  local unused_count=${#NOT_USED_SCRIPTS[@]}
  local used_percent=$(( (script_count - unused_count) * 100 / script_count ))
  
  echo -e "\n${BOLD}${GREEN}Script Analysis Complete!${NC}"
  echo -e "${BOLD}Usage Stats:${NC} $script_count total scripts, $used_percent% utilized"
  
  echo -e "\n${BOLD}Detailed reports available at:${NC}"
  echo -e "  ${YELLOW}Usage Summary:${NC} ${AUDIT_LOG_DIR}/usage_summary.txt"
  echo -e "  ${YELLOW}Full Report:${NC} $FULL_REPORT_LOG"
  echo -e "  ${YELLOW}Unused Scripts:${NC} $UNUSED_SCRIPTS_LOG"
  echo -e "  ${YELLOW}Documentation Issues:${NC} $DOC_INCONSISTENCIES_LOG"
  echo -e "  ${YELLOW}Dynamic Script References:${NC} $DYNAMIC_REFS_LOG"
  if [ "$JSON_OUTPUT" = true ]; then
    echo -e "  ${YELLOW}JSON Report:${NC} ${AUDIT_LOG_DIR}/script_usage_report.json"
  fi
  
  # Log report paths
  echo "" >> "$FULL_REPORT_LOG"
  echo "REPORT LOCATIONS:" >> "$FULL_REPORT_LOG"
  echo "  Usage Summary: ${AUDIT_LOG_DIR}/usage_summary.txt" >> "$FULL_REPORT_LOG"
  echo "  Full Report: $FULL_REPORT_LOG" >> "$FULL_REPORT_LOG"
  echo "  Unused Scripts: $UNUSED_SCRIPTS_LOG" >> "$FULL_REPORT_LOG"
  echo "  Documentation Issues: $DOC_INCONSISTENCIES_LOG" >> "$FULL_REPORT_LOG"
  echo "  Dynamic Script References: $DYNAMIC_REFS_LOG" >> "$FULL_REPORT_LOG"
  if [ "$JSON_OUTPUT" = true ]; then
    echo "  JSON Report: ${AUDIT_LOG_DIR}/script_usage_report.json" >> "$FULL_REPORT_LOG"
  fi
  
  # Cleanup temporary files
  if [ "$VERBOSE" = false ]; then
    rm -rf "$TEMP_DIR"
  else
    log "INFO" "Temporary files preserved at $TEMP_DIR" "$FULL_REPORT_LOG"
  fi
  
  echo -e "\n${GREEN}Script usage analysis completed.${NC}"
}

# Run main function
main
