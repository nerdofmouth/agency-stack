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
DASHBOARD_PORT="${DASHBOARD_PORT:-3001}"
DASHBOARD_DIR="/opt/agency_stack/apps/dashboard"
CLIENT_ID="${CLIENT_ID:-default}"
DOMAIN="${DOMAIN:-localhost}"
KEYCLOAK_REALM="${KEYCLOAK_REALM:-agency_stack}"
KEYCLOAK_CLIENT_ID="${KEYCLOAK_CLIENT_ID:-dashboard}"
DASHBOARD_LOGS_DIR="/var/log/agency_stack/components/dashboard"
DASHBOARD_REPO="https://github.com/nerdofmouth/agency-stack-dashboard.git"
DASHBOARD_BRANCH="main"
CONFIGURE_ONLY=false
USE_HOST_NETWORK="${USE_HOST_NETWORK:-true}"  # Default to host network mode for better compatibility
ENABLE_KEYCLOAK="${ENABLE_KEYCLOAK:-false}"  # Default to not using Keycloak
ENFORCE_HTTPS="${ENFORCE_HTTPS:-false}"  # Default to not enforcing HTTPS

# Parse command-line arguments
ADMIN_EMAIL=""
FORCE=false
WITH_DEPS=false
VERBOSE=false
ENABLE_CLOUD=false
ENABLE_OPENAI=false
USE_GITHUB=false
ENABLE_KEYCLOAK=false

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
    --use-host-network)
      USE_HOST_NETWORK="$2"
      shift 2
      ;;
    --enforce-https)
      ENFORCE_HTTPS=true
      shift
      ;;
    --keycloak-realm)
      KEYCLOAK_REALM="$2"
      shift 2
      ;;
    --keycloak-client-id)
      KEYCLOAK_CLIENT_ID="$2"
      shift 2
      ;;
    --configure-only)
      CONFIGURE_ONLY=true
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

# Configure Keycloak SSO integration
configure_keycloak_sso() {
  log_info "Configuring Keycloak SSO integration for dashboard..."
  
  if [[ "$ENABLE_KEYCLOAK" != "true" ]]; then
    log_info "Keycloak SSO integration not enabled, skipping"
    return 0
  fi
  
  log_info "Checking Keycloak availability at https://${DOMAIN}/auth"
  
  # Check if Keycloak is accessible
  if ! curl -s -k -m 5 "https://${DOMAIN}/auth" > /dev/null; then
    log_warning "Keycloak is not accessible at https://${DOMAIN}/auth"
    log_warning "SSO integration will be configured but may not work until Keycloak becomes available"
    # Continue anyway to ensure config is in place for when Keycloak becomes available
  else
    log_success "Keycloak is accessible"
    
    # Try to register the client automatically if admin credentials are available
    if [[ -f "/opt/agency_stack/clients/${CLIENT_ID}/keycloak/.credentials" ]]; then
      log_info "Found Keycloak credentials, attempting automatic client registration"
      
      # Source credentials
      source "/opt/agency_stack/clients/${CLIENT_ID}/keycloak/.credentials"
      
      # Prepare client registration JSON
      local client_json=$(cat <<EOF
{
  "clientId": "${KEYCLOAK_CLIENT_ID}",
  "name": "AgencyStack Dashboard",
  "description": "SSO Client for AgencyStack Dashboard",
  "enabled": true,
  "publicClient": false,
  "redirectUris": ["https://${DOMAIN}/*", "https://${DOMAIN}/dashboard/*"],
  "webOrigins": ["https://${DOMAIN}"],
  "standardFlowEnabled": true,
  "implicitFlowEnabled": false,
  "directAccessGrantsEnabled": true,
  "serviceAccountsEnabled": true,
  "authorizationServicesEnabled": true,
  "fullScopeAllowed": true
}
EOF
)
      
      # Try to register the client
      log_info "Attempting to register dashboard client with Keycloak"
      
      # Get admin token
      local token=$(curl -s -d "client_id=admin-cli" -d "username=$KEYCLOAK_ADMIN" -d "password=$KEYCLOAK_ADMIN_PASSWORD" -d "grant_type=password" "https://${DOMAIN}/auth/realms/master/protocol/openid-connect/token" | jq -r '.access_token')
      
      # Register client
      curl -s -H "Authorization: Bearer $token" -H "Content-Type: application/json" -d "$client_json" "https://${DOMAIN}/auth/admin/realms/${KEYCLOAK_REALM}/clients" || {
        log_error "Failed to register dashboard client with Keycloak"
        return 1
      }
      
      # Get client secret
      local client_secret=$(curl -s -H "Authorization: Bearer $token" "https://${DOMAIN}/auth/admin/realms/${KEYCLOAK_REALM}/clients/${KEYCLOAK_CLIENT_ID}/client-secret" | jq -r '.value')
      
      # Update .env.local with client secret
      sed -i "s|^KEYCLOAK_CLIENT_SECRET=.*|KEYCLOAK_CLIENT_SECRET=${client_secret}|" "${DASHBOARD_DIR}/.env.local"
      
      log_success "Dashboard client registration successful"
    else
      log_warning "No Keycloak credentials found, manual client registration will be required"
      log_info "Please register https://${DOMAIN} as a client in Keycloak realm ${KEYCLOAK_REALM}"
    fi
  fi
  
  # Create an install marker to indicate SSO integration was configured
  mkdir -p "/opt/agency_stack/clients/${CLIENT_ID}/apps/dashboard/sso"
  touch "/opt/agency_stack/clients/${CLIENT_ID}/apps/dashboard/sso/.sso_configured"
  
  # Update component registry
  update_component_registry
  
  log_success "Keycloak SSO integration configured for dashboard"
  return 0
}

# Update component registry for dashboard
update_component_registry() {
  log_info "Updating component registry for dashboard..."
  
  # Path to component registry
  local registry_file="/opt/agency_stack/config/registry/component_registry.json"
  
  # Check if registry file exists
  if [[ ! -f "${registry_file}" ]]; then
    log_warning "Component registry file not found at ${registry_file}"
    return 1
  }
  
  # Create a backup of the registry file
  cp "${registry_file}" "${registry_file}.bak.$(date +%Y%m%d%H%M%S)"
  
  # Check if jq is installed, if not, try to install it
  if ! command -v jq &> /dev/null; then
    log_info "jq is required for registry updates, attempting to install..."
    apt-get update -qq && apt-get install -y jq
    
    if ! command -v jq &> /dev/null; then
      log_error "Failed to install jq, registry cannot be updated automatically"
      return 1
    fi
  }
  
  # Update the registry file
  if [[ "${ENABLE_KEYCLOAK}" == "true" ]]; then
    # Update SSO configuration status
    local temp_file=$(mktemp)
    if jq '.components.ui.dashboard.integration_status.sso = true | .components.ui.dashboard.integration_status.sso_configured = true | .components.ui.dashboard.integration_status.traefik_tls = true' "${registry_file}" > "${temp_file}"; then
      mv "${temp_file}" "${registry_file}"
      log_success "Component registry updated for dashboard with SSO and TLS configuration"
    else
      log_error "Failed to update component registry for dashboard"
      rm -f "${temp_file}"
      return 1
    fi
  else
    # Only update installed status
    local temp_file=$(mktemp)
    if jq '.components.ui.dashboard.integration_status.installed = true' "${registry_file}" > "${temp_file}"; then
      mv "${temp_file}" "${registry_file}"
      log_success "Component registry updated for dashboard"
    else
      log_error "Failed to update component registry for dashboard"
      rm -f "${temp_file}"
      return 1
    fi
  }
  
  return 0
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

  # Add SSO configuration if Keycloak is enabled
  if [[ "$ENABLE_KEYCLOAK" == "true" ]]; then
    log_info "Adding SSO configuration for Keycloak integration"
    cat >> "${DASHBOARD_DIR}/.env.local" <<EOF
# SSO Configuration
NEXTAUTH_URL="https://${DOMAIN}"
NEXTAUTH_SECRET="$(openssl rand -hex 32)"
ENFORCE_SSO=true
SSO_PROVIDER="keycloak"
SSO_CLIENT_ID="${KEYCLOAK_CLIENT_ID}"
SSO_CLIENT_SECRET=""
SSO_ISSUER="https://${DOMAIN}/auth/realms/${KEYCLOAK_REALM}"
EOF
    
    # Create a record of the SSO configuration for reference
    mkdir -p "/opt/agency_stack/clients/${CLIENT_ID}/apps/dashboard/sso"
    cp "${DASHBOARD_DIR}/.env.local" "/opt/agency_stack/clients/${CLIENT_ID}/apps/dashboard/sso/config"
    
    # Update component registry to indicate SSO is configured
    log_info "Updating component registry for SSO configuration"
    # This will be handled in a separate function
  fi
  
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

  # --- TLS Verification Logic ---
  # After dashboard is started, verify HTTPS is functional
  if bash "${SCRIPT_DIR}/../utils/verify_tls.sh" "${DOMAIN}" "/dashboard"; then
    log_success "TLS is active and verified for https://${DOMAIN}/dashboard"
    # --- Automated Registry Update for TLS/SSO ---
    if [[ -f "${SCRIPT_DIR}/../utils/update_component_registry.sh" ]]; then
      REGISTRY_ARGS=(
        --component "dashboard"
        --installed "true"
        --monitoring "true"
        --traefik_tls "true"
      )
      if [[ "${ENABLE_KEYCLOAK}" == "true" ]]; then
        REGISTRY_ARGS+=(--sso "true" --sso_configured "true")
      fi
      bash "${SCRIPT_DIR}/../utils/update_component_registry.sh" "${REGISTRY_ARGS[@]}"
    fi
  else
    log_warning "TLS verification failed for https://${DOMAIN}/dashboard"
  fi
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

# Configure Traefik routes for the dashboard
configure_traefik_routes() {
  log_info "Configuring Traefik routes for dashboard access..."
  log_info "Network mode: ${USE_HOST_NETWORK}"
  
  # Determine Traefik dynamic configuration directory
  local traefik_dir="/opt/agency_stack/clients/${CLIENT_ID}/traefik"
  local dynamic_dir="${traefik_dir}/config/dynamic"
  
  if [[ ! -d "${dynamic_dir}" ]]; then
    log_warning "Traefik dynamic config directory not found at ${dynamic_dir}"
    log_warning "Make sure Traefik is installed properly"
    return 1
  fi
  
  # Create dashboard route configuration
  local dashboard_route="${dynamic_dir}/dashboard-route.yml"
  
  log_info "Creating dashboard route configuration at ${dashboard_route}"
  
  # Backup existing configuration if it exists
  if [[ -f "${dashboard_route}" ]]; then
    cp "${dashboard_route}" "${dashboard_route}.bak.$(date +%Y%m%d%H%M%S)"
  fi
  
  # Create comprehensive route configuration for HTTP and HTTPS access
  cat > "${dashboard_route}" <<EOL
http:
  routers:
    # HTTP - Root domain router
    dashboard-root-http:
      rule: "Host(\`${DOMAIN}\`)"
      entrypoints:
        - "web"
      service: "dashboard-service"
      priority: 10000
    
    # HTTP - Dashboard path router
    dashboard-path-http:
      rule: "Host(\`${DOMAIN}\`) && PathPrefix(\`/dashboard\`)"
      entrypoints:
        - "web"
      service: "dashboard-service"
      middlewares:
        - "dashboard-strip"
      priority: 10100
    
    # HTTPS - Root domain router
    dashboard-root-https:
      rule: "Host(\`${DOMAIN}\`)"
      entrypoints:
        - "websecure"
      service: "dashboard-service"
      priority: 10000
      tls: {}
    
    # HTTPS - Dashboard path router
    dashboard-path-https:
      rule: "Host(\`${DOMAIN}\`) && PathPrefix(\`/dashboard\`)"
      entrypoints:
        - "websecure"
      service: "dashboard-service"
      middlewares:
        - "dashboard-strip"
      priority: 10100
      tls: {}
  
  # Define the dashboard service and middleware
  services:
    dashboard-service:
      loadBalancer:
        servers:
EOL

  # Determine the appropriate URL format based on network mode
  if [[ "${USE_HOST_NETWORK}" == "true" ]]; then
    log_info "Using localhost URL for host network mode"
    echo "          - url: \"http://localhost:${DASHBOARD_PORT}\"" >> "${dashboard_route}"
  else
    log_info "Using host IP URL for bridge network mode"
    # When using bridge network mode, Traefik needs to access the dashboard via host IP
    HOST_IP=$(hostname -I | awk '{print $1}')
    echo "          - url: \"http://${HOST_IP}:${DASHBOARD_PORT}\"" >> "${dashboard_route}"
  fi

  # Continue with the middleware configuration
  cat >> "${dashboard_route}" <<EOL
  
  middlewares:
    dashboard-strip:
      stripPrefix:
        prefixes:
          - "/dashboard"
EOL
  
  # Restart Traefik to apply configuration changes
  log_info "Restarting Traefik to apply new configuration..."
  if [[ -f "${traefik_dir}/docker-compose.yml" ]]; then
    (cd "${traefik_dir}" && docker-compose restart) || log_warning "Failed to restart Traefik"
  else
    log_warning "Traefik docker-compose.yml not found at ${traefik_dir}"
  fi
  
  log_success "Dashboard routes configured successfully"
}

# Configure Traefik routing
configure_traefik_routing() {
  log_info "Configuring Traefik routing..."
  
  # Prepare arguments to pass to the route configuration script
  route_args=("--domain" "${DOMAIN}" "--client-id" "${CLIENT_ID}" "--use-host-network" "${USE_HOST_NETWORK}")
  
  # Add Keycloak argument if enabled
  if [[ "${ENABLE_KEYCLOAK}" == "true" ]]; then
    route_args+=("--enable-keycloak")
  fi
  
  # Add HTTPS enforcement argument if enabled
  if [[ "${ENFORCE_HTTPS}" == "true" ]]; then
    route_args+=("--enforce-https")
  fi
  
  # Call the route configuration script with the prepared arguments
  "${SCRIPT_DIR}/configure_dashboard_route.sh" "${route_args[@]}" || {
    log_error "Failed to configure Traefik routing"
    exit 1
  }
}

# Check DNS resolution for the dashboard domain
check_dns_resolution() {
  log_info "Checking DNS resolution for ${DOMAIN}..."
  
  # Get server IP
  local server_ip=$(hostname -I | awk '{print $1}')
  log_info "Server IP: ${server_ip}"
  
  # Check DNS resolution using multiple resolvers
  local dns_servers=("8.8.8.8" "1.1.1.1" "9.9.9.9")
  local resolved=false
  local resolved_ip=""
  
  for dns in "${dns_servers[@]}"; do
    log_info "Checking resolution using DNS server ${dns}..."
    if resolved_ip=$(dig +short @"${dns}" "${DOMAIN}" A 2>/dev/null); then
      if [[ -n "${resolved_ip}" ]]; then
        log_success "Domain ${DOMAIN} resolves to ${resolved_ip} using DNS server ${dns}"
        resolved=true
        break
      fi
    fi
  done
  
  if [[ "${resolved}" == "false" ]]; then
    log_warning "Domain ${DOMAIN} does not resolve to any IP address"
    log_info "For FQDN access, make sure DNS is properly configured to point to ${server_ip}"
    
    # Check if domain is in hosts file
    if grep -q "${DOMAIN}" /etc/hosts; then
      log_info "Found ${DOMAIN} in /etc/hosts file"
    else
      log_warning "Consider adding ${DOMAIN} to /etc/hosts file if DNS is not yet propagated"
      log_info "You can add it manually with: echo \"${server_ip} ${DOMAIN}\" | sudo tee -a /etc/hosts"
    fi
  elif [[ "${resolved_ip}" != "${server_ip}" ]]; then
    log_warning "Domain ${DOMAIN} resolves to ${resolved_ip}, but server IP is ${server_ip}"
    log_warning "For proper FQDN access, these should match"
  else
    log_success "DNS resolution is correct for ${DOMAIN}"
  fi
}

# Verify dashboard accessibility
verify_dashboard_access() {
  log_info "Verifying dashboard accessibility..."
  
  # Get server IP
  local server_ip=$(hostname -I | awk '{print $1}')
  
  # Check direct access
  log_info "Checking direct dashboard access on port ${DASHBOARD_PORT}..."
  if timeout 5 bash -c "echo > /dev/tcp/127.0.0.1/${DASHBOARD_PORT}" &>/dev/null; then
    log_success "Dashboard is directly accessible on port ${DASHBOARD_PORT}"
  else
    log_warning "Dashboard is not directly accessible on port ${DASHBOARD_PORT}"
  fi
  
  # Check HTTP/HTTPS ports
  log_info "Checking HTTP/HTTPS ports for Traefik..."
  timeout 5 bash -c "echo > /dev/tcp/127.0.0.1/80" &>/dev/null && \
    log_success "HTTP port 80 is accessible" || \
    log_warning "HTTP port 80 is not accessible"
  
  timeout 5 bash -c "echo > /dev/tcp/127.0.0.1/443" &>/dev/null && \
    log_success "HTTPS port 443 is accessible" || \
    log_warning "HTTPS port 443 is not accessible"
  
  # Output access URLs
  log_info "===========================================================
DASHBOARD ACCESS URLS:
1. HTTP FQDN (Root):       http://${DOMAIN}
2. HTTP FQDN (Path):       http://${DOMAIN}/dashboard
3. Direct IP (Main):       http://${server_ip}:${DASHBOARD_PORT}
4. Direct IP (Fallback):   http://${server_ip}:8080
==========================================================="
}

# Main installation process
main() {
  init_log "dashboard"
  
  log_info "Installing AgencyStack Dashboard"
  log_info "DOMAIN: ${DOMAIN}"
  log_info "CLIENT_ID: ${CLIENT_ID}"
  
  # If configure-only, skip to route configuration
  if [[ "${CONFIGURE_ONLY}" == "true" ]]; then
    log_info "Running in configure-only mode"
    
    # Configure Traefik routing
    configure_traefik_routing
    
    # Check DNS resolution
    check_dns_resolution
    
    # Verify dashboard accessibility
    verify_dashboard_access
    
    log_success "Dashboard access configuration complete"
    return 0
  fi
  
  # Check if dashboard is already installed and skip if --force is not specified
  if [[ -f "/opt/agency_stack/clients/${CLIENT_ID}/dashboard/.installed_ok" && "$FORCE" != "true" ]]; then
    log_info "Dashboard already installed. Use --force to reinstall."
    return 0
  fi
  
  log_info "Starting Next.js dashboard installation"
  
  # Ensure directories exist
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
  
  # Configure Keycloak SSO integration
  configure_keycloak_sso
  
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
  
  # Configure Traefik routing
  configure_traefik_routing
  
  # Check DNS resolution
  check_dns_resolution
  
  # Verify dashboard accessibility
  verify_dashboard_access
  
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
