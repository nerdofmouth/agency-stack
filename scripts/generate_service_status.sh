#!/bin/bash
# generate_service_status.sh - Generate service status for AgencyStack Dashboard
# https://stack.nerdofmouth.com

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Variables
CONFIG_ENV="/opt/agency_stack/config.env"
LOG_DIR="/var/log/agency_stack"
LOG_FILE="${LOG_DIR}/service_status-$(date +%Y%m%d-%H%M%S).log"
DASHBOARD_DIR="/opt/agency_stack/dashboard"
STATUS_FILE="${DASHBOARD_DIR}/service_status.json"
PORTS_FILE="/opt/agency_stack/ports/ports.json"

# Create necessary directories
mkdir -p "$LOG_DIR"
mkdir -p "$DASHBOARD_DIR"
mkdir -p "/opt/agency_stack/ports"

# Logging function
log() {
  echo -e "$1" | tee -a "$LOG_FILE"
}

log "${MAGENTA}${BOLD}🔍 AgencyStack Service Discovery${NC}"
log "========================================"
log "$(date)"
log "Server: $(hostname)"
log ""

# Check if config.env exists and source it
if [ -f "$CONFIG_ENV" ]; then
  source "$CONFIG_ENV"
  PRIMARY_DOMAIN=${PRIMARY_DOMAIN:-"example.com"}
else
  log "${YELLOW}Warning: config.env not found, using default values${NC}"
  PRIMARY_DOMAIN="example.com"
fi

# Service category definitions
declare -A CATEGORIES
CATEGORIES=(
  ["traefik"]="Core Infrastructure"
  ["portainer"]="Core Infrastructure"
  ["netmaker"]="Core Infrastructure"
  ["docker"]="Core Infrastructure"
  ["minio"]="Core Infrastructure"
  ["mysql"]="Databases"
  ["postgresql"]="Databases"
  ["mongodb"]="Databases"
  ["mariadb"]="Databases"
  ["keycloak"]="Identity & Auth"
  ["wordpress"]="CMS & Sites"
  ["erpnext"]="Business Applications"
  ["frappe"]="Business Applications"
  ["mailu"]="Communication"
  ["roundcube"]="Communication"
  ["listmonk"]="Communication"
  ["chatwoot"]="Communication"
  ["n8n"]="Automation"
  ["posthog"]="Analytics"
  ["uptime-kuma"]="Monitoring"
  ["loki"]="Monitoring"
  ["grafana"]="Monitoring"
  ["prometheus"]="Monitoring"
  ["cal"]="Scheduling"
  ["focalboard"]="Project Management"
  ["seafile"]="File Sharing"
  ["fail2ban"]="Security & Backups"
  ["restic"]="Security & Backups"
)

# Get all running Docker containers with agencystack in name or label
get_docker_containers() {
  log "${BLUE}Scanning Docker containers...${NC}"
  
  # Initialize the JSON structure
  echo "{" > "$STATUS_FILE"
  echo '  "generated_at": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'",
  "server": "'$(hostname)'",
  "domain": "'$PRIMARY_DOMAIN'",
  "services": [' >> "$STATUS_FILE"
  
  # Detect all installed components
  INSTALLED_COMPONENTS_FILE="/opt/agency_stack/installed_components.txt"
  INSTALLED_COMPONENTS=()
  if [ -f "$INSTALLED_COMPONENTS_FILE" ]; then
    while IFS= read -r component; do
      INSTALLED_COMPONENTS+=("$component")
    done < "$INSTALLED_COMPONENTS_FILE"
  fi
  
  # Initialize ports tracking
  echo "{" > "$PORTS_FILE"
  echo '  "updated_at": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'",
  "ports_in_use": {' >> "$PORTS_FILE"
  
  # Get list of containers
  local containers=$(docker ps --format '{{.Names}}')
  local first_container=true
  local first_port=true
  
  # Loop through each container
  for container in $containers; do
    # Skip non-agency containers unless specifically looking for them
    if [[ ! "$container" =~ agency_stack || "$container" =~ "dashboard" ]]; then
      continue
    fi
    
    # Get container info
    local status=$(docker inspect --format='{{.State.Status}}' $container)
    local created=$(docker inspect --format='{{.Created}}' $container)
    local image=$(docker inspect --format='{{.Config.Image}}' $container)
    
    # Extract service name from container name
    local service=$(echo $container | sed 's/agency_stack_//')
    
    # Get category
    local category="Other"
    for key in "${!CATEGORIES[@]}"; do
      if [[ "$service" == *"$key"* ]]; then
        category="${CATEGORIES[$key]}"
        break
      fi
    done
    
    # Check for traefik labels to get domain
    local domain=""
    local raw_domain=$(docker inspect --format='{{range $k, $v := .Config.Labels}}{{if eq $k "traefik.http.routers.agency-'$service'.rule"}}{{$v}}{{end}}{{end}}' $container)
    if [[ "$raw_domain" == *"Host"* ]]; then
      domain=$(echo $raw_domain | grep -oP '(?<=Host\(`)[^`]+')
    fi
    
    # Get exposed ports
    local ports=$(docker inspect --format='{{range $p, $conf := .NetworkSettings.Ports}}{{if $conf}}{{(index $conf 0).HostPort}}{{end}},{{end}}' $container | sed 's/,$//')
    
    # Get health check status if available
    local health_status=""
    if docker inspect --format='{{if .Config.Healthcheck}}{{.State.Health.Status}}{{else}}none{{end}}' $container 2>/dev/null | grep -q -v "none"; then
      health_status=$(docker inspect --format='{{.State.Health.Status}}' $container)
    else
      health_status=$status
    fi
    
    # Add ports to ports.json
    if [ -n "$ports" ] && [ "$ports" != "," ]; then
      IFS=',' read -ra PORT_ARRAY <<< "$ports"
      for port in "${PORT_ARRAY[@]}"; do
        if [ -n "$port" ]; then
          if [ "$first_port" = true ]; then
            first_port=false
          else
            echo ',' >> "$PORTS_FILE"
          fi
          echo '    "'$port'": {
      "service": "'$service'",
      "container": "'$container'",
      "assigned_at": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'"
    }' >> "$PORTS_FILE"
        fi
      done
    fi
    
    # Determine if this is an installed component
    local is_installed=false
    for component in "${INSTALLED_COMPONENTS[@]}"; do
      if [[ "$component" == *"$service"* ]]; then
        is_installed=true
        break
      fi
    done
    
    # Add to service status JSON
    if [ "$first_container" = true ]; then
      first_container=false
    else
      echo "," >> "$STATUS_FILE"
    fi
    
    echo '    {
      "name": "'$service'",
      "container": "'$container'",
      "status": "'$status'",
      "health": "'$health_status'",
      "category": "'$category'",
      "domain": "'$domain'",
      "ports": "'$ports'",
      "image": "'$image'",
      "created": "'$created'",
      "installed": '$is_installed'
    }' >> "$STATUS_FILE"
  done
  
  # Add non-running but installed components
  for component in "${INSTALLED_COMPONENTS[@]}"; do
    # Check if component already in list
    local already_added=false
    for container in $containers; do
      if [[ "$container" =~ "$component" ]]; then
        already_added=true
        break
      fi
    done
    
    if [ "$already_added" = false ]; then
      # Determine category
      local category="Other"
      for key in "${!CATEGORIES[@]}"; do
        if [[ "$component" == *"$key"* ]]; then
          category="${CATEGORIES[$key]}"
          break
        fi
      done
      
      if [ "$first_container" = true ]; then
        first_container=false
      else
        echo "," >> "$STATUS_FILE"
      fi
      
      echo '    {
      "name": "'$component'",
      "container": "N/A",
      "status": "stopped",
      "health": "unknown",
      "category": "'$category'",
      "domain": "",
      "ports": "",
      "image": "",
      "created": "",
      "installed": true
    }' >> "$STATUS_FILE"
    fi
  done
  
  # Close ports.json
  echo '
  }
}' >> "$PORTS_FILE"
  
  # Close the services array and JSON object
  echo '
  ]
}' >> "$STATUS_FILE"
  
  log "${GREEN}Service discovery complete. Found $(grep -c "name" "$STATUS_FILE") services.${NC}"
}

# Generate Markdown version of the status
generate_markdown() {
  local markdown_file="/home/revelationx/CascadeProjects/foss-server-stack/docs/pages/dashboard.md"
  
  log "${BLUE}Generating Markdown dashboard...${NC}"
  
  echo "# 🧭 AgencyStack Dashboard – System Overview

> **Note:** This file is auto-generated by the \`generate_service_status.sh\` script.
> Do not edit manually as your changes will be overwritten.
> Last updated: $(date)

Welcome to your **AgencyStack HQ** — an admin control panel for managing your full FOSS enterprise platform.

## 🔌 Installed Apps & Services

| Category | Application | Status | Access Link | Notes |
|----------|-------------|--------|------------|-------|" > "$markdown_file"

  # Parse the JSON and append to markdown
  local categories=$(jq -r '.services[].category' "$STATUS_FILE" | sort | uniq)
  
  for category in $categories; do
    echo "| **$category** | | | | |" >> "$markdown_file"
    
    # Get services for this category
    jq -r '.services[] | select(.category=="'"$category"'") | "| '"$category"' | " + .name + " | " + if .status == "running" then "✅ Running" else "🔲 Stopped" end + " | " + if .domain != "" then "https://" + .domain else if .ports != "" then "http://localhost:" + .ports else "N/A" end end + " | " + if .installed then "Installed" else "Not installed" end + " |"' "$STATUS_FILE" >> "$markdown_file"
  done
  
  # Add footer
  echo "
## ⚙️ Status Legend

- ✅ **Running** — Service is live and accessible  
- 🔄 **Configurable** — Requires API key or external account setup  
- 🔲 **Stopped** — Component installed but not running

## 📍 Quick Launch Actions

- \`make health-check\` – Full system diagnostic  
- \`make logs\` – View logs across all services  
- \`make dashboard\` – Refresh this dashboard
- \`make integrate-components\` – Connect all systems together  

> 🧠 *\"Run your agency. Reclaim your agency.\" – The Agency Project by NerdOfMouth*
" >> "$markdown_file"

  log "${GREEN}Markdown dashboard generated at ${markdown_file}${NC}"
}

# Create dashboard directory structure
setup_dashboard_structure() {
  log "${BLUE}Setting up dashboard directory structure...${NC}"
  
  mkdir -p "${DASHBOARD_DIR}/assets"
  
  log "${GREEN}Dashboard directory structure created${NC}"
}

# Main function
main() {
  log "${BLUE}Starting service discovery...${NC}"
  
  # Setup structure
  setup_dashboard_structure
  
  # Get Docker containers
  get_docker_containers
  
  # Generate Markdown
  generate_markdown
  
  log "${GREEN}${BOLD}Service discovery complete!${NC}"
  log "Service status saved to: ${STATUS_FILE}"
}

# Run main function
main
