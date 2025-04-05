#!/bin/bash
# audit_and_cleanup.sh - AgencyStack Repository Audit and Cleanup Utility
# [https://stack.nerdofmouth.com](https://stack.nerdofmouth.com)
#
# Orchestrates scanning, auditing, and cleaning of unused or stale resources
# Includes scripts, Makefile targets, ports, directories, logs, etc.
#
# Author: AgencyStack Team
# Version: 1.0.0
# Created: $(date +%Y-%m-%d)

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
CLEANUP_LOG="${AUDIT_LOG_DIR}/cleanup_$(date +%Y%m%d_%H%M%S).log"
TEMP_DIR="/tmp/agency_stack_audit"
DRY_RUN=true
FORCE=false
VERBOSE=false
SKIP_TRACKING=false
SKIP_CLEANUP=false
SKIP_REPORT=false
MAX_LOGS_DAYS=30
MAX_UNUSED_DAYS=180
SCAN_UNUSED_PORTS=true
GIT_AWARE=true
QUIET=false
SKIP_CONFIRM=false
COMPONENT_EXCLUSIONS=()
CLEANUP_ITEMS=()
EMAIL_REPORT=false
EMAIL_TO=""
AUDIT_DIRS=()

# Usage Information
show_help() {
  echo -e "${MAGENTA}${BOLD}AgencyStack Repository Audit and Cleanup Utility${NC}"
  echo -e "====================================================="
  echo -e "Analyzes and cleans up unused, stale, or deprecated files and resources."
  echo -e ""
  echo -e "${CYAN}Usage:${NC}"
  echo -e "  $0 [options]"
  echo -e ""
  echo -e "${CYAN}Options:${NC}"
  echo -e "  ${BOLD}--clean${NC}                      Perform actual cleanup (default: dry-run)"
  echo -e "  ${BOLD}--force${NC}                      Skip confirmation prompts for cleanup operations"
  echo -e "  ${BOLD}--skip-tracking${NC}              Skip script usage tracking phase"
  echo -e "  ${BOLD}--skip-cleanup${NC}               Skip cleanup phase, only generate reports"
  echo -e "  ${BOLD}--skip-report${NC}                Skip report generation"
  echo -e "  ${BOLD}--scan-dir${NC} <dir>             Additional directory to scan (can be used multiple times)"
  echo -e "  ${BOLD}--exclude-component${NC} <name>   Component to exclude from cleanup (can be used multiple times)"
  echo -e "  ${BOLD}--max-log-days${NC} <days>        Maximum age of logs to keep (default: 30)"
  echo -e "  ${BOLD}--max-unused-days${NC} <days>     Only clean up unused scripts older than this (default: 180)"
  echo -e "  ${BOLD}--no-port-scan${NC}               Skip unused port scanning"
  echo -e "  ${BOLD}--no-git${NC}                     Disable Git-aware features"
  echo -e "  ${BOLD}--quiet${NC}                      Minimal output, useful for cron jobs"
  echo -e "  ${BOLD}--email-report${NC} <address>     Email address to send report to"
  echo -e "  ${BOLD}--verbose${NC}                    Show detailed output"
  echo -e "  ${BOLD}--help${NC}                       Show this help message and exit"
  echo -e ""
  echo -e "${CYAN}Examples:${NC}"
  echo -e "  $0 --scan-dir /path/to/custom/scripts"
  echo -e "  $0 --clean --max-log-days 60"
  echo -e "  $0 --skip-tracking --clean --force"
  echo -e ""
  echo -e "${CYAN}Note:${NC}"
  echo -e "  By default, this tool runs in dry-run mode and will not modify any files."
  echo -e "  Use --clean to perform actual cleanup operations."
  exit 0
}

# Create log directories if they don't exist
setup_environment() {
  mkdir -p "$AUDIT_LOG_DIR"
  mkdir -p "$TEMP_DIR"
  
  # Create empty log file
  : > "${CLEANUP_LOG}"
  
  # Add header to log
  echo "# AgencyStack Repository Cleanup Log - Generated on $(date)" > "${CLEANUP_LOG}"
  echo "# Mode: $([ "$DRY_RUN" = true ] && echo "DRY-RUN" || echo "ACTUAL CLEANUP")" >> "${CLEANUP_LOG}"
  echo "# Command: $0 $*" >> "${CLEANUP_LOG}"
  echo "" >> "${CLEANUP_LOG}"
}

# Log message to both stdout and logfile
log() {
  local level="$1"
  local message="$2"
  local color=""
  
  case "$level" in
    "INFO") color="$BLUE" ;;
    "SUCCESS") color="$GREEN" ;;
    "WARNING") color="$YELLOW" ;;
    "ERROR") color="$RED" ;;
    "ACTION") color="$CYAN" ;;
    *) color="$NC" ;;
  esac
  
  if [ "$QUIET" = false ] || [ "$level" = "ERROR" ]; then
    echo -e "${color}[$level] $message${NC}"
  fi
  
  echo "[$level] $message" >> "${CLEANUP_LOG}"
}

# Run the track_usage.sh script to identify unused scripts
run_script_tracking() {
  if [ "$SKIP_TRACKING" = true ]; then
    log "INFO" "Skipping script usage tracking phase" "${CLEANUP_LOG}"
    return 0
  fi
  
  log "INFO" "Running script usage tracking..." "${CLEANUP_LOG}"
  
  local track_script="${SCRIPT_DIR}/track_usage.sh"
  if [ ! -f "$track_script" ]; then
    log "ERROR" "Script tracking tool not found at $track_script" "${CLEANUP_LOG}"
    exit 1
  fi
  
  local track_args=()
  
  # Add scan directories if specified
  for dir in "${AUDIT_DIRS[@]}"; do
    track_args+=(--include-dir "$dir")
  done
  
  # Add verbose flag if needed
  if [ "$VERBOSE" = true ]; then
    track_args+=(--verbose)
  fi
  
  # Run the track_usage.sh script
  log "INFO" "Executing: $track_script ${track_args[*]}" "${CLEANUP_LOG}"
  "$track_script" "${track_args[@]}" | tee -a "${CLEANUP_LOG}"
  
  # Check if unused scripts were found
  if [ -f "${AUDIT_LOG_DIR}/unused_scripts.log" ]; then
    local unused_count=$(grep -c "Script not referenced" "${AUDIT_LOG_DIR}/unused_scripts.log" || echo "0")
    log "INFO" "Found $unused_count unused scripts" "${CLEANUP_LOG}"
    
    # Add unused scripts to cleanup items if older than threshold
    if [ "$unused_count" -gt 0 ]; then
      log "INFO" "Checking age of unused scripts..." "${CLEANUP_LOG}"
      
      # Extract script paths from unused_scripts.log
      grep "Script not referenced:" "${AUDIT_LOG_DIR}/unused_scripts.log" | sed 's/\[WARNING\] Script not referenced: //' > "${TEMP_DIR}/unused_scripts_paths.txt"
      
      while read -r script_path; do
        local full_path="${ROOT_DIR}/${script_path}"
        
        # Skip if file doesn't exist
        if [ ! -f "$full_path" ]; then
          continue
        fi
        
        # Check file age
        local file_age_days=$((($(date +%s) - $(stat -c %Y "$full_path")) / 86400))
        
        if [ "$file_age_days" -gt "$MAX_UNUSED_DAYS" ]; then
          log "WARNING" "Unused script older than $MAX_UNUSED_DAYS days: $script_path (age: $file_age_days days)" "${CLEANUP_LOG}"
          CLEANUP_ITEMS+=("$full_path")
        fi
      done < "${TEMP_DIR}/unused_scripts_paths.txt"
    fi
  else
    log "WARNING" "No unused scripts log found at ${AUDIT_LOG_DIR}/unused_scripts.log" "${CLEANUP_LOG}"
  fi
  
  log "SUCCESS" "Script usage tracking completed" "${CLEANUP_LOG}"
}

# Scan for old log files
scan_old_logs() {
  log "INFO" "Scanning for old log files..." "${CLEANUP_LOG}"
  
  # Get current date in seconds since epoch
  local now=$(date +%s)
  
  # Find log files older than MAX_LOGS_DAYS
  find "${LOG_DIR}" -type f -name "*.log" | while read -r log_file; do
    local file_mtime=$(stat -c %Y "$log_file")
    local file_age_days=$(( (now - file_mtime) / 86400 ))
    
    if [ "$file_age_days" -gt "$MAX_LOGS_DAYS" ]; then
      log "INFO" "Old log file: $log_file (age: $file_age_days days)" "${CLEANUP_LOG}"
      CLEANUP_ITEMS+=("$log_file")
    fi
  done
}

# Scan for unused ports
scan_unused_ports() {
  if [ "$SCAN_UNUSED_PORTS" = false ]; then
    log "INFO" "Skipping unused port scanning" "${CLEANUP_LOG}"
    return 0
  fi
  
  log "INFO" "Scanning for unused ports..." "${CLEANUP_LOG}"
  
  local port_util="${SCRIPT_DIR}/port_conflict_detector.sh"
  if [ -f "$port_util" ]; then
    log "INFO" "Running port conflict detector..." "${CLEANUP_LOG}"
    "$port_util" --report-unused | tee -a "${CLEANUP_LOG}"
  else
    log "WARNING" "Port utility not found at $port_util" "${CLEANUP_LOG}"
    
    # Simple fallback - scan all docker-compose files for port mappings
    log "INFO" "Fallback: Scanning docker-compose files for port mappings..." "${CLEANUP_LOG}"
    
    find "${ROOT_DIR}" -name "docker-compose*.yml" | while read -r compose_file; do
      log "INFO" "Scanning ports in $compose_file" "${CLEANUP_LOG}"
      grep -E 'ports:|-\s*"[0-9]+:[0-9]+"' "$compose_file" >> "${TEMP_DIR}/port_mappings.txt"
    done
  fi
}

# Scan for Git-modified unused files
scan_git_modified() {
  if [ "$GIT_AWARE" = false ]; then
    log "INFO" "Skipping Git-aware scanning" "${CLEANUP_LOG}"
    return 0
  fi
  
  if ! command -v git &> /dev/null; then
    log "WARNING" "Git not found, skipping Git-aware scanning" "${CLEANUP_LOG}"
    return 0
  fi
  
  # Check if we're in a git repository
  if ! git -C "${ROOT_DIR}" rev-parse --is-inside-work-tree &> /dev/null; then
    log "WARNING" "Not a Git repository, skipping Git-aware scanning" "${CLEANUP_LOG}"
    return 0
  fi
  
  log "INFO" "Scanning for Git-modified unused files..." "${CLEANUP_LOG}"
  
  # Get a list of modified files
  git -C "${ROOT_DIR}" diff --name-only | grep -E '\.sh$' > "${TEMP_DIR}/git_modified.txt"
  
  # Check if these modified files are also unused
  if [ -f "${AUDIT_LOG_DIR}/unused_scripts.log" ]; then
    while read -r modified_file; do
      local rel_path="${modified_file#${ROOT_DIR}/}"
      if grep -q "$rel_path" "${AUDIT_LOG_DIR}/unused_scripts.log"; then
        log "WARNING" "Git-modified unused file: $modified_file" "${CLEANUP_LOG}"
      fi
    done < "${TEMP_DIR}/git_modified.txt"
  fi
}

# Perform cleanup operations
perform_cleanup() {
  if [ "$SKIP_CLEANUP" = true ]; then
    log "INFO" "Skipping cleanup phase" "${CLEANUP_LOG}"
    return 0
  fi
  
  if [ ${#CLEANUP_ITEMS[@]} -eq 0 ]; then
    log "SUCCESS" "No items to clean up" "${CLEANUP_LOG}"
    return 0
  fi
  
  log "INFO" "Preparing to clean up ${#CLEANUP_ITEMS[@]} items..." "${CLEANUP_LOG}"
  
  # If not in dry-run mode, confirm before proceeding
  if [ "$DRY_RUN" = false ] && [ "$FORCE" = false ] && [ "$SKIP_CONFIRM" = false ]; then
    echo -e "\n${YELLOW}${BOLD}WARNING: You are about to delete ${#CLEANUP_ITEMS[@]} items.${NC}"
    echo -e "${YELLOW}This action cannot be undone.${NC}"
    echo -e "Continue? (y/N): "
    read -r confirm
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
      log "INFO" "Cleanup aborted by user" "${CLEANUP_LOG}"
      return 0
    fi
  fi
  
  # Process each cleanup item
  for item in "${CLEANUP_ITEMS[@]}"; do
    # Skip excluded components
    local basename=$(basename "$item")
    local skip=false
    
    for excluded in "${COMPONENT_EXCLUSIONS[@]}"; do
      if [[ "$basename" == *"$excluded"* ]]; then
        log "INFO" "Skipping excluded component: $item" "${CLEANUP_LOG}"
        skip=true
        break
      fi
    done
    
    if [ "$skip" = true ]; then
      continue
    fi
    
    # Create backup if not in dry-run mode
    if [ "$DRY_RUN" = false ]; then
      local backup_dir="${AUDIT_LOG_DIR}/backups/$(date +%Y%m%d)"
      mkdir -p "$backup_dir"
      
      log "ACTION" "Creating backup of $item" "${CLEANUP_LOG}"
      cp -a "$item" "${backup_dir}/"
      
      # Perform the cleanup
      log "ACTION" "Removing: $item" "${CLEANUP_LOG}"
      rm -f "$item"
    else
      log "ACTION" "[DRY-RUN] Would remove: $item" "${CLEANUP_LOG}"
    fi
  done
  
  if [ "$DRY_RUN" = true ]; then
    log "SUCCESS" "Dry run completed. Use --clean to perform actual cleanup" "${CLEANUP_LOG}"
  else
    log "SUCCESS" "Cleanup completed. Removed ${#CLEANUP_ITEMS[@]} items" "${CLEANUP_LOG}"
  fi
}

# Generate summary report
generate_report() {
  if [ "$SKIP_REPORT" = true ]; then
    log "INFO" "Skipping report generation" "${CLEANUP_LOG}"
    return 0
  fi
  
  log "INFO" "Generating summary report..." "${CLEANUP_LOG}"
  
  local report_file="${AUDIT_LOG_DIR}/summary_$(date +%Y%m%d).txt"
  : > "$report_file"
  
  # Report header
  cat << EOF > "$report_file"
=============================================
AgencyStack Repository Audit Summary Report
=============================================
Generated: $(date)
Mode: $([ "$DRY_RUN" = true ] && echo "DRY-RUN" || echo "ACTUAL CLEANUP")

SUMMARY
-------
EOF
  
  # Add script usage statistics
  if [ -f "${TEMP_DIR}/script_count.txt" ] && [ -f "${TEMP_DIR}/unused_count.txt" ]; then
    local script_count=$(cat "${TEMP_DIR}/script_count.txt")
    local unused_count=$(cat "${TEMP_DIR}/unused_count.txt")
    local used_percent=$((100 - (unused_count * 100 / script_count)))
    
    cat << EOF >> "$report_file"
Scripts:
  - Total scripts: $script_count
  - Used scripts: $((script_count - unused_count)) ($used_percent%)
  - Unused scripts: $unused_count ($((100 - used_percent))%)
EOF
  fi
  
  # Add cleanup statistics
  cat << EOF >> "$report_file"

Cleanup:
  - Total items flagged: ${#CLEANUP_ITEMS[@]}
  - Items cleaned: $([ "$DRY_RUN" = true ] && echo "0 (dry run)" || echo "${#CLEANUP_ITEMS[@]}")
EOF
  
  # Add detailed lists
  cat << EOF >> "$report_file"

DETAILED FINDINGS
----------------
EOF
  
  # Add unused scripts
  if [ -f "${AUDIT_LOG_DIR}/unused_scripts.log" ]; then
    cat << EOF >> "$report_file"
Unused Scripts:
$(grep "Script not referenced" "${AUDIT_LOG_DIR}/unused_scripts.log" | sed 's/\[WARNING\] //')

EOF
  fi
  
  # Add documentation inconsistencies
  if [ -f "${AUDIT_LOG_DIR}/inconsistent_docs.log" ]; then
    cat << EOF >> "$report_file"
Documentation Inconsistencies:
$(grep -v "^#" "${AUDIT_LOG_DIR}/inconsistent_docs.log" | sed 's/\[WARNING\] //')

EOF
  fi
  
  # Add cleanup items
  cat << EOF >> "$report_file"
Items $([ "$DRY_RUN" = true ] && echo "flagged for cleanup" || echo "cleaned up"):
EOF
  
  for item in "${CLEANUP_ITEMS[@]}"; do
    echo "  - $item" >> "$report_file"
  done
  
  log "SUCCESS" "Summary report generated: $report_file" "${CLEANUP_LOG}"
  
  # Email report if requested
  if [ "$EMAIL_REPORT" = true ] && [ -n "$EMAIL_TO" ]; then
    if command -v mail &> /dev/null; then
      log "INFO" "Emailing report to $EMAIL_TO" "${CLEANUP_LOG}"
      mail -s "AgencyStack Repository Audit Report - $(date +%Y-%m-%d)" "$EMAIL_TO" < "$report_file"
    else
      log "WARNING" "mail command not found, cannot send email report" "${CLEANUP_LOG}"
    fi
  fi
  
  # Display report summary to console
  if [ "$QUIET" = false ]; then
    echo -e "\n${BOLD}${MAGENTA}AgencyStack Repository Audit Summary${NC}"
    echo -e "${BOLD}=====================================${NC}"
    
    if [ -f "${TEMP_DIR}/script_count.txt" ] && [ -f "${TEMP_DIR}/unused_count.txt" ]; then
      local script_count=$(cat "${TEMP_DIR}/script_count.txt")
      local unused_count=$(cat "${TEMP_DIR}/unused_count.txt")
      local used_percent=$((100 - (unused_count * 100 / script_count)))
      
      echo -e "${BOLD}Scripts:${NC}"
      echo -e "  Total: $script_count"
      echo -e "  Used: $((script_count - unused_count)) ($used_percent%)"
      echo -e "  Unused: $unused_count ($((100 - used_percent))%)"
    fi
    
    echo -e "\n${BOLD}Cleanup:${NC}"
    echo -e "  Items flagged: ${#CLEANUP_ITEMS[@]}"
    echo -e "  Cleanup mode: $([ "$DRY_RUN" = true ] && echo "${YELLOW}DRY-RUN${NC}" || echo "${GREEN}ACTUAL CLEANUP${NC}")"
    
    echo -e "\n${BOLD}Report:${NC} $report_file"
  fi
}

# Cleanup temporary files
cleanup() {
  if [ "$VERBOSE" = false ]; then
    rm -rf "$TEMP_DIR"
  else
    log "INFO" "Temporary files preserved at: $TEMP_DIR" "${CLEANUP_LOG}"
  fi
}

# Process command line arguments
process_args() {
  while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
      --clean)
        DRY_RUN=false
        shift
        ;;
      --force)
        FORCE=true
        shift
        ;;
      --skip-tracking)
        SKIP_TRACKING=true
        shift
        ;;
      --skip-cleanup)
        SKIP_CLEANUP=true
        shift
        ;;
      --skip-report)
        SKIP_REPORT=true
        shift
        ;;
      --scan-dir)
        AUDIT_DIRS+=("$2")
        shift
        shift
        ;;
      --exclude-component)
        COMPONENT_EXCLUSIONS+=("$2")
        shift
        shift
        ;;
      --max-log-days)
        MAX_LOGS_DAYS="$2"
        shift
        shift
        ;;
      --max-unused-days)
        MAX_UNUSED_DAYS="$2"
        shift
        shift
        ;;
      --no-port-scan)
        SCAN_UNUSED_PORTS=false
        shift
        ;;
      --no-git)
        GIT_AWARE=false
        shift
        ;;
      --quiet)
        QUIET=true
        shift
        ;;
      --email-report)
        EMAIL_REPORT=true
        EMAIL_TO="$2"
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
        echo -e "Use --help for usage information"
        exit 1
        ;;
    esac
  done
}

# Main execution
main() {
  echo -e "${BOLD}${MAGENTA}AgencyStack Repository Audit and Cleanup${NC}"
  echo -e "${BOLD}---------------------------------------${NC}"
  
  setup_environment
  run_script_tracking
  scan_old_logs
  scan_unused_ports
  scan_git_modified
  perform_cleanup
  generate_report
  cleanup
  
  echo -e "\n${GREEN}Repository audit and cleanup completed.${NC}"
  
  if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}This was a dry run. Use --clean to perform actual cleanup.${NC}"
  fi
}

# Process command line arguments
process_args "$@"

# Run main function
main
