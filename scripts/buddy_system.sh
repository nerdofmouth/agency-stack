#!/bin/bash
# buddy_system.sh - Self-healing buddy system for AgencyStack
# https://stack.nerdofmouth.com

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Logging setup
LOGDIR="/var/log/agency_stack"
mkdir -p "$LOGDIR"
LOGFILE="$LOGDIR/buddy-system.log"
touch "$LOGFILE"

# Import branding
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/agency_branding.sh"

# Logging function
log() {
  local level="$1"
  local message="$2"
  local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  echo -e "[$timestamp] [AgencyStack-Buddy] [$level] $message" | tee -a "$LOGFILE"
}

# Visual feedback
print_header() { echo -e "\n${MAGENTA}${BOLD}$1${NC}\n"; }
print_success() { echo -e "${GREEN}✅ $1${NC}"; log "SUCCESS" "$1"; }
print_info() { echo -e "${BLUE}ℹ️ $1${NC}"; log "INFO" "$1"; }
print_warning() { echo -e "${YELLOW}⚠️ $1${NC}"; log "WARNING" "$1"; }
print_error() { echo -e "${RED}❌ $1${NC}"; log "ERROR" "$1"; }

# Config file paths
CONFIG_DIR="/opt/agency_stack/config"
BUDDIES_CONFIG="${CONFIG_DIR}/buddies.json"
BUDDY_KEYS_DIR="${CONFIG_DIR}/buddy_keys"

# Make sure config directory exists
mkdir -p "$CONFIG_DIR"
mkdir -p "$BUDDY_KEYS_DIR"

# Function to check if config exists
check_config() {
  if [ ! -f "$BUDDIES_CONFIG" ]; then
    print_warning "Buddy system configuration not found at $BUDDIES_CONFIG"
    return 1
  fi
  return 0
}

# Function to create default config if it doesn't exist
create_default_config() {
  local hostname=$(hostname -f)
  local server_ip=$(hostname -I | awk '{print $1}')

  if [ ! -f "$BUDDIES_CONFIG" ]; then
    print_info "Creating default buddy system configuration"
    
    cat > "$BUDDIES_CONFIG" << EOF
{
  "name": "${hostname}",
  "ip": "${server_ip}",
  "buddies": [],
  "notification_email": "admin@example.com",
  "check_interval_minutes": 5,
  "recovery_actions": ["restart", "notify"],
  "drone_ci_enabled": true,
  "health_check_endpoints": [
    {
      "name": "traefik",
      "url": "http://localhost:8080/ping",
      "expected_response": "OK"
    }
  ]
}
EOF
    print_success "Created default configuration at $BUDDIES_CONFIG"
    print_info "Please edit the configuration file to add buddy servers"
  fi
}

# Function to generate SSH keys for buddy authentication
generate_ssh_keys() {
  local hostname=$(hostname -f)
  local key_file="${BUDDY_KEYS_DIR}/${hostname}"
  
  if [ -f "$key_file" ]; then
    print_warning "SSH keys already exist for this server. Skipping generation."
    return 0
  fi
  
  print_info "Generating SSH keys for buddy system authentication"
  ssh-keygen -t ed25519 -f "$key_file" -N "" -C "agencystack-buddy-${hostname}"
  
  print_success "SSH keys generated at ${key_file}"
  print_info "Public key to share with buddy servers:"
  echo ""
  cat "${key_file}.pub"
  echo ""
  print_info "Copy this public key to the authorized_keys file on your buddy servers"
}

# Function to check health of a buddy server
check_buddy_health() {
  local buddy_name="$1"
  local buddy_ip="$2"
  local ssh_key="$3"
  
  print_info "Checking health of buddy server: $buddy_name ($buddy_ip)"
  
  # Check if server is reachable
  if ! ping -c 1 "$buddy_ip" &> /dev/null; then
    print_error "Buddy server $buddy_name is not responding to ping"
    return 1
  fi
  
  # Check if SSH access works
  if ! ssh -i "$ssh_key" -o StrictHostKeyChecking=no -o ConnectTimeout=5 "root@${buddy_ip}" "echo 'AgencyStack-Buddy-Check'" &> /dev/null; then
    print_error "Cannot establish SSH connection to buddy server $buddy_name"
    return 1
  fi
  
  # Check if AgencyStack is running
  if ! ssh -i "$ssh_key" -o StrictHostKeyChecking=no "root@${buddy_ip}" "docker ps | grep -q traefik" &> /dev/null; then
    print_error "AgencyStack services are not running on buddy server $buddy_name"
    return 1
  fi
  
  print_success "Buddy server $buddy_name is healthy"
  return 0
}

# Function to perform recovery actions
perform_recovery_actions() {
  local buddy_name="$1"
  local buddy_ip="$2"
  local ssh_key="$3"
  local actions="$4"
  
  print_warning "Performing recovery actions for buddy server $buddy_name"
  
  for action in $(echo "$actions" | tr ',' ' '); do
    case "$action" in
      restart)
        print_info "Attempting to restart services on $buddy_name"
        ssh -i "$ssh_key" -o StrictHostKeyChecking=no "root@${buddy_ip}" "cd /opt/agency_stack && make restart" &>> "$LOGFILE"
        ;;
      rebuild)
        print_info "Attempting to rebuild $buddy_name (this may take a while)"
        ssh -i "$ssh_key" -o StrictHostKeyChecking=no "root@${buddy_ip}" "cd /opt && rm -rf agency_stack_backup && cp -r agency_stack agency_stack_backup && cd agency_stack && make clean && make install" &>> "$LOGFILE"
        ;;
      notify)
        print_info "Sending notification about $buddy_name"
        local email=$(jq -r '.notification_email' "$BUDDIES_CONFIG")
        if [ "$email" != "null" ] && [ -n "$email" ]; then
          echo "AgencyStack Buddy System Alert: $buddy_name is experiencing issues" | mail -s "AgencyStack Buddy System Alert" "$email"
        fi
        ;;
      *)
        print_warning "Unknown recovery action: $action"
        ;;
    esac
  done
}

# Main function to monitor buddy servers
monitor_buddies() {
  if ! check_config; then
    create_default_config
    return 1
  fi
  
  print_header "Starting buddy system monitoring"
  
  local server_name=$(jq -r '.name' "$BUDDIES_CONFIG")
  local buddies=$(jq -c '.buddies[]' "$BUDDIES_CONFIG")
  
  print_info "Server: $server_name"
  print_info "Found $(echo "$buddies" | wc -l) buddy servers to monitor"
  
  echo "$buddies" | while read -r buddy; do
    local buddy_name=$(echo "$buddy" | jq -r '.name')
    local buddy_ip=$(echo "$buddy" | jq -r '.ip')
    local ssh_key=$(echo "$buddy" | jq -r '.ssh_key')
    local recovery_actions=$(echo "$buddy" | jq -r '.recovery_actions | join(",")')
    
    print_info "Monitoring buddy: $buddy_name ($buddy_ip)"
    
    if ! check_buddy_health "$buddy_name" "$buddy_ip" "$ssh_key"; then
      print_warning "Buddy server $buddy_name needs recovery"
      perform_recovery_actions "$buddy_name" "$buddy_ip" "$ssh_key" "$recovery_actions"
    fi
  done
  
  print_header "Buddy system monitoring complete"
}

# Function to install cron job for regular monitoring
install_cron_job() {
  local check_interval=$(jq -r '.check_interval_minutes // 5' "$BUDDIES_CONFIG")
  
  print_info "Setting up cron job to run every $check_interval minutes"
  
  # Remove existing cron job if it exists
  crontab -l 2>/dev/null | grep -v "buddy_system.sh" | crontab -
  
  # Add new cron job
  (crontab -l 2>/dev/null; echo "*/$check_interval * * * * $SCRIPT_DIR/buddy_system.sh monitor >> $LOGFILE 2>&1") | crontab -
  
  print_success "Cron job installed"
}

# Function to setup DroneCI integration
setup_drone_integration() {
  local drone_enabled=$(jq -r '.drone_ci_enabled // false' "$BUDDIES_CONFIG")
  
  if [ "$drone_enabled" != "true" ]; then
    print_info "DroneCI integration is disabled in config"
    return 0
  fi
  
  print_info "Setting up DroneCI integration for buddy system"
  
  # Check if DroneCI is installed
  if ! docker ps | grep -q drone-server; then
    print_warning "DroneCI doesn't seem to be running. Skipping integration."
    return 1
  fi
  
  # Create DroneCI pipeline for buddy system
  local drone_config_dir="/opt/agency_stack/drone-pipelines"
  mkdir -p "$drone_config_dir"
  
  cat > "${drone_config_dir}/buddy-system.yml" << EOF
kind: pipeline
type: docker
name: buddy-system-monitoring

trigger:
  event:
    - cron
  cron:
    - buddy-check

steps:
  - name: check-buddy-health
    image: alpine
    commands:
      - apk add --no-cache bash jq openssh-client
      - bash /opt/agency_stack/scripts/buddy_system.sh monitor
EOF
  
  print_success "DroneCI integration setup complete"
  print_info "You'll need to configure this pipeline in your DroneCI instance"
}

# Command handling
case "$1" in
  init)
    print_header "Initializing buddy system"
    create_default_config
    ;;
  generate-keys)
    print_header "Generating SSH keys for buddy system"
    generate_ssh_keys
    ;;
  monitor)
    monitor_buddies
    ;;
  install-cron)
    print_header "Installing cron job for buddy system"
    check_config && install_cron_job
    ;;
  setup-drone)
    print_header "Setting up DroneCI integration"
    check_config && setup_drone_integration
    ;;
  *)
    print_header "AgencyStack Buddy System"
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  init           Initialize buddy system configuration"
    echo "  generate-keys  Generate SSH keys for buddy authentication"
    echo "  monitor        Check health of buddy servers and perform recovery if needed"
    echo "  install-cron   Install cron job for regular monitoring"
    echo "  setup-drone    Setup DroneCI integration"
    echo ""
    echo "Visit https://stack.nerdofmouth.com/pages/self-healing.html for more information"
    ;;
esac

exit 0
