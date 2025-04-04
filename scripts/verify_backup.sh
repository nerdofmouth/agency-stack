#!/bin/bash
# verify_backup.sh - Verify Restic backups for AgencyStack
# https://stack.nerdofmouth.com

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Log file
LOG_DIR="/var/log/agency_stack"
LOG_FILE="${LOG_DIR}/restic_verification-$(date +%Y%m%d-%H%M%S).log"
VERIFICATION_SUMMARY="${LOG_DIR}/restic_verification_latest.log"

# Status tracking
ERRORS=0
ERROR_MESSAGES=""

# Create log directory if it doesn't exist
mkdir -p "$LOG_DIR"

# Set PATH to include restic
export PATH=$PATH:/usr/local/bin:/usr/bin

# Logging function
log() {
  echo -e "$1" | tee -a "$LOG_FILE"
}

log "${MAGENTA}${BOLD}🔐 AgencyStack Restic Backup Verification${NC}"
log "=============================================="
log "$(date)"
log "Server: $(hostname)"
log ""

# Check if restic is installed
if ! command -v restic &> /dev/null; then
  log "${RED}Restic is not installed${NC}"
  echo "restic_check_status=failed" > "$VERIFICATION_SUMMARY"
  echo "restic_check_errors=1" >> "$VERIFICATION_SUMMARY"
  echo "restic_check_message=Restic not installed" >> "$VERIFICATION_SUMMARY"
  exit 1
fi

# Check if config.env exists
if [ ! -f "/opt/agency_stack/config.env" ]; then
  log "${RED}Error: config.env file not found${NC}"
  echo "restic_check_status=failed" > "$VERIFICATION_SUMMARY"
  echo "restic_check_errors=1" >> "$VERIFICATION_SUMMARY"
  echo "restic_check_message=config.env not found" >> "$VERIFICATION_SUMMARY"
  exit 1
fi

# Load configuration
source "/opt/agency_stack/config.env"

# Check if RESTIC_REPOSITORY is set
if [ -z "$RESTIC_REPOSITORY" ]; then
  log "${RED}Error: RESTIC_REPOSITORY not set in config.env${NC}"
  echo "restic_check_status=failed" > "$VERIFICATION_SUMMARY"
  echo "restic_check_errors=1" >> "$VERIFICATION_SUMMARY"
  echo "restic_check_message=RESTIC_REPOSITORY not configured" >> "$VERIFICATION_SUMMARY"
  exit 1
fi

# Check if RESTIC_PASSWORD is set
if [ -z "$RESTIC_PASSWORD" ]; then
  log "${RED}Error: RESTIC_PASSWORD not set in config.env${NC}"
  echo "restic_check_status=failed" > "$VERIFICATION_SUMMARY"
  echo "restic_check_errors=1" >> "$VERIFICATION_SUMMARY"
  echo "restic_check_message=RESTIC_PASSWORD not configured" >> "$VERIFICATION_SUMMARY"
  exit 1
fi

# Set environment variables for restic
export RESTIC_REPOSITORY="$RESTIC_REPOSITORY"
export RESTIC_PASSWORD="$RESTIC_PASSWORD"

# Set AWS credentials if using S3
if [[ "$RESTIC_REPOSITORY" == s3:* ]]; then
  if [ -n "$AWS_ACCESS_KEY_ID" ] && [ -n "$AWS_SECRET_ACCESS_KEY" ]; then
    export AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID"
    export AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY"
    log "${BLUE}Using AWS S3 as backup repository${NC}"
  else
    log "${RED}Error: AWS credentials not set for S3 repository${NC}"
    echo "restic_check_status=failed" > "$VERIFICATION_SUMMARY"
    echo "restic_check_errors=1" >> "$VERIFICATION_SUMMARY"
    echo "restic_check_message=AWS credentials not configured" >> "$VERIFICATION_SUMMARY"
    exit 1
  fi
fi

# List snapshots to ensure we can connect
log "${BLUE}Checking connection to restic repository...${NC}"
if ! restic snapshots &> /dev/null; then
  log "${RED}Error: Cannot connect to restic repository${NC}"
  log "${RED}Please check your repository path and credentials${NC}"
  echo "restic_check_status=failed" > "$VERIFICATION_SUMMARY"
  echo "restic_check_errors=1" >> "$VERIFICATION_SUMMARY"
  echo "restic_check_message=Cannot connect to repository" >> "$VERIFICATION_SUMMARY"
  exit 1
fi

# Get latest snapshot ID
log "${BLUE}Getting latest snapshot...${NC}"
LATEST_SNAPSHOT=$(restic snapshots --latest 1 --json | jq -r '.[0].id')

if [ -z "$LATEST_SNAPSHOT" ] || [ "$LATEST_SNAPSHOT" == "null" ]; then
  log "${YELLOW}Warning: No snapshots found in repository${NC}"
  echo "restic_check_status=warning" > "$VERIFICATION_SUMMARY"
  echo "restic_check_errors=0" >> "$VERIFICATION_SUMMARY"
  echo "restic_check_message=No snapshots found" >> "$VERIFICATION_SUMMARY"
  exit 0
fi

log "${GREEN}Latest snapshot: $LATEST_SNAPSHOT${NC}"

# Check snapshot integrity
log "${BLUE}Verifying repository data integrity...${NC}"
if restic check &>> "$LOG_FILE"; then
  log "${GREEN}✅ Repository integrity check passed${NC}"
else
  log "${RED}❌ Repository integrity check failed${NC}"
  ERRORS=$((ERRORS + 1))
  ERROR_MESSAGES="${ERROR_MESSAGES}Repository integrity check failed\n"
fi

# Verify files from the latest snapshot
log "${BLUE}Verifying files from latest snapshot...${NC}"
if restic verify --read-data-subset=10% "$LATEST_SNAPSHOT" &>> "$LOG_FILE"; then
  log "${GREEN}✅ Snapshot data verification passed${NC}"
else
  log "${RED}❌ Snapshot data verification failed${NC}"
  ERRORS=$((ERRORS + 1))
  ERROR_MESSAGES="${ERROR_MESSAGES}Snapshot data verification failed\n"
fi

# Get statistics
log "${BLUE}Getting backup statistics...${NC}"
STATS=$(restic stats --json)
TOTAL_SIZE=$(echo "$STATS" | jq -r '.total_size')
TOTAL_SIZE_HUMAN=$(numfmt --to=iec-i --suffix=B "$TOTAL_SIZE")
TOTAL_FILES=$(echo "$STATS" | jq -r '.total_file_count')

log "${CYAN}Total backup size: $TOTAL_SIZE_HUMAN${NC}"
log "${CYAN}Total files: $TOTAL_FILES${NC}"

# Get snapshot details
SNAPSHOT_TIME=$(restic snapshots --latest 1 --json | jq -r '.[0].time')
HUMAN_TIME=$(date -d "$SNAPSHOT_TIME" '+%Y-%m-%d %H:%M:%S')
log "${CYAN}Latest backup: $HUMAN_TIME${NC}"

# Write summary file for health check integration
if [ $ERRORS -eq 0 ]; then
  echo "restic_check_status=passed" > "$VERIFICATION_SUMMARY"
  echo "restic_check_errors=0" >> "$VERIFICATION_SUMMARY"
  echo "restic_check_message=All verification tests passed" >> "$VERIFICATION_SUMMARY"
  echo "restic_last_backup=${HUMAN_TIME}" >> "$VERIFICATION_SUMMARY"
  echo "restic_backup_size=${TOTAL_SIZE_HUMAN}" >> "$VERIFICATION_SUMMARY"
  echo "restic_backup_files=${TOTAL_FILES}" >> "$VERIFICATION_SUMMARY"
else
  echo "restic_check_status=failed" > "$VERIFICATION_SUMMARY"
  echo "restic_check_errors=$ERRORS" >> "$VERIFICATION_SUMMARY"
  echo "restic_check_message=Verification failed with $ERRORS errors" >> "$VERIFICATION_SUMMARY"
  echo "restic_last_backup=${HUMAN_TIME}" >> "$VERIFICATION_SUMMARY"
  echo "restic_backup_size=${TOTAL_SIZE_HUMAN}" >> "$VERIFICATION_SUMMARY"
  echo "restic_backup_files=${TOTAL_FILES}" >> "$VERIFICATION_SUMMARY"
  
  # Send alert if configured
  if [ -f "/opt/agency_stack/scripts/health_check.sh" ]; then
    # Source the send_alerts function from health_check.sh
    source <(grep -A 50 "send_alerts" "/opt/agency_stack/scripts/health_check.sh" | head -n 50)
    # This assumes send_alerts function exists in health_check.sh
    if type send_alerts &>/dev/null; then
      ERROR_MESSAGES="Backup verification failed:\n$ERROR_MESSAGES"
      ERRORS=$ERRORS
      send_alerts
    fi
  fi
fi

log ""
log "${GREEN}${BOLD}Backup verification complete!${NC}"
log "Log saved to: $LOG_FILE"
log "Summary saved to: $VERIFICATION_SUMMARY"

# Exit with error code if there were errors
if [ $ERRORS -gt 0 ]; then
  exit 1
fi

exit 0
