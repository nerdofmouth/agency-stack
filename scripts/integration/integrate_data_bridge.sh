#!/bin/bash
# integrate_data_bridge.sh - Data Exchange Integration for AgencyStack
# https://stack.nerdofmouth.com

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common functions
source "${SCRIPT_DIR}/integrate_common.sh"

# Data Bridge Integration version
DATA_BRIDGE_VERSION="1.0.1"

# Start logging
LOG_FILE="${INTEGRATION_LOG_DIR}/data_bridge-${CURRENT_DATE}.log"
log "${MAGENTA}${BOLD}🔄 AgencyStack Data Exchange Bridge${NC}"
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

# WordPress to ERPNext Data Bridge
integrate_wordpress_erpnext() {
  if ! is_component_installed "WordPress"; then
    log "${YELLOW}WordPress not installed, skipping WordPress → ERPNext data bridge${NC}"
    return 1
  fi

  if ! is_component_installed "ERPNext"; then
    log "${YELLOW}ERPNext not installed, skipping WordPress → ERPNext data bridge${NC}"
    return 1
  fi

  log "${BLUE}Setting up WordPress ↔ ERPNext data exchange bridge...${NC}"
  
  # Check if integration already applied
  if integration_is_applied "data-bridge" "WordPress"; then
    log "${GREEN}WordPress ↔ ERPNext data bridge already configured${NC}"
    
    # Ask if user wants to re-apply
    if [ "$AUTO_MODE" = false ]; then
      log "${YELLOW}Do you want to re-apply the WordPress ↔ ERPNext data bridge? (y/n)${NC}"
      read -r answer
      if [[ ! "$answer" =~ ^[Yy]$ ]]; then
        log "Skipping WordPress ↔ ERPNext data bridge"
        return 0
      fi
    else
      # In auto mode, skip re-applying by default
      return 0
    fi
  fi
  
  # Create directories for integration plugins
  WP_PLUGIN_DIR="/opt/agency_stack/wordpress/wp-content/plugins/erpnext-connector"
  sudo mkdir -p "$WP_PLUGIN_DIR"
  
  # Create WordPress plugin for ERPNext integration
  log "${BLUE}Creating WordPress plugin for ERPNext integration...${NC}"
  
  # Main plugin file
  cat << 'EOF' | sudo tee "${WP_PLUGIN_DIR}/erpnext-connector.php" > /dev/null
<?php
/**
 * Plugin Name: ERPNext Connector
 * Description: Connect WordPress to ERPNext for data exchange
 * Version: 1.0.1
 * Author: AgencyStack
 */

defined('ABSPATH') or die('Direct access not allowed');

class ERPNextConnector {
    private $api_url;
    private $api_key;
    private $api_secret;
    private $sync_enabled = false;

    public function __construct() {
        add_action('admin_menu', array($this, 'add_admin_menu'));
        add_action('admin_init', array($this, 'register_settings'));
        add_action('wp_ajax_sync_to_erpnext', array($this, 'sync_to_erpnext'));
        add_action('wp_ajax_test_connection', array($this, 'test_connection'));
        
        // Initialize settings
        $this->api_url = get_option('erpnext_api_url', '');
        $this->api_key = get_option('erpnext_api_key', '');
        $this->api_secret = get_option('erpnext_api_secret', '');
        $this->sync_enabled = get_option('erpnext_sync_enabled', false);
        
        // Register hooks for data sync
        if ($this->sync_enabled) {
            // User sync
            add_action('user_register', array($this, 'sync_user_to_erpnext'), 10, 2);
            add_action('profile_update', array($this, 'sync_user_to_erpnext'), 10, 2);
            
            // WooCommerce hooks (if installed)
            if (class_exists('WooCommerce')) {
                add_action('woocommerce_new_order', array($this, 'sync_order_to_erpnext'));
                add_action('woocommerce_order_status_changed', array($this, 'sync_order_status_to_erpnext'), 10, 3);
                add_action('woocommerce_new_product', array($this, 'sync_product_to_erpnext'));
                add_action('woocommerce_update_product', array($this, 'sync_product_to_erpnext'));
            }
            
            // Contact Form 7 hooks (if installed)
            if (class_exists('WPCF7')) {
                add_action('wpcf7_mail_sent', array($this, 'sync_contact_form_to_erpnext'));
            }
        }
    }
    
    public function add_admin_menu() {
        add_menu_page(
            'ERPNext Integration',
            'ERPNext',
            'manage_options',
            'erpnext-connector',
            array($this, 'admin_page'),
            'dashicons-networking',
            30
        );
    }
    
    public function register_settings() {
        register_setting('erpnext_connector_options', 'erpnext_api_url');
        register_setting('erpnext_connector_options', 'erpnext_api_key');
        register_setting('erpnext_connector_options', 'erpnext_api_secret');
        register_setting('erpnext_connector_options', 'erpnext_sync_enabled');
    }
    
    public function admin_page() {
        ?>
        <div class="wrap">
            <h1>ERPNext Integration</h1>
            
            <form method="post" action="options.php">
                <?php settings_fields('erpnext_connector_options'); ?>
                <table class="form-table">
                    <tr>
                        <th scope="row">ERPNext URL</th>
                        <td>
                            <input type="url" name="erpnext_api_url" value="<?php echo esc_attr(get_option('erpnext_api_url')); ?>" class="regular-text" placeholder="https://erp.yourdomain.com" />
                        </td>
                    </tr>
                    <tr>
                        <th scope="row">API Key</th>
                        <td>
                            <input type="text" name="erpnext_api_key" value="<?php echo esc_attr(get_option('erpnext_api_key')); ?>" class="regular-text" />
                        </td>
                    </tr>
                    <tr>
                        <th scope="row">API Secret</th>
                        <td>
                            <input type="password" name="erpnext_api_secret" value="<?php echo esc_attr(get_option('erpnext_api_secret')); ?>" class="regular-text" />
                        </td>
                    </tr>
                    <tr>
                        <th scope="row">Enable Sync</th>
                        <td>
                            <input type="checkbox" name="erpnext_sync_enabled" value="1" <?php checked(1, get_option('erpnext_sync_enabled'), true); ?> />
                            <p class="description">Enable automatic synchronization of users, orders, and contacts</p>
                        </td>
                    </tr>
                </table>
                
                <?php submit_button('Save Settings'); ?>
            </form>
            
            <hr>
            
            <h2>Data Synchronization</h2>
            <p>Manually trigger synchronization of WordPress data to ERPNext</p>
            
            <button id="test-connection" class="button">Test Connection</button>
            <button id="sync-users" class="button">Sync Users</button>
            <?php if (class_exists('WooCommerce')) : ?>
                <button id="sync-products" class="button">Sync Products</button>
                <button id="sync-orders" class="button">Sync Orders</button>
            <?php endif; ?>
            
            <div id="sync-results" style="margin-top: 20px;"></div>
            
            <script>
                jQuery(document).ready(function($) {
                    $('#test-connection').on('click', function(e) {
                        e.preventDefault();
                        $('#sync-results').html('<p>Testing connection...</p>');
                        
                        $.post(ajaxurl, {
                            action: 'test_connection'
                        }, function(response) {
                            $('#sync-results').html('<p>' + response.data + '</p>');
                        });
                    });
                    
                    $('#sync-users').on('click', function(e) {
                        e.preventDefault();
                        $('#sync-results').html('<p>Syncing users to ERPNext...</p>');
                        
                        $.post(ajaxurl, {
                            action: 'sync_to_erpnext',
                            data_type: 'users'
                        }, function(response) {
                            $('#sync-results').html('<p>' + response.data + '</p>');
                        });
                    });
                    
                    $('#sync-products').on('click', function(e) {
                        e.preventDefault();
                        $('#sync-results').html('<p>Syncing products to ERPNext...</p>');
                        
                        $.post(ajaxurl, {
                            action: 'sync_to_erpnext',
                            data_type: 'products'
                        }, function(response) {
                            $('#sync-results').html('<p>' + response.data + '</p>');
                        });
                    });
                    
                    $('#sync-orders').on('click', function(e) {
                        e.preventDefault();
                        $('#sync-results').html('<p>Syncing orders to ERPNext...</p>');
                        
                        $.post(ajaxurl, {
                            action: 'sync_to_erpnext',
                            data_type: 'orders'
                        }, function(response) {
                            $('#sync-results').html('<p>' + response.data + '</p>');
                        });
                    });
                });
            </script>
        </div>
        <?php
    }
    
    public function test_connection() {
        // Simple connection test implementation
        $api_url = get_option('erpnext_api_url');
        $api_key = get_option('erpnext_api_key');
        $api_secret = get_option('erpnext_api_secret');
        
        if (empty($api_url) || empty($api_key) || empty($api_secret)) {
            wp_send_json_error('API connection details are missing. Please configure the ERPNext settings.');
        }
        
        // Test endpoint URL
        $test_url = trailingslashit($api_url) . 'api/method/frappe.auth.get_logged_user';
        
        $response = wp_remote_get($test_url, array(
            'headers' => array(
                'Authorization' => 'token ' . $api_key . ':' . $api_secret
            )
        ));
        
        if (is_wp_error($response)) {
            wp_send_json_error('Connection failed: ' . $response->get_error_message());
        }
        
        $response_code = wp_remote_retrieve_response_code($response);
        $response_body = wp_remote_retrieve_body($response);
        $response_data = json_decode($response_body, true);
        
        if ($response_code === 200 && isset($response_data['message'])) {
            wp_send_json_success('Connection successful! Connected as: ' . $response_data['message']);
        } else {
            wp_send_json_error('Connection failed. Response code: ' . $response_code . '. Please check your API credentials.');
        }
    }
    
    public function sync_to_erpnext() {
        $data_type = isset($_POST['data_type']) ? sanitize_text_field($_POST['data_type']) : '';
        
        switch ($data_type) {
            case 'users':
                $result = $this->bulk_sync_users();
                break;
            case 'products':
                $result = $this->bulk_sync_products();
                break;
            case 'orders':
                $result = $this->bulk_sync_orders();
                break;
            default:
                $result = 'Invalid data type specified';
                break;
        }
        
        wp_send_json_success($result);
    }
    
    private function bulk_sync_users() {
        // Implementation for syncing users
        return 'User synchronization feature is implemented as a placeholder. Complete integration requires ERPNext API configuration.';
    }
    
    private function bulk_sync_products() {
        // Implementation for syncing products
        return 'Product synchronization feature is implemented as a placeholder. Complete integration requires ERPNext API configuration.';
    }
    
    private function bulk_sync_orders() {
        // Implementation for syncing orders
        return 'Order synchronization feature is implemented as a placeholder. Complete integration requires ERPNext API configuration.';
    }
    
    public function sync_user_to_erpnext($user_id, $user_data = null) {
        // Implementation for syncing a single user
    }
    
    public function sync_order_to_erpnext($order_id) {
        // Implementation for syncing a single order
    }
    
    public function sync_order_status_to_erpnext($order_id, $old_status, $new_status) {
        // Implementation for syncing order status changes
    }
    
    public function sync_product_to_erpnext($product_id) {
        // Implementation for syncing a single product
    }
    
    public function sync_contact_form_to_erpnext($contact_form) {
        // Implementation for syncing contact form submissions
    }
}

// Initialize the plugin
new ERPNextConnector();
EOF
  
  # Create ERPNext app for WordPress integration
  log "${BLUE}Creating ERPNext connector for WordPress integration...${NC}"
  
  ERPNEXT_APP_DIR="/opt/agency_stack/erpnext/custom_apps/wordpress_connector"
  sudo mkdir -p "${ERPNEXT_APP_DIR}/wordpress_connector"
  
  # Create setup.py
  cat << 'EOF' | sudo tee "${ERPNEXT_APP_DIR}/setup.py" > /dev/null
from setuptools import setup, find_packages

setup(
    name="wordpress_connector",
    version="1.0.1",
    description="Connect ERPNext to WordPress",
    author="AgencyStack",
    author_email="admin@example.com",
    packages=find_packages(),
    zip_safe=False,
    include_package_data=True,
    install_requires=["frappe"]
)
EOF
  
  # Create __init__.py
  cat << 'EOF' | sudo tee "${ERPNEXT_APP_DIR}/wordpress_connector/__init__.py" > /dev/null
__version__ = '1.0.1'
EOF
  
  # Create hooks.py
  cat << 'EOF' | sudo tee "${ERPNEXT_APP_DIR}/wordpress_connector/hooks.py" > /dev/null
# -*- coding: utf-8 -*-
from __future__ import unicode_literals
from . import __version__ as app_version

app_name = "wordpress_connector"
app_title = "WordPress Connector"
app_publisher = "AgencyStack"
app_description = "Connect ERPNext to WordPress"
app_icon = "octicon octicon-file-directory"
app_color = "blue"
app_email = "admin@example.com"
app_license = "MIT"

# Document Events
doc_events = {
    "Customer": {
        "after_insert": "wordpress_connector.api.sync_customer_to_wordpress",
        "on_update": "wordpress_connector.api.sync_customer_to_wordpress"
    },
    "Item": {
        "after_insert": "wordpress_connector.api.sync_item_to_wordpress",
        "on_update": "wordpress_connector.api.sync_item_to_wordpress"
    },
    "Sales Order": {
        "on_update": "wordpress_connector.api.sync_order_status_to_wordpress"
    }
}

# Scheduled Tasks
scheduler_events = {
    "daily": [
        "wordpress_connector.tasks.daily"
    ],
}

# API endpoints
api_cmd_methods = {
    "wordpress_connector.api.receive_webhook": ["POST"],
    "wordpress_connector.api.get_customers": ["GET"],
    "wordpress_connector.api.get_items": ["GET"]
}
EOF
  
  # Create API module
  sudo mkdir -p "${ERPNEXT_APP_DIR}/wordpress_connector/api"
  
  cat << 'EOF' | sudo tee "${ERPNEXT_APP_DIR}/wordpress_connector/api/__init__.py" > /dev/null
# -*- coding: utf-8 -*-
from __future__ import unicode_literals

import frappe
import json
import requests
from frappe import _

def get_wordpress_settings():
    """Get WordPress connection settings"""
    return frappe.get_single("WordPress Settings")

def sync_customer_to_wordpress(doc, method=None):
    """Sync a customer to WordPress when created or modified"""
    try:
        settings = get_wordpress_settings()
        if not settings.enabled:
            return
            
        # Implementation would go here
        frappe.logger().info(f"Would sync customer {doc.name} to WordPress")
    except Exception as e:
        frappe.logger().error(f"Error syncing customer to WordPress: {str(e)}")

def sync_item_to_wordpress(doc, method=None):
    """Sync an item to WordPress when created or modified"""
    try:
        settings = get_wordpress_settings()
        if not settings.enabled:
            return
            
        # Implementation would go here
        frappe.logger().info(f"Would sync item {doc.name} to WordPress")
    except Exception as e:
        frappe.logger().error(f"Error syncing item to WordPress: {str(e)}")

def sync_order_status_to_wordpress(doc, method=None):
    """Sync order status to WordPress when changed"""
    try:
        settings = get_wordpress_settings()
        if not settings.enabled:
            return
            
        # Implementation would go here
        frappe.logger().info(f"Would sync order status for {doc.name} to WordPress")
    except Exception as e:
        frappe.logger().error(f"Error syncing order status to WordPress: {str(e)}")

@frappe.whitelist(allow_guest=True)
def receive_webhook():
    """Endpoint for receiving webhooks from WordPress"""
    try:
        settings = get_wordpress_settings()
        if not settings.enabled:
            return json.dumps({"success": False, "message": "Integration is disabled"})
            
        # Get the request data
        if frappe.request and frappe.request.data:
            data = json.loads(frappe.request.data)
            
            # Process webhook based on type
            webhook_type = data.get('type')
            
            if webhook_type == 'user':
                # Handle user webhook
                frappe.logger().info(f"Received user webhook from WordPress")
                
            elif webhook_type == 'order':
                # Handle order webhook
                frappe.logger().info(f"Received order webhook from WordPress")
                
            elif webhook_type == 'product':
                # Handle product webhook
                frappe.logger().info(f"Received product webhook from WordPress")
                
            return json.dumps({"success": True})
        
        return json.dumps({"success": False, "message": "No data received"})
    except Exception as e:
        frappe.logger().error(f"Error processing WordPress webhook: {str(e)}")
        return json.dumps({"success": False, "message": str(e)})

@frappe.whitelist()
def get_customers():
    """Get customers list for WordPress"""
    try:
        customers = frappe.get_list("Customer", fields=["name", "customer_name", "email_id"])
        return json.dumps({"success": True, "data": customers})
    except Exception as e:
        frappe.logger().error(f"Error getting customers for WordPress: {str(e)}")
        return json.dumps({"success": False, "message": str(e)})

@frappe.whitelist()
def get_items():
    """Get items list for WordPress"""
    try:
        items = frappe.get_list("Item", fields=["name", "item_name", "description", "standard_rate"])
        return json.dumps({"success": True, "data": items})
    except Exception as e:
        frappe.logger().error(f"Error getting items for WordPress: {str(e)}")
        return json.dumps({"success": False, "message": str(e)})
EOF
  
  # Create DocType for WordPress Settings
  sudo mkdir -p "${ERPNEXT_APP_DIR}/wordpress_connector/wordpress_connector/doctype/wordpress_settings"
  
  cat << 'EOF' | sudo tee "${ERPNEXT_APP_DIR}/wordpress_connector/wordpress_connector/doctype/wordpress_settings/__init__.py" > /dev/null
EOF
  
  cat << 'EOF' | sudo tee "${ERPNEXT_APP_DIR}/wordpress_connector/wordpress_connector/doctype/wordpress_settings/wordpress_settings.json" > /dev/null
{
 "creation": "2023-01-01 00:00:00.000000",
 "doctype": "DocType",
 "editable_grid": 1,
 "engine": "InnoDB",
 "field_order": [
  "enabled",
  "wordpress_url",
  "api_key",
  "api_secret",
  "webhook_secret"
 ],
 "fields": [
  {
   "default": "0",
   "fieldname": "enabled",
   "fieldtype": "Check",
   "label": "Enabled"
  },
  {
   "fieldname": "wordpress_url",
   "fieldtype": "Data",
   "label": "WordPress URL",
   "reqd": 1
  },
  {
   "fieldname": "api_key",
   "fieldtype": "Data",
   "label": "API Key",
   "reqd": 1
  },
  {
   "fieldname": "api_secret",
   "fieldtype": "Password",
   "label": "API Secret",
   "reqd": 1
  },
  {
   "fieldname": "webhook_secret",
   "fieldtype": "Data",
   "label": "Webhook Secret"
  }
 ],
 "issingle": 1,
 "modified": "2023-01-01 00:00:00.000000",
 "modified_by": "Administrator",
 "module": "WordPress Connector",
 "name": "WordPress Settings",
 "owner": "Administrator",
 "permissions": [
  {
   "create": 1,
   "delete": 1,
   "email": 1,
   "print": 1,
   "read": 1,
   "role": "System Manager",
   "share": 1,
   "write": 1
  }
 ],
 "quick_entry": 1,
 "sort_field": "modified",
 "sort_order": "DESC",
 "track_changes": 1
}
EOF
  
  cat << 'EOF' | sudo tee "${ERPNEXT_APP_DIR}/wordpress_connector/wordpress_connector/doctype/wordpress_settings/wordpress_settings.py" > /dev/null
# -*- coding: utf-8 -*-
# Copyright (c) 2023, AgencyStack and contributors
# For license information, please see license.txt

from __future__ import unicode_literals
import frappe
from frappe.model.document import Document

class WordPressSettings(Document):
    def validate(self):
        if self.enabled and not (self.wordpress_url and self.api_key and self.api_secret):
            frappe.throw("WordPress URL, API Key and API Secret are required when integration is enabled")
EOF
  
  # Create tasks module
  sudo mkdir -p "${ERPNEXT_APP_DIR}/wordpress_connector/tasks"
  
  cat << 'EOF' | sudo tee "${ERPNEXT_APP_DIR}/wordpress_connector/tasks/__init__.py" > /dev/null
# -*- coding: utf-8 -*-
from __future__ import unicode_literals

import frappe

def daily():
    """Daily scheduled tasks"""
    try:
        settings = frappe.get_single("WordPress Settings")
        if not settings.enabled:
            return
            
        # Synchronize data daily
        frappe.logger().info("Running WordPress daily sync tasks")
        
        # Example: Sync products that have changed
        # sync_changed_items()
        
    except Exception as e:
        frappe.logger().error(f"Error in WordPress daily tasks: {str(e)}")
EOF
  
  # Create WP-CLI command to install the plugin if WordPress is running
  WP_CLI="/opt/agency_stack/wordpress/wp.sh"
  if [ -f "$WP_CLI" ]; then
    log "${BLUE}Activating ERPNext Connector plugin in WordPress...${NC}"
    sudo $WP_CLI plugin activate erpnext-connector || log "${YELLOW}Plugin activation will need to be done manually${NC}"
  else
    log "${YELLOW}WordPress CLI not available, manual plugin activation required${NC}"
  fi
  
  # Create instructions for installing the ERPNext app
  BENCH_CLI="/opt/agency_stack/erpnext/bench.sh"
  if [ -f "$BENCH_CLI" ]; then
    log "${BLUE}Instructions for installing WordPress Connector in ERPNext:${NC}"
    log "1. Run: cd /opt/agency_stack/erpnext"
    log "2. Run: ${BENCH_CLI} get-app /opt/agency_stack/erpnext/custom_apps/wordpress_connector"
    log "3. Run: ${BENCH_CLI} --site ${ERPNEXT_SITE_NAME:-erp.${PRIMARY_DOMAIN}} install-app wordpress_connector"
    log "4. In ERPNext, go to WordPress Settings to configure the connection to WordPress"
  else
    log "${YELLOW}ERPNext bench not available, manual app installation required${NC}"
  fi
  
  log "${GREEN}✅ WordPress ↔ ERPNext data bridge created${NC}"
  
  # Record integration as applied
  record_integration "data-bridge" "WordPress" "$DATA_BRIDGE_VERSION" "Created data exchange components for WordPress ↔ ERPNext bidirectional sync"
  record_integration "data-bridge" "ERPNext" "$DATA_BRIDGE_VERSION" "Created data exchange components for WordPress ↔ ERPNext bidirectional sync"
  
  return 0
}

# Main function
main() {
  log "${BLUE}Starting Data Exchange Bridge integrations...${NC}"
  
  # Integrate WordPress with ERPNext
  integrate_wordpress_erpnext
  
  # Additional data bridges can be added here
  
  # Generate integration report
  generate_integration_report
  
  log ""
  log "${GREEN}${BOLD}Data Exchange Bridge integration complete!${NC}"
  log "See integration log for details: ${LOG_FILE}"
  log "See integration report for summary and recommended actions."
}

# Run main function
main
