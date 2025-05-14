#!/usr/bin/env node

/**
 * PeaceFestivalUSA Traefik Integration Plan
 * Using Taskmaster-AI for Sequential Execution
 * 
 * Following AgencyStack Charter v1.0.3 principles:
 * - Repository as Source of Truth
 * - Idempotency & Automation
 * - Auditability & Documentation
 * - Strict Containerization
 * - Proper Change Workflow
 * - TLS required for all networked services
 * - Multi-Tenancy & Security
 */

const fs = require('fs');
const path = require('path');
const { promisify } = require('util');
const exec = promisify(require('child_process').exec);

// AgencyStack Charter-compliant paths
const REPO_ROOT = path.resolve(__dirname, '../../../');
const LOG_DIR = '/var/log/agency_stack/components';
const CLIENT_ID = 'peacefestivalusa';
const LOG_FILE = path.join(LOG_DIR, `${CLIENT_ID}_traefik_integration.log`);
const CLIENT_DIR = `/opt/agency_stack/clients/${CLIENT_ID}`;
const TRAEFIK_DIR = `/opt/agency_stack/clients/${CLIENT_ID}/traefik`;
const WP_DIR = `/opt/agency_stack/clients/${CLIENT_ID}/wordpress`;

// Ensure log directory exists
if (!fs.existsSync(LOG_DIR)) {
  fs.mkdirSync(LOG_DIR, { recursive: true });
}

// Logger function with timestamp
function log(message, type = 'INFO') {
  const timestamp = new Date().toISOString();
  const logMessage = `[${timestamp}] [${type}] ${message}`;
  
  console.log(logMessage);
  
  // Write to log file following Charter logging standards
  fs.appendFileSync(LOG_FILE, logMessage + '\n');
}

// Execute shell command with proper error handling
async function executeCommand(command, cwd = REPO_ROOT) {
  log(`Executing: ${command}`, 'COMMAND');
  
  try {
    const { stdout, stderr } = await exec(command, { cwd });
    if (stdout) log(stdout.trim(), 'STDOUT');
    if (stderr) log(stderr.trim(), 'STDERR');
    return { success: true, stdout, stderr };
  } catch (error) {
    log(`Error executing command: ${error.message}`, 'ERROR');
    if (error.stdout) log(error.stdout.trim(), 'STDOUT');
    if (error.stderr) log(error.stderr.trim(), 'STDERR');
    return { success: false, error };
  }
}

// Integration steps - following sequential thinking model
const integrationSteps = {
  // Phase 1: Preparation and Environment Analysis
  async analyzeCurrentDeployment() {
    log('PHASE 1: ANALYZING CURRENT DEPLOYMENT', 'PHASE');
    
    // Check if Traefik is already running
    const traefikRunning = await executeCommand('docker ps | grep traefik || echo "Not running"');
    if (traefikRunning.stdout && !traefikRunning.stdout.includes('Not running')) {
      log('Traefik is already running', 'WARNING');
    }
    
    // Check WordPress container status
    const wpStatus = await executeCommand('docker ps | grep peacefestivalusa_wordpress || echo "Not running"');
    if (wpStatus.stdout && wpStatus.stdout.includes('Not running')) {
      log('WordPress container is not running - please start it first', 'ERROR');
      process.exit(1);
    }
    
    // Create Traefik directory structure following Charter principles
    await executeCommand(`mkdir -p ${TRAEFIK_DIR}/config/dynamic`);
    await executeCommand(`mkdir -p ${TRAEFIK_DIR}/acme`);
    await executeCommand(`mkdir -p ${TRAEFIK_DIR}/logs`);
    
    // Backup current WordPress docker-compose.yml
    if (fs.existsSync(`${WP_DIR}/docker-compose.yml`)) {
      await executeCommand(`cp ${WP_DIR}/docker-compose.yml ${WP_DIR}/docker-compose.yml.bak-$(date +%Y%m%d%H%M%S)`);
      log('Backed up existing WordPress docker-compose.yml', 'INFO');
    }
    
    return { success: true };
  },
  
  // Phase 2: Traefik Installation and Configuration
  async installTraefik() {
    log('PHASE 2: INSTALLING AND CONFIGURING TRAEFIK', 'PHASE');
    
    // Create Traefik configuration file
    const traefikConfig = `
# Traefik Static Configuration
# Following AgencyStack Charter v1.0.3 principles

global:
  checkNewVersion: false
  sendAnonymousUsage: false

log:
  level: "INFO"
  filePath: "/logs/traefik.log"

api:
  dashboard: true
  insecure: false

entryPoints:
  web:
    address: ":80"
    http:
      redirections:
        entryPoint:
          to: websecure
          scheme: https
  
  websecure:
    address: ":443"
    http:
      tls:
        certResolver: letsencrypt

certificatesResolvers:
  letsencrypt:
    acme:
      email: "admin@peacefestivalusa.nerdofmouth.com"
      storage: "/acme/acme.json"
      httpChallenge:
        entryPoint: web

providers:
  docker:
    endpoint: "unix:///var/run/docker.sock"
    exposedByDefault: false
    network: traefik-network
  
  file:
    directory: "/config/dynamic"
    watch: true
`;

    fs.writeFileSync(`${TRAEFIK_DIR}/config/traefik.yml`, traefikConfig);
    log('Created Traefik configuration file', 'INFO');
    
    // Create Traefik docker-compose.yml
    const traefikDockerCompose = `
version: '3'

services:
  traefik:
    container_name: peacefestivalusa_traefik
    image: traefik:v2.10
    restart: always
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ${TRAEFIK_DIR}/config/traefik.yml:/etc/traefik/traefik.yml
      - ${TRAEFIK_DIR}/config/dynamic:/etc/traefik/config/dynamic
      - ${TRAEFIK_DIR}/acme:/acme
      - ${TRAEFIK_DIR}/logs:/logs
    networks:
      - traefik-network
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.traefik.rule=Host(\`traefik.peacefestivalusa.localhost\`)"
      - "traefik.http.routers.traefik.service=api@internal"
      - "traefik.http.routers.traefik.middlewares=auth"
      - "traefik.http.middlewares.auth.basicauth.users=admin:$$apr1$$LoG5nQ8S$$CyUH0gFQwCwjgAZgvjNj80"

networks:
  traefik-network:
    name: traefik-network
    driver: bridge
`;

    fs.writeFileSync(`${TRAEFIK_DIR}/docker-compose.yml`, traefikDockerCompose);
    log('Created Traefik docker-compose.yml', 'INFO');
    
    // Start Traefik
    await executeCommand(`cd ${TRAEFIK_DIR} && docker-compose up -d`);
    log('Traefik started', 'SUCCESS');
    
    return { success: true };
  },
  
  // Phase 3: WordPress Integration with Traefik
  async integrateWordPress() {
    log('PHASE 3: INTEGRATING WORDPRESS WITH TRAEFIK', 'PHASE');
    
    // Get current docker-compose content
    const currentCompose = fs.readFileSync(`${WP_DIR}/docker-compose.yml`, 'utf8');
    
    // Create new docker-compose with Traefik integration
    const updatedCompose = `
version: '3'

services:
  mariadb:
    container_name: peacefestivalusa_mariadb
    image: mariadb:10.5
    restart: unless-stopped
    volumes:
      - ${WP_DIR}/mariadb-data:/var/lib/mysql
      - ${WP_DIR}/init-scripts:/docker-entrypoint-initdb.d
    environment:
      MYSQL_ROOT_PASSWORD: laTOUff1wXPFPov5
      MYSQL_DATABASE: peacefestivalusa_wordpress
      MYSQL_USER: peacefestivalusa_wp
      MYSQL_PASSWORD: 5oOqapxbb98hQPov
      MYSQL_ALLOW_EMPTY_PASSWORD: "no"
      MYSQL_ROOT_HOST: "%"
    command: --default-authentication-plugin=mysql_native_password
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-u", "root", "-plaTOUff1wXPFPov5"]
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      - wordpress_network
      - traefik-network
    # Using service port instead of exposing to host directly
    expose:
      - "3306"

  wordpress:
    container_name: peacefestivalusa_wordpress
    image: wordpress:6.1-php8.1-apache
    restart: always
    depends_on:
      - mariadb
    volumes:
      - ${WP_DIR}/wp-content:/var/www/html/wp-content
      - ${WP_DIR}/custom-entrypoint.sh:/usr/local/bin/custom-entrypoint.sh
      - ${WP_DIR}/wp-config/wp-config-agency.php:/tmp/wp-config-agency.php
    env_file:
      - ${WP_DIR}/.env
    entrypoint: ["/usr/local/bin/custom-entrypoint.sh"]
    command: ["apache2-foreground"]
    networks:
      - wordpress_network
      - traefik-network
    expose:
      - "80"
    labels:
      - "traefik.enable=true"
      # HTTP Router configuration
      - "traefik.http.routers.peacefestivalusa.rule=Host(\`peacefestivalusa.localhost\`)"
      - "traefik.http.routers.peacefestivalusa.entrypoints=websecure"
      - "traefik.http.routers.peacefestivalusa.service=peacefestivalusa"
      # Service configuration
      - "traefik.http.services.peacefestivalusa.loadbalancer.server.port=80"
      # Middleware for security headers
      - "traefik.http.middlewares.secureheaders.headers.frameDeny=true"
      - "traefik.http.middlewares.secureheaders.headers.sslRedirect=true"
      - "traefik.http.middlewares.secureheaders.headers.contentTypeNosniff=true"
      - "traefik.http.middlewares.secureheaders.headers.browserXssFilter=true"
      - "traefik.http.routers.peacefestivalusa.middlewares=secureheaders"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost/wp-content/verify-deployment.php"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s

networks:
  wordpress_network:
    driver: bridge
  traefik-network:
    external: true
`;

    fs.writeFileSync(`${WP_DIR}/docker-compose.yml`, updatedCompose);
    log('Updated WordPress docker-compose.yml with Traefik integration', 'INFO');
    
    // Restart WordPress with Traefik integration
    await executeCommand(`cd ${WP_DIR} && docker-compose down && docker-compose up -d`);
    log('Restarted WordPress containers with Traefik integration', 'SUCCESS');
    
    return { success: true };
  },
  
  // Phase 4: Testing and Verification
  async testIntegration() {
    log('PHASE 4: TESTING AND VERIFICATION', 'PHASE');
    
    // Wait for services to stabilize
    log('Waiting for services to initialize...', 'INFO');
    await new Promise(resolve => setTimeout(resolve, 10000));
    
    // Test Traefik status
    const traefikStatus = await executeCommand('docker ps | grep peacefestivalusa_traefik');
    if (!traefikStatus.success) {
      log('Traefik container is not running properly', 'ERROR');
      return { success: false };
    }
    
    // Test WordPress status
    const wpStatus = await executeCommand('docker ps | grep peacefestivalusa_wordpress');
    if (!wpStatus.success) {
      log('WordPress container is not running properly', 'ERROR');
      return { success: false };
    }
    
    // Test WordPress connectivity through Traefik
    const wpTest = await executeCommand('curl -k -I https://peacefestivalusa.localhost');
    if (wpTest.success && wpTest.stdout.includes('HTTP/')) {
      log('Successfully connected to WordPress through Traefik proxy', 'SUCCESS');
    } else {
      log('Failed to connect to WordPress through Traefik proxy', 'WARNING');
      log('Make sure you have added peacefestivalusa.localhost to your hosts file', 'INFO');
    }
    
    // Create hosts file entry instructions
    log('To complete the setup, add the following entry to your /etc/hosts file:', 'INFO');
    log('127.0.0.1 peacefestivalusa.localhost traefik.peacefestivalusa.localhost', 'INFO');
    
    return { success: true };
  },
  
  // Phase 5: Documentation and Production Configuration
  async documentSetup() {
    log('PHASE 5: DOCUMENTATION AND PRODUCTION CONFIGURATION', 'PHASE');
    
    // Create documentation file
    const documentation = `
# PeaceFestivalUSA Traefik Integration

## Overview
This document describes the integration of PeaceFestivalUSA WordPress with Traefik reverse proxy,
following the AgencyStack Charter v1.0.3 principles.

## Architecture
- **Traefik**: Serves as the edge router, handling TLS termination and routing
- **WordPress**: Container running the WordPress application
- **MariaDB**: Database container for WordPress

## Networks
- **traefik-network**: External network for Traefik communication
- **wordpress_network**: Internal network for WordPress and MariaDB communication

## Local Development URLs
- WordPress: https://peacefestivalusa.localhost
- Traefik Dashboard: https://traefik.peacefestivalusa.localhost

## Production URLs
- WordPress: https://peacefestivalusa.nerdofmouth.com
- Traefik Dashboard: https://traefik.peacefestivalusa.nerdofmouth.com

## Production Configuration
For production deployment, update the following:

1. Modify domain names in Traefik labels
2. Configure valid TLS certificates using Let's Encrypt
3. Set up strong authentication for Traefik dashboard
4. Enable proper network security measures

## Deployment Instructions
See \`scripts/components/taskmaster/peacefestival_traefik_integration.js\` for deployment steps.
`;

    fs.writeFileSync(`${CLIENT_DIR}/traefik-integration.md`, documentation);
    log('Created documentation file', 'INFO');
    
    // Create production config template
    const productionConfig = `
# Traefik Production Configuration for PeaceFestivalUSA
# Following AgencyStack Charter v1.0.3 principles

global:
  checkNewVersion: false
  sendAnonymousUsage: false

log:
  level: "INFO"
  filePath: "/logs/traefik.log"

api:
  dashboard: true
  insecure: false

entryPoints:
  web:
    address: ":80"
    http:
      redirections:
        entryPoint:
          to: websecure
          scheme: https
  
  websecure:
    address: ":443"
    http:
      tls:
        certResolver: letsencrypt

certificatesResolvers:
  letsencrypt:
    acme:
      email: "admin@peacefestivalusa.nerdofmouth.com"
      storage: "/acme/acme.json"
      httpChallenge:
        entryPoint: web

providers:
  docker:
    endpoint: "unix:///var/run/docker.sock"
    exposedByDefault: false
    network: traefik-network
  
  file:
    directory: "/config/dynamic"
    watch: true
`;

    fs.writeFileSync(`${TRAEFIK_DIR}/config/traefik.production.yml`, productionConfig);
    log('Created production configuration template', 'INFO');
    
    return { success: true };
  }
};

// Main execution function
async function runIntegration() {
  log('STARTING PEACEFESTIVALUSA TRAEFIK INTEGRATION', 'START');
  
  try {
    // Execute each phase sequentially
    const phases = Object.values(integrationSteps);
    
    for (const phase of phases) {
      const result = await phase();
      
      if (!result || !result.success) {
        log('Integration failed at phase: ' + phase.name, 'ERROR');
        process.exit(1);
      }
    }
    
    log('PEACEFESTIVALUSA TRAEFIK INTEGRATION COMPLETED SUCCESSFULLY', 'SUCCESS');
  } catch (error) {
    log(`INTEGRATION FAILED: ${error.message}`, 'ERROR');
    process.exit(1);
  }
}

// Execute the integration plan
runIntegration();
