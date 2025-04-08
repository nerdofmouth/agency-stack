#!/bin/bash
# Install AgencyStack Dashboard Component
# Installs and configures the Next.js dashboard for monitoring component status

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../utils/common.sh" || {
  echo "Error: Failed to source common utilities"
  exit 1
}

# Initialize logging
init_log "dashboard"
log_info "Starting Next.js dashboard component installation"

# Default values
DASHBOARD_PORT=3000
DASHBOARD_DIR="/opt/agency_stack/apps/dashboard"
DASHBOARD_LOGS_DIR="/var/log/agency_stack/components"
DASHBOARD_REPO="https://github.com/nerdofmouth/agency-stack-dashboard.git"
DASHBOARD_BRANCH="main"

# Parse command-line arguments
DOMAIN=""
ADMIN_EMAIL=""
CLIENT_ID=""
FORCE=false
WITH_DEPS=false
VERBOSE=false
ENABLE_CLOUD=false
ENABLE_OPENAI=false
USE_GITHUB=false

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
    *)
      log_error "Unknown option: $1"
      exit 1
      ;;
  esac
done

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

# Clone or update dashboard source code
setup_dashboard_source() {
  log_info "Setting up dashboard source code"
  
  if [[ -d "${DASHBOARD_DIR}/.git" ]]; then
    log_info "Dashboard repository already exists, updating..."
    cd "$DASHBOARD_DIR" || return 1
    git fetch origin
    git reset --hard "origin/${DASHBOARD_BRANCH}"
    git clean -fdx
  else
    log_info "Cloning dashboard repository..."
    git clone -b "$DASHBOARD_BRANCH" "$DASHBOARD_REPO" "$DASHBOARD_DIR"
    if [[ $? -ne 0 ]]; then
      log_error "Failed to clone dashboard repository"
      return 1
    fi
  fi
  
  log_info "Dashboard source code setup complete"
  return 0
}

# Generate environment configuration
generate_env_config() {
  log_info "Generating environment configuration"
  
  local keycloak_config=""
  local keycloak_client_id="agency-stack-dashboard"
  local keycloak_realm="agency-stack"
  local keycloak_url="https://auth.${DOMAIN:-proto001.alpha.nerdofmouth.com}"
  local api_url="https://${DOMAIN:-proto001.alpha.nerdofmouth.com}/api"
  
  # Check for client-specific Keycloak config
  if [[ -n "$CLIENT_ID" && -f "/opt/agency_stack/clients/${CLIENT_ID}/keycloak/config.json" ]]; then
    keycloak_config="/opt/agency_stack/clients/${CLIENT_ID}/keycloak/config.json"
    log_info "Using client-specific Keycloak config: $keycloak_config"
    
    # Extract values from client config
    if command -v jq &>/dev/null; then
      keycloak_realm=$(jq -r '.realm // "agency-stack"' "$keycloak_config")
      keycloak_url=$(jq -r '.url // "https://auth.proto001.alpha.nerdofmouth.com"' "$keycloak_config")
      keycloak_client_id=$(jq -r '.clients[] | select(.clientId == "agency-stack-dashboard") | .clientId // "agency-stack-dashboard"' "$keycloak_config")
    fi
  # Check for global Keycloak config
  elif [[ -f "/opt/agency_stack/secrets/keycloak.env" ]]; then
    keycloak_config="/opt/agency_stack/secrets/keycloak.env"
    log_info "Using global Keycloak config: $keycloak_config"
    
    # Source the env file to get variables
    # shellcheck disable=SC1090
    source "$keycloak_config"
    
    # Use variables from the sourced file if they exist
    keycloak_realm="${KEYCLOAK_REALM:-$keycloak_realm}"
    keycloak_url="${KEYCLOAK_URL:-$keycloak_url}"
    keycloak_client_id="${KEYCLOAK_CLIENT_ID:-$keycloak_client_id}"
  else
    log_warning "No Keycloak configuration found, using defaults"
  fi
  
  # Create .env.local file
  cat > "${DASHBOARD_DIR}/.env.local" <<EOF
# Generated by AgencyStack installer - $(date)
NEXT_PUBLIC_APP_NAME="AgencyStack Dashboard"
NEXT_PUBLIC_APP_DESCRIPTION="Real-time monitoring of AgencyStack components"
NEXT_PUBLIC_KEYCLOAK_REALM=${keycloak_realm}
NEXT_PUBLIC_KEYCLOAK_URL=${keycloak_url}
NEXT_PUBLIC_KEYCLOAK_CLIENT_ID=${keycloak_client_id}
NEXT_PUBLIC_API_URL=${api_url}
NEXT_PUBLIC_COMPONENT_REGISTRY_PATH="/opt/agency_stack/config/registry/component_registry.json"
NEXT_PUBLIC_LOGS_DIR="/var/log/agency_stack/components"
NEXT_PUBLIC_INSTALL_DIR="/opt/agency_stack"
EOF

  if [[ -n "$CLIENT_ID" ]]; then
    echo "NEXT_PUBLIC_CLIENT_ID=${CLIENT_ID}" >> "${DASHBOARD_DIR}/.env.local"
    echo "NEXT_PUBLIC_CLIENT_INSTALL_DIR=/opt/agency_stack/clients/${CLIENT_ID}" >> "${DASHBOARD_DIR}/.env.local"
  fi
  
  log_info "Environment configuration generated: ${DASHBOARD_DIR}/.env.local"
  return 0
}

# Build the dashboard application
build_dashboard() {
  log_info "Building dashboard application"
  
  cd "$DASHBOARD_DIR" || return 1
  
  log_info "Installing dependencies with pnpm"
  pnpm install --frozen-lockfile
  if [[ $? -ne 0 ]]; then
    log_error "Failed to install dependencies"
    return 1
  fi
  
  log_info "Building Next.js application"
  pnpm build
  if [[ $? -ne 0 ]]; then
    log_error "Failed to build application"
    return 1
  fi
  
  log_info "Dashboard build completed successfully"
  return 0
}

# Setup process manager (pm2) for the dashboard
setup_process_manager() {
  log_info "Setting up process manager"
  
  # Install pm2 if not already installed
  if ! command -v pm2 &>/dev/null; then
    log_info "Installing pm2"
    npm install -g pm2
    if [[ $? -ne 0 ]]; then
      log_error "Failed to install pm2"
      return 1
    fi
  fi
  
  # Create pm2 ecosystem config
  cat > "${DASHBOARD_DIR}/ecosystem.config.js" <<EOF
module.exports = {
  apps: [
    {
      name: "agency-stack-dashboard",
      script: "node_modules/next/dist/bin/next",
      args: "start",
      cwd: "${DASHBOARD_DIR}",
      instances: 1,
      autorestart: true,
      watch: false,
      max_memory_restart: "500M",
      env: {
        NODE_ENV: "production",
        PORT: ${DASHBOARD_PORT}
      },
      log_file: "${DASHBOARD_LOGS_DIR}/dashboard-pm2.log",
      out_file: "${DASHBOARD_LOGS_DIR}/dashboard-out.log",
      error_file: "${DASHBOARD_LOGS_DIR}/dashboard-error.log",
      merge_logs: true,
      time: true
    }
  ]
};
EOF
  
  # Start or restart the application
  cd "$DASHBOARD_DIR" || return 1
  pm2 start ecosystem.config.js --update-env
  
  # Save pm2 configuration so it persists across reboots
  pm2 save
  
  # Set up pm2 to start on system boot if needed
  if ! systemctl is-enabled pm2-root &>/dev/null; then
    pm2 startup
    systemctl enable pm2-root
  fi
  
  log_info "Process manager setup complete"
  return 0
}

# Configure reverse proxy with Traefik
configure_reverse_proxy() {
  log_info "Configuring reverse proxy"
  
  local traefik_dir="/opt/agency_stack/traefik/config"
  if [[ -n "$CLIENT_ID" ]]; then
    traefik_dir="/opt/agency_stack/clients/${CLIENT_ID}/traefik/config"
  fi
  
  if [[ ! -d "$traefik_dir" ]]; then
    log_warning "Traefik config directory not found, skipping reverse proxy configuration"
    return 0
  fi
  
  # Create dashboard.toml file for Traefik
  local dashboard_domain="${DOMAIN:-proto001.alpha.nerdofmouth.com}"
  
  mkdir -p "${traefik_dir}/conf.d"
  cat > "${traefik_dir}/conf.d/dashboard.toml" <<EOF
# AgencyStack Dashboard - Traefik Configuration
# Generated by install_dashboard.sh

[http.routers]
  [http.routers.dashboard]
    rule = "Host(\`${dashboard_domain}\`) && PathPrefix(\`/dashboard\`)"
    entryPoints = ["websecure"]
    service = "dashboard"
    middlewares = ["dashboard-strip"]
    [http.routers.dashboard.tls]
      certResolver = "letsencrypt"

[http.services]
  [http.services.dashboard.loadBalancer]
    [[http.services.dashboard.loadBalancer.servers]]
      url = "http://localhost:${DASHBOARD_PORT}"

[http.middlewares]
  [http.middlewares.dashboard-strip.stripPrefix]
    prefixes = ["/dashboard"]

EOF
  
  log_info "Reverse proxy configured: ${traefik_dir}/conf.d/dashboard.toml"
  
  # Restart Traefik to apply changes
  if systemctl is-active traefik &>/dev/null; then
    log_info "Restarting Traefik to apply configuration"
    systemctl restart traefik
  fi
  
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
# Domain: ${DOMAIN:-proto001.alpha.nerdofmouth.com}
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
  log_info "Dashboard URL: https://${DOMAIN:-proto001.alpha.nerdofmouth.com}/dashboard"
  return 0
}

# Run main function
main
exit $?
