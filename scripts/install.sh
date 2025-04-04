#!/bin/bash
# AgencyStack Installer Script
# https://stack.nerdofmouth.com
# This script helps manage the installation of the AgencyStack components

# Installation variables
SCRIPT_DIR="$(dirname "$0")/agency_stack_bootstrap_bundle_v10"
PARENT_DIR=$(dirname "$SCRIPT_DIR")
DATE=$(date +%Y%m%d-%H%M%S)
LOGDIR="/var/log/agency_stack"
mkdir -p "$LOGDIR"
LOGFILE="$LOGDIR/install-$DATE.log"
PORT_MANAGER="$(dirname "$0")/port_manager.sh"
STATEFILE="/opt/agency_stack/installation_state.json"
mkdir -p "/opt/agency_stack" || { echo "Failed to create /opt/agency_stack directory. Please run with sudo."; exit 1; }
touch "$LOGFILE" || { echo "Failed to create log file. Please run with sudo."; exit 1; }

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Initialize port manager if it exists
if [ -f "$PORT_MANAGER" ]; then
  source "$PORT_MANAGER"
  echo "Port manager initialized" | tee -a "$LOGFILE"
fi

# Logging function
log() {
  local level="$1"
  local message="$2"
  local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  echo -e "[$timestamp] [AgencyStack] [$level] $message" | tee -a "$LOGFILE"
}

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Please run as root or with sudo${NC}"
  exit 1
fi

# Function to check dependencies
check_dependencies() {
  log "INFO" "Checking system dependencies..."
  
  local missing_deps=()
  for cmd in curl wget jq openssl unzip git htop procps; do
    if ! command -v $cmd &> /dev/null; then
      missing_deps+=("$cmd")
    fi
  done
  
  if [ ${#missing_deps[@]} -ne 0 ]; then
    log "WARN" "Missing dependencies: ${missing_deps[*]}"
    echo -e "${YELLOW} Installing missing dependencies...${NC}"
    apt-get update
    apt-get install -y ${missing_deps[@]}
  else
    log "INFO" "All dependencies are installed"
  fi
  
  # Check if Docker is installed and running
  if ! command -v docker &> /dev/null; then
    log "WARN" "Docker is not installed"
    echo -e "${YELLOW}Docker is not installed. It will be installed when you select the Docker component.${NC}"
  else
    if ! docker info &>/dev/null; then
      log "WARN" "Docker is installed but not running"
      echo -e "${YELLOW}Docker is installed but not running. Starting Docker...${NC}"
      systemctl start docker
    else
      log "INFO" "Docker is installed and running"
    fi
  fi
}

# Display header
clear
cat << "EOF"
    _                            ____  _             _    
   / \   __ _  ___ _ __   ___ _/ ___|| |_ __ _  ___| | __
  / _ \ / _` |/ _ \ '_ \ / __| \___ \| __/ _` |/ __| |/ /
 / ___ \ (_| |  __/ | | | (__| |___) | || (_| | (__|   < 
/_/   \_\__, |\___|_| |_|\___|_|____/ \__\__,_|\___|_|\_\
        |___/                                            
EOF
echo ""
echo -e "${BLUE}${BOLD}AgencyStack Installation & Management Center${NC}"
echo -e "${CYAN}Logging to: $LOGFILE${NC}"
echo ""

log "INFO" "Starting AgencyStack installer"

# Installation state tracking
STATEDIR="/home/revelationx/.agency_stack"
STATEFILE="$STATEDIR/install_state.json"

# Initialize state tracking if it doesn't exist
initialize_state() {
  mkdir -p "$STATEDIR"
  if [ ! -f "$STATEFILE" ]; then
    echo '{"components":{},"last_updated":"'$(date -Iseconds)'","version":"1.0.0"}' > "$STATEFILE"
    log "INFO" "Initialized installation state tracking"
  fi
}

# Update component state
update_state() {
  local component="$1"
  local status="$2"  # "pending", "installed", "failed"
  local timestamp=$(date -Iseconds)
  
  # Check if jq is installed
  if ! command -v jq &> /dev/null; then
    log "WARN" "jq is not installed, cannot update state"
    return 1
  fi
  
  jq --arg comp "$component" \
     --arg status "$status" \
     --arg time "$timestamp" \
     '.components[$comp] = {"status": $status, "timestamp": $time} | .last_updated = $time' \
     "$STATEFILE" > "${STATEFILE}.tmp" && mv "${STATEFILE}.tmp" "$STATEFILE"
  
  log "INFO" "Updated state for $component: $status"
}

# Get component state
get_state() {
  local component="$1"
  
  if [ ! -f "$STATEFILE" ] || ! command -v jq &> /dev/null; then
    echo "unknown"
    return 1
  fi
  
  jq -r --arg comp "$component" '.components[$comp].status // "unknown"' "$STATEFILE"
}

# Check for resumable installation
check_resume() {
  if [ -f "$STATEFILE" ] && command -v jq &> /dev/null; then
    log "INFO" "Checking for resumable installation"
    
    # Get pending or failed components
    local pending=$(jq -r '.components | to_entries[] | select(.value.status == "pending" or .value.status == "failed") | .key' "$STATEFILE")
    
    if [ -n "$pending" ]; then
      echo -e "${YELLOW} Found incomplete installation. Do you want to resume?${NC}"
      echo -e "${CYAN}Pending or failed components:${NC}"
      
      for comp in $pending; do
        local status=$(jq -r --arg comp "$comp" '.components[$comp].status' "$STATEFILE")
        local timestamp=$(jq -r --arg comp "$comp" '.components[$comp].timestamp' "$STATEFILE")
        
        if [ "$status" == "pending" ]; then
          echo -e " • ${YELLOW}$comp${NC} (pending since $timestamp)"
        else
          echo -e " • ${RED}$comp${NC} (failed at $timestamp)"
        fi
      done
      
      read -p "Resume installation? [Y/n]: " RESUME
      if [[ "${RESUME,,}" != "n" ]]; then
        log "INFO" "Resuming installation from previous state"
        return 0
      fi
    fi
  fi
  
  # Initialize state if not resuming
  initialize_state
  return 1
}

# Initialize state tracking
check_resume

# Initial configuration
if [ ! -f "/opt/agency_stack/config.env" ]; then
  log "INFO" "Initial configuration not found, running setup"
  
  # Create configuration directory
  mkdir -p /opt/agency_stack/
  
  # Visual feedback
  print_header() { echo -e "\n${MAGENTA}${BOLD}$1${NC}\n"; }
  print_success() { echo -e "${GREEN} $1${NC}"; }
  print_info() { echo -e "${BLUE} $1${NC}"; }
  
  # Interactive mode by default
  INTERACTIVE=true
  if [[ "$1" == "--non-interactive" ]]; then
    INTERACTIVE=false
    log "INFO" "Running in non-interactive mode"
  fi
  
  # Display setup header
  print_header "AgencyStack Initial Configuration"
  log "INFO" "Starting initial configuration"
  
  # Gather domain information
  if [ "$INTERACTIVE" = true ]; then
    print_info "Please enter your primary domain name"
    read -p "Primary domain [example.com]: " PRIMARY_DOMAIN
  fi
  PRIMARY_DOMAIN=${PRIMARY_DOMAIN:-example.com}
  
  # Generate subdomain configurations
  DASHBOARD_DOMAIN="dashboard.${PRIMARY_DOMAIN}"
  PORTAINER_DOMAIN="portainer.${PRIMARY_DOMAIN}"
  AUTH_DOMAIN="auth.${PRIMARY_DOMAIN}"
  
  # Generate admin credentials
  if [ "$INTERACTIVE" = true ]; then
    print_info "Please enter admin password (leave empty to auto-generate)"
    read -s -p "Admin password [auto-generate]: " ADMIN_PASSWORD
    echo ""
  fi
  
  if [ -z "$ADMIN_PASSWORD" ]; then
    ADMIN_PASSWORD=$(openssl rand -base64 12)
    print_success "Generated admin password: $ADMIN_PASSWORD"
    print_info "IMPORTANT: Save this password in a secure location!"
    log "INFO" "Generated random admin password"
  else
    print_success "Admin password set"
    log "INFO" "Custom admin password set"
  fi
  
  # Optional SMTP configuration
  if [ "$INTERACTIVE" = true ]; then
    print_info "Would you like to configure SMTP for email delivery?"
    read -p "Configure SMTP? [y/N]: " CONFIGURE_SMTP
    
    SMTP_ENABLED="false"
    if [[ "${CONFIGURE_SMTP,,}" == "y" ]]; then
      SMTP_ENABLED="true"
      print_info "Enter SMTP details"
      read -p "SMTP host [smtp.example.com]: " SMTP_HOST
      SMTP_HOST=${SMTP_HOST:-smtp.example.com}
      
      read -p "SMTP port [587]: " SMTP_PORT
      SMTP_PORT=${SMTP_PORT:-587}
      
      read -p "SMTP username: " SMTP_USER
      read -s -p "SMTP password: " SMTP_PASSWORD
      echo ""
      
      read -p "From email [noreply@${PRIMARY_DOMAIN}]: " SMTP_FROM
      SMTP_FROM=${SMTP_FROM:-noreply@${PRIMARY_DOMAIN}}
      
      print_success "SMTP configuration saved"
      log "INFO" "SMTP configuration completed"
    fi
  fi
  
  # Optional Builder.io integration
  if [ "$INTERACTIVE" = true ]; then
    print_info "Would you like to enable Builder.io integration?"
    read -p "Enable Builder.io? [y/N]: " ENABLE_BUILDER
    
    BUILDER_ENABLE="false"
    if [[ "${ENABLE_BUILDER,,}" == "y" ]]; then
      BUILDER_ENABLE="true"
      print_info "Enter Builder.io API key (leave empty to configure later)"
      read -p "Builder.io API key: " BUILDER_API_KEY
      
      if [ -n "$BUILDER_API_KEY" ]; then
        print_success "Builder.io integration enabled with API key"
        log "INFO" "Builder.io API key configured"
      else
        print_info "Builder.io enabled but API key not configured"
        log "INFO" "Builder.io enabled without API key"
      fi
    fi
  fi
  
  # Save configuration to file with AgencyStack branding
  cat > /opt/agency_stack/config.env << ENVFILE
# AgencyStack Configuration
# Generated by AgencyStack Installer
# https://stack.nerdofmouth.com
# Created: $(date +"%Y-%m-%d %H:%M:%S")

# Stack Configuration
STACK_NAME="AgencyStack"
STACK_VERSION="1.0.0"
STACK_BRAND_URL="stack.nerdofmouth.com"
STACK_INSTALL_DATE="$(date +"%Y-%m-%d %H:%M:%S")"

# Domain Configuration
PRIMARY_DOMAIN="${PRIMARY_DOMAIN}"
DASHBOARD_DOMAIN="${DASHBOARD_DOMAIN}"
PORTAINER_DOMAIN="${PORTAINER_DOMAIN}"
AUTH_DOMAIN="${AUTH_DOMAIN}"

# Admin Credentials
ADMIN_EMAIL="admin@${PRIMARY_DOMAIN}"
ADMIN_PASSWORD="${ADMIN_PASSWORD}"

# Docker Configuration
DOCKER_SOCK="/var/run/docker.sock"
COMPOSE_PROJECT_NAME="agency_stack"

# Traefik Configuration
TRAEFIK_DASHBOARD_ENABLED="true"
TRAEFIK_DASHBOARD_DOMAIN="traefik.${PRIMARY_DOMAIN}"
TRAEFIK_ACME_EMAIL="admin@${PRIMARY_DOMAIN}"

# Builder.io Integration
BUILDER_ENABLE="${BUILDER_ENABLE}"
BUILDER_API_KEY="${BUILDER_API_KEY}"
BUILDER_MODEL="page"

# Email Settings
SMTP_ENABLED="${SMTP_ENABLED}"
SMTP_HOST="${SMTP_HOST}"
SMTP_PORT="${SMTP_PORT}"
SMTP_USER="${SMTP_USER}"
SMTP_PASSWORD="${SMTP_PASSWORD}"
SMTP_FROM="${SMTP_FROM}"

# Client Settings
ENABLE_MULTI_CLIENT="true"
CLIENT_PREFIX="client"
ENVFILE

  log "INFO" "Initial configuration saved to /opt/agency_stack/config.env"
  print_success "Configuration saved to /opt/agency_stack/config.env"
  
  # Create version file
  echo "1.0.0" > /opt/agency_stack/version
  
  # Create component directory
  mkdir -p /opt/agency_stack/clients
  mkdir -p /var/log/agency_stack
  
  # Create a .clients.json file for tracking clients
  echo '{"clients":[]}' > /opt/agency_stack/clients/.clients.json
  
else
  log "INFO" "Loading existing configuration"
  source /opt/agency_stack/config.env
  print_success "Loaded existing configuration for domain: $PRIMARY_DOMAIN"
fi

# Function to check DNS configuration
function check_dns_configuration() {
  print_header "DNS Configuration Check"
  
  # Get server's public IP
  SERVER_IP=$(curl -s https://api.ipify.org)
  
  if [ -z "$PRIMARY_DOMAIN" ] || [ "$PRIMARY_DOMAIN" = "example.com" ]; then
    print_warning "You haven't configured a custom domain yet."
    echo -e "You will be prompted to enter your domain during installation."
    echo -e "Make sure your domain's DNS records point to this server: ${GREEN}${SERVER_IP}${NC}\n"
    return 0
  fi
  
  # Check if domain resolves
  DOMAIN_IP=$(dig +short "$PRIMARY_DOMAIN" 2>/dev/null)
  
  if [ -z "$DOMAIN_IP" ]; then
    print_warning "Domain $PRIMARY_DOMAIN does not resolve to any IP address."
    echo -e "Please configure your DNS records to point to this server: ${GREEN}${SERVER_IP}${NC}\n"
    log "WARN" "Domain $PRIMARY_DOMAIN does not resolve"
  elif [ "$DOMAIN_IP" != "$SERVER_IP" ]; then
    print_warning "Domain $PRIMARY_DOMAIN resolves to $DOMAIN_IP, not to this server ($SERVER_IP)."
    echo -e "Your DNS configuration may not be correct, which will cause issues with SSL certificates and service access.\n"
    log "WARN" "Domain $PRIMARY_DOMAIN resolves to wrong IP: $DOMAIN_IP (server: $SERVER_IP)"
  else
    print_success "DNS configuration for $PRIMARY_DOMAIN looks good! (Resolves to $DOMAIN_IP)"
    log "INFO" "DNS check passed for $PRIMARY_DOMAIN"
  fi
}

# Check DNS configuration
check_dns_configuration

# Check system dependencies
check_dependencies

# Function to display available components
show_components() {
  echo -e "${MAGENTA}${BOLD}Available Components:${NC}"
  echo -e "${CYAN}Core Infrastructure:${NC}"
  echo -e "  ${BOLD}1.${NC}  Prerequisites (basic system packages)"
  echo -e "  ${BOLD}2.${NC}  Docker"
  echo -e "  ${BOLD}3.${NC}  Docker Compose"
  echo -e "  ${BOLD}4.${NC}  Traefik SSL (reverse proxy)"
  echo -e "  ${BOLD}5.${NC}  Portainer (container management)"
  echo -e "  ${BOLD}24.${NC} DroneCI (continuous integration)"
  
  echo -e "${CYAN}Business Applications:${NC}"
  echo -e "  ${BOLD}6.${NC}  ERPNext (ERP system)"
  echo -e "  ${BOLD}16.${NC} KillBill (billing system)"
  echo -e "  ${BOLD}11.${NC} Cal.com (scheduling system)"
  echo -e "  ${BOLD}19.${NC} Documenso (document signing)"
  
  echo -e "${CYAN}Content Management:${NC}" 
  echo -e "  ${BOLD}7.${NC}  PeerTube (video platform)"
  echo -e "  ${BOLD}8.${NC}  WordPress Module"
  echo -e "  ${BOLD}18.${NC} Seafile (file sharing)"
  echo -e "  ${BOLD}31.${NC} Builder.io (visual CMS)"
  
  echo -e "${CYAN}Team Collaboration:${NC}"
  echo -e "  ${BOLD}9.${NC}  Focalboard (project management)"
  echo -e "  ${BOLD}14.${NC} TaskWarrior/Calcure (task management)"
  
  echo -e "${CYAN}Marketing & Analytics:${NC}"
  echo -e "  ${BOLD}10.${NC} Listmonk (newsletter service)"
  echo -e "  ${BOLD}15.${NC} PostHog (analytics)"
  echo -e "  ${BOLD}20.${NC} WebPush (push notifications)"
  
  echo -e "${CYAN}Integration:${NC}"
  echo -e "  ${BOLD}12.${NC} n8n (workflow automation)"
  echo -e "  ${BOLD}13.${NC} OpenIntegrationHub (integration platform)"
  
  echo -e "${CYAN}System & Security:${NC}"
  echo -e "  ${BOLD}21.${NC} Netdata (monitoring)"
  echo -e "  ${BOLD}22.${NC} Fail2ban (security)"
  echo -e "  ${BOLD}23.${NC} Security (additional security measures)"
  echo -e "  ${BOLD}17.${NC} VoIP"
  
  echo -e "${CYAN}New Components:${NC}"
  echo -e "  ${BOLD}25.${NC} Keycloak (identity management)"
  echo -e "  ${BOLD}26.${NC} Tailscale (mesh networking)"
  echo -e "  ${BOLD}27.${NC} Signing & Timestamps (document integrity)"
  echo -e "  ${BOLD}28.${NC} Backup Strategy (automated backups)"
  echo -e "  ${BOLD}29.${NC} Markdown + Lexical (document editing)"
  echo -e "  ${BOLD}30.${NC} Launchpad Dashboard (central access)"
  echo -e "  ${BOLD}32.${NC} Loki (logging)"
  echo -e "  ${BOLD}33.${NC} Grafana (monitoring)"
  echo -e "  ${BOLD}34.${NC} WordPress (content management)"
  echo -e "  ${BOLD}35.${NC} ERPNext (business management)"
  
  echo -e "${CYAN}Installation Options:${NC}"
  echo -e "  ${BOLD}40.${NC} Install Core Components Only"
  echo -e "  ${BOLD}50.${NC} Install All Components"
  echo -e "  ${BOLD}60.${NC} View Port Allocations"
  echo -e "  ${BOLD}70.${NC} Check System Status"
  echo -e "  ${BOLD}80.${NC} Show Installation Log"
  echo -e "  ${BOLD}0.${NC}  Exit"
  echo ""
}

# Function to display a spinner while waiting for a process
spinner() {
  local pid=$1
  local delay=0.1
  local spinstr='|/-\'
  while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
    local temp=${spinstr#?}
    printf " [%c]  " "$spinstr"
    local spinstr=$temp${spinstr%"$temp"}
    sleep $delay
    printf "\b\b\b\b\b\b"
  done
  printf "    \b\b\b\b"
}

# Function to install a component with progress tracking
install_component() {
  local component=$1
  local script=""
  
  case $component in
    1) script="install_prerequisites.sh" ;;
    2) script="install_docker.sh" ;;
    3) script="install_docker_compose.sh" ;;
    4) script="install_traefik_ssl.sh" ;;
    5) script="install_portainer.sh" ;;
    6) script="install_erpnext.sh" ;;
    7) script="install_peertube.sh" ;;
    8) script="install_wordpress_module.sh" ;;
    9) script="install_focalboard.sh" ;;
    10) script="install_listmonk.sh" ;;
    11) script="install_calcom.sh" ;;
    12) script="install_n8n.sh" ;;
    13) script="install_openintegrationhub.sh" ;;
    14) script="install_taskwarrior_calcure.sh" ;;
    15) script="install_posthog.sh" ;;
    16) script="install_killbill.sh" ;;
    17) script="install_voip.sh" ;;
    18) script="install_seafile.sh" ;;
    19) script="install_documenso.sh" ;;
    20) script="install_webpush.sh" ;;
    21) script="install_netdata.sh" ;;
    22) script="install_fail2ban.sh" ;;
    23) script="install_security.sh" ;;
    24) script="install_droneci.sh" ;;
    25) script="install_keycloak.sh" ;;
    26) script="install_tailscale.sh" ;;
    27) script="install_signing_timestamps.sh" ;;
    28) script="install_backup_strategy.sh" ;;
    29) script="install_markdown_lexical.sh" ;;
    30) script="install_launchpad_dashboard.sh" ;;
    31) script="install_builderio.sh" ;;
    32) script="install_loki.sh" ;;
    33) script="install_grafana.sh" ;;
    34) script="install_wordpress.sh" ;;
    35) script="install_erpnext.sh" ;;
    40) 
      echo -e "${BLUE}${BOLD} Installing AgencyStack Core Components...${NC}"
      log "INFO" "Installing core components bundle"
      install_component 1 && install_component 2 && install_component 3 && 
      install_component 4 && install_component 5 && install_component 24 && install_component 30
      return $?
      ;;
    50) 
      script="install_all.sh" 
      log "INFO" "Installing all AgencyStack components"
      ;;
    60) 
      if [ -f "$PORT_MANAGER" ]; then
        echo -e "${CYAN}${BOLD} Current Port Allocations:${NC}"
        "$PORT_MANAGER" list
      else
        echo -e "${RED} Port manager not found${NC}"
      fi
      return 0
      ;;
    70)
      echo -e "${CYAN}${BOLD} AgencyStack System Status:${NC}"
      echo -e "${YELLOW} Docker Containers:${NC}"
      docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || echo -e "${RED} Docker not running${NC}"
      echo -e "\n${YELLOW} Disk Usage:${NC}"
      df -h | grep -v tmpfs
      echo -e "\n${YELLOW} Memory Usage:${NC}"
      free -h
      return 0
      ;;
    80)
      echo -e "${CYAN}${BOLD} AgencyStack Installation Log:${NC}"
      if [ -f "$LOGFILE" ]; then
        tail -n 50 "$LOGFILE" | less
      else
        echo -e "${RED} Log file not found${NC}"
      fi
      return 0
      ;;
    *) echo -e "${RED} Invalid option${NC}"; return 1 ;;
  esac
  
  # Check if the component is already installed successfully
  local state=$(get_state "$script")
  if [ "$state" == "installed" ]; then
    echo -e "${YELLOW} Component $script is already installed.${NC}"
    read -p "Do you want to reinstall? [y/N]: " REINSTALL
    if [[ "${REINSTALL,,}" != "y" ]]; then
      log "INFO" "Skipping already installed component: $script"
      echo -e "${BLUE} Skipping installation of $script${NC}"
      return 0
    fi
    log "INFO" "Reinstalling component: $script"
    echo -e "${BLUE} Reinstalling $script${NC}"
  fi
  
  echo -e "\n${GREEN}${BOLD} Installing AgencyStack component: $script ${NC}"
  log "INFO" "Installing component: $script"
  
  # Update component state to pending
  update_state "$script" "pending"
  
  if [ -f "$SCRIPT_DIR/$script" ]; then
    # Create a progress bar
    echo -ne "${YELLOW}Progress: [                    ] 0%${NC}\r"
    
    # Run the script and capture output to log
    (bash "$SCRIPT_DIR/$script" 2>&1 | tee -a "$LOGFILE") &
    local pid=$!
    
    # Show spinner while the script is running
    while kill -0 $pid 2>/dev/null; do
      for i in {1..40}; do
        if kill -0 $pid 2>/dev/null; then
          sleep 0.1
          percent=$((i * 100 / 40))
          completed=$((i / 2))
          remaining=$((20 - completed))
          progress="["
          for ((j=0; j<completed; j++)); do progress+="#"; done
          for ((j=0; j<remaining; j++)); do progress+=" "; done
          progress+="]"
          echo -ne "${YELLOW}Progress: $progress $percent%${NC}\r"
        else
          break
        fi
      done
    done
    
    wait $pid
    local exit_code=$?
    
    echo -ne "${GREEN}Progress: [####################] 100%${NC}\n"
    
    if [ $exit_code -eq 0 ]; then
      update_state "$script" "installed"
      log "INFO" "Installation of $script completed successfully"
      echo -e "${GREEN}${BOLD} AgencyStack component $script installed successfully${NC}"
      # Record successful installation
      echo "$(date +"%Y-%m-%d %H:%M:%S") - $script" >> /opt/agency_stack/installed_components.txt
      
      # Show motto after successful installation
      source "$SCRIPT_PATH/agency_branding.sh" && random_tagline
      echo ""
      
      # Show port allocation if port manager exists
      if [ -f "$PORT_MANAGER" ]; then
        local ports=$("$PORT_MANAGER" list 2>/dev/null)
        if [ -n "$ports" ]; then
          echo -e "${CYAN}Updated port allocations after installation:${NC}"
          echo "$ports" | grep -i "$(basename "$script" .sh)" || echo "$ports" | tail -n 3
        fi
      fi
      
      return 0
    else
      update_state "$script" "failed"
      log "ERROR" "Installation of $script failed with exit code $exit_code"
      echo -e "${RED}${BOLD} AgencyStack component $script installation failed${NC}"
      return 1
    fi
  else
    update_state "$script" "failed"
    log "ERROR" "Script not found: $script"
    echo -e "${RED} Script not found: $script${NC}"
    return 1
  fi
}

# Function to handle error recovery
handle_error() {
  local last_command=$1
  local exit_code=$2
  
  log "ERROR" "Command '$last_command' failed with exit code $exit_code"
  echo -e "\n${RED}${BOLD}Error occurred:${NC} The last command '$last_command' failed with exit code $exit_code"
  
  case $last_command in
    *docker*)
      echo -e "${YELLOW}Possible causes:${NC}"
      echo "  - Docker daemon not running"
      echo "  - Docker permission issues"
      echo -e "${YELLOW}Recovery steps:${NC}"
      echo "  - Try running: sudo systemctl restart docker"
      echo "  - Check Docker status: sudo systemctl status docker"
      ;;
    *wget*|*curl*)
      echo -e "${YELLOW}Possible causes:${NC}"
      echo "  - Network connectivity issues"
      echo "  - Resource not available"
      echo -e "${YELLOW}Recovery steps:${NC}"
      echo "  - Check your internet connection"
      echo "  - Verify the URL is correct"
      ;;
    *apt-get*)
      echo -e "${YELLOW}Possible causes:${NC}"
      echo "  - Package repository issues"
      echo "  - Lock file conflicts"
      echo -e "${YELLOW}Recovery steps:${NC}"
      echo "  - Run: sudo apt-get update"
      echo "  - Check for lock files: sudo lsof /var/lib/dpkg/lock"
      ;;
    *)
      echo -e "${YELLOW}Recovery steps:${NC}"
      echo "  - Check the installation log: $LOGFILE"
      echo "  - Try running the component installation again"
      ;;
  esac
}

# Set up trap for error handling
trap 'handle_error "${BASH_COMMAND}" $?' ERR

# Create a management symlink for easier access
if [ ! -f "/usr/local/bin/agency_stack" ]; then
  log "INFO" "Creating agency_stack management symlink"
  cat > /usr/local/bin/agency_stack << 'AGENCYSCRIPT'
#!/bin/bash
SCRIPT_DIR="$(dirname $(readlink -f $0))/../share/foss-server-stack"

case "$1" in
  status)
    echo " Checking service status..."
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    ;;
  ports)
    if [ -f "$SCRIPT_DIR/port_manager.sh" ]; then
      "$SCRIPT_DIR/port_manager.sh" list
    else
      echo "Port manager not found"
    fi
    ;;
  logs)
    if [ -z "$2" ]; then
      echo "Usage: $(basename $0) logs [service_name]"
      exit 1
    fi
    docker logs "$2" --tail 100 -f
    ;;
  restart)
    if [ -z "$2" ]; then
      echo "Usage: $(basename $0) restart [service_name]"
      exit 1
    fi
    docker restart "$2"
    ;;
  install)
    /opt/foss-server-stack/scripts/install.sh
    ;;
  help|*)
    echo "Usage: agency_stack [command]"
    echo "Commands:"
    echo "  status              Show status of all containers"
    echo "  ports               Show port allocations"
    echo "  logs [service]      Show logs for a service"
    echo "  restart [service]   Restart a service"
    echo "  install             Run the installer"
    echo "  help                Show this help"
    ;;
esac
AGENCYSCRIPT
  chmod +x /usr/local/bin/agency_stack
  
  # Create directory for support files
  mkdir -p /usr/local/share/foss-server-stack
  cp "$(dirname "$0")/port_manager.sh" /usr/local/share/foss-server-stack/ 2>/dev/null || true
  
  log "INFO" "Created agency_stack command for easier management"
  echo -e "${GREEN}Created 'agency_stack' command for easier management${NC}"
fi

# Function to setup basic utilities
setup_basic_utilities() {
  echo -e "${BLUE}${BOLD} Setting up basic utilities...${NC}"
  log "INFO" "Setting up basic utilities"
  apt-get update
  apt-get install -y htop git unzip curl wget
  
  # Set up log rotation for production readiness
  echo -e "${BLUE}${BOLD} Setting up log rotation...${NC}"
  if [ -f "$(dirname "$0")/setup_log_rotation.sh" ]; then
    bash "$(dirname "$0")/setup_log_rotation.sh"
    log "INFO" "Log rotation configured"
  else
    log "WARN" "Log rotation script not found"
  fi
  
  echo -e "${GREEN}Basic utilities setup completed${NC}"
}

# Main menu
main_menu() {
  clear
  echo -e "${MAGENTA}${BOLD} AgencyStack Installation Menu ${NC}"
  echo -e " ============================="
  source "$(dirname "$0")/agency_branding.sh" && random_tagline
  echo
  echo -e "${BLUE}${BOLD} Select components to install:${NC}"
  
  # Setup basic utilities and log rotation for production readiness
  setup_basic_utilities

  # Display menu options
  show_components
  read -p "Enter your choice (0-80): " choice
  
  # Validate input is not empty and is a number
  if [[ -z "$choice" || ! "$choice" =~ ^[0-9]+$ ]]; then
    echo -e "${YELLOW} Invalid option${NC}"
    return
  fi
  
  if [ "$choice" -eq 0 ]; then
    log "INFO" "Exiting installer"
    echo -e "${BLUE}${BOLD}Exiting installer. Thank you!${NC}"
    echo -e "${GREEN}You can manage your installation with the 'agency_stack' command${NC}"
    exit 0
  else
    install_component $choice
    echo ""
    read -p "Press enter to continue..."
  fi
  
  echo ""
}

# Start the main menu
main_menu
