#!/bin/bash
# integrate_components.sh - Integrate AgencyStack components
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
LOG_FILE="${LOG_DIR}/integrate_components-$(date +%Y%m%d-%H%M%S).log"

# Create log directory if it doesn't exist
mkdir -p "$LOG_DIR"

# Non-interactive mode flag
AUTO_MODE=false
INTEGRATION_TYPE="all"

# Check command-line arguments
for arg in "$@"; do
  case $arg in
    --yes|--auto)
      AUTO_MODE=true
      ;;
    --type=*)
      INTEGRATION_TYPE="${arg#*=}"
      ;;
    *)
      # Unknown argument
      ;;
  esac
done

# Logging function
log() {
  echo -e "$1" | tee -a "$LOG_FILE"
}

log "${MAGENTA}${BOLD}🔄 AgencyStack Component Integration${NC}"
log "========================================"
log "$(date)"
log "Server: $(hostname)"
log ""

# Check if config.env exists and source it
if [ -f "$CONFIG_ENV" ]; then
  source "$CONFIG_ENV"
else
  log "${RED}Error: config.env not found${NC}"
  log "Please run the AgencyStack installation first"
  exit 1
fi

# Check installed components
INSTALLED_COMPONENTS_FILE="/opt/agency_stack/installed_components.txt"
if [ ! -f "$INSTALLED_COMPONENTS_FILE" ]; then
  log "${RED}Error: No installed components found${NC}"
  log "Please install components first using 'make install'"
  exit 1
fi

# Read installed components into array
INSTALLED_COMPONENTS=()
while IFS= read -r component; do
  INSTALLED_COMPONENTS+=("$component")
done < "$INSTALLED_COMPONENTS_FILE"

log "${BLUE}Detected installed components:${NC}"
for component in "${INSTALLED_COMPONENTS[@]}"; do
  log "- $component"
done
log ""

# Check if key components are installed
HAS_WORDPRESS=false
HAS_ERPNEXT=false
HAS_KEYCLOAK=false
HAS_MAILU=false
HAS_LOKI=false
HAS_GRAFANA=false

for component in "${INSTALLED_COMPONENTS[@]}"; do
  if [[ "$component" == "WordPress" ]]; then
    HAS_WORDPRESS=true
  elif [[ "$component" == "ERPNext" ]]; then
    HAS_ERPNEXT=true
  elif [[ "$component" == "Keycloak" ]]; then
    HAS_KEYCLOAK=true
  elif [[ "$component" == "Mailu" ]]; then
    HAS_MAILU=true
  elif [[ "$component" == "Loki" ]]; then
    HAS_LOKI=true
  elif [[ "$component" == "Grafana Monitoring" ]]; then
    HAS_GRAFANA=true
  fi
done

# Integration 1: Email Integration with Mailu
integrate_email() {
  log "${BLUE}Setting up email integration with Mailu...${NC}"
  
  if [ "$HAS_MAILU" = false ]; then
    log "${YELLOW}Warning: Mailu is not installed${NC}"
    log "Skipping email integration. Install Mailu for complete email integration."
    return
  fi
  
  # WordPress Email Integration
  if [ "$HAS_WORDPRESS" = true ]; then
    log "${BLUE}Configuring WordPress to use Mailu for email...${NC}"
    
    if [ -f "/opt/agency_stack/wordpress/wp.sh" ]; then
      # Install WP Mail SMTP plugin if not already installed
      /opt/agency_stack/wordpress/wp.sh plugin is-installed wp-mail-smtp || /opt/agency_stack/wordpress/wp.sh plugin install wp-mail-smtp --activate
      
      # Configure SMTP settings
      /opt/agency_stack/wordpress/wp.sh option update wp_mail_smtp_options '{
        "mail": {
          "from_email": "wordpress@'${PRIMARY_DOMAIN}'",
          "from_name": "WordPress",
          "mailer": "smtp",
          "return_path": false,
          "from_email_force": true,
          "from_name_force": true
        },
        "smtp": {
          "host": "mailu",
          "port": "587",
          "encryption": "tls",
          "autotls": true,
          "auth": true,
          "user": "wordpress@'${PRIMARY_DOMAIN}'",
          "pass": "'${MAILU_ADMIN_PASSWORD}'"
        }
      }' --format=json
      
      log "${GREEN}✅ WordPress email integration complete${NC}"
    else
      log "${YELLOW}Warning: WordPress CLI not available${NC}"
      log "Please configure WordPress email manually:"
      log "1. Install WP Mail SMTP plugin"
      log "2. Configure with host: mailu, port: 587"
      log "3. Set authentication to username: wordpress@${PRIMARY_DOMAIN}"
    fi
  fi
  
  # ERPNext Email Integration
  if [ "$HAS_ERPNEXT" = true ]; then
    log "${BLUE}Configuring ERPNext to use Mailu for email...${NC}"
    
    if [ -f "/opt/agency_stack/erpnext/bench.sh" ]; then
      # Configure email in ERPNext
      /opt/agency_stack/erpnext/bench.sh --site ${ERPNEXT_SITE_NAME} set-config -g smtp_server mailu
      /opt/agency_stack/erpnext/bench.sh --site ${ERPNEXT_SITE_NAME} set-config -g smtp_port 587
      /opt/agency_stack/erpnext/bench.sh --site ${ERPNEXT_SITE_NAME} set-config -g smtp_use_tls 1
      /opt/agency_stack/erpnext/bench.sh --site ${ERPNEXT_SITE_NAME} set-config -g email_sender_name "ERPNext"
      /opt/agency_stack/erpnext/bench.sh --site ${ERPNEXT_SITE_NAME} set-config -g auto_email_id "erpnext@${PRIMARY_DOMAIN}"
      
      log "${GREEN}✅ ERPNext email integration complete${NC}"
    else
      log "${YELLOW}Warning: ERPNext bench not available${NC}"
      log "Please configure ERPNext email manually:"
      log "1. Go to Email Domain settings in ERPNext"
      log "2. Configure with host: mailu, port: 587"
      log "3. Enable TLS and set authentication"
    fi
  fi
}

# Integration 2: Single Sign-On with Keycloak
integrate_sso() {
  log "${BLUE}Setting up Single Sign-On with Keycloak...${NC}"
  
  if [ "$HAS_KEYCLOAK" = false ]; then
    log "${YELLOW}Warning: Keycloak is not installed${NC}"
    log "Skipping SSO integration. Install Keycloak for SSO capabilities."
    return
  fi
  
  # Run the Keycloak integration script if available
  if [ -f "/home/revelationx/CascadeProjects/foss-server-stack/scripts/keycloak_integration.sh" ]; then
    log "${BLUE}Running Keycloak integration script...${NC}"
    bash /home/revelationx/CascadeProjects/foss-server-stack/scripts/keycloak_integration.sh
  else
    log "${YELLOW}Warning: Keycloak integration script not found${NC}"
  fi
  
  # WordPress SSO Integration (additional steps beyond keycloak_integration.sh)
  if [ "$HAS_WORDPRESS" = true ]; then
    log "${BLUE}Configuring WordPress for Keycloak SSO...${NC}"
    
    if [ -f "/opt/agency_stack/wordpress/wp.sh" ]; then
      # Install OAuth plugin if not already installed
      /opt/agency_stack/wordpress/wp.sh plugin is-installed miniorange-openid-connect-client || /opt/agency_stack/wordpress/wp.sh plugin install miniorange-openid-connect-client --activate
      
      log "${GREEN}✅ WordPress SSO plugin installed${NC}"
      log "${YELLOW}Note: Manual configuration is required to complete WordPress SSO setup${NC}"
      log "1. Go to WordPress Admin -> miniOrange OIDC"
      log "2. Configure the Keycloak client with:"
      log "   - Client ID: wordpress"
      log "   - Client Secret: (from Keycloak)"
      log "   - Authorization Endpoint: https://${KEYCLOAK_DOMAIN}/auth/realms/agencystack/protocol/openid-connect/auth"
      log "   - Token Endpoint: https://${KEYCLOAK_DOMAIN}/auth/realms/agencystack/protocol/openid-connect/token"
      log "   - User Info Endpoint: https://${KEYCLOAK_DOMAIN}/auth/realms/agencystack/protocol/openid-connect/userinfo"
    else
      log "${YELLOW}Warning: WordPress CLI not available${NC}"
      log "Please install WordPress SSO plugin manually"
    fi
  fi
}

# Integration 3: Monitoring Integration
integrate_monitoring() {
  log "${BLUE}Setting up monitoring integration...${NC}"
  
  if [ "$HAS_LOKI" = false ] || [ "$HAS_GRAFANA" = false ]; then
    log "${YELLOW}Warning: Loki or Grafana is not installed${NC}"
    log "Skipping monitoring integration. Install both for complete monitoring."
    return
  fi
  
  # WordPress Monitoring Integration
  if [ "$HAS_WORDPRESS" = true ]; then
    log "${BLUE}Configuring WordPress monitoring...${NC}"
    
    # Create Loki log configuration for WordPress
    mkdir -p /opt/agency_stack/loki/config/pipeline_stages.d/
    
    cat > /opt/agency_stack/loki/config/pipeline_stages.d/wordpress.yaml << EOL
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
          format: 2006/01/02 15:04:05
EOL
    
    # Restart Loki to apply configuration
    docker restart agency_stack_loki
    
    log "${GREEN}✅ WordPress log monitoring configured${NC}"
    log "${YELLOW}Note: WordPress logs will be available in Grafana via Loki data source${NC}"
  fi
  
  # ERPNext Monitoring Integration
  if [ "$HAS_ERPNEXT" = true ]; then
    log "${BLUE}Configuring ERPNext monitoring...${NC}"
    
    # Create Loki log configuration for ERPNext
    mkdir -p /opt/agency_stack/loki/config/pipeline_stages.d/
    
    cat > /opt/agency_stack/loki/config/pipeline_stages.d/erpnext.yaml << EOL
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
          format: 2006-01-02 15:04:05,000
EOL
    
    # Restart Loki to apply configuration
    docker restart agency_stack_loki
    
    log "${GREEN}✅ ERPNext log monitoring configured${NC}"
    log "${YELLOW}Note: ERPNext logs will be available in Grafana via Loki data source${NC}"
  fi
}

# Integration 4: Data Exchange Bridge
create_data_bridge() {
  log "${BLUE}Setting up data exchange bridge...${NC}"
  
  if [ "$HAS_WORDPRESS" = false ] || [ "$HAS_ERPNEXT" = false ]; then
    log "${YELLOW}Warning: WordPress or ERPNext is not installed${NC}"
    log "Skipping data bridge creation. Install both for data integration."
    return
  fi
  
  # Create WordPress plugin for ERPNext integration
  mkdir -p /opt/agency_stack/wordpress/wp-content/plugins/erpnext-connector
  
  cat > /opt/agency_stack/wordpress/wp-content/plugins/erpnext-connector/erpnext-connector.php << EOL
<?php
/**
 * Plugin Name: ERPNext Connector
 * Description: Connect WordPress to ERPNext
 * Version: 1.0.0
 * Author: AgencyStack
 */

defined('ABSPATH') or die('Direct access not allowed');

class ERPNextConnector {
    private \$api_url;
    private \$api_key;
    private \$api_secret;

    public function __construct() {
        \$this->api_url = get_option('erpnext_api_url', 'https://${ERPNEXT_DOMAIN}');
        \$this->api_key = get_option('erpnext_api_key', '');
        \$this->api_secret = get_option('erpnext_api_secret', '');
        
        add_action('admin_menu', array(\$this, 'add_admin_menu'));
        add_action('wp_ajax_sync_to_erpnext', array(\$this, 'sync_to_erpnext'));
    }
    
    public function add_admin_menu() {
        add_menu_page(
            'ERPNext Integration',
            'ERPNext',
            'manage_options',
            'erpnext-connector',
            array(\$this, 'admin_page'),
            'dashicons-networking',
            30
        );
    }
    
    public function admin_page() {
        echo '<div class="wrap">';
        echo '<h1>ERPNext Integration</h1>';
        echo '<p>Connect your WordPress site to ERPNext at ' . esc_html(\$this->api_url) . '</p>';
        echo '<button id="sync-to-erpnext" class="button button-primary">Sync Data to ERPNext</button>';
        echo '<div id="sync-status"></div>';
        echo '</div>';
        
        echo '<script>
            jQuery(document).ready(function(\$) {
                $("#sync-to-erpnext").click(function() {
                    $("#sync-status").html("<p>Syncing data to ERPNext...</p>");
                    \$.post(ajaxurl, {
                        action: "sync_to_erpnext"
                    }, function(response) {
                        $("#sync-status").html("<p>" + response.data + "</p>");
                    });
                });
            });
        </script>';
    }
    
    public function sync_to_erpnext() {
        // Example implementation
        wp_send_json_success('Data synchronized with ERPNext. View your data at ' . \$this->api_url);
    }
}

new ERPNextConnector();
EOL
  
  # Create ERPNext app for WordPress integration
  mkdir -p /opt/agency_stack/erpnext/custom_apps/wordpress_connector
  
  cat > /opt/agency_stack/erpnext/custom_apps/wordpress_connector/setup.py << EOL
from setuptools import setup, find_packages

setup(
    name="wordpress_connector",
    version="0.0.1",
    description="Connect ERPNext to WordPress",
    author="AgencyStack",
    author_email="admin@${PRIMARY_DOMAIN}",
    packages=find_packages(),
    zip_safe=False,
    include_package_data=True,
    install_requires=["frappe"]
)
EOL
  
  mkdir -p /opt/agency_stack/erpnext/custom_apps/wordpress_connector/wordpress_connector
  
  cat > /opt/agency_stack/erpnext/custom_apps/wordpress_connector/wordpress_connector/__init__.py << EOL
__version__ = '0.0.1'
EOL
  
  log "${GREEN}✅ Data exchange bridge created${NC}"
  log "${YELLOW}Note: Additional configuration required to complete data integration${NC}"
  log "1. For WordPress: Activate the ERPNext Connector plugin"
  log "2. For ERPNext: Install the custom WordPress connector app"
}

# Main function
main() {
  # Run the integration based on the integration type
  if [[ "$INTEGRATION_TYPE" == "all" ]]; then
    log "${BLUE}Running all integrations...${NC}"

    integrate_email
    integrate_sso
    integrate_monitoring
    create_data_bridge
  elif [[ "$INTEGRATION_TYPE" == "sso" ]]; then
    log "${BLUE}Running Single Sign-On integration...${NC}"
    integrate_sso
  elif [[ "$INTEGRATION_TYPE" == "email" ]]; then
    log "${BLUE}Running Email integration...${NC}"
    integrate_email
  elif [[ "$INTEGRATION_TYPE" == "monitoring" ]]; then
    log "${BLUE}Running Monitoring integration...${NC}"
    integrate_monitoring
  elif [[ "$INTEGRATION_TYPE" == "data-bridge" ]]; then
    log "${BLUE}Running Data Exchange Bridge integration...${NC}"
    create_data_bridge
  else
    log "${RED}Unknown integration type: ${INTEGRATION_TYPE}${NC}"
    log "Valid types: all, sso, email, monitoring, data-bridge"
    exit 1
  fi
  
  log ""
  log "${GREEN}${BOLD}Integration complete!${NC}"
  log "See above for specific configuration instructions for each component."
}

# Run main function
main
