#!/bin/bash
# MCP Deployment Planner
# Follows AgencyStack Charter v1.0.3 principles:
# - Repository as Source of Truth
# - Strict Containerization
# - Idempotency & Automation
# - TDD Protocol Compliance

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common utilities if available
if [[ -f "${SCRIPT_DIR}/../../utils/common.sh" ]]; then
  source "${SCRIPT_DIR}/../../utils/common.sh"
else
  # Fallback logging functions
  log_info() { echo -e "[INFO] $1"; }
  log_error() { echo -e "[ERROR] $1"; }
  log_success() { echo -e "[SUCCESS] $1"; }
  log_warning() { echo -e "[WARNING] $1"; }
fi

# Default values
CLIENT_ID="${1:-peacefestivalusa}"
COMPONENTS="${2:-wordpress,traefik,keycloak,mcp_server}"
MCP_URL="${3:-http://localhost:3000}"
OUTPUT_FILE="${4:-/tmp/${CLIENT_ID}_deployment_plan.json}"

# Log header
log_info "==================================================="
log_info "AgencyStack MCP Deployment Planner"
log_info "Following AgencyStack Charter v1.0.3 principles"
log_info "==================================================="
log_info "Client ID: ${CLIENT_ID}"
log_info "Components: ${COMPONENTS}"
log_info "MCP URL: ${MCP_URL}"
log_info "Output File: ${OUTPUT_FILE}"
log_info "==================================================="

# Function to check if a command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Check if required commands exist
if ! command_exists curl; then
  log_error "curl command not found. Please install curl."
  exit 1
fi

if ! command_exists jq; then
  log_warning "jq command not found. JSON output will not be formatted."
fi

# Check MCP server health
log_info "Checking MCP server health..."
HEALTH_CHECK=$(curl -s "${MCP_URL}/health")

if [[ $? -ne 0 ]]; then
  log_error "Failed to connect to MCP server at ${MCP_URL}"
  exit 1
fi

log_success "MCP server is available"

# Create a deployment plan JSON payload
log_info "Creating deployment plan request..."

# Convert components string to array for JSON
IFS=',' read -ra COMPONENT_ARRAY <<< "${COMPONENTS}"
COMPONENT_JSON=$(printf '"%s",' "${COMPONENT_ARRAY[@]}" | sed 's/,$//')

# Prepare the JSON payload
PAYLOAD=$(cat <<EOF
{
  "task": "deployment_planning",
  "client_id": "${CLIENT_ID}",
  "components": [${COMPONENT_JSON}],
  "charter_version": "1.0.3",
  "tdd_compliance": true,
  "mcp_integration": true,
  "validate_wordpress": true
}
EOF
)

# Send request to MCP server
log_info "Requesting deployment plan from MCP server..."
RESPONSE=$(curl -s -X POST -H "Content-Type: application/json" -d "${PAYLOAD}" "${MCP_URL}/taskmaster")

if [[ $? -ne 0 ]]; then
  log_error "Failed to get deployment plan from MCP server"
  exit 1
fi

# Create manual deployment plan if MCP server doesn't support planning
if [[ ! $RESPONSE =~ "plan" ]]; then
  log_warning "MCP server didn't return a plan. Creating a manual deployment plan..."
  
  # Create a manual plan following AgencyStack Charter
  PLAN=$(cat <<EOF
{
  "name": "${CLIENT_ID}-deployment-plan",
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "client_id": "${CLIENT_ID}",
  "components": [${COMPONENT_JSON}],
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
)

  # Add installation tasks
  TASK_ID=1
  for component in "${COMPONENT_ARRAY[@]}"; do
    # Handle traefik first (dependency ordering)
    if [[ "$component" == "traefik" ]]; then
      INSTALL_TASKS="${INSTALL_TASKS}        {
          \"id\": \"install-${TASK_ID}\",
          \"name\": \"Install ${component}\",
          \"status\": \"pending\",
          \"component\": \"${component}\",
          \"command\": \"make ${component} CLIENT_ID=${CLIENT_ID}\",
          \"description\": \"Install ${component} following Charter containerization principles\"
        },
"
      TASK_ID=$((TASK_ID+1))
    fi
  done
  
  # Add other components
  for component in "${COMPONENT_ARRAY[@]}"; do
    if [[ "$component" != "traefik" ]]; then
      INSTALL_TASKS="${INSTALL_TASKS}        {
          \"id\": \"install-${TASK_ID}\",
          \"name\": \"Install ${component}\",
          \"status\": \"pending\",
          \"component\": \"${component}\",
          \"command\": \"make ${component} CLIENT_ID=${CLIENT_ID}\",
          \"description\": \"Install ${component} following Charter containerization principles\"
        }$(if [[ "$component" != "${COMPONENT_ARRAY[-1]}" && "$component" != "traefik" ]]; then echo ","; fi)
"
      TASK_ID=$((TASK_ID+1))
    fi
  done

  # Remove trailing comma if needed
  INSTALL_TASKS=$(echo "$INSTALL_TASKS" | sed 's/,$//')
  
  # Continue building the plan
  PLAN="${PLAN}${INSTALL_TASKS}
      ]
    },
    {
      "name": "validation",
      "description": "Validate components following TDD Protocol",
      "tasks": [
EOF

  # Add validation tasks
  TASK_ID=1
  for component in "${COMPONENT_ARRAY[@]}"; do
    VALIDATION_TASKS="${VALIDATION_TASKS}        {
          \"id\": \"test-${TASK_ID}\",
          \"name\": \"Test ${component}\",
          \"status\": \"pending\",
          \"component\": \"${component}\",
          \"command\": \"make ${component}-test CLIENT_ID=${CLIENT_ID}\",
          \"description\": \"Run comprehensive tests for ${component} following TDD protocol\"
        }$(if [[ "$component" != "${COMPONENT_ARRAY[-1]}" ]]; then echo ","; fi)
"
    TASK_ID=$((TASK_ID+1))
  done
  
  # Finish the plan
  PLAN="${PLAN}${VALIDATION_TASKS}
      ]
    },
    {
      "name": "integration",
      "description": "Validate component integrations",
      "tasks": [
        {
          "id": "integration-1",
          "name": "Verify MCP server health",
          "status": "pending",
          "command": "curl -s http://localhost:3000/health | jq",
          "description": "Verify MCP server is healthy and responsive"
        },
        {
          "id": "integration-2",
          "name": "Validate WordPress with MCP",
          "status": "pending",
          "command": "curl -X POST -H \"Content-Type: application/json\" -d '{\"task\":\"verify_wordpress\",\"url\":\"http://localhost:8082\"}' http://localhost:3000/puppeteer | jq",
          "description": "Use MCP server to validate WordPress installation"
        }
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
)

  # Set the response to our manual plan
  RESPONSE="{ \"success\": true, \"message\": \"Manual deployment plan generated\", \"plan\": ${PLAN} }"
fi

# Save the plan to the output file
log_info "Saving deployment plan to ${OUTPUT_FILE}..."
echo "${RESPONSE}" > "${OUTPUT_FILE}"

# Format with jq if available
if command_exists jq; then
  jq . "${OUTPUT_FILE}" > "${OUTPUT_FILE}.formatted" && mv "${OUTPUT_FILE}.formatted" "${OUTPUT_FILE}"
fi

log_success "Deployment plan created successfully!"
log_info "To view the plan: cat ${OUTPUT_FILE} | jq"
log_info "To execute the plan: bash ${SCRIPT_DIR}/execute_deployment_plan.sh ${OUTPUT_FILE}"

# Done
exit 0
