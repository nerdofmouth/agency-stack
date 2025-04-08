#!/bin/bash
# Install AgencyStack Dashboard Component
# Installs and configures the Next.js dashboard for monitoring component status

# Determine script path and repo root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Set up logging
LOG_FILE=${LOG_FILE:-/var/log/agency_stack/components/dashboard.log}
mkdir -p "$(dirname "$LOG_FILE")"

# Create our own logging functions
init_log() {
  local component="$1"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] ==========================================="
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] Starting install_${component}.sh"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] CLIENT_ID: ${CLIENT_ID:-default}"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] DOMAIN: ${DOMAIN:-localhost}"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] ==========================================="
}

log_error() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $1" | tee -a "$LOG_FILE" >&2
}

log_info() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $1" | tee -a "$LOG_FILE"
}

log_warning() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARNING] $1" | tee -a "$LOG_FILE" >&2
}

log_success() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SUCCESS] $1" | tee -a "$LOG_FILE"
}

# Default values
DASHBOARD_PORT=3000
DASHBOARD_DIR="/opt/agency_stack/apps/dashboard"
CLIENT_ID=${CLIENT_ID:-default}
DOMAIN=${DOMAIN:-localhost}
KEYCLOAK_REALM=${KEYCLOAK_REALM:-agency_stack}
KEYCLOAK_CLIENT_ID=${KEYCLOAK_CLIENT_ID:-dashboard}
DASHBOARD_LOGS_DIR="/var/log/agency_stack/components"
DASHBOARD_REPO="https://github.com/nerdofmouth/agency-stack-dashboard.git"
DASHBOARD_BRANCH="main"

# Parse command-line arguments
ADMIN_EMAIL=""
FORCE=false
WITH_DEPS=false
VERBOSE=false
ENABLE_CLOUD=false
ENABLE_OPENAI=false
USE_GITHUB=false
ENABLE_KEYCLOAK=false

# Process arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --domain)
      DOMAIN="$2"
      shift 2
      ;;
    --admin-email)
      ADMIN_EMAIL="$2"
      shift 2
      ;;
    --client-id)
      CLIENT_ID="$2"
      shift 2
      ;;
    --force)
      FORCE=true
      shift
      ;;
    --with-deps)
      WITH_DEPS=true
      shift
      ;;
    --verbose)
      VERBOSE=true
      shift
      ;;
    --enable-cloud)
      ENABLE_CLOUD=true
      shift
      ;;
    --enable-openai)
      ENABLE_OPENAI=true
      shift
      ;;
    --use-github)
      USE_GITHUB=true
      shift
      ;;
    --enable-keycloak)
      ENABLE_KEYCLOAK=true
      shift
      ;;
    *)
      log_error "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Initialize logging (after processing arguments)
init_log "dashboard"
log_info "Starting Next.js dashboard component installation"
log_info "Using domain: ${DOMAIN}"

# Set client-specific paths if CLIENT_ID is provided
if [[ -n "$CLIENT_ID" ]]; then
  DASHBOARD_DIR="/opt/agency_stack/clients/${CLIENT_ID}/apps/dashboard"
  log_info "Client-specific installation: ${CLIENT_ID}"
fi

# Ensure required directories exist
ensure_directories() {
  log_info "Creating required directories"
  mkdir -p "$DASHBOARD_DIR"
  mkdir -p "$DASHBOARD_LOGS_DIR"
  
  # Create parent directory for the installed_ok marker
  mkdir -p "/opt/agency_stack/dashboard"
  if [[ -n "$CLIENT_ID" ]]; then
    mkdir -p "/opt/agency_stack/clients/${CLIENT_ID}/dashboard"
  fi
  
  return 0
}

# Check for Node.js and install if needed (without global installation)
check_nodejs() {
  log_info "Checking for Node.js"
  
  if [[ ! -d "${DASHBOARD_DIR}/node" ]]; then
    log_info "Node.js not found in project directory, downloading..."
    
    # Create node directory
    mkdir -p "${DASHBOARD_DIR}/node"
    
    # Download and extract Node.js (using LTS version)
    local NODE_VERSION="18.17.1"
    local NODE_DIST="https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-x64.tar.gz"
    
    log_info "Downloading Node.js v${NODE_VERSION}"
    curl -sL "$NODE_DIST" | tar xz -C "${DASHBOARD_DIR}/node" --strip-components=1
    
    # Add node to project path
    export PATH="${DASHBOARD_DIR}/node/bin:$PATH"
    log_info "Node.js installed to project directory: ${DASHBOARD_DIR}/node"
  else
    export PATH="${DASHBOARD_DIR}/node/bin:$PATH"
    log_info "Using existing Node.js installation in project directory"
  fi
  
  # Verify Node.js is accessible
  if ! command -v node &>/dev/null; then
    log_error "Node.js is not in PATH even after installation attempt"
    return 1
  fi
  
  log_info "Node.js version: $(node -v)"
  log_info "npm version: $(npm -v)"
  
  # Install pnpm if not already installed
  if ! command -v pnpm &>/dev/null; then
    log_info "Installing pnpm"
    npm install -g pnpm
    
    if ! command -v pnpm &>/dev/null; then
      log_error "Failed to install pnpm"
      return 1
    fi
  fi
  
  log_info "pnpm version: $(pnpm -v)"
  return 0
}

# Check Keycloak availability if SSO is enabled
check_keycloak() {
  if [[ "$ENABLE_KEYCLOAK" == "true" ]]; then
    log_info "Checking Keycloak availability"
    
    # Check for Keycloak installation
    if ! command -v "${SCRIPT_DIR}/../utils/keycloak_client.sh" &>/dev/null; then
      log_warning "Keycloak client utility not found but --enable-keycloak was specified"
    fi
    
    # Check if Keycloak service is running
    if ! systemctl is-active --quiet keycloak &>/dev/null && ! docker ps | grep -q keycloak; then
      log_warning "Keycloak service does not appear to be running"
      log_warning "The dashboard requires Keycloak for SSO functionality"
      
      if [[ "$FORCE" != "true" ]]; then
        log_error "Aborting installation. Use --force to continue anyway."
        return 1
      fi
    fi
  fi
  
  return 0
}

# Setup dashboard source code
setup_dashboard_source() {
  log_info "Setting up dashboard source code..."
  
  # Ensure the dashboard directory exists
  mkdir -p "${DASHBOARD_DIR}"
  
  # Copy dashboard source files from the repository to installation directory
  log_info "Copying dashboard source files from repository..."
  
  # Copy API endpoints
  mkdir -p "${DASHBOARD_DIR}/pages/api"
  cp -r "${REPO_ROOT}/dashboard/api/"* "${DASHBOARD_DIR}/pages/api/"
  
  # Copy pages
  cp -r "${REPO_ROOT}/dashboard/pages/"* "${DASHBOARD_DIR}/pages/"
  
  # Copy components
  mkdir -p "${DASHBOARD_DIR}/components"
  cp -r "${REPO_ROOT}/dashboard/components/"* "${DASHBOARD_DIR}/components/"
  
  # Copy styles
  mkdir -p "${DASHBOARD_DIR}/styles"
  cp -r "${REPO_ROOT}/dashboard/styles/"* "${DASHBOARD_DIR}/styles/"
  
  # Copy package.json
  cp "${REPO_ROOT}/dashboard/package.json" "${DASHBOARD_DIR}/"
  
  log_success "Dashboard source files copied successfully."
}

# Generate environment configuration
generate_env_config() {
  log_info "Generating environment configuration..."
  
  # Create .env.local file for NextJS dashboard
  cat > "${DASHBOARD_DIR}/.env.local" <<EOF
# AgencyStack Dashboard Configuration
# Auto-generated by install_dashboard.sh

# Basic Configuration
NEXT_PUBLIC_APP_NAME=AgencyStack Dashboard
NEXT_PUBLIC_DOMAIN=${DOMAIN}
NEXT_PUBLIC_CLIENT_ID=${CLIENT_ID}

# Keycloak SSO Configuration
NEXT_PUBLIC_KEYCLOAK_URL=https://keycloak.${DOMAIN}
NEXT_PUBLIC_KEYCLOAK_REALM=${KEYCLOAK_REALM}
NEXT_PUBLIC_KEYCLOAK_CLIENT_ID=${KEYCLOAK_CLIENT_ID}

# API Configuration
NEXT_PUBLIC_API_URL=/api
EOF

  # Make sure permissions are correct
  chmod 644 "${DASHBOARD_DIR}/.env.local"
  
  log_success "Environment configuration generated."
}

# Build the dashboard application
build_dashboard() {
  log_info "Building dashboard application..."
  
  cd "${DASHBOARD_DIR}" || return 1
  
  # Ensure npm dependencies are installed
  log_info "Installing npm dependencies..."
  npm install --quiet || {
    log_error "Failed to install npm dependencies"
    return 1
  }
  
  # Build the Next.js application
  log_info "Building Next.js application..."
  npm run build || {
    log_error "Failed to build Next.js application"
    return 1
  }
  
  log_success "Dashboard application built successfully"
  return 0
}

# Setup process manager (pm2) for the dashboard
setup_process_manager() {
  log_info "Setting up process manager for dashboard..."
  
  # Check if pm2 is installed
  if ! command -v pm2 &>/dev/null; then
    log_info "Installing pm2 process manager..."
    npm install -g pm2 || {
      log_error "Failed to install pm2"
      return 1
    }
  fi
  
  # Create the ecosystem.config.js file for pm2
  log_info "Creating pm2 ecosystem configuration..."
  cat > "${DASHBOARD_DIR}/ecosystem.config.js" <<EOF
module.exports = {
  apps: [{
    name: 'agencystack-dashboard',
    script: 'npm',
    args: 'start',
    instances: 1,
    autorestart: true,
    watch: false,
    max_memory_restart: '500M',
    env: {
      NODE_ENV: 'production',
      PORT: ${DASHBOARD_PORT}
    }
  }]
};
EOF
  
  # Stop any existing dashboard process
  if pm2 list | grep -q "agencystack-dashboard"; then
    log_info "Stopping existing dashboard process..."
    pm2 stop agencystack-dashboard || true
    pm2 delete agencystack-dashboard || true
  fi
  
  # Start the dashboard process
  log_info "Starting dashboard process with pm2..."
  cd "${DASHBOARD_DIR}" || return 1
  pm2 start ecosystem.config.js || {
    log_error "Failed to start dashboard process"
    return 1
  }
  
  # Save the pm2 process list so it survives reboots
  log_info "Saving pm2 process list..."
  pm2 save || {
    log_warning "Failed to save pm2 process list, dashboard may not auto-start after reboot"
  }
  
  # Set up pm2 to start on boot
  log_info "Setting up pm2 to start on boot..."
  pm2 startup || {
    log_warning "Failed to set up pm2 startup, dashboard may not auto-start after reboot"
  }
  
  log_success "Process manager setup complete"
  return 0
}

# Configure reverse proxy with Traefik
configure_reverse_proxy() {
  log_info "Configuring reverse proxy"
  
  # Check if Traefik is installed
  if [[ -d "/opt/agency_stack/apps/traefik" ]]; then
    local traefik_dir="/opt/agency_stack/apps/traefik"
  elif [[ -n "$CLIENT_ID" && -d "/opt/agency_stack/clients/${CLIENT_ID}/apps/traefik" ]]; then
    local traefik_dir="/opt/agency_stack/clients/${CLIENT_ID}/apps/traefik"
  else
    # Try to create the directory if it doesn't exist
    local traefik_dir="/opt/agency_stack/apps/traefik"
    sudo mkdir -p "${traefik_dir}/conf.d"
    if [[ ! -d "${traefik_dir}/conf.d" ]]; then
      log_warning "Could not create Traefik config directory, skipping reverse proxy configuration"
      log_info "You may need to manually configure your reverse proxy to forward traffic to the dashboard"
      log_info "The dashboard is running on port ${DASHBOARD_PORT}"
      return 0
    fi
  fi
  
  # Create dashboard.toml file for Traefik
  local dashboard_domain="${DOMAIN}"
  
  mkdir -p "${traefik_dir}/conf.d"
  cat > "${traefik_dir}/conf.d/dashboard.toml" <<EOF
[http.routers.dashboard]
  rule = "Host(\`${dashboard_domain}\`) && PathPrefix(\`/dashboard\`)"
  entryPoints = ["websecure"]
  service = "dashboard"
  middlewares = ["dashboard-stripprefix"]
  [http.routers.dashboard.tls]
    certResolver = "letsencrypt"

[http.services.dashboard]
  [http.services.dashboard.loadBalancer]
    [[http.services.dashboard.loadBalancer.servers]]
      url = "http://127.0.0.1:${DASHBOARD_PORT}"

[http.middlewares.dashboard-stripprefix.stripPrefix]
  prefixes = ["/dashboard"]
EOF

  # Check if the Traefik service is running and reload if it is
  if docker ps | grep -q "traefik"; then
    log_info "Reloading Traefik configuration"
    docker kill --signal=HUP $(docker ps | grep "traefik" | awk '{print $1}') 2>/dev/null || true
  fi
  
  # Alternatively, if Traefik is running as a systemd service
  if systemctl is-active --quiet traefik.service; then
    log_info "Reloading Traefik service"
    systemctl reload traefik.service 2>/dev/null || true
  fi
  
  log_info "Reverse proxy configuration complete"
  return 0
}

# Create installation marker
create_installed_marker() {
  log_info "Creating installation marker"
  
  local marker_dir="/opt/agency_stack/dashboard"
  if [[ -n "$CLIENT_ID" ]]; then
    marker_dir="/opt/agency_stack/clients/${CLIENT_ID}/dashboard"
  fi
  
  # Write installation details to marker file
  cat > "${marker_dir}/.installed_ok" <<EOF
# AgencyStack Dashboard Installation Marker
# Generated: $(date)
# Version: 1.0.0
# Installed By: ${USER:-root}
# Installation Directory: ${DASHBOARD_DIR}
# Domain: ${DOMAIN}
# Client ID: ${CLIENT_ID:-global}
EOF
  
  chmod 644 "${marker_dir}/.installed_ok"
  log_info "Installation marker created at ${marker_dir}/.installed_ok"
  return 0
}

# Main installation process
main() {
  log_info "Starting Next.js dashboard installation"
  
  # Check if already installed and not forced
  local marker_dir="/opt/agency_stack/dashboard"
  if [[ -n "$CLIENT_ID" ]]; then
    marker_dir="/opt/agency_stack/clients/${CLIENT_ID}/dashboard"
  fi
  
  if [[ -f "${marker_dir}/.installed_ok" && "$FORCE" != "true" ]]; then
    log_info "Dashboard already installed. Use --force to reinstall."
    return 0
  fi
  
  # Setup directories
  ensure_directories || {
    log_error "Failed to create required directories"
    return 1
  }
  
  # Check Keycloak if enabled
  check_keycloak || {
    log_error "Keycloak check failed"
    return 1
  }
  
  # Check Node.js
  check_nodejs || {
    log_error "Failed to setup Node.js environment"
    return 1
  }
  
  # Setup dashboard source
  setup_dashboard_source || {
    log_error "Failed to setup dashboard source code"
    return 1
  }
  
  # Generate environment config
  generate_env_config || {
    log_error "Failed to generate environment configuration"
    return 1
  }
  
  # Build dashboard
  build_dashboard || {
    log_error "Failed to build dashboard application"
    return 1
  }
  
  # Setup process manager
  setup_process_manager || {
    log_error "Failed to setup process manager"
    return 1
  }
  
  # Configure reverse proxy
  configure_reverse_proxy || {
    log_error "Failed to configure reverse proxy"
    # Continue even if reverse proxy configuration fails
  }
  
  # Create installation marker
  create_installed_marker || {
    log_error "Failed to create installation marker"
    return 1
  }
  
  log_info "Dashboard installation completed successfully"
  log_info "Dashboard URL: https://${DOMAIN}/dashboard"
  log_success "Dashboard installation completed"
  return 0
}

# Run main function
main
exit $?
