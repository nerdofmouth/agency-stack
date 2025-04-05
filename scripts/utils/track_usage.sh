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
ORPHANED_DEPS_LOG="${AUDIT_LOG_DIR}/orphaned_dependencies.log"
INCONSISTENT_DOCS_LOG="${AUDIT_LOG_DIR}/inconsistent_docs.log"
FULL_REPORT_LOG="${AUDIT_LOG_DIR}/audit_report.log"
TEMP_DIR="/tmp/agency_stack_audit"
VERBOSE=false
ANALYZE_DOCS=true
ANALYZE_MAKEFILES=true
ANALYZE_INTEGRATIONS=true
EXCLUDE_PATTERNS=()
INCLUDE_DIRS=()
MAX_DEPTH=5
OUTPUT_FORMAT="text" # text, json, csv
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")

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
  echo -e "  ${BOLD}--exclude${NC} <pattern>       Exclude files matching pattern (can be used multiple times)"
  echo -e "  ${BOLD}--max-depth${NC} <number>      Maximum directory depth to analyze (default: 5)"
  echo -e "  ${BOLD}--output${NC} <format>         Output format: text, json, csv (default: text)"
  echo -e "  ${BOLD}--skip-docs${NC}               Skip documentation analysis"
  echo -e "  ${BOLD}--skip-makefiles${NC}          Skip Makefile analysis"
  echo -e "  ${BOLD}--skip-integrations${NC}       Skip integration script analysis"
  echo -e "  ${BOLD}--verbose${NC}                 Show detailed output"
  echo -e "  ${BOLD}--help${NC}                    Show this help message and exit"
  echo -e ""
  echo -e "${CYAN}Examples:${NC}"
  echo -e "  $0 --target-dir /scripts/components"
  echo -e "  $0 --verbose --exclude '*.bak' --exclude '*.template'"
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
  : > "${ORPHANED_DEPS_LOG}"
  : > "${INCONSISTENT_DOCS_LOG}"
  : > "${FULL_REPORT_LOG}"
  
  # Add headers to logs
  echo "# AgencyStack Unused Scripts Report - Generated on $(date)" > "${UNUSED_SCRIPTS_LOG}"
  echo "# AgencyStack Orphaned Dependencies Report - Generated on $(date)" > "${ORPHANED_DEPS_LOG}"
  echo "# AgencyStack Documentation Inconsistencies - Generated on $(date)" > "${INCONSISTENT_DOCS_LOG}"
  echo "# AgencyStack Full Audit Report - Generated on $(date)" > "${FULL_REPORT_LOG}"
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
  
  echo -e "${color}[$level] $message${NC}"
  echo "[$level] $message" >> "$logfile"
}

# Find all scripts in the target directories
find_scripts() {
  log "INFO" "Finding all script files..." "$FULL_REPORT_LOG"
  
  if [ ${#INCLUDE_DIRS[@]} -eq 0 ]; then
    # Default script directories if none specified
    INCLUDE_DIRS=(
      "${ROOT_DIR}/scripts"
      "${ROOT_DIR}/scripts/components"
      "${ROOT_DIR}/scripts/utils"
      "${ROOT_DIR}/scripts/admin"
      "${ROOT_DIR}/scripts/core"
      "${ROOT_DIR}/scripts/security"
      "${ROOT_DIR}/scripts/integration"
    )
  fi
  
  local exclude_args=()
  for pattern in "${EXCLUDE_PATTERNS[@]}"; do
    exclude_args+=(-not -path "*$pattern*")
  done
  
  local script_count=0
  local script_list="${TEMP_DIR}/all_scripts.txt"
  : > "$script_list"
  
  for dir in "${INCLUDE_DIRS[@]}"; do
    if [ -d "$dir" ]; then
      log "INFO" "Scanning directory: $dir" "$FULL_REPORT_LOG"
      
      # Find all shell scripts
      find "$dir" -maxdepth "$MAX_DEPTH" -type f -name "*.sh" "${exclude_args[@]}" 2>/dev/null | while read -r script; do
        echo "$script" >> "$script_list"
        ((script_count++))
      done
    else
      log "WARNING" "Directory not found: $dir" "$FULL_REPORT_LOG"
    fi
  done
  
  log "SUCCESS" "Found $script_count script files" "$FULL_REPORT_LOG"
  echo "$script_count" > "${TEMP_DIR}/script_count.txt"
}

# Analyze Makefile targets and references
analyze_makefiles() {
  if [ "$ANALYZE_MAKEFILES" = false ]; then
    log "INFO" "Skipping Makefile analysis" "$FULL_REPORT_LOG"
    return
  fi
  
  log "INFO" "Analyzing Makefile targets and references..." "$FULL_REPORT_LOG"
  local makefile="${ROOT_DIR}/Makefile"
  
  if [ ! -f "$makefile" ]; then
    log "WARNING" "Makefile not found at $makefile" "$FULL_REPORT_LOG"
    return
  fi
  
  # Extract all targets from Makefile
  grep -E '^[a-zA-Z0-9_-]+:' "$makefile" | sed 's/:.*//' > "${TEMP_DIR}/makefile_targets.txt"
  
  # Extract all script references from Makefile
  grep -E '\.sh' "$makefile" | grep -oE '[a-zA-Z0-9_/-]+\.sh' | sort | uniq > "${TEMP_DIR}/makefile_script_refs.txt"
  
  log "SUCCESS" "Found $(wc -l < "${TEMP_DIR}/makefile_targets.txt") Makefile targets" "$FULL_REPORT_LOG"
  log "SUCCESS" "Found $(wc -l < "${TEMP_DIR}/makefile_script_refs.txt") script references in Makefile" "$FULL_REPORT_LOG"
}

# Analyze integration scripts
analyze_integrations() {
  if [ "$ANALYZE_INTEGRATIONS" = false ]; then
    log "INFO" "Skipping integration script analysis" "$FULL_REPORT_LOG"
    return
  fi
  
  log "INFO" "Analyzing integration scripts..." "$FULL_REPORT_LOG"
  
  # Look for component registry
  local comp_registry="${CONFIG_DIR}/installed_components.txt"
  if [ -f "$comp_registry" ]; then
    log "INFO" "Found component registry at $comp_registry" "$FULL_REPORT_LOG"
    cp "$comp_registry" "${TEMP_DIR}/installed_components.txt"
  else
    log "WARNING" "Component registry not found at $comp_registry" "$FULL_REPORT_LOG"
  fi
  
  # Find integration scripts
  find "${ROOT_DIR}" -type f -name "integrate_*.sh" | while read -r integ_script; do
    log "INFO" "Analyzing integration script: $integ_script" "$FULL_REPORT_LOG"
    
    # Extract component references from integration scripts
    grep -E 'component|--component' "$integ_script" > "${TEMP_DIR}/$(basename "$integ_script").refs"
  done
  
  # Analyze installation scripts
  find "${ROOT_DIR}" -type f -name "install.sh" -o -name "install_all.sh" | while read -r install_script; do
    log "INFO" "Analyzing installation script: $install_script" "$FULL_REPORT_LOG"
    
    # Extract component references from installation scripts
    grep -E 'install_|\.sh' "$install_script" > "${TEMP_DIR}/$(basename "$install_script").refs"
  done
}

# Analyze documentation for script references
analyze_docs() {
  if [ "$ANALYZE_DOCS" = false ]; then
    log "INFO" "Skipping documentation analysis" "$FULL_REPORT_LOG"
    return
  fi
  
  log "INFO" "Analyzing documentation for script references..." "$FULL_REPORT_LOG"
  local docs_dir="${ROOT_DIR}/docs"
  
  if [ ! -d "$docs_dir" ]; then
    log "WARNING" "Documentation directory not found at $docs_dir" "$FULL_REPORT_LOG"
    return
  fi
  
  # Find all markdown files
  find "$docs_dir" -type f -name "*.md" > "${TEMP_DIR}/all_docs.txt"
  log "INFO" "Found $(wc -l < "${TEMP_DIR}/all_docs.txt") documentation files" "$FULL_REPORT_LOG"
  
  # Extract script references from documentation
  local doc_script_refs="${TEMP_DIR}/doc_script_refs.txt"
  : > "$doc_script_refs"
  
  while read -r doc_file; do
    grep -oE '[a-zA-Z0-9_/-]+\.sh' "$doc_file" | sort | uniq >> "$doc_script_refs"
  done < "${TEMP_DIR}/all_docs.txt"
  
  sort "$doc_script_refs" | uniq > "${TEMP_DIR}/doc_script_refs_uniq.txt"
  log "SUCCESS" "Found $(wc -l < "${TEMP_DIR}/doc_script_refs_uniq.txt") unique script references in documentation" "$FULL_REPORT_LOG"
}

# Check script cross-references
check_script_references() {
  log "INFO" "Checking script cross-references..." "$FULL_REPORT_LOG"
  local all_scripts="${TEMP_DIR}/all_scripts.txt"
  local ref_count=0
  local unused_count=0
  
  # Create a file to track all references
  local all_refs="${TEMP_DIR}/all_references.txt"
  : > "$all_refs"
  
  # Compile all references from various sources
  if [ -f "${TEMP_DIR}/makefile_script_refs.txt" ]; then
    cat "${TEMP_DIR}/makefile_script_refs.txt" >> "$all_refs"
  fi
  
  if [ -f "${TEMP_DIR}/doc_script_refs_uniq.txt" ]; then
    cat "${TEMP_DIR}/doc_script_refs_uniq.txt" >> "$all_refs"
  fi
  
  # Get all references from all scripts
  while read -r script; do
    # Create file to temporarily store references
    local temp_refs="${TEMP_DIR}/$(basename "$script").refs"
    
    # Find references to other scripts
    grep -o '[a-zA-Z0-9_/-]\+\.sh' "$script" | sort | uniq > "$temp_refs"
    cat "$temp_refs" >> "$all_refs"
  done < "$all_scripts"
  
  # Deduplicate all references
  sort "$all_refs" | uniq > "${TEMP_DIR}/all_references_uniq.txt"
  ref_count=$(wc -l < "${TEMP_DIR}/all_references_uniq.txt")
  
  # Check each script for usage
  while read -r script; do
    local script_name=$(basename "$script")
    local script_dir=$(dirname "$script")
    local relative_path="${script#$ROOT_DIR/}"
    
    # Count references to this script
    local usage_count=$(grep -c "$script_name" "${TEMP_DIR}/all_references_uniq.txt" || echo "0")
    
    if [ "$usage_count" -eq 0 ]; then
      log "WARNING" "Script not referenced: $relative_path" "$UNUSED_SCRIPTS_LOG"
      if [ "$VERBOSE" = true ]; then
        log "WARNING" "Script not referenced: $relative_path" "$FULL_REPORT_LOG"
      fi
      ((unused_count++))
    else
      if [ "$VERBOSE" = true ]; then
        log "SUCCESS" "Script referenced $usage_count times: $relative_path" "$FULL_REPORT_LOG"
      fi
    fi
  done < "$all_scripts"
  
  # Generate statistics
  log "INFO" "Total scripts: $(wc -l < "$all_scripts")" "$FULL_REPORT_LOG"
  log "INFO" "Total references: $ref_count" "$FULL_REPORT_LOG"
  log "WARNING" "Unused scripts: $unused_count" "$FULL_REPORT_LOG"
  
  echo "$unused_count" > "${TEMP_DIR}/unused_count.txt"
}

# Check for documentation inconsistencies
check_doc_consistency() {
  if [ "$ANALYZE_DOCS" = false ]; then
    return
  fi
  
  log "INFO" "Checking documentation consistency..." "$FULL_REPORT_LOG"
  
  # Compare scripts referenced in docs but not existing
  comm -13 <(sort "$TEMP_DIR/all_scripts.txt" | xargs -n1 basename | sort) <(sort "$TEMP_DIR/doc_script_refs_uniq.txt") > "$TEMP_DIR/docs_nonexistent_scripts.txt"
  
  # Check for key scripts not documented
  local important_scripts="${TEMP_DIR}/important_scripts.txt"
  : > "$important_scripts"
  
  # Add component installation scripts to important list
  find "${ROOT_DIR}/scripts/components" -type f -name "install_*.sh" | xargs -n1 basename >> "$important_scripts"
  
  # Add other key scripts
  echo "install.sh" >> "$important_scripts"
  echo "integrate_components.sh" >> "$important_scripts"
  
  # Find important scripts that aren't documented
  comm -23 <(sort "$important_scripts") <(sort "$TEMP_DIR/doc_script_refs_uniq.txt") > "$TEMP_DIR/undocumented_scripts.txt"
  
  # Log results
  while read -r script; do
    if [ -n "$script" ]; then
      log "WARNING" "Referenced in docs but doesn't exist: $script" "$INCONSISTENT_DOCS_LOG"
    fi
  done < "$TEMP_DIR/docs_nonexistent_scripts.txt"
  
  while read -r script; do
    if [ -n "$script" ]; then
      log "WARNING" "Important script not documented: $script" "$INCONSISTENT_DOCS_LOG"
    fi
  done < "$TEMP_DIR/undocumented_scripts.txt"
}

# Generate summary report
generate_summary() {
  local script_count=$(cat "${TEMP_DIR}/script_count.txt")
  local unused_count=$(cat "${TEMP_DIR}/unused_count.txt")
  local used_percent=$((100 - (unused_count * 100 / script_count)))
  
  echo -e "\n${BOLD}${MAGENTA}AgencyStack Script Usage Summary${NC}"
  echo -e "${BOLD}==================================${NC}"
  echo -e "${BOLD}Total scripts analyzed:${NC} $script_count"
  echo -e "${BOLD}Scripts in use:${NC} $((script_count - unused_count)) ($used_percent%)"
  echo -e "${BOLD}Unused scripts:${NC} $unused_count ($((100 - used_percent))%)"
  
  # Generate the same summary in the log
  echo "" >> "$FULL_REPORT_LOG"
  echo "AgencyStack Script Usage Summary" >> "$FULL_REPORT_LOG"
  echo "==================================" >> "$FULL_REPORT_LOG"
  echo "Total scripts analyzed: $script_count" >> "$FULL_REPORT_LOG"
  echo "Scripts in use: $((script_count - unused_count)) ($used_percent%)" >> "$FULL_REPORT_LOG"
  echo "Unused scripts: $unused_count ($((100 - used_percent))%)" >> "$FULL_REPORT_LOG"
  
  # Generate report paths
  echo -e "\n${BOLD}Detailed reports available at:${NC}"
  echo -e "  ${YELLOW}Full Report:${NC} $FULL_REPORT_LOG"
  echo -e "  ${YELLOW}Unused Scripts:${NC} $UNUSED_SCRIPTS_LOG"
  echo -e "  ${YELLOW}Documentation Issues:${NC} $INCONSISTENT_DOCS_LOG"
  
  # Log report paths
  echo "" >> "$FULL_REPORT_LOG"
  echo "Detailed reports available at:" >> "$FULL_REPORT_LOG"
  echo "  Full Report: $FULL_REPORT_LOG" >> "$FULL_REPORT_LOG"
  echo "  Unused Scripts: $UNUSED_SCRIPTS_LOG" >> "$FULL_REPORT_LOG"
  echo "  Documentation Issues: $INCONSISTENT_DOCS_LOG" >> "$FULL_REPORT_LOG"
}

# Cleanup temporary files
cleanup() {
  if [ "$VERBOSE" = false ]; then
    rm -rf "$TEMP_DIR"
  else
    log "INFO" "Temporary files preserved at: $TEMP_DIR" "$FULL_REPORT_LOG"
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
    --exclude)
      EXCLUDE_PATTERNS+=("$2")
      shift
      shift
      ;;
    --max-depth)
      MAX_DEPTH="$2"
      shift
      shift
      ;;
    --output)
      OUTPUT_FORMAT="$2"
      shift
      shift
      ;;
    --skip-docs)
      ANALYZE_DOCS=false
      shift
      ;;
    --skip-makefiles)
      ANALYZE_MAKEFILES=false
      shift
      ;;
    --skip-integrations)
      ANALYZE_INTEGRATIONS=false
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
      echo -e "Use --help for usage information"
      exit 1
      ;;
  esac
done

# Main execution
main() {
  echo -e "${BOLD}${MAGENTA}AgencyStack Script Usage Tracker${NC}"
  echo -e "${BOLD}-----------------------------${NC}"
  
  setup_environment
  find_scripts
  analyze_makefiles
  analyze_integrations
  analyze_docs
  check_script_references
  check_doc_consistency
  generate_summary
  cleanup
  
  echo -e "\n${GREEN}Script usage analysis completed.${NC}"
}

# Run main function
main
