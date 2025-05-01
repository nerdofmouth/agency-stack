#!/bin/bash

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/../utils/common.sh" ]]; then
  source "${SCRIPT_DIR}/../utils/common.sh"
fi

# Enforce containerization (prevent host contamination)
exit_with_warning_if_host

# AgencyStack Component Installer: launchpad-dashboard.sh
# Path: /scripts/components/install_launchpad-dashboard.sh
#
set -e

# Source common utilities

# Use robust, portable path for helpers
source "$(dirname "$0")/../utils/log_helpers.sh"

# Default configuration
CLIENT_ID="${CLIENT_ID:-default}"
DOMAIN="${DOMAIN:-localhost}"
ADMIN_EMAIL="${ADMIN_EMAIL:-admin@example.com}"
FORCE=false
VERBOSE=false
WITH_DEPS=false
DASHBOARD_PORT=1337
STATUS_PORT=3001

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --client-id=*)
            CLIENT_ID="${1#*=}"
            shift
            ;;
        --domain=*)
            DOMAIN="${1#*=}"
            shift
            ;;
        --admin-email=*)
            ADMIN_EMAIL="${1#*=}"
            shift
            ;;
        --force)
            FORCE=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --with-deps)
            WITH_DEPS=true
            shift
            ;;
        --help)
            echo "Usage: $(basename "$0") [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --client-id=ID        Client ID for multi-tenant setup (default: default)"
            echo "  --domain=DOMAIN       Domain name for installation (default: localhost)"
            echo "  --admin-email=EMAIL   Admin email address (default: admin@example.com)"
            echo "  --force               Force reinstallation even if already installed"
            echo "  --verbose             Show detailed output"
            echo "  --with-deps           Install dependencies as well"
            echo "  --help                Show this help message"
            exit 0
            ;;
        *)
            log_error "Unknown parameter: $1"
            exit 1
            ;;
    esac
done

# Create necessary directories and set permissions
INSTALL_DIR="/opt/agency_stack/clients/${CLIENT_ID}/launchpad-dashboard"
LOG_DIR="/var/log/agency_stack/components"
LOG_FILE="${LOG_DIR}/launchpad-dashboard.log"

log_info "Starting Launchpad Dashboard installation..." "${LOG_FILE}"
log_banner "Installing Launchpad Dashboard" "${LOG_FILE}"

mkdir -p "${INSTALL_DIR}" "$(dirname "${LOG_FILE}")"
mkdir -p "${INSTALL_DIR}/public" "${INSTALL_DIR}/config"

# Function to check if already installed
check_installed() {
    if docker ps -a --format '{{.Names}}' | grep -q "launchpad-dashboard"; then
        return 0
    else
        return 1
    fi
}

# Stop and remove existing containers if force reinstall
if check_installed; then
    if [ "$FORCE" = true ]; then
        log_banner "Removing existing Launchpad Dashboard installation" "${LOG_FILE}"
        log_cmd "docker stop launchpad-dashboard || true" "${LOG_FILE}"
        log_cmd "docker rm launchpad-dashboard || true" "${LOG_FILE}"
    else
        log_success "Launchpad Dashboard is already installed. Use --force to reinstall." "${LOG_FILE}"
        exit 0
    fi

# Create services configuration file
log_banner "Creating configuration files" "${LOG_FILE}"

log_cmd "cat > ${INSTALL_DIR}/config/services.json << 'EOL'
{
  \"services\": [
    {
      \"name\": \"Launchpad Dashboard\",
      \"description\": \"Central access to all services\",
      \"url\": \"https://${DOMAIN}\",
      \"icon\": \"dashboard\",
      \"category\": \"Core\"
    }
  ]
}
EOL" "${LOG_FILE}"

# Create the server.js file
log_cmd "cat > ${INSTALL_DIR}/server.js << 'EOL'
const express = require('express');
const path = require('path');
const fs = require('fs');
const http = require('http');
const https = require('https');
const morgan = require('morgan');
const bodyParser = require('body-parser');
const basicAuth = require('express-basic-auth');

const app = express();
const PORT = process.env.PORT || 1337;

// Middleware
app.use(morgan('combined'));
app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: true }));

// Basic authentication
const users = { 'admin': process.env.ADMIN_PASSWORD || 'change_me_now' };
app.use(basicAuth({
  users,
  challenge: true,
  realm: 'AgencyStack Dashboard'
}));

// Static files
app.use(express.static(path.join(__dirname, 'public')));

// Services endpoint
app.get('/api/services', (req, res) => {
  const services = loadServices();
  res.json(services);
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'ok' });
});

// Load services from configuration
const loadServices = () => {
  try {
    const configFile = path.join(__dirname, 'config', 'services.json');
    if (fs.existsSync(configFile)) {
      const servicesData = fs.readFileSync(configFile);
      return JSON.parse(servicesData);
    } else {
      console.error('Services configuration file not found');
      return { services: [] };
    }
  } catch (error) {
    console.error('Error loading services:', error);
    return { services: [] };
  }
};

// Start server
app.listen(PORT, () => {
  console.log(\`Launchpad Dashboard running on port \${PORT}\`);
});
EOL" "${LOG_FILE}"

# Create the Docker Compose file
log_cmd "cat > ${INSTALL_DIR}/docker-compose.yml << 'EOL'
version: '3'

services:
  dashboard:
    image: node:18-alpine
    container_name: launchpad-dashboard
    working_dir: /app
    volumes:
      - ./:/app
    ports:
      - '${DASHBOARD_PORT}:1337'
    restart: unless-stopped
    command: >
      sh -c 'npm install express morgan body-parser express-basic-auth &&
             node server.js'
    environment:
      - ADMIN_PASSWORD=change_me_now
      - PORT=1337
    networks:
      - agency-network
    labels:
      - 'traefik.enable=true'
      - 'traefik.http.routers.dashboard.rule=Host(`${DOMAIN}`)'
      - 'traefik.http.routers.dashboard.entrypoints=websecure'
      - 'traefik.http.routers.dashboard.tls=true'
      - 'traefik.http.services.dashboard.loadbalancer.server.port=1337'

networks:
  agency-network:
    external: true
EOL" "${LOG_FILE}"

# Create index.html for the dashboard
log_cmd "cat > ${INSTALL_DIR}/public/index.html << 'EOL'
<!DOCTYPE html>
<html lang='en'>
<head>
  <meta charset='UTF-8'>
  <meta name='viewport' content='width=device-width, initial-scale=1.0'>
  <title>AgencyStack Dashboard</title>
  <link rel='stylesheet' href='https://cdn.jsdelivr.net/npm/bootstrap@5.2.3/dist/css/bootstrap.min.css'>
  <link rel='stylesheet' href='https://cdn.jsdelivr.net/npm/bootstrap-icons@1.10.2/font/bootstrap-icons.css'>
  <style>
    body {
      font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
      padding-bottom: 40px;
    }
    .service-card {
      height: 100%;
      transition: transform 0.2s;
      border: none;
      box-shadow: 0 4px 6px rgba(0,0,0,0.1);
    }
    .service-card:hover {
      transform: translateY(-5px);
      box-shadow: 0 8px 15px rgba(0,0,0,0.1);
    }
    .service-icon {
      font-size: 2.5rem;
      margin-bottom: 15px;
    }
    .navbar-brand img {
      height: 30px;
      margin-right: 10px;
    }
    .category-header {
      margin-top: 30px;
      margin-bottom: 20px;
      border-bottom: 1px solid #eaeaea;
      padding-bottom: 10px;
    }
  </style>
</head>
<body>
  <nav class='navbar navbar-expand-lg navbar-dark bg-primary'>
    <div class='container'>
      <a class='navbar-brand' href='#'>
        <i class='bi bi-rocket'></i> AgencyStack Dashboard
      </a>
      <button class='navbar-toggler' type='button' data-bs-toggle='collapse' data-bs-target='#navbarNav'>
        <span class='navbar-toggler-icon'></span>
      </button>
      <div class='collapse navbar-collapse' id='navbarNav'>
        <ul class='navbar-nav ms-auto'>
          <li class='nav-item'>
            <a class='nav-link' href='#' id='refresh-btn'>
              <i class='bi bi-arrow-clockwise'></i> Refresh
            </a>
          </li>
        </ul>
      </div>
    </div>
  </nav>

  <div class='container mt-4'>
    <div class='row'>
      <div class='col-12'>
        <div class='alert alert-info' role='alert'>
          <i class='bi bi-info-circle'></i> Welcome to AgencyStack Dashboard. This central hub provides access to all installed services.
        </div>
      </div>
    </div>

    <div id='services-container'>
      <!-- Services will be loaded here -->
      <div class='text-center py-5'>
        <div class='spinner-border text-primary' role='status'>
          <span class='visually-hidden'>Loading...</span>
        </div>
        <p class='mt-2'>Loading services...</p>
      </div>
    </div>
  </div>

  <footer class='footer mt-auto py-3 bg-light'>
    <div class='container text-center'>
      <span class='text-muted'>AgencyStack &copy; 2025 | <a href='https://stack.nerdofmouth.com' target='_blank'>Documentation</a></span>
    </div>
  </footer>

  <script src='https://cdn.jsdelivr.net/npm/bootstrap@5.2.3/dist/js/bootstrap.bundle.min.js'></script>
  <script>
    document.addEventListener('DOMContentLoaded', function() {
      fetchServices();
      
      document.getElementById('refresh-btn').addEventListener('click', function(e) {
        e.preventDefault();
        fetchServices();
      });
    });

    function fetchServices() {
      fetch('/api/services')
        .then(response => response.json())
        .then(data => {
          renderServices(data);
        })
        .catch(error => {
          console.error('Error fetching services:', error);
          document.getElementById('services-container').innerHTML = 
            '<div class="alert alert-danger">Error loading services. Please try again later.</div>';
        });
    }

    function renderServices(data) {
      const container = document.getElementById('services-container');
      container.innerHTML = '';
      
      if (!data.services || data.services.length === 0) {
        container.innerHTML = '<div class="alert alert-warning">No services found.</div>';
        return;
      }

      // Group by category
      const servicesByCategory = {};
      data.services.forEach(service => {
        const category = service.category || 'Other';
        if (!servicesByCategory[category]) {
          servicesByCategory[category] = [];
        }
        servicesByCategory[category].push(service);
      });

      // Render each category
      Object.keys(servicesByCategory).sort().forEach(category => {
        const services = servicesByCategory[category];
        
        // Create category header
        const categoryHeader = document.createElement('h2');
        categoryHeader.className = 'category-header';
        categoryHeader.textContent = category;
        container.appendChild(categoryHeader);
        
        // Create row for services
        const row = document.createElement('div');
        row.className = 'row row-cols-1 row-cols-md-3 row-cols-lg-4 g-4 mb-4';
        
        services.forEach(service => {
          const col = document.createElement('div');
          col.className = 'col';
          col.innerHTML = `
            <div class="card service-card h-100">
              <div class="card-body text-center">
                <div class="service-icon">
                  <i class="bi bi-${service.icon || 'app'}"></i>
                </div>
                <h5 class="card-title">${service.name}</h5>
                <p class="card-text">${service.description || ''}</p>
              </div>
              <div class="card-footer bg-transparent border-top-0 text-center">
                <a href="${service.url}" class="btn btn-primary" target="_blank">
                  <i class="bi bi-box-arrow-up-right"></i> Launch
                </a>
              </div>
            </div>
          `;
          row.appendChild(col);
        });
        
        container.appendChild(row);
      });
    }
  </script>
</body>
</html>
EOL" "${LOG_FILE}"

# Start the services
log_banner "Starting Launchpad Dashboard services" "${LOG_FILE}"
log_cmd "cd ${INSTALL_DIR} && docker-compose up -d" "${LOG_FILE}"

# Verify installation
if check_installed; then
    # Create installation marker
    echo "$(date)" > "${INSTALL_DIR}/.installed_ok"
    
    # Add to installed components
    if [ -f "/opt/agency_stack/installed_components.txt" ]; then
        if ! grep -q "Launchpad Dashboard" "/opt/agency_stack/installed_components.txt"; then
            echo "Launchpad Dashboard" >> "/opt/agency_stack/installed_components.txt"
        fi
    fi
    
    # Store credentials
    mkdir -p "/opt/agency_stack/secrets/launchpad-dashboard"
    cat > "/opt/agency_stack/secrets/launchpad-dashboard/${DOMAIN}.env" << EOL
# Launchpad Dashboard Credentials for ${DOMAIN}
# Generated on $(date)
# KEEP THIS FILE SECURE

DASHBOARD_URL=https://${DOMAIN}
ADMIN_USERNAME=admin
ADMIN_PASSWORD=change_me_now
EOL

    # Final success message
    log_success "Launchpad Dashboard installed successfully!" "${LOG_FILE}"
    log_info "Dashboard URL: https://${DOMAIN}" "${LOG_FILE}"
    log_info "Admin Username: admin" "${LOG_FILE}"
    log_info "Admin Password: change_me_now (please change this!)" "${LOG_FILE}"
    log_info "Credentials saved to: /opt/agency_stack/secrets/launchpad-dashboard/${DOMAIN}.env" "${LOG_FILE}"
    exit 0
    log_error "Failed to start Launchpad Dashboard container" "${LOG_FILE}"
    log_info "Check the logs for more information" "${LOG_FILE}"
    exit 1
