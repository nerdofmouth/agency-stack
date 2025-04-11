#!/bin/bash
# sync_dashboard_oauth.sh - Synchronize OAuth status data between VMs
# https://stack.nerdofmouth.com
#
# This script synchronizes Keycloak OAuth provider status data between VMs
# following the AgencyStack repository integrity policy.

set -e

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/common.sh" ]]; then
  source "${SCRIPT_DIR}/common.sh"
else
  log_error() { echo "[ERROR] $1" >&2; }
  log_info() { echo "[INFO] $1"; }
  log_success() { echo "[SUCCESS] $1"; }
  log_warning() { echo "[WARNING] $1"; }
fi

# Default settings
SOURCE_HOST=""
TARGET_HOST=""
DOMAIN=""
SOURCE_CLIENT_ID="default"
TARGET_CLIENT_ID="default"
CONFIG_DIR="/opt/agency_stack/config"
DASHBOARD_DIR="/opt/agency_stack/dashboard"
VERBOSE=false
FORCE=false
DRY_RUN=false

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --source-host)
      SOURCE_HOST="$2"
      shift 2
      ;;
    --target-host)
      TARGET_HOST="$2"
      shift 2
      ;;
    --domain)
      DOMAIN="$2"
      shift 2
      ;;
    --source-client-id)
      SOURCE_CLIENT_ID="$2"
      shift 2
      ;;
    --target-client-id)
      TARGET_CLIENT_ID="$2"
      shift 2
      ;;
    --force)
      FORCE=true
      shift
      ;;
    --verbose)
      VERBOSE=true
      shift
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --help)
      echo "Usage: $0 [options]"
      echo "Options:"
      echo "  --source-host HOST      Source host with Keycloak OAuth status data"
      echo "  --target-host HOST      Target host to receive the data"
      echo "  --domain DOMAIN         Domain name for the Keycloak instance"
      echo "  --source-client-id ID   Source client ID (default: default)"
      echo "  --target-client-id ID   Target client ID (default: default)"
      echo "  --force                 Force update even if target data is newer"
      echo "  --verbose               Show verbose output"
      echo "  --dry-run               Show what would be done without changing anything"
      exit 0
      ;;
    *)
      log_error "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Check if source and target hosts are provided
if [[ -z "$SOURCE_HOST" ]]; then
  log_error "No source host specified. Use --source-host option."
  exit 1
fi

if [[ -z "$TARGET_HOST" ]]; then
  log_error "No target host specified. Use --target-host option."
  exit 1
fi

if [[ -z "$DOMAIN" ]]; then
  log_warning "No domain specified. Using source hostname as domain."
  DOMAIN="$SOURCE_HOST"
fi

log_info "==================================================="
log_info "Starting sync_dashboard_oauth.sh"
log_info "SOURCE_HOST: $SOURCE_HOST"
log_info "TARGET_HOST: $TARGET_HOST"
log_info "DOMAIN: $DOMAIN"
log_info "SOURCE_CLIENT_ID: $SOURCE_CLIENT_ID"
log_info "TARGET_CLIENT_ID: $TARGET_CLIENT_ID"
log_info "==================================================="

# Create temporary directories
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

SOURCE_DATA="${TMP_DIR}/source_component_registry.json"
TARGET_DATA="${TMP_DIR}/target_component_registry.json"
MERGED_DATA="${TMP_DIR}/merged_component_registry.json"

# Function to extract OAuth data from component registry
extract_oauth_data() {
  local input_file="$1"
  local output_file="$2"
  
  log_info "Extracting OAuth data from $input_file"
  
  # Extract Keycloak component with OAuth data
  if [ -f "$input_file" ]; then
    jq '.components[] | select(.name == "keycloak")' "$input_file" > "$output_file"
    if [ -s "$output_file" ]; then
      log_success "Extracted OAuth data successfully"
      return 0
    else
      log_warning "No Keycloak OAuth data found in registry"
      echo "{}" > "$output_file"
      return 1
    fi
  else
    log_error "Component registry file not found: $input_file"
    echo "{}" > "$output_file"
    return 1
  fi
}

# Function to merge OAuth data into target component registry
merge_oauth_data() {
  local source_oauth="$1"
  local target_registry="$2"
  local output_file="$3"
  
  log_info "Merging OAuth data into target registry"
  
  if [ -s "$source_oauth" ] && [ -f "$target_registry" ]; then
    # Check if keycloak component exists in target registry
    if jq -e '.components[] | select(.name == "keycloak")' "$target_registry" > /dev/null; then
      # Update existing keycloak component
      jq --argjson oauth "$(cat "$source_oauth")" '
        .components = [
          .components[] | 
          if .name == "keycloak" then 
            $oauth 
          else 
            .
          end
        ]
      ' "$target_registry" > "$output_file"
    else
      # Add new keycloak component
      jq --argjson oauth "$(cat "$source_oauth")" '
        .components += [$oauth]
      ' "$target_registry" > "$output_file"
    fi
    
    log_success "Merged OAuth data successfully"
    return 0
  else
    log_error "Cannot merge OAuth data, source or target file missing or empty"
    return 1
  fi
}

# Step 1: Fetch component registry from source host
log_info "Fetching component registry from source host ($SOURCE_HOST)"
if [ "$DRY_RUN" = false ]; then
  if ! ssh "root@$SOURCE_HOST" "cat ${CONFIG_DIR}/component_registry.json" > "${TMP_DIR}/source_registry.json"; then
    log_error "Failed to fetch component registry from source host"
    exit 1
  fi
else
  log_info "[DRY RUN] Would fetch component registry from ${SOURCE_HOST}"
  echo '{"components":[]}' > "${TMP_DIR}/source_registry.json"
fi

# Step 2: Fetch component registry from target host
log_info "Fetching component registry from target host ($TARGET_HOST)"
if [ "$DRY_RUN" = false ]; then
  if ! ssh "root@$TARGET_HOST" "cat ${CONFIG_DIR}/component_registry.json 2>/dev/null || echo '{\"components\":[]}';" > "${TMP_DIR}/target_registry.json"; then
    log_warning "Failed to fetch component registry from target host, creating new one"
    echo '{"components":[]}' > "${TMP_DIR}/target_registry.json"
  fi
else
  log_info "[DRY RUN] Would fetch component registry from ${TARGET_HOST}"
  echo '{"components":[]}' > "${TMP_DIR}/target_registry.json"
fi

# Step 3: Extract OAuth data from source registry
extract_oauth_data "${TMP_DIR}/source_registry.json" "$SOURCE_DATA"

# Step 4: Merge OAuth data into target registry
merge_oauth_data "$SOURCE_DATA" "${TMP_DIR}/target_registry.json" "$MERGED_DATA"

# Step 5: Push merged registry to target host
log_info "Pushing merged component registry to target host ($TARGET_HOST)"
if [ "$DRY_RUN" = false ]; then
  # Ensure config directory exists
  ssh "root@$TARGET_HOST" "mkdir -p ${CONFIG_DIR}"
  
  # Copy merged registry
  scp "$MERGED_DATA" "root@${TARGET_HOST}:${CONFIG_DIR}/component_registry.json"
  
  log_success "Component registry with OAuth data pushed to target host"
else
  log_info "[DRY RUN] Would push merged component registry to ${TARGET_HOST}"
  
  if [ "$VERBOSE" = true ]; then
    log_info "Merged registry content:"
    cat "$MERGED_DATA"
  fi
fi

# Step 6: Update dashboard data on target host
log_info "Updating dashboard data on target host ($TARGET_HOST)"
if [ "$DRY_RUN" = false ]; then
  # Execute dashboard update on target if available
  if ssh "root@$TARGET_HOST" "[ -f /opt/agency_stack/scripts/dashboard/update_dashboard_data.sh ]"; then
    ssh "root@$TARGET_HOST" "cd /opt/agency_stack && bash scripts/dashboard/update_dashboard_data.sh"
    log_success "Dashboard data updated on target host"
  else
    log_warning "Dashboard update script not found on target host, skipping update"
  fi
else
  log_info "[DRY RUN] Would update dashboard data on ${TARGET_HOST}"
fi

log_success "OAuth dashboard data synchronization completed"
