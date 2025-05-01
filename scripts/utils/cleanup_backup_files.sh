#!/bin/bash
# cleanup_backup_files.sh - Clean up backup and temporary files created during standardization
# Following AgencyStack Charter v1.0.3 principles for repository integrity

set -euo pipefail

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$(dirname "${SCRIPT_DIR}")")"

if [[ -f "${SCRIPT_DIR}/common.sh" ]]; then
  source "${SCRIPT_DIR}/common.sh"
else
  # Minimal logging functions if common.sh is not available
  log_info() { echo -e "[INFO] $*"; }
  log_warning() { echo -e "[WARNING] $*"; }
  log_error() { echo -e "[ERROR] $*"; }
  log_success() { echo -e "[SUCCESS] $*"; }
fi

# Check that we're running inside a container/VM
exit_with_warning_if_host "cleanup_backup_files"

# Display banner
log_info "========================================="
log_info "AgencyStack Backup Files Cleanup Utility"
log_info "Following Charter v1.0.3 principles"
log_info "========================================="

# Default options
DRY_RUN=false
VERBOSE=false
OLDER_THAN_DAYS=0
SEARCH_DIR="${REPO_ROOT}"
FILE_TYPES=(".bak" ".bak.*" ".tmp" ".tmp.*" ".swp" "*.backup.*" "*.old")

# Display usage information
show_usage() {
  echo -e "${BOLD}AgencyStack Backup Files Cleanup Utility${NC}"
  echo "Cleans up backup and temporary files created during standardization"
  echo ""
  echo "Usage:"
  echo "  $(basename "$0") [options]"
  echo ""
  echo "Options:"
  echo "  --directory DIR     Directory to search for backup files (default: repo root)"
  echo "  --older-than DAYS   Only remove files older than DAYS days (0 = all files)"
  echo "  --dry-run           Only report files that would be deleted"
  echo "  --verbose           Show detailed cleanup steps"
  echo "  --help              Show this help message"
  echo ""
  echo "Example:"
  echo "  $(basename "$0") --directory /root/_repos/agency-stack/scripts/components --older-than 7"
  echo "  $(basename "$0") --dry-run --verbose"
  echo ""
}

# Parse command line arguments
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --directory)
      SEARCH_DIR="$2"
      shift 2
      ;;
    --older-than)
      OLDER_THAN_DAYS="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --verbose)
      VERBOSE=true
      shift
      ;;
    --help)
      show_usage
      exit 0
      ;;
    *)
      log_error "Unknown option: $1"
      show_usage
      exit 1
      ;;
  esac
done

# Validate inputs
if [[ ! -d "$SEARCH_DIR" ]]; then
  log_error "Directory not found: $SEARCH_DIR"
  exit 1
fi

log_info "Searching for backup files in: $SEARCH_DIR"
[[ "$OLDER_THAN_DAYS" -gt 0 ]] && log_info "Only removing files older than $OLDER_THAN_DAYS days"
[[ "$DRY_RUN" = "true" ]] && log_info "Dry run mode: Files will not actually be deleted"

# Count variables
TOTAL_FILES=0
TOTAL_SIZE=0

# Clean up backup files
for type in "${FILE_TYPES[@]}"; do
  if [[ "$VERBOSE" = "true" ]]; then
    log_info "Searching for files matching pattern: *${type}"
  fi
  
  find_cmd="find \"$SEARCH_DIR\" -type f -name \"*${type}\""
  
  if [[ "$OLDER_THAN_DAYS" -gt 0 ]]; then
    find_cmd+=" -mtime +${OLDER_THAN_DAYS}"
  fi
  
  backup_files=$(eval "$find_cmd")
  
  if [[ -n "$backup_files" ]]; then
    while IFS= read -r file; do
      if [[ -f "$file" ]]; then
        file_size=$(du -h "$file" | cut -f1)
        file_bytes=$(stat -c %s "$file" 2>/dev/null || stat -f %z "$file")
        file_date=$(date -r "$file" "+%Y-%m-%d %H:%M:%S")
        
        TOTAL_FILES=$((TOTAL_FILES + 1))
        TOTAL_SIZE=$((TOTAL_SIZE + file_bytes))
        
        relative_path="${file#$REPO_ROOT/}"
        
        if [[ "$VERBOSE" = "true" || "$DRY_RUN" = "true" ]]; then
          log_info "Found: $relative_path (${file_size}, created on ${file_date})"
        fi
        
        if [[ "$DRY_RUN" = "false" ]]; then
          rm "$file"
          [[ "$VERBOSE" = "true" ]] && log_success "Deleted: $relative_path"
        fi
      fi
    done <<< "$backup_files"
  fi
done

# Convert total size to human-readable format
if [[ $TOTAL_SIZE -ge 1073741824 ]]; then
  TOTAL_SIZE_HUMAN="$(awk "BEGIN {printf \"%.2f\", ${TOTAL_SIZE}/1073741824}")GB"
elif [[ $TOTAL_SIZE -ge 1048576 ]]; then
  TOTAL_SIZE_HUMAN="$(awk "BEGIN {printf \"%.2f\", ${TOTAL_SIZE}/1048576}")MB"
elif [[ $TOTAL_SIZE -ge 1024 ]]; then
  TOTAL_SIZE_HUMAN="$(awk "BEGIN {printf \"%.2f\", ${TOTAL_SIZE}/1024}")KB"
else
  TOTAL_SIZE_HUMAN="${TOTAL_SIZE}B"
fi

# Report results
if [[ $TOTAL_FILES -eq 0 ]]; then
  log_success "No backup files found."
else
  if [[ "$DRY_RUN" = "true" ]]; then
    log_info "Found $TOTAL_FILES backup files (${TOTAL_SIZE_HUMAN}) that would be deleted."
  else
    log_success "Deleted $TOTAL_FILES backup files (${TOTAL_SIZE_HUMAN})."
  fi
fi

# Record this run in the changelog
if [[ -f "${SCRIPT_DIR}/changelog_utils.sh" ]] && [[ "$DRY_RUN" = "false" ]]; then
  source "${SCRIPT_DIR}/changelog_utils.sh"
  log_agent_fix "cleanup_backup_files" "Cleaned up backup files following Charter compliance implementation"
fi

log_success "Backup file cleanup completed successfully"
