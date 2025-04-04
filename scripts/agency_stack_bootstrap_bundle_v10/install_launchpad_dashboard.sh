#!/bin/bash
# install_launchpad_dashboard.sh - Central dashboard for accessing all services

echo "📜 Installing Launchpad Dashboard..."

# Source the port manager
source /home/revelationx/CascadeProjects/foss-server-stack/scripts/port_manager.sh

# Default ports
DEFAULT_DASHBOARD_PORT=1337
DEFAULT_STATUS_PORT=3001

# Register the ports and get assigned values
DASHBOARD_PORT=$(register_port "launchpad_dashboard" "$DEFAULT_DASHBOARD_PORT" "flexible")
STATUS_PORT=$(register_port "status_monitor" "$DEFAULT_STATUS_PORT" "flexible")

echo "🔌 Launchpad Dashboard will use port: $DASHBOARD_PORT"
echo "🔌 Status Monitor will use port: $STATUS_PORT"

# Create directory for dashboard
mkdir -p /opt/launchpad-dashboard
mkdir -p /opt/launchpad-dashboard/src
mkdir -p /opt/launchpad-dashboard/config
mkdir -p /opt/launchpad-dashboard/data

# Install required packages
apt-get update
apt-get install -y nodejs npm

# Create the docker-compose file
cat > /opt/launchpad-dashboard/docker-compose.yml <<EOL
version: '3'

services:
  dashboard:
    image: node:16-alpine
    container_name: launchpad_dashboard
    working_dir: /app
    command: sh -c "npm install && npm run start"
    volumes:
      - ./src:/app
      - ./config:/app/config
      - ./data:/app/data
    restart: always
    ports:
      - "$DASHBOARD_PORT:3000"
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.dashboard.rule=Host(\`dashboard.example.com\`)"
      - "traefik.http.routers.dashboard.entrypoints=websecure"
      - "traefik.http.routers.dashboard.tls.certresolver=myresolver"
      - "traefik.http.services.dashboard.loadbalancer.server.port=3000"
      - "traefik.http.routers.dashboard.middlewares=dashboard-auth@file"
    networks:
      - traefik

  # Optional status monitoring integration
  status-monitor:
    image: louislam/uptime-kuma:1
    container_name: status_monitor
    volumes:
      - ./data/uptime-kuma:/app/data
    ports:
      - "$STATUS_PORT:3001"
    restart: always
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.status.rule=Host(\`status.example.com\`)"
      - "traefik.http.routers.status.entrypoints=websecure"
      - "traefik.http.routers.status.tls.certresolver=myresolver"
      - "traefik.http.services.status.loadbalancer.server.port=3001"
      - "traefik.http.routers.status.middlewares=dashboard-auth@file"
    networks:
      - traefik

networks:
  traefik:
    external: true
EOL

# Create package.json for the dashboard
cat > /opt/launchpad-dashboard/src/package.json <<EOL
{
  "name": "launchpad-dashboard",
  "version": "1.0.0",
  "description": "Central dashboard for accessing all services",
  "main": "server.js",
  "scripts": {
    "start": "node server.js",
    "dev": "nodemon server.js"
  },
  "dependencies": {
    "express": "^4.17.1",
    "express-basic-auth": "^1.2.0",
    "dotenv": "^10.0.0",
    "node-fetch": "^2.6.7",
    "pug": "^3.0.2",
    "body-parser": "^1.19.0",
    "cookie-parser": "^1.4.6",
    "compression": "^1.7.4",
    "helmet": "^5.0.2"
  },
  "devDependencies": {
    "nodemon": "^2.0.15"
  }
}
EOL

# Create server.js for the dashboard
cat > /opt/launchpad-dashboard/src/server.js <<EOL
const express = require('express');
const basicAuth = require('express-basic-auth');
const dotenv = require('dotenv');
const path = require('path');
const fs = require('fs');
const bodyParser = require('body-parser');
const cookieParser = require('cookie-parser');
const compression = require('compression');
const helmet = require('helmet');
const fetch = require('node-fetch');

// Load environment variables
dotenv.config({ path: './config/.env' });

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(compression());
app.use(helmet({
  contentSecurityPolicy: false, // Customize as needed
}));
app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: true }));
app.use(cookieParser());
app.use(express.static(path.join(__dirname, 'public')));

// Set view engine
app.set('view engine', 'pug');
app.set('views', path.join(__dirname, 'views'));

// Optional Basic Authentication
if (process.env.USE_AUTH === 'true') {
  app.use(basicAuth({
    users: { [process.env.AUTH_USER]: process.env.AUTH_PASSWORD },
    challenge: true,
    realm: 'Launchpad Dashboard',
  }));
}

// Load services from config file
const loadServices = () => {
  try {
    const configFile = path.join(__dirname, 'config', 'services.json');
    if (fs.existsSync(configFile)) {
      const servicesData = fs.readFileSync(configFile);
      return JSON.parse(servicesData);
    }
    return { categories: [] };
  } catch (error) {
    console.error('Error loading services:', error);
    return { categories: [] };
  }
};

// Routes
app.get('/', (req, res) => {
  const services = loadServices();
  res.render('index', { 
    title: process.env.DASHBOARD_TITLE || 'Launchpad Dashboard',
    services,
    env: process.env
  });
});

// System status endpoint
app.get('/api/status', async (req, res) => {
  try {
    const services = loadServices();
    const statuses = [];

    // Basic status checks (can be expanded)
    for (const category of services.categories) {
      for (const service of category.services) {
        if (service.url) {
          try {
            const response = await fetch(service.url, { 
              method: 'HEAD',
              timeout: 3000
            });
            statuses.push({
              name: service.name,
              url: service.url,
              status: response.ok ? 'up' : 'down',
              statusCode: response.status
            });
          } catch (error) {
            statuses.push({
              name: service.name,
              url: service.url,
              status: 'down',
              error: error.message
            });
          }
        }
      }
    }

    res.json({ statuses });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Start server
app.listen(PORT, () => {
  console.log(`Launchpad Dashboard running on port ${PORT}`);
});
EOL

# Create views directory and templates
mkdir -p /opt/launchpad-dashboard/src/views
mkdir -p /opt/launchpad-dashboard/src/public/css
mkdir -p /opt/launchpad-dashboard/src/public/js
mkdir -p /opt/launchpad-dashboard/src/public/img

# Create base layout template
cat > /opt/launchpad-dashboard/src/views/layout.pug <<EOL
doctype html
html(lang="en")
  head
    meta(charset="UTF-8")
    meta(name="viewport", content="width=device-width, initial-scale=1.0")
    title #{title}
    link(rel="stylesheet", href="https://cdn.jsdelivr.net/npm/bootstrap@5.1.3/dist/css/bootstrap.min.css")
    link(rel="stylesheet", href="https://cdn.jsdelivr.net/npm/font-awesome@4.7.0/css/font-awesome.min.css")
    link(rel="stylesheet", href="/css/style.css")
    block head
  body(class=env.DASHBOARD_THEME || 'light')
    header
      nav.navbar.navbar-expand-lg.navbar-dark.bg-dark
        .container-fluid
          a.navbar-brand(href="/") #{env.DASHBOARD_TITLE || 'Launchpad Dashboard'}
          button.navbar-toggler(type="button", data-bs-toggle="collapse", data-bs-target="#navbarNav")
            span.navbar-toggler-icon
          #navbarNav.collapse.navbar-collapse
            ul.navbar-nav.ms-auto
              if env.STATUS_URL
                li.nav-item
                  a.nav-link(href=env.STATUS_URL, target="_blank") System Status
              if env.DOCS_URL
                li.nav-item
                  a.nav-link(href=env.DOCS_URL, target="_blank") Documentation
              if env.ADMIN_URL
                li.nav-item
                  a.nav-link(href=env.ADMIN_URL, target="_blank") Admin
    
    main.container.py-4
      block content
    
    footer.py-3.mt-4.border-top
      .container.text-center
        p.text-muted #{env.FOOTER_TEXT || ' 2025 FOSS Server Stack'}
    
    script(src="https://cdn.jsdelivr.net/npm/bootstrap@5.1.3/dist/js/bootstrap.bundle.min.js")
    script(src="/js/main.js")
    block scripts
EOL

# Create index template
cat > /opt/launchpad-dashboard/src/views/index.pug <<EOL
extends layout

block content
  h1.mb-4 #{title}
  
  if env.DASHBOARD_DESCRIPTION
    .alert.alert-info.mb-4 #{env.DASHBOARD_DESCRIPTION}
  
  .row
    each category in services.categories
      .col-md-6.mb-4
        .card
          .card-header
            h5.mb-0 #{category.name}
          .card-body
            ul.list-group.list-group-flush
              each service in category.services
                li.list-group-item.d-flex.justify-content-between.align-items-center
                  div
                    i(class="fa fa-" + (service.icon || 'link'))
                    span.ms-2 #{service.name}
                    if service.description
                      small.d-block.text-muted #{service.description}
                  if service.url
                    a.btn.btn-sm.btn-primary(href=service.url, target="_blank")
                      | Open
                      i.fa.fa-external-link.ms-1
                  else
                    span.badge.bg-secondary Not Available
EOL

# Create CSS file
cat > /opt/launchpad-dashboard/src/public/css/style.css <<EOL
body {
  font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
  padding-bottom: 40px;
}

body.dark {
  background-color: #121212;
  color: #eee;
}

body.dark .card {
  background-color: #1e1e1e;
  border-color: #333;
}

body.dark .card-header {
  background-color: #252525;
  color: #eee;
  border-color: #333;
}

body.dark .list-group-item {
  background-color: #1e1e1e;
  color: #eee;
  border-color: #333;
}

body.dark .text-muted {
  color: #aaa !important;
}

.service-card {
  transition: transform 0.2s ease;
}

.service-card:hover {
  transform: translateY(-5px);
}

.logo-img {
  width: 32px;
  height: 32px;
  object-fit: contain;
}
EOL

# Create JS file
cat > /opt/launchpad-dashboard/src/public/js/main.js <<EOL
// Service status check
document.addEventListener('DOMContentLoaded', function() {
  const checkStatuses = async () => {
    try {
      const response = await fetch('/api/status');
      if (response.ok) {
        const data = await response.json();
        
        // Update status indicators
        data.statuses.forEach(service => {
          const statusElement = document.querySelector(`[data-service="${service.name}"]`);
          if (statusElement) {
            statusElement.className = `status-indicator ${service.status}`;
            statusElement.title = `Status: ${service.status} (${service.statusCode || 'N/A'})`;
          }
        });
      }
    } catch (error) {
      console.error('Error checking service statuses:', error);
    }
  };

  // Check initially and then every 60 seconds
  checkStatuses();
  setInterval(checkStatuses, 60000);
});
EOL

# Create services configuration template
cat > /opt/launchpad-dashboard/config/services.json <<EOL
{
  "categories": [
    {
      "name": "Core Services",
      "services": [
        {
          "name": "Portainer",
          "icon": "ship",
          "description": "Container Management",
          "url": "https://portainer.example.com"
        },
        {
          "name": "Keycloak",
          "icon": "key",
          "description": "Identity and Access Management",
          "url": "https://keycloak.example.com"
        },
        {
          "name": "Traefik",
          "icon": "random",
          "description": "Reverse Proxy & SSL",
          "url": "https://traefik.example.com"
        }
      ]
    },
    {
      "name": "Business Applications",
      "services": [
        {
          "name": "ERPNext",
          "icon": "building",
          "description": "Enterprise Resource Planning",
          "url": "https://erp.example.com"
        },
        {
          "name": "KillBill",
          "icon": "money",
          "description": "Billing System",
          "url": "https://billing.example.com"
        },
        {
          "name": "Cal.com",
          "icon": "calendar",
          "description": "Scheduling Platform",
          "url": "https://calendar.example.com"
        }
      ]
    },
    {
      "name": "Content Management",
      "services": [
        {
          "name": "WordPress",
          "icon": "wordpress",
          "description": "Content Management System",
          "url": "https://www.example.com"
        },
        {
          "name": "PeerTube",
          "icon": "video-camera",
          "description": "Video Platform",
          "url": "https://video.example.com"
        },
        {
          "name": "Document Editor",
          "icon": "file-text",
          "description": "Markdown + Lexical",
          "url": "https://docs.example.com"
        }
      ]
    },
    {
      "name": "Tools & Monitoring",
      "services": [
        {
          "name": "Status Monitor",
          "icon": "heartbeat",
          "description": "Uptime Monitoring",
          "url": "https://status.example.com"
        },
        {
          "name": "Netdata",
          "icon": "area-chart",
          "description": "System Monitoring",
          "url": "https://monitor.example.com"
        },
        {
          "name": "n8n",
          "icon": "random",
          "description": "Workflow Automation",
          "url": "https://workflow.example.com"
        }
      ]
    }
  ]
}
EOL

# Create environment configuration template
cat > /opt/launchpad-dashboard/config/.env.example <<EOL
# Dashboard Configuration
PORT=3000
DASHBOARD_TITLE=FOSS Server Stack
DASHBOARD_DESCRIPTION=Central dashboard for all services
DASHBOARD_THEME=dark  # light or dark

# External URLs
STATUS_URL=https://status.example.com
DOCS_URL=https://docs.example.com
ADMIN_URL=https://admin.example.com

# Authentication
USE_AUTH=true
AUTH_USER=admin
AUTH_PASSWORD=change_me_now

# Footer
FOOTER_TEXT= 2025 FOSS Server Stack - Powered by Open Source

# Keycloak Integration (optional)
KEYCLOAK_URL=https://keycloak.example.com
KEYCLOAK_REALM=foss-stack
KEYCLOAK_CLIENT_ID=dashboard
KEYCLOAK_CLIENT_SECRET=your_client_secret
EOL

# Create a basic Traefik middleware configuration for authentication
cat > /opt/launchpad-dashboard/config/traefik-auth.toml <<EOL
[http.middlewares.dashboard-auth.basicAuth]
  users = [
    "admin:$apr1$ruca84Hq$mbjdMZBAG.KWn7vfN/SNK/"  # password: change_me_now
  ]
EOL

# Create service file for the dashboard
cat > /etc/systemd/system/launchpad-dashboard.service <<EOL
[Unit]
Description=Launchpad Dashboard
After=network.target

[Service]
WorkingDirectory=/opt/launchpad-dashboard/src
ExecStart=/usr/bin/node server.js
Restart=always
User=root
Environment=NODE_ENV=production
Environment=PORT=$DASHBOARD_PORT

[Install]
WantedBy=multi-user.target
EOL

# Create a setup.sh script
cat > /opt/launchpad-dashboard/setup.sh <<EOL
#!/bin/bash
# Setup script for Launchpad Dashboard

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root" >&2
  exit 1
fi

# Create config from template
if [ ! -f "/opt/launchpad-dashboard/config/.env" ]; then
  cp /opt/launchpad-dashboard/config/.env.example /opt/launchpad-dashboard/config/.env
  
  # Generate a random password
  RANDOM_PASSWORD=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 16)
  
  # Update the password in .env
  sed -i "s/AUTH_PASSWORD=change_me_now/AUTH_PASSWORD=$RANDOM_PASSWORD/" /opt/launchpad-dashboard/config/.env
  
  # Generate hashed password for Traefik
  HASHED_PASSWORD=$(htpasswd -nb admin "$RANDOM_PASSWORD" | sed -e s/\\$/\\$\\$/g)
  
  # Update the password in traefik-auth.toml
  sed -i "s|admin:.*|\"$HASHED_PASSWORD\"|" /opt/launchpad-dashboard/config/traefik-auth.toml
  
  echo "Generated random password: $RANDOM_PASSWORD"
  echo "Remember to update your service URLs in the config files."
fi

# Install dependencies
cd /opt/launchpad-dashboard/src
npm install

# Start the dashboard
cd /opt/launchpad-dashboard
docker-compose up -d

echo "Launchpad Dashboard setup completed"
EOL

# Make the setup script executable
chmod +x /opt/launchpad-dashboard/setup.sh

echo " Launchpad Dashboard installed successfully!"
echo " Configuration:"
echo "  1. Run the setup script: /opt/launchpad-dashboard/setup.sh"
echo "  2. Update service URLs in /opt/launchpad-dashboard/config/services.json"
echo "  3. Customize dashboard settings in /opt/launchpad-dashboard/config/.env"
echo "  4. Update Traefik configuration to include the auth middleware"
echo " To start the dashboard manually:"
echo "  cd /opt/launchpad-dashboard && docker-compose up -d"
echo " Access your dashboard at: https://dashboard.example.com"
echo " Default credentials (change these immediately):"
echo "  - Username: admin"
echo "  - Password: Generated during setup (shown during setup.sh execution)"
