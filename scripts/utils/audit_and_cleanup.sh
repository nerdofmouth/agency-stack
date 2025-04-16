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
QUICK_ANALYSIS=false

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
  echo -e "  ${BOLD}--quick${NC}                      Perform quick analysis (skip documentation analysis)"
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
  
  # Limit scope for faster analysis in first run
  track_args+=(--max-depth 3)
  
  # Skip documentation analysis for faster processing
  if [ "$QUICK_ANALYSIS" = true ]; then
    track_args+=(--skip-docs)
  fi
  
  # Add verbose flag if needed
  if [ "$VERBOSE" = true ]; then
    track_args+=(--verbose)
  fi
  
  # Run the track_usage.sh script
  log "INFO" "Executing: $track_script ${track_args[*]}" "${CLEANUP_LOG}"
  echo -e "${CYAN}Running script usage analysis. This may take a few moments...${NC}"
  
  if [ -f "/var/log/agency_stack/audit/unused_scripts.log" ]; then
    # Backup previous logs
    mv "/var/log/agency_stack/audit/unused_scripts.log" "/var/log/agency_stack/audit/unused_scripts.log.bak"
  fi
  
  # Execute track_usage.sh with timeout to prevent hanging
  timeout 300 "$track_script" "${track_args[@]}" 2>&1 | tee -a "${CLEANUP_LOG}"
  
  # Check if the script completed successfully
  if [ ${PIPESTATUS[0]} -eq 124 ]; then
    log "WARNING" "Script usage tracking timed out after 5 minutes. Results may be incomplete." "${CLEANUP_LOG}"
    echo -e "${YELLOW}Script usage tracking timed out after 5 minutes. Results may be incomplete.${NC}"
  else
    log "SUCCESS" "Script usage tracking completed." "${CLEANUP_LOG}"
  fi
  
  # Check if unused scripts were found
  if [ -f "${AUDIT_LOG_DIR}/unused_scripts.log" ]; then
    local unused_count=$(grep -c "Script not referenced" "${AUDIT_LOG_DIR}/unused_scripts.log" || echo "0")
    log "INFO" "Found $unused_count unused scripts" "${CLEANUP_LOG}"
    
    # Add unused scripts to cleanup items if older than threshold
    if [ "$unused_count" -gt 0 ]; then
      log "INFO" "Checking age of unused scripts..." "${CLEANUP_LOG}"
      echo -e "${CYAN}Analyzing $unused_count potentially unused scripts...${NC}"
      
      # Extract script paths from unused_scripts.log
      grep "Script not referenced:" "${AUDIT_LOG_DIR}/unused_scripts.log" | sed 's/\[WARNING\] Script not referenced: //' > "${TEMP_DIR}/unused_scripts_paths.txt"
      
      local script_current=0
      local script_total=$(wc -l < "${TEMP_DIR}/unused_scripts_paths.txt")
      
      while read -r script_path; do
        ((script_current++))
        
        # Show progress
        if [ $((script_current % 5)) -eq 0 ] || [ "$script_current" -eq "$script_total" ]; then
          echo -ne "Analyzing script age: $script_current of $script_total ($(( script_current * 100 / script_total ))%)\r"
        fi
        
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
      
      echo "" # Clear progress line
    fi
  else
    log "WARNING" "No unused scripts log found at ${AUDIT_LOG_DIR}/unused_scripts.log" "${CLEANUP_LOG}"
  fi
}

# Scan for old log files
scan_old_logs() {
  log "INFO" "Scanning for old log files..." "${CLEANUP_LOG}"
  echo -e "${CYAN}Scanning for old log files...${NC}"
  
  # Get current date in seconds since epoch
  local now=$(date +%s)
  local log_count=0
  
  # Ensure log directory exists
  if [ ! -d "${LOG_DIR}" ]; then
    log "WARNING" "Log directory not found: ${LOG_DIR}" "${CLEANUP_LOG}"
    return
  fi
  
  # Find log files older than MAX_LOGS_DAYS
  find "${LOG_DIR}" -type f -name "*.log" | while read -r log_file; do
    local file_mtime=$(stat -c %Y "$log_file")
    local file_age_days=$(( (now - file_mtime) / 86400 ))
    
    ((log_count++))
    
    # Show progress for every 10 logs
    if [ $((log_count % 10)) -eq 0 ]; then
      echo -ne "Scanned $log_count log files...\r"
    fi
    
    if [ "$file_age_days" -gt "$MAX_LOGS_DAYS" ]; then
      log "INFO" "Old log file: $log_file (age: $file_age_days days)" "${CLEANUP_LOG}"
      CLEANUP_ITEMS+=("$log_file")
    fi
  done
  
  echo "" # Clear progress line
  log "INFO" "Scanned $log_count log files" "${CLEANUP_LOG}"
  echo -e "${CYAN}Scanned $log_count log files${NC}"
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
    echo -e "${GREEN}No items to clean up${NC}"
    return 0
  fi
  
  log "INFO" "Preparing to clean up ${#CLEANUP_ITEMS[@]} items..." "${CLEANUP_LOG}"
  echo -e "${CYAN}Preparing to clean up ${#CLEANUP_ITEMS[@]} items...${NC}"
  
  # Print list of items to be cleaned up
  echo -e "${YELLOW}The following items will be cleaned up:${NC}"
  for ((i=0; i<${#CLEANUP_ITEMS[@]} && i<10; i++)); do
    echo -e "  ${YELLOW}- ${CLEANUP_ITEMS[$i]}${NC}"
  done
  
  # Show count if more than 10 items
  if [ ${#CLEANUP_ITEMS[@]} -gt 10 ]; then
    echo -e "  ${YELLOW}... and $((${#CLEANUP_ITEMS[@]} - 10)) more items${NC}"
  fi
  
  # If not in dry-run mode, confirm before proceeding
  if [ "$DRY_RUN" = false ] && [ "$FORCE" = false ] && [ "$SKIP_CONFIRM" = false ]; then
    echo -e "\n${YELLOW}${BOLD}WARNING: You are about to delete ${#CLEANUP_ITEMS[@]} items.${NC}"
    echo -e "${YELLOW}This action cannot be undone.${NC}"
    echo -e "Continue? (y/N): "
    read -r confirm
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
      log "INFO" "Cleanup aborted by user" "${CLEANUP_LOG}"
      echo -e "${YELLOW}Cleanup aborted.${NC}"
      return 0
    fi
  fi
  
  # Create backup directory
  local backup_dir="${AUDIT_LOG_DIR}/backups/$(date +%Y%m%d)"
  mkdir -p "$backup_dir"
  
  # Process each cleanup item with progress indicator
  local item_current=0
  local item_total=${#CLEANUP_ITEMS[@]}
  
  for item in "${CLEANUP_ITEMS[@]}"; do
    ((item_current++))
    
    # Show progress
    if [ $((item_current % 5)) -eq 0 ] || [ "$item_current" -eq "$item_total" ]; then
      echo -ne "Processing: $item_current of $item_total ($(( item_current * 100 / item_total ))%)\r"
    fi
    
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
      log "ACTION" "Creating backup of $item" "${CLEANUP_LOG}"
      
      # Ensure backup directory structure exists
      mkdir -p "$backup_dir/$(dirname "$item" | sed "s|$ROOT_DIR||")"
      
      # Create backup with full path structure
      cp -a "$item" "$backup_dir/$(dirname "$item" | sed "s|$ROOT_DIR||")/"
      
      # Perform the cleanup
      log "ACTION" "Removing: $item" "${CLEANUP_LOG}"
      rm -f "$item"
    else
      log "ACTION" "[DRY-RUN] Would remove: $item" "${CLEANUP_LOG}"
    fi
  done
  
  echo "" # Clear progress line
  
  if [ "$DRY_RUN" = true ]; then
    log "SUCCESS" "Dry run completed. Use --clean to perform actual cleanup" "${CLEANUP_LOG}"
    echo -e "${GREEN}Dry run completed. No files were modified.${NC}"
    echo -e "${GREEN}Use --clean to perform actual cleanup.${NC}"
  else
    log "SUCCESS" "Cleanup completed. Removed ${#CLEANUP_ITEMS[@]} items" "${CLEANUP_LOG}"
    echo -e "${GREEN}Cleanup completed. Removed ${#CLEANUP_ITEMS[@]} items.${NC}"
    echo -e "${GREEN}Backups saved to: $backup_dir${NC}"
  fi
}

# Generate comprehensive audit report
generate_report() {
  if [ "$SKIP_REPORT" = true ]; then
    log "INFO" "Skipping report generation phase" "${CLEANUP_LOG}"
    return 0
  fi
  
  log "INFO" "Generating audit report..." "${CLEANUP_LOG}"
  echo -e "${CYAN}Generating comprehensive audit report...${NC}"
  
  local report_file="${AUDIT_LOG_DIR}/summary_$(date +%Y%m%d).txt"
  local current_date=$(date "+%Y-%m-%d %H:%M:%S")
  
  # Create report header
  cat > "$report_file" << EOF
=========================================================================
                  AGENCYSTACK REPOSITORY AUDIT REPORT
                          Generated: $current_date
=========================================================================

EOF

  # System information
  cat >> "$report_file" << EOF
SYSTEM INFORMATION:
------------------
Hostname: $(hostname)
OS: $(grep PRETTY_NAME /etc/os-release | cut -d'"' -f2)
Kernel: $(uname -r)
Repository Root: ${ROOT_DIR}

EOF

  # Audit summary
  cat >> "$report_file" << EOF
AUDIT SUMMARY:
-------------
Mode: $([ "$DRY_RUN" = true ] && echo "Dry Run (no files modified)" || echo "Cleanup Mode (files may have been modified)")
Git-aware: $([ "$GIT_AWARE" = true ] && echo "Yes" || echo "No")
Quick analysis: $([ "$QUICK_ANALYSIS" = true ] && echo "Yes" || echo "No")

EOF

  # Unused scripts summary
  if [ -f "${AUDIT_LOG_DIR}/unused_scripts.log" ]; then
    local unused_count=$(grep -c "Script not referenced" "${AUDIT_LOG_DIR}/unused_scripts.log" || echo "0")
    local cleanup_count=${#CLEANUP_ITEMS[@]}
    
    cat >> "$report_file" << EOF
UNUSED SCRIPTS SUMMARY:
----------------------
Total scripts scanned: $(grep "Scanning script: " "${CLEANUP_LOG}" | wc -l || echo "Unknown")
Unused scripts detected: $unused_count
Scripts eligible for cleanup: $cleanup_count

EOF

    # List top 10 unused scripts
    if [ "$unused_count" -gt 0 ]; then
      echo "TOP UNUSED SCRIPTS (by age):" >> "$report_file"
      echo "--------------------------" >> "$report_file"
      
      # Extract script paths from unused_scripts.log and get their age
      grep "Script not referenced:" "${AUDIT_LOG_DIR}/unused_scripts.log" | 
      sed 's/\[WARNING\] Script not referenced: //' | 
      while read -r script_path; do
        local full_path="${ROOT_DIR}/${script_path}"
        
        if [ -f "$full_path" ]; then
          local file_age_days=$((($(date +%s) - $(stat -c %Y "$full_path")) / 86400))
          echo "$script_path|$file_age_days"
        fi
      done | 
      sort -t'|' -k2,2nr | 
      head -10 | 
      while IFS="|" read -r path age; do
        local git_info=""
        if [ "$GIT_AWARE" = true ] && [ -d "${ROOT_DIR}/.git" ]; then
          git_info=$(cd "${ROOT_DIR}" && git log -1 --format="Last commit: %cr by %an" -- "$path" 2>/dev/null || echo "Not in git")
        fi
        echo "- $path (Age: $age days) - $git_info" >> "$report_file"
      done
      
      echo "" >> "$report_file"
    fi
  else
    cat >> "$report_file" << EOF
UNUSED SCRIPTS SUMMARY:
----------------------
No unused scripts log found. Script usage tracking may not have completed successfully.

EOF
  fi

  # Documentation consistency
  if [ -f "${AUDIT_LOG_DIR}/doc_inconsistencies.log" ]; then
    local inconsistency_count=$(grep -c "\[WARNING\]" "${AUDIT_LOG_DIR}/doc_inconsistencies.log" || echo "0")
    
    cat >> "$report_file" << EOF
DOCUMENTATION CONSISTENCY:
-------------------------
Documentation inconsistencies detected: $inconsistency_count

EOF

    if [ "$inconsistency_count" -gt 0 ]; then
      echo "TOP DOCUMENTATION INCONSISTENCIES:" >> "$report_file"
      echo "--------------------------------" >> "$report_file"
      grep "\[WARNING\]" "${AUDIT_LOG_DIR}/doc_inconsistencies.log" | head -10 | 
      sed 's/\[WARNING\] /- /' >> "$report_file"
      
      if [ "$inconsistency_count" -gt 10 ]; then
        echo "... and $(($inconsistency_count - 10)) more inconsistencies" >> "$report_file"
      fi
      
      echo "" >> "$report_file"
    fi
  else
    cat >> "$report_file" << EOF
DOCUMENTATION CONSISTENCY:
-------------------------
No documentation consistency log found. Documentation analysis may have been skipped.

EOF
  fi

  # Log files summary
  cat >> "$report_file" << EOF
LOG FILES SUMMARY:
----------------
Old log files detected: $(grep -c "Old log file:" "${CLEANUP_LOG}" || echo "0")
Max log age threshold: ${MAX_LOGS_DAYS} days

EOF

  # Cleanup summary
  cat >> "$report_file" << EOF
CLEANUP SUMMARY:
--------------
Total items flagged for cleanup: ${#CLEANUP_ITEMS[@]}
$([ "$DRY_RUN" = true ] && echo "No items were actually removed (dry run mode)" || echo "Items removed: ${#CLEANUP_ITEMS[@]}")
$([ "$DRY_RUN" = false ] && echo "Backup location: ${AUDIT_LOG_DIR}/backups/$(date +%Y%m%d)" || echo "")

EOF

  # Recommendations
  cat >> "$report_file" << EOF
RECOMMENDATIONS:
--------------
1. Review the unused scripts list for any false positives
2. Run a full audit periodically (at least quarterly)
3. Document any scripts that should be excluded from cleanup
4. For production systems, always run with --dry-run first

EOF

  # Footer
  cat >> "$report_file" << EOF
=========================================================================
             Report generated by AgencyStack Audit System
                https://stack.nerdofmouth.com
=========================================================================
EOF

  # Create a symlink to the latest report
  ln -sf "$report_file" "${AUDIT_LOG_DIR}/audit_report.log"
  
  log "SUCCESS" "Audit report generated: $report_file" "${CLEANUP_LOG}"
  echo -e "${GREEN}Audit report generated: $report_file${NC}"
  
  # Display report summary if not in quiet mode
  if [ "$QUIET" = false ]; then
    echo -e "${CYAN}${BOLD}Audit Report Summary:${NC}"
    echo -e "${CYAN}------------------------------------------${NC}"
    grep -A 3 "UNUSED SCRIPTS SUMMARY:" "$report_file"
    grep -A 2 "DOCUMENTATION CONSISTENCY:" "$report_file"
    grep -A 2 "CLEANUP SUMMARY:" "$report_file"
    echo -e "${CYAN}------------------------------------------${NC}"
    echo -e "${GREEN}To view the full report, run: make audit-report${NC}"
  fi
  
  # Email report if requested
  if [ "$EMAIL_REPORT" = true ] && [ -n "$EMAIL_TO" ]; then
    log "INFO" "Emailing audit report to $EMAIL_TO" "${CLEANUP_LOG}"
    
    if command -v mail >/dev/null 2>&1; then
      mail -s "AgencyStack Audit Report: $(date +%Y-%m-%d)" "$EMAIL_TO" < "$report_file"
      log "SUCCESS" "Audit report emailed to $EMAIL_TO" "${CLEANUP_LOG}"
    else
      log "ERROR" "mail command not found. Email report not sent." "${CLEANUP_LOG}"
    fi
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
      --quick)
        QUICK_ANALYSIS=true
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

# Run the main function
main
