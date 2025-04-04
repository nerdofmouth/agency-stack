#!/bin/bash
# integrate_monitoring.sh - Monitoring Integration for AgencyStack
# https://stack.nerdofmouth.com

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common functions
source "${SCRIPT_DIR}/integrate_common.sh"

# Monitoring Integration version
MONITORING_VERSION="1.0.1"

# Start logging
LOG_FILE="${INTEGRATION_LOG_DIR}/monitoring-${CURRENT_DATE}.log"
log "${MAGENTA}${BOLD}📊 AgencyStack Monitoring Integration${NC}"
log "========================================================"
log "$(date)"
log "Server: $(hostname)"
log ""

# Non-interactive mode flag
AUTO_MODE=false

# Check command-line arguments
for arg in "$@"; do
  case $arg in
    --yes|--auto)
      AUTO_MODE=true
      ;;
    *)
      # Unknown argument
      ;;
  esac
done

# Get installed components
get_installed_components

# Check if Loki and Grafana are installed
if ! is_component_installed "Loki"; then
  log "${YELLOW}Warning: Loki is not installed${NC}"
  log "Skipping monitoring integration. Install Loki for centralized logging."
fi

if ! is_component_installed "Grafana"; then
  log "${YELLOW}Warning: Grafana is not installed${NC}"
  log "Skipping monitoring visualization. Install Grafana for dashboard capabilities."
fi

# WordPress Monitoring Integration
integrate_wordpress_monitoring() {
  if ! is_component_installed "WordPress"; then
    log "${YELLOW}WordPress not installed, skipping WordPress monitoring integration${NC}"
    return 1
  fi

  if ! is_component_installed "Loki"; then
    log "${YELLOW}Loki not installed, skipping WordPress monitoring integration${NC}"
    return 1
  fi

  log "${BLUE}Setting up WordPress monitoring with Loki...${NC}"
  
  # Check if integration already applied
  if integration_is_applied "monitoring" "WordPress"; then
    log "${GREEN}WordPress monitoring integration already applied${NC}"
    
    # Ask if user wants to re-apply
    if [ "$AUTO_MODE" = false ]; then
      log "${YELLOW}Do you want to re-apply the WordPress monitoring integration? (y/n)${NC}"
      read -r answer
      if [[ ! "$answer" =~ ^[Yy]$ ]]; then
        log "Skipping WordPress monitoring integration"
        return 0
      fi
    else
      # In auto mode, skip re-applying by default
      return 0
    fi
  fi
  
  # Create Loki pipeline for WordPress
  log "${BLUE}Configuring Loki pipeline for WordPress...${NC}"
  
  # Create pipeline directory if it doesn't exist
  LOKI_PIPELINE_DIR="/opt/agency_stack/loki/config/pipeline_stages.d"
  sudo mkdir -p "$LOKI_PIPELINE_DIR"
  
  # Create WordPress pipeline configuration
  WORDPRESS_PIPELINE="${LOKI_PIPELINE_DIR}/wordpress.yaml"
  
  # Create pipeline config
  cat << EOF | sudo tee "$WORDPRESS_PIPELINE" > /dev/null
- match:
    selector: '{container="agency_stack_wordpress"}'
    stages:
      - regex:
          expression: '(?P<timestamp>\d{4}/\d{2}/\d{2} \d{2}:\d{2}:\d{2}) \[(?P<level>[a-zA-Z]+)\] (?P<message>.*)'
      - labels:
          level:
          timestamp:
      - timestamp:
          source: timestamp
          format: "2006/01/02 15:04:05"
EOF
  
  # Create health check endpoint for WordPress
  if is_component_installed "Uptime Kuma"; then
    log "${BLUE}Configuring health check endpoint for WordPress...${NC}"
    
    # Install WP REST API plugin if not already installed
    WP_CLI="/opt/agency_stack/wordpress/wp.sh"
    if [ -f "$WP_CLI" ]; then
      if ! sudo $WP_CLI plugin is-installed wp-rest-api-health-check; then
        log "${BLUE}Installing WordPress health check plugin...${NC}"
        sudo $WP_CLI plugin install wp-rest-api-health-check --activate
      elif ! sudo $WP_CLI plugin is-active wp-rest-api-health-check; then
        log "${BLUE}Activating WordPress health check plugin...${NC}"
        sudo $WP_CLI plugin activate wp-rest-api-health-check
      fi
      
      WP_DOMAIN=$(sudo $WP_CLI option get siteurl || echo "https://wordpress.${PRIMARY_DOMAIN}")
      log "${GREEN}WordPress health endpoint available at: ${WP_DOMAIN}/wp-json/health-check/v1/status${NC}"
    else
      log "${YELLOW}WordPress CLI not available, skipping health check endpoint setup${NC}"
    fi
  fi
  
  # Restart Loki to apply changes
  if is_container_running "agency_stack_loki"; then
    log "${BLUE}Restarting Loki to apply configuration changes...${NC}"
    docker restart agency_stack_loki
  fi
  
  log "${GREEN}✅ WordPress monitoring integration complete${NC}"
  
  # Record integration as applied
  record_integration "monitoring" "WordPress" "$MONITORING_VERSION" "Loki log pipeline configuration for WordPress logs"
  
  return 0
}

# ERPNext Monitoring Integration
integrate_erpnext_monitoring() {
  if ! is_component_installed "ERPNext"; then
    log "${YELLOW}ERPNext not installed, skipping ERPNext monitoring integration${NC}"
    return 1
  fi

  if ! is_component_installed "Loki"; then
    log "${YELLOW}Loki not installed, skipping ERPNext monitoring integration${NC}"
    return 1
  fi

  log "${BLUE}Setting up ERPNext monitoring with Loki...${NC}"
  
  # Check if integration already applied
  if integration_is_applied "monitoring" "ERPNext"; then
    log "${GREEN}ERPNext monitoring integration already applied${NC}"
    
    # Ask if user wants to re-apply
    if [ "$AUTO_MODE" = false ]; then
      log "${YELLOW}Do you want to re-apply the ERPNext monitoring integration? (y/n)${NC}"
      read -r answer
      if [[ ! "$answer" =~ ^[Yy]$ ]]; then
        log "Skipping ERPNext monitoring integration"
        return 0
      fi
    else
      # In auto mode, skip re-applying by default
      return 0
    fi
  fi
  
  # Create Loki pipeline for ERPNext
  log "${BLUE}Configuring Loki pipeline for ERPNext...${NC}"
  
  # Create pipeline directory if it doesn't exist
  LOKI_PIPELINE_DIR="/opt/agency_stack/loki/config/pipeline_stages.d"
  sudo mkdir -p "$LOKI_PIPELINE_DIR"
  
  # Create ERPNext pipeline configuration
  ERPNEXT_PIPELINE="${LOKI_PIPELINE_DIR}/erpnext.yaml"
  
  # Create pipeline config
  cat << EOF | sudo tee "$ERPNEXT_PIPELINE" > /dev/null
- match:
    selector: '{container=~"agency_stack_erpnext.*"}'
    stages:
      - regex:
          expression: '(?P<timestamp>\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2},\d{3}) (?P<level>[A-Z]+) (?P<module>[^:]+): (?P<message>.*)'
      - labels:
          level:
          module:
      - timestamp:
          source: timestamp
          format: "2006-01-02 15:04:05,000"
EOF
  
  # Create health check configuration
  if is_component_installed "Uptime Kuma"; then
    log "${BLUE}Configuring health check endpoint for ERPNext...${NC}"
    log "${YELLOW}Note: ERPNext health check endpoint will be at https://ERPNEXT_DOMAIN/api/method/ping${NC}"
  fi
  
  # Restart Loki to apply changes
  if is_container_running "agency_stack_loki"; then
    log "${BLUE}Restarting Loki to apply configuration changes...${NC}"
    docker restart agency_stack_loki
  fi
  
  log "${GREEN}✅ ERPNext monitoring integration complete${NC}"
  
  # Record integration as applied
  record_integration "monitoring" "ERPNext" "$MONITORING_VERSION" "Loki log pipeline configuration for ERPNext logs"
  
  return 0
}

# Mailu Monitoring Integration
integrate_mailu_monitoring() {
  if ! is_component_installed "Mailu"; then
    log "${YELLOW}Mailu not installed, skipping Mailu monitoring integration${NC}"
    return 1
  fi

  if ! is_component_installed "Loki"; then
    log "${YELLOW}Loki not installed, skipping Mailu monitoring integration${NC}"
    return 1
  fi

  log "${BLUE}Setting up Mailu monitoring with Loki...${NC}"
  
  # Check if integration already applied
  if integration_is_applied "monitoring" "Mailu"; then
    log "${GREEN}Mailu monitoring integration already applied${NC}"
    
    # Ask if user wants to re-apply
    if [ "$AUTO_MODE" = false ]; then
      log "${YELLOW}Do you want to re-apply the Mailu monitoring integration? (y/n)${NC}"
      read -r answer
      if [[ ! "$answer" =~ ^[Yy]$ ]]; then
        log "Skipping Mailu monitoring integration"
        return 0
      fi
    else
      # In auto mode, skip re-applying by default
      return 0
    fi
  fi
  
  # Create Loki pipeline for Mailu
  log "${BLUE}Configuring Loki pipeline for Mailu...${NC}"
  
  # Create pipeline directory if it doesn't exist
  LOKI_PIPELINE_DIR="/opt/agency_stack/loki/config/pipeline_stages.d"
  sudo mkdir -p "$LOKI_PIPELINE_DIR"
  
  # Create Mailu pipeline configuration
  MAILU_PIPELINE="${LOKI_PIPELINE_DIR}/mailu.yaml"
  
  # Create pipeline config
  cat << EOF | sudo tee "$MAILU_PIPELINE" > /dev/null
- match:
    selector: '{container=~"agency_stack_mailu.*"}'
    stages:
      - regex:
          expression: '(?P<timestamp>\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2},\d{3}) (?P<level>[A-Z]+) (?P<message>.*)'
      - labels:
          level:
      - timestamp:
          source: timestamp
          format: "2006-01-02 15:04:05,000"
EOF
  
  # Restart Loki to apply changes
  if is_container_running "agency_stack_loki"; then
    log "${BLUE}Restarting Loki to apply configuration changes...${NC}"
    docker restart agency_stack_loki
  fi
  
  log "${GREEN}✅ Mailu monitoring integration complete${NC}"
  
  # Record integration as applied
  record_integration "monitoring" "Mailu" "$MONITORING_VERSION" "Loki log pipeline configuration for Mailu logs"
  
  return 0
}

# Create Grafana Dashboard
create_grafana_dashboard() {
  if ! is_component_installed "Grafana"; then
    log "${YELLOW}Grafana not installed, skipping dashboard creation${NC}"
    return 1
  fi

  log "${BLUE}Creating AgencyStack Logs Dashboard in Grafana...${NC}"
  
  # Check if integration already applied
  if integration_is_applied "monitoring" "Grafana"; then
    log "${GREEN}Grafana dashboard integration already applied${NC}"
    
    # Ask if user wants to re-apply
    if [ "$AUTO_MODE" = false ]; then
      log "${YELLOW}Do you want to re-apply the Grafana dashboard integration? (y/n)${NC}"
      read -r answer
      if [[ ! "$answer" =~ ^[Yy]$ ]]; then
        log "Skipping Grafana dashboard creation"
        return 0
      fi
    else
      # In auto mode, skip re-applying by default
      return 0
    fi
  fi
  
  # Create dashboard directory if it doesn't exist
  GRAFANA_DASHBOARD_DIR="/opt/agency_stack/grafana/provisioning/dashboards"
  sudo mkdir -p "$GRAFANA_DASHBOARD_DIR"
  
  # Create dashboard JSON
  DASHBOARD_JSON="${GRAFANA_DASHBOARD_DIR}/agencystack-logs.json"
  
  # Create a simple dashboard template
  cat << 'EOF' | sudo tee "$DASHBOARD_JSON" > /dev/null
{
  "annotations": {
    "list": [
      {
        "builtIn": 1,
        "datasource": "-- Grafana --",
        "enable": true,
        "hide": true,
        "iconColor": "rgba(0, 211, 255, 1)",
        "name": "Annotations & Alerts",
        "type": "dashboard"
      }
    ]
  },
  "editable": true,
  "gnetId": null,
  "graphTooltip": 0,
  "id": null,
  "links": [],
  "panels": [
    {
      "datasource": "Loki",
      "gridPos": {
        "h": 8,
        "w": 24,
        "x": 0,
        "y": 0
      },
      "id": 2,
      "options": {
        "showLabels": false,
        "showTime": true,
        "sortOrder": "Descending",
        "wrapLogMessage": true
      },
      "targets": [
        {
          "expr": "{container=~\"agency_stack_.*\"}",
          "refId": "A"
        }
      ],
      "timeFrom": null,
      "timeShift": null,
      "title": "All AgencyStack Logs",
      "type": "logs"
    },
    {
      "datasource": "Loki",
      "gridPos": {
        "h": 8,
        "w": 12,
        "x": 0,
        "y": 8
      },
      "id": 3,
      "options": {
        "showLabels": false,
        "showTime": true,
        "sortOrder": "Descending",
        "wrapLogMessage": true
      },
      "targets": [
        {
          "expr": "{container=~\"agency_stack_wordpress.*\"}",
          "refId": "A"
        }
      ],
      "timeFrom": null,
      "timeShift": null,
      "title": "WordPress Logs",
      "type": "logs"
    },
    {
      "datasource": "Loki",
      "gridPos": {
        "h": 8,
        "w": 12,
        "x": 12,
        "y": 8
      },
      "id": 4,
      "options": {
        "showLabels": false,
        "showTime": true,
        "sortOrder": "Descending",
        "wrapLogMessage": true
      },
      "targets": [
        {
          "expr": "{container=~\"agency_stack_erpnext.*\"}",
          "refId": "A"
        }
      ],
      "timeFrom": null,
      "timeShift": null,
      "title": "ERPNext Logs",
      "type": "logs"
    },
    {
      "datasource": "Loki",
      "gridPos": {
        "h": 8,
        "w": 12,
        "x": 0,
        "y": 16
      },
      "id": 5,
      "options": {
        "showLabels": false,
        "showTime": true,
        "sortOrder": "Descending",
        "wrapLogMessage": true
      },
      "targets": [
        {
          "expr": "{container=~\"agency_stack_mailu.*\"}",
          "refId": "A"
        }
      ],
      "timeFrom": null,
      "timeShift": null,
      "title": "Mailu Logs",
      "type": "logs"
    },
    {
      "datasource": "Loki",
      "gridPos": {
        "h": 8,
        "w": 12,
        "x": 12,
        "y": 16
      },
      "id": 6,
      "options": {
        "showLabels": false,
        "showTime": true,
        "sortOrder": "Descending",
        "wrapLogMessage": true
      },
      "targets": [
        {
          "expr": "{container=~\"agency_stack_keycloak.*\"}",
          "refId": "A"
        }
      ],
      "timeFrom": null,
      "timeShift": null,
      "title": "Keycloak Logs",
      "type": "logs"
    }
  ],
  "refresh": "10s",
  "schemaVersion": 22,
  "style": "dark",
  "tags": [
    "agencystack"
  ],
  "templating": {
    "list": []
  },
  "time": {
    "from": "now-1h",
    "to": "now"
  },
  "timepicker": {
    "refresh_intervals": [
      "5s",
      "10s",
      "30s",
      "1m",
      "5m",
      "15m",
      "30m",
      "1h",
      "2h",
      "1d"
    ]
  },
  "timezone": "",
  "title": "AgencyStack Logs",
  "uid": "agency-stack-logs",
  "version": 1
}
EOF
  
  # Create dashboard provisioning config
  DASHBOARD_CONFIG="${GRAFANA_DASHBOARD_DIR}/../dashboards.yaml"
  if [ ! -f "$DASHBOARD_CONFIG" ]; then
    sudo mkdir -p "$(dirname "$DASHBOARD_CONFIG")"
    
    cat << EOF | sudo tee "$DASHBOARD_CONFIG" > /dev/null
apiVersion: 1

providers:
  - name: 'agencystack'
    orgId: 1
    folder: 'AgencyStack'
    type: file
    disableDeletion: false
    updateIntervalSeconds: 30
    allowUiUpdates: true
    options:
      path: /etc/grafana/provisioning/dashboards
      foldersFromFilesStructure: false
EOF
  fi
  
  # Restart Grafana to apply changes
  if is_container_running "agency_stack_grafana"; then
    log "${BLUE}Restarting Grafana to apply dashboard changes...${NC}"
    docker restart agency_stack_grafana
  fi
  
  log "${GREEN}✅ Grafana dashboard created${NC}"
  log "${GREEN}Dashboard will be available at: https://${GRAFANA_DOMAIN:-grafana.${PRIMARY_DOMAIN}}/d/agency-stack-logs${NC}"
  
  # Record integration as applied
  record_integration "monitoring" "Grafana" "$MONITORING_VERSION" "Created AgencyStack Logs dashboard with panels for all components"
  
  return 0
}

# Configure Uptime Kuma
configure_uptime_kuma() {
  if ! is_component_installed "Uptime Kuma"; then
    log "${YELLOW}Uptime Kuma not installed, skipping health check configuration${NC}"
    return 1
  fi

  log "${BLUE}Configuring Uptime Kuma for AgencyStack health checks...${NC}"
  
  # Check if integration already applied
  if integration_is_applied "monitoring" "Uptime Kuma"; then
    log "${GREEN}Uptime Kuma integration already applied${NC}"
    
    # Ask if user wants to re-apply
    if [ "$AUTO_MODE" = false ]; then
      log "${YELLOW}Do you want to re-apply the Uptime Kuma integration? (y/n)${NC}"
      read -r answer
      if [[ ! "$answer" =~ ^[Yy]$ ]]; then
        log "Skipping Uptime Kuma configuration"
        return 0
      fi
    else
      # In auto mode, skip re-applying by default
      return 0
    fi
  fi
  
  log "${YELLOW}Note: Uptime Kuma requires manual configuration through its UI${NC}"
  log "Please set up the following monitors in Uptime Kuma:"
  
  # WordPress monitor
  if is_component_installed "WordPress"; then
    WP_DOMAIN="wordpress.${PRIMARY_DOMAIN}"
    log "1. WordPress: https://${WP_DOMAIN}/wp-json/health-check/v1/status"
  fi
  
  # ERPNext monitor
  if is_component_installed "ERPNext"; then
    ERPNEXT_DOMAIN="erp.${PRIMARY_DOMAIN}"
    log "2. ERPNext: https://${ERPNEXT_DOMAIN}/api/method/ping"
  fi
  
  # Keycloak monitor
  if is_component_installed "Keycloak"; then
    KEYCLOAK_DOMAIN="sso.${PRIMARY_DOMAIN}"
    log "3. Keycloak: https://${KEYCLOAK_DOMAIN}/auth/realms/master/.well-known/openid-configuration"
  fi
  
  # Mailu monitor
  if is_component_installed "Mailu"; then
    MAILU_DOMAIN="mail.${PRIMARY_DOMAIN}"
    log "4. Mailu: https://${MAILU_DOMAIN}/admin/"
  fi
  
  log "${GREEN}✅ Uptime Kuma configuration guide complete${NC}"
  
  # Record integration as applied
  record_integration "monitoring" "Uptime Kuma" "$MONITORING_VERSION" "Configuration guide for monitoring all AgencyStack components"
  
  return 0
}

# Main function
main() {
  log "${BLUE}Starting Monitoring integrations...${NC}"
  
  # Integrate WordPress with Loki
  integrate_wordpress_monitoring
  
  # Integrate ERPNext with Loki
  integrate_erpnext_monitoring
  
  # Integrate Mailu with Loki
  integrate_mailu_monitoring
  
  # Create Grafana dashboard
  create_grafana_dashboard
  
  # Configure Uptime Kuma
  configure_uptime_kuma
  
  # Generate integration report
  generate_integration_report
  
  log ""
  log "${GREEN}${BOLD}Monitoring integration complete!${NC}"
  log "See integration log for details: ${LOG_FILE}"
  log "See integration report for summary and recommended actions."
}

# Run main function
main
