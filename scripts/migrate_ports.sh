#!/bin/bash
# migrate_ports.sh - Migrates existing port configurations to the port management system
# This script should be run when implementing the port manager on existing installations

echo "🔌 Migrating existing port configurations to port management system..."

# Source the port manager
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$SCRIPT_DIR/port_manager.sh"

# Helper function to extract port from docker-compose file
extract_port() {
  local file=$1
  local service=$2
  local pattern=$3
  local default=$4
  
  if [ -f "$file" ]; then
    # Try to extract port using grep and sed
    local port=$(grep -A10 "$pattern" "$file" | grep -m1 "ports:" -A2 | grep -oE ':[0-9]+:' | head -1 | tr -d ':')
    
    if [ -z "$port" ]; then
      # If not found in ports section, try container_name
      port=$(grep -A20 "container_name: $service" "$file" | grep -m1 ":[0-9]*:" | grep -oE '[0-9]+:' | head -1 | tr -d ':')
    fi
    
    if [ -n "$port" ]; then
      echo "$port"
      return 0
    fi
  fi
  
  # Return default if port not found
  echo "$default"
  return 0
}

# Migrate ports for core services
echo "Migrating core service ports..."

# Keycloak
KEYCLOAK_FILE="/opt/keycloak/docker-compose.yml"
KEYCLOAK_PORT=$(extract_port "$KEYCLOAK_FILE" "keycloak" "keycloak:" 8080)
KEYCLOAK_PG_PORT=$(extract_port "$KEYCLOAK_FILE" "postgres" "postgres:" 5432)
register_port "keycloak" "$KEYCLOAK_PORT" "flexible"
register_port "keycloak_postgres" "$KEYCLOAK_PG_PORT" "flexible"

# Launchpad Dashboard
DASHBOARD_FILE="/opt/launchpad-dashboard/docker-compose.yml"
DASHBOARD_PORT=$(extract_port "$DASHBOARD_FILE" "launchpad_dashboard" "dashboard:" 1337)
STATUS_PORT=$(extract_port "$DASHBOARD_FILE" "status_monitor" "status-monitor:" 3001)
register_port "launchpad_dashboard" "$DASHBOARD_PORT" "flexible"
register_port "status_monitor" "$STATUS_PORT" "flexible"

# ERPNext
ERPNEXT_FILE="/opt/erpnext/docker-compose.yml"
ERPNEXT_PORT=$(extract_port "$ERPNEXT_FILE" "erpnext" "frappe:" 8000)
register_port "erpnext" "$ERPNEXT_PORT" "flexible"

# Cal.com
CALCOM_FILE="/opt/calcom/docker-compose.yml"
CALCOM_PORT=$(extract_port "$CALCOM_FILE" "calcom" "calcom:" 3000)
register_port "calcom" "$CALCOM_PORT" "flexible"

# n8n
N8N_FILE="/opt/n8n/docker-compose.yml"
N8N_PORT=$(extract_port "$N8N_FILE" "n8n" "n8n:" 5678)
register_port "n8n" "$N8N_PORT" "flexible"

# FocalBoard
FOCALBOARD_FILE="/opt/focalboard/docker-compose.yml"
FOCALBOARD_PORT=$(extract_port "$FOCALBOARD_FILE" "focalboard" "focalboard:" 8000)
register_port "focalboard" "$FOCALBOARD_PORT" "flexible"

# Hedgedoc
HEDGEDOC_FILE="/opt/hedgedoc/docker-compose.yml"
HEDGEDOC_PORT=$(extract_port "$HEDGEDOC_FILE" "hedgedoc" "hedgedoc:" 3000)
register_port "hedgedoc" "$HEDGEDOC_PORT" "flexible"

# Gitea
GITEA_FILE="/opt/gitea/docker-compose.yml"
GITEA_PORT=$(extract_port "$GITEA_FILE" "gitea" "gitea:" 3000)
register_port "gitea" "$GITEA_PORT" "flexible"

# Display registered ports
echo "Migration complete. Current port allocation:"
list_ports

echo "✅ Port migration completed successfully!"
echo "⚠️  NOTE: If a service wasn't found, it will use its default port when next installed."
echo "🔧 Review the port allocations above and manually adjust if needed using:"
echo "   $SCRIPT_DIR/port_manager.sh register [service] [port] [fixed|flexible]"
