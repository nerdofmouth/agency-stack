#!/bin/bash
# Simple MCP Deployment Planner
# Follows AgencyStack Charter v1.0.3 principles:
# - Repository as Source of Truth
# - Strict Containerization
# - Idempotency & Automation
# - TDD Protocol Compliance

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Default values
CLIENT_ID="${1:-peacefestivalusa}"
COMPONENTS="${2:-wordpress,traefik,keycloak,mcp_server}"
OUTPUT_FILE="${3:-/tmp/${CLIENT_ID}_deployment_plan.json}"

# Log functions
log_info() { echo -e "[INFO] $1"; }
log_error() { echo -e "[ERROR] $1"; }
log_success() { echo -e "[SUCCESS] $1"; }
log_warning() { echo -e "[WARNING] $1"; }

# Log header
log_info "==================================================="
log_info "AgencyStack MCP Deployment Planner"
log_info "Following AgencyStack Charter v1.0.3 principles"
log_info "==================================================="
log_info "Client ID: ${CLIENT_ID}"
log_info "Components: ${COMPONENTS}"
log_info "Output File: ${OUTPUT_FILE}"
log_info "==================================================="

# Convert components string to array
IFS=',' read -ra COMPONENT_ARRAY <<< "${COMPONENTS}"

# Create a basic deployment plan directly
log_info "Creating deployment plan..."

# Generate timestamp
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Start the plan
cat > "${OUTPUT_FILE}" << EOF
{
  "name": "${CLIENT_ID}-deployment-plan",
  "timestamp": "${TIMESTAMP}",
  "client_id": "${CLIENT_ID}",
  "components": [
EOF

# Add components
for i in "${!COMPONENT_ARRAY[@]}"; do
  COMPONENT="${COMPONENT_ARRAY[$i]}"
  echo "    \"${COMPONENT}\"$([ $i -lt $((${#COMPONENT_ARRAY[@]} - 1)) ] && echo ",")" >> "${OUTPUT_FILE}"
done

# Continue with the plan structure
cat >> "${OUTPUT_FILE}" << EOF
  ],
  "charter_version": "1.0.3",
  "tdd_compliance": true,
  "phases": [
    {
      "name": "preparation",
      "description": "Validate environment and prerequisites",
      "tasks": [
        {
          "id": "prep-1",
          "name": "Validate directory structure",
          "status": "pending",
          "command": "make env-check",
          "description": "Ensures all required directories exist following Charter structure"
        },
        {
          "id": "prep-2",
          "name": "Check prerequisites",
          "status": "pending",
          "command": "make prereq-check",
          "description": "Validates Docker, Docker Compose, and other requirements"
        },
        {
          "id": "prep-3",
          "name": "Backup existing data",
          "status": "pending",
          "command": "make backup CLIENT_ID=${CLIENT_ID}",
          "description": "Creates backup of any existing data as a safety measure"
        }
      ]
    },
    {
      "name": "installation",
      "description": "Install components in dependency order",
      "tasks": [
EOF

# Add installation tasks, respecting dependencies
# Traefik first (if present)
TASK_ID=1
for COMPONENT in "${COMPONENT_ARRAY[@]}"; do
  if [[ "${COMPONENT}" == "traefik" ]]; then
    cat >> "${OUTPUT_FILE}" << EOF
        {
          "id": "install-${TASK_ID}",
          "name": "Install ${COMPONENT}",
          "status": "pending",
          "component": "${COMPONENT}",
          "command": "make ${COMPONENT} CLIENT_ID=${CLIENT_ID}",
          "description": "Install ${COMPONENT} following Charter containerization principles"
        },
EOF
    TASK_ID=$((TASK_ID+1))
    break
  fi
done

# Keycloak next (if present and traefik also present)
for COMPONENT in "${COMPONENT_ARRAY[@]}"; do
  if [[ "${COMPONENT}" == "keycloak" ]] && [[ " ${COMPONENT_ARRAY[*]} " =~ " traefik " ]]; then
    cat >> "${OUTPUT_FILE}" << EOF
        {
          "id": "install-${TASK_ID}",
          "name": "Install ${COMPONENT}",
          "status": "pending",
          "component": "${COMPONENT}",
          "command": "make ${COMPONENT} CLIENT_ID=${CLIENT_ID}",
          "description": "Install ${COMPONENT} following Charter containerization principles"
        },
EOF
    TASK_ID=$((TASK_ID+1))
    break
  fi
done

# Then other components
for COMPONENT in "${COMPONENT_ARRAY[@]}"; do
  if [[ "${COMPONENT}" != "traefik" ]] && [[ "${COMPONENT}" != "keycloak" ]]; then
    cat >> "${OUTPUT_FILE}" << EOF
        {
          "id": "install-${TASK_ID}",
          "name": "Install ${COMPONENT}",
          "status": "pending",
          "component": "${COMPONENT}",
          "command": "make ${COMPONENT} CLIENT_ID=${CLIENT_ID}",
          "description": "Install ${COMPONENT} following Charter containerization principles"
        }$([ "${COMPONENT}" != "${COMPONENT_ARRAY[-1]}" ] && [[ "${COMPONENT_ARRAY[-1]}" != "traefik" ]] && [[ "${COMPONENT_ARRAY[-1]}" != "keycloak" ]] && echo ",")
EOF
    TASK_ID=$((TASK_ID+1))
  fi
done

# Continue with the plan
cat >> "${OUTPUT_FILE}" << EOF
      ]
    },
    {
      "name": "validation",
      "description": "Validate components following TDD Protocol",
      "tasks": [
EOF

# Add test tasks
TASK_ID=1
for i in "${!COMPONENT_ARRAY[@]}"; do
  COMPONENT="${COMPONENT_ARRAY[$i]}"
  cat >> "${OUTPUT_FILE}" << EOF
        {
          "id": "test-${TASK_ID}",
          "name": "Test ${COMPONENT}",
          "status": "pending",
          "component": "${COMPONENT}",
          "command": "make ${COMPONENT}-test CLIENT_ID=${CLIENT_ID}",
          "description": "Run comprehensive tests for ${COMPONENT} following TDD protocol"
        }$([ $i -lt $((${#COMPONENT_ARRAY[@]} - 1)) ] && echo ",")
EOF
  TASK_ID=$((TASK_ID+1))
done

# Finish the plan
cat >> "${OUTPUT_FILE}" << EOF
      ]
    },
    {
      "name": "integration",
      "description": "Validate component integrations",
      "tasks": [
EOF

# Add integration tasks
if [[ " ${COMPONENT_ARRAY[*]} " =~ " mcp_server " ]]; then
  cat >> "${OUTPUT_FILE}" << EOF
        {
          "id": "integration-1",
          "name": "Verify MCP server health",
          "status": "pending",
          "command": "curl -s http://localhost:3000/health | jq",
          "description": "Verify MCP server is healthy and responsive"
        },
EOF
fi

if [[ " ${COMPONENT_ARRAY[*]} " =~ " wordpress " ]] && [[ " ${COMPONENT_ARRAY[*]} " =~ " mcp_server " ]]; then
  cat >> "${OUTPUT_FILE}" << EOF
        {
          "id": "integration-2",
          "name": "Validate WordPress with MCP",
          "status": "pending",
          "command": "curl -X POST -H \"Content-Type: application/json\" -d '{\"task\":\"verify_wordpress\",\"url\":\"http://localhost:8082\"}' http://localhost:3000/puppeteer | jq",
          "description": "Use MCP server to validate WordPress installation"
        },
EOF
fi

if [[ " ${COMPONENT_ARRAY[*]} " =~ " traefik " ]] && [[ " ${COMPONENT_ARRAY[*]} " =~ " keycloak " ]]; then
  cat >> "${OUTPUT_FILE}" << EOF
        {
          "id": "integration-3",
          "name": "Verify Traefik-Keycloak integration",
          "status": "pending",
          "command": "make verify-traefik-keycloak",
          "description": "Verify Traefik is properly routing to Keycloak"
        }
EOF
fi

# Remove trailing comma from last entry
sed -i '$ s/},$/}/' "${OUTPUT_FILE}"

# Complete integration and documentation sections
cat >> "${OUTPUT_FILE}" << EOF
      ]
    },
    {
      "name": "documentation",
      "description": "Update documentation and generate reports",
      "tasks": [
        {
          "id": "doc-1",
          "name": "Update component registry",
          "status": "pending",
          "command": "make update-registry",
          "description": "Update component registry with newly installed components"
        },
        {
          "id": "doc-2",
          "name": "Generate deployment report",
          "status": "pending",
          "command": "make generate-report CLIENT_ID=${CLIENT_ID}",
          "description": "Create deployment report with configuration details"
        }
      ]
    }
  ]
}
EOF

log_success "Deployment plan created successfully!"
log_info "Plan saved to: ${OUTPUT_FILE}"

# Display plan if jq is available
if command -v jq >/dev/null 2>&1; then
  log_info "Plan summary:"
  jq -r '.name + " for client " + .client_id + " with " + (.components | length | tostring) + " components"' "${OUTPUT_FILE}"
  log_info "To view the complete plan: cat ${OUTPUT_FILE} | jq"
fi

# Done
exit 0
