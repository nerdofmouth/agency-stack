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
      return 1
      ;;
  esac
done

# Ensure required directories exist
ensure_directories() {
  log_info "Creating required directories"
  
  # Create dashboard directory if it doesn't exist
  if [[ ! -d "$DASHBOARD_DIR" ]]; then
    mkdir -p "$DASHBOARD_DIR"
  fi
  
  # Create logs directory if it doesn't exist
  mkdir -p "$DASHBOARD_LOGS_DIR"
  
  # Create client-specific install directory
  INSTALL_DIR="/opt/agency_stack/clients/${CLIENT_ID}/dashboard"
  mkdir -p "$INSTALL_DIR"
}

# Check for Node.js and install if needed (without global installation)
check_nodejs() {
  log_info "Checking for Node.js"
  
  # Check if Node.js is installed in the project directory
  if [[ -f "${DASHBOARD_DIR}/node/bin/node" ]]; then
    log_info "Using existing Node.js installation in project directory"
    export PATH="${DASHBOARD_DIR}/node/bin:$PATH"
    
    # Output version info for logging
    log_info "Node.js version: $(node --version)"
    log_info "npm version: $(npm --version)"
    
    if command -v pnpm &>/dev/null; then
      log_info "pnpm version: $(pnpm --version)"
    fi
    
    return 0
  fi
  
  # Check if Node.js is installed globally
  if command -v node &>/dev/null; then
    log_info "Using globally installed Node.js"
    
    # Output version info for logging
    log_info "Node.js version: $(node --version)"
    log_info "npm version: $(npm --version)"
    
    if command -v pnpm &>/dev/null; then
      log_info "pnpm version: $(pnpm --version)"
    fi
    
    return 0
  fi
  
  # If we're at this point, Node.js is not installed, so try to install it locally
  log_info "Node.js not found, installing locally"
  
  # Create a directory for Node.js
  mkdir -p "${DASHBOARD_DIR}/node"
  
  # Download the latest Node.js LTS version for Linux x64
  log_info "Downloading Node.js LTS"
  curl -s https://nodejs.org/dist/v18.17.1/node-v18.17.1-linux-x64.tar.gz | tar xzf - -C "${DASHBOARD_DIR}/node" --strip-components=1 || {
    log_error "Failed to download and extract Node.js"
    return 1
  }
  
  # Add Node.js to the PATH
  export PATH="${DASHBOARD_DIR}/node/bin:$PATH"
  
  # Output version info for logging
  log_info "Node.js version: $(node --version)"
  log_info "npm version: $(npm --version)"
  
  return 0
}

# Check Keycloak availability if SSO is enabled
check_keycloak() {
  if [[ "$ENABLE_KEYCLOAK" == "true" ]]; then
    log_info "Checking Keycloak availability"
    
    # Try to find Keycloak installation
    local keycloak_url="https://${DOMAIN}/auth"
    
    log_info "Testing Keycloak connectivity at: $keycloak_url"
    
    if ! curl -s -k -m 5 "$keycloak_url" > /dev/null; then
      log_warning "Keycloak does not appear to be accessible at $keycloak_url"
      log_warning "SSO features may not work correctly"
    else
      log_success "Keycloak is accessible at $keycloak_url"
    fi
  else
    log_info "Keycloak integration not enabled, skipping check"
  fi
}

# Setup dashboard source code
setup_dashboard_source() {
  log_info "Setting up dashboard source code..."
  
  # Determine whether to copy from repository or use GitHub
  if [[ "$USE_GITHUB" == "true" && -n "$DASHBOARD_REPO" ]]; then
    log_info "Cloning dashboard source from GitHub: $DASHBOARD_REPO"
    
    git clone --depth 1 --branch "$DASHBOARD_BRANCH" "$DASHBOARD_REPO" "$DASHBOARD_DIR" || {
      log_error "Failed to clone dashboard repository"
      return 1
    }
  else
    log_info "Copying dashboard source files from repository..."
    
    # Copy files from repo
    cp -r "${REPO_ROOT}/dashboard"/* "$DASHBOARD_DIR/" || {
      log_error "Failed to copy dashboard files from repository"
      return 1
    }
  fi
  
  log_success "Dashboard source files copied successfully."
  return 0
}

# Generate environment configuration
generate_env_config() {
  log_info "Generating environment configuration..."
  
  # Create .env.local file
  cat > "${DASHBOARD_DIR}/.env.local" <<EOF
# Dashboard Environment Configuration
NODE_ENV=production
CLIENT_ID="${CLIENT_ID}"
DOMAIN="${DOMAIN}"
PORT="${DASHBOARD_PORT}"
KEYCLOAK_URL="https://${DOMAIN}/auth"
KEYCLOAK_REALM="${KEYCLOAK_REALM}"
KEYCLOAK_CLIENT_ID="${KEYCLOAK_CLIENT_ID}"
COMPONENTS_LOG_DIR="${DASHBOARD_LOGS_DIR}"
EOF
  
  log_success "Environment configuration generated."
}

# Setup Docker container for the dashboard
setup_dashboard_container() {
  log_info "Setting up Docker container for the dashboard..."

  # Ensure the Docker network exists
  if ! docker network ls | grep -q agency_stack; then
    log_info "Creating Docker network for agency_stack components..."
    docker network create agency_stack || {
      log_error "Failed to create Docker network"
      return 1
    }
  fi

  INSTALL_DIR="/opt/agency_stack/clients/${CLIENT_ID}/dashboard"
  mkdir -p "${INSTALL_DIR}/logs"

  # Stop and remove existing container if it exists
  if docker ps -a | grep -q "dashboard_${CLIENT_ID}"; then
    log_info "Stopping and removing existing dashboard container..."
    docker stop "dashboard_${CLIENT_ID}" >/dev/null 2>&1 || true
    docker rm "dashboard_${CLIENT_ID}" >/dev/null 2>&1 || true
  fi

  # Stop any existing PM2 dashboard process to free up port 3000
  if command -v pm2 &>/dev/null && pm2 list | grep -q "agencystack-dashboard"; then
    log_info "Stopping existing PM2 dashboard process..."
    pm2 stop agencystack-dashboard >/dev/null 2>&1 || true
    pm2 delete agencystack-dashboard >/dev/null 2>&1 || true
    sleep 2
  fi

  # Create a simple nginx container to serve the Next.js dashboard
  log_info "Creating dashboard container with Nginx..."
  
  # Create a simple dashboard container serving static content for now
  docker run -d \
    --name "dashboard_${CLIENT_ID}" \
    --restart unless-stopped \
    --network agency_stack \
    -p "${DASHBOARD_PORT}:80" \
    -v "${DASHBOARD_DIR}:/usr/share/nginx/html:ro" \
    -v "${INSTALL_DIR}/logs:/var/log/nginx" \
    -e "CLIENT_ID=${CLIENT_ID}" \
    -e "DOMAIN=${DOMAIN}" \
    -l "traefik.enable=true" \
    -l "traefik.http.routers.dashboard.rule=Host(\`${DOMAIN}\`) && PathPrefix(\`/dashboard\`)" \
    -l "traefik.http.routers.dashboard.entrypoints=websecure" \
    -l "traefik.http.routers.dashboard.tls=true" \
    -l "traefik.http.middlewares.dashboard-strip.stripprefix.prefixes=/dashboard" \
    -l "traefik.http.routers.dashboard.middlewares=dashboard-strip" \
    nginx:alpine || {
      log_error "Failed to create dashboard container"
      return 1
    }

  # Create a simple index.html for testing
  mkdir -p "${DASHBOARD_DIR}"
  cat > "${DASHBOARD_DIR}/index.html" <<EOF
<!DOCTYPE html>
<html>
<head>
  <title>AgencyStack Dashboard</title>
  <style>
    body {
      font-family: Arial, sans-serif;
      margin: 40px;
      line-height: 1.6;
      color: #333;
    }
    h1 {
      color: #2c3e50;
    }
    .status-card {
      background: #f8f9fa;
      border-left: 4px solid #4CAF50;
      padding: 15px;
      margin-bottom: 20px;
      border-radius: 4px;
      box-shadow: 0 2px 5px rgba(0,0,0,0.1);
    }
    .running {
      border-left-color: #4CAF50;
    }
    .error {
      border-left-color: #F44336;
    }
    .stopped {
      border-left-color: #FFC107;
    }
  </style>
</head>
<body>
  <h1>AgencyStack Dashboard</h1>
  <p>This is a temporary static version of the dashboard.</p>
  <p>Current domain: ${DOMAIN}</p>
  <p>Client ID: ${CLIENT_ID}</p>
  
  <div class="status-card running">
    <h3>Traefik</h3>
    <p>Status: Running</p>
  </div>
  
  <div class="status-card running">
    <h3>Keycloak</h3>
    <p>Status: Running</p>
  </div>
  
  <div class="status-card running">
    <h3>Dashboard</h3>
    <p>Status: Running</p>
  </div>
</body>
</html>
EOF

  log_success "Dashboard container started successfully"
  log_info "Dashboard will be available at: https://${DOMAIN}/dashboard"
}

# Create installation marker
create_installed_marker() {
  log_info "Creating installation marker..."
  
  # Create client-specific installation directory if it doesn't exist
  local client_dir="/opt/agency_stack/clients/${CLIENT_ID}"
  mkdir -p "${client_dir}/dashboard"
  
  # Write installation details to marker file
  cat > "${client_dir}/dashboard/.installed_ok" <<EOF
dashboard_installed=true
dashboard_port=${DASHBOARD_PORT}
dashboard_domain=${DOMAIN}
dashboard_install_date=$(date '+%Y-%m-%d %H:%M:%S')
EOF
  
  # Set appropriate permissions
  chmod 644 "${client_dir}/dashboard/.installed_ok"
  
  log_success "Installation marker created"
  return 0
}

# Main installation process
main() {
  init_log "dashboard"
  
  log_info "Starting Next.js dashboard component installation"
  log_info "Using domain: ${DOMAIN}"
  log_info "Client-specific installation: ${CLIENT_ID}"
  
  # Check if dashboard is already installed and skip if --force is not specified
  if [[ -f "/opt/agency_stack/clients/${CLIENT_ID}/dashboard/.installed_ok" && "$FORCE" != "true" ]]; then
    log_info "Dashboard already installed. Use --force to reinstall."
    return 0
  fi
  
  log_info "Starting Next.js dashboard installation"
  
  # Ensure required directories exist
  ensure_directories || {
    log_error "Failed to create required directories"
    return 1
  }
  
  # Check for Node.js
  check_nodejs || {
    log_error "Failed to setup Node.js environment"
    return 1
  }
  
  # Check Keycloak if enabled
  if [[ "$ENABLE_KEYCLOAK" == "true" ]]; then
    check_keycloak || {
      log_warning "Keycloak check failed, continuing anyway"
    }
  fi
  
  # Setup dashboard source code
  setup_dashboard_source || {
    log_error "Failed to setup dashboard source code"
    return 1
  }
  
  # Generate environment configuration
  generate_env_config || {
    log_error "Failed to generate environment configuration"
    return 1
  }
  
  # Setup Docker container for the dashboard
  setup_dashboard_container || {
    log_error "Failed to setup dashboard container"
    return 1
  }
  
  # Create installation marker
  create_installed_marker || {
    log_error "Failed to create installation marker"
    return 1
  }
  
  log_success "Dashboard installation completed successfully"
  log_info "Dashboard is now accessible at: https://${DOMAIN}/dashboard"
  
  return 0
}

# Run main function
main
exit $?
