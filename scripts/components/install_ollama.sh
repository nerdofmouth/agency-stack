#!/bin/bash
# install_ollama.sh - AgencyStack Ollama LLM Service Integration
# [https://stack.nerdofmouth.com](https://stack.nerdofmouth.com)
#
# Installs and configures Ollama for local LLM inference
# Part of the AgencyStack AI Foundation
#
# Author: AgencyStack Team
# Version: 1.0.0
# Date: April 5, 2025

# --- BEGIN: Preflight/Prerequisite Check ---
source "$(dirname \"$0\")/../utils/common.sh"
preflight_check_agencystack || {
  echo -e "[ERROR] Preflight checks failed. Resolve issues before proceeding."
  exit 1
}
# --- END: Preflight/Prerequisite Check ---

# Strict error handling
set -eo pipefail

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
CONFIG_DIR="/opt/agency_stack"
LOG_DIR="/var/log/agency_stack"
COMPONENT_LOG_DIR="${LOG_DIR}/components"
OLLAMA_LOG="${COMPONENT_LOG_DIR}/ollama.log"
INSTALLED_COMPONENTS="${CONFIG_DIR}/installed_components.txt"
COMPONENT_REGISTRY="${CONFIG_DIR}/config/registry/component_registry.json"
DASHBOARD_DATA="${CONFIG_DIR}/config/dashboard_data.json"
CLIENT_ID_FILE="${CONFIG_DIR}/client_id"
DOCKER_DIR="${CONFIG_DIR}/docker/ollama"

# Ollama Configuration
OLLAMA_VERSION="0.1.27"
CLIENT_ID=""
CLIENT_DIR=""
MODELS=""
PORT="11434"
METRICS_PORT="11435"
WITH_DEPS=false
FORCE=false
USE_GPU=false
ENABLE_MONITORING=true
OLLAMA_DATA_DIR="/var/lib/ollama"
MEMORY_LIMIT="8g"
OLLAMA_CONTAINER_NAME="ollama"

# Function to log messages
log() {
  local level="$1"
  local message="$2"
  local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
  
  # Ensure log directory exists
  mkdir -p "${COMPONENT_LOG_DIR}"
  
  # Log to file
  echo "[$timestamp] [$level] $message" >> "${OLLAMA_LOG}"
  
  # Output to console with colors
  case "$level" in
    "INFO")  echo -e "${GREEN}[$level] $message${NC}" ;;
    "WARN")  echo -e "${YELLOW}[$level] $message${NC}" ;;
    "ERROR") echo -e "${RED}[$level] $message${NC}" ;;
    *)       echo -e "[$level] $message" ;;
  esac
}

# Show usage information
show_help() {
  echo -e "${BOLD}${MAGENTA}AgencyStack Ollama Installer${NC}"
  echo -e "${BOLD}Usage:${NC} $0 [OPTIONS]"
  echo
  echo -e "${BOLD}Options:${NC}"
  echo -e "  ${CYAN}--client-id${NC} <id>           Client ID for multi-tenant setup"
  echo -e "  ${CYAN}--models${NC} <models>          Space-separated list of models to install (e.g., 'llama2 mistral codellama')"
  echo -e "  ${CYAN}--port${NC} <port>              Port for Ollama API (default: 11434)"
  echo -e "  ${CYAN}--metrics-port${NC} <port>      Port for Prometheus metrics (default: 11435)"
  echo -e "  ${CYAN}--with-deps${NC}                Install dependencies (Docker, etc.)"
  echo -e "  ${CYAN}--force${NC}                    Force installation even if already installed"
  echo -e "  ${CYAN}--use-gpu${NC}                  Enable GPU acceleration (requires NVIDIA GPU and drivers)"
  echo -e "  ${CYAN}--memory-limit${NC} <limit>     Memory limit for Ollama container (default: 8g)"
  echo -e "  ${CYAN}--disable-monitoring${NC}       Disable monitoring integration"
  echo -e "  ${CYAN}--help${NC}                     Show this help message and exit"
  echo
  echo -e "${BOLD}Examples:${NC}"
  echo -e "  $0 --client-id client1 --models 'llama2 mistral' --with-deps"
  echo -e "  $0 --client-id client1 --models codellama --use-gpu --memory-limit 16g"
  exit 0
}

# Setup client directory structure
setup_client_dir() {
  # If no client ID provided, use 'default'
  if [ -z "$CLIENT_ID" ]; then
    CLIENT_ID="default"
    log "INFO" "No client ID provided, using 'default'"
  fi
  
  # Set up client directory
  CLIENT_DIR="${CONFIG_DIR}/clients/${CLIENT_ID}"
  mkdir -p "${CLIENT_DIR}"
  
  # Create AI directories
  mkdir -p "${CLIENT_DIR}/ai/ollama/config"
  mkdir -p "${CLIENT_DIR}/ai/ollama/logs"
  mkdir -p "${CLIENT_DIR}/ai/ollama/scripts"
  mkdir -p "${CLIENT_DIR}/ai/ollama/usage"
  
  log "INFO" "Set up client directory at ${CLIENT_DIR}"
  
  # Save client ID to file if it doesn't exist
  if [ ! -f "${CLIENT_ID_FILE}" ]; then
    echo "${CLIENT_ID}" > "${CLIENT_ID_FILE}"
    log "INFO" "Saved client ID to ${CLIENT_ID_FILE}"
  fi
}

# Check system requirements
check_requirements() {
  log "INFO" "Checking system requirements..."
  
  # Check if Docker is installed
  if ! command -v docker &> /dev/null && ! [ "$WITH_DEPS" = true ]; then
    log "ERROR" "Docker is not installed. Please install Docker first or use --with-deps"
    exit 1
  fi
  
  # Check if Docker Compose is installed
  if ! command -v docker-compose &> /dev/null && ! [ "$WITH_DEPS" = true ]; then
    log "ERROR" "Docker Compose is not installed. Please install Docker Compose first or use --with-deps"
    exit 1
  fi
  
  # Check for GPU if requested
  if [ "$USE_GPU" = true ]; then
    if ! command -v nvidia-smi &> /dev/null; then
      log "ERROR" "NVIDIA GPU drivers not found but --use-gpu was specified"
      log "ERROR" "Please install NVIDIA drivers or remove --use-gpu flag"
      exit 1
    fi
    
    # Check for nvidia-container-toolkit
    if ! docker info | grep -q "Runtimes:.*nvidia"; then
      log "ERROR" "nvidia-container-toolkit not found but --use-gpu was specified"
      log "ERROR" "Please install nvidia-container-toolkit or remove --use-gpu flag"
      if [ "$WITH_DEPS" = true ]; then
        log "WARN" "Will attempt to install nvidia-container-toolkit with --with-deps"
      else
        exit 1
      fi
    fi
  fi
  
  # Check for available disk space (at least 10GB free for models)
  AVAILABLE_SPACE=$(df -BG "${OLLAMA_DATA_DIR}" | awk 'NR==2 {print $4}' | tr -d 'G')
  if [ -z "$AVAILABLE_SPACE" ] || [ "$AVAILABLE_SPACE" -lt 10 ]; then
    log "WARN" "Less than 10GB of free space available. Models may require significant disk space."
  fi
  
  # Check for available memory
  AVAILABLE_MEMORY=$(free -g | awk 'NR==2 {print $2}')
  if [ -z "$AVAILABLE_MEMORY" ] || [ "$AVAILABLE_MEMORY" -lt 8 ]; then
    log "WARN" "Less than 8GB of system memory detected. Performance may be degraded."
  fi
  
  # All checks passed
  log "INFO" "System requirements check passed"
}

# Install dependencies if required
install_dependencies() {
  if [ "$WITH_DEPS" = false ]; then
    log "INFO" "Skipping dependency installation (--with-deps not specified)"
    return
  fi
  
  log "INFO" "Installing dependencies..."
  
  # Install Docker if not installed
  if ! command -v docker &> /dev/null; then
    log "INFO" "Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    usermod -aG docker $(whoami)
    systemctl enable docker
    systemctl start docker
    log "INFO" "Docker installed successfully"
  else
    log "INFO" "Docker is already installed"
  fi
  
  # Install Docker Compose if not installed
  if ! command -v docker-compose &> /dev/null; then
    log "INFO" "Installing Docker Compose..."
    curl -L "https://github.com/docker/compose/releases/download/v2.18.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    log "INFO" "Docker Compose installed successfully"
  else
    log "INFO" "Docker Compose is already installed"
  fi
  
  # Install NVIDIA Container Toolkit if needed
  if [ "$USE_GPU" = true ] && ! docker info | grep -q "Runtimes:.*nvidia"; then
    log "INFO" "Installing NVIDIA Container Toolkit..."
    
    # Add NVIDIA repository
    curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
    
    if [ -f "/etc/debian_version" ]; then
      # Debian/Ubuntu
      curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
        sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
        tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
      
      apt-get update
      apt-get install -y nvidia-container-toolkit
    elif [ -f "/etc/redhat-release" ]; then
      # CentOS/RHEL
      curl -s -L https://nvidia.github.io/libnvidia-container/stable/rpm/nvidia-container-toolkit.repo | \
        tee /etc/yum.repos.d/nvidia-container-toolkit.repo
      
      yum install -y nvidia-container-toolkit
    else
      log "WARN" "Unsupported distribution for automatic NVIDIA toolkit installation"
      log "WARN" "Please install nvidia-container-toolkit manually"
    fi
    
    # Configure Docker to use NVIDIA runtime
    nvidia-ctk runtime configure --runtime=docker
    systemctl restart docker
    
    log "INFO" "NVIDIA Container Toolkit installed successfully"
  fi
  
  # Create Ollama data directory
  mkdir -p "${OLLAMA_DATA_DIR}"
  
  log "INFO" "Dependencies installed successfully"
}

# Create Docker configuration
create_docker_config() {
  log "INFO" "Creating Docker configuration..."
  
  # Create Docker directory if it doesn't exist
  mkdir -p "${DOCKER_DIR}"
  
  # Check if Docker Compose file already exists
  if [ -f "${DOCKER_DIR}/docker-compose.yml" ] && [ "$FORCE" = false ]; then
    log "WARN" "Docker Compose file already exists. Use --force to overwrite."
    return
  fi
  
  # Create .env file for Docker Compose
  cat > "${DOCKER_DIR}/.env" << EOF
# Ollama environment variables
# Generated on $(date -Iseconds)

CLIENT_ID=${CLIENT_ID}
PORT=${PORT}
METRICS_PORT=${METRICS_PORT}
MEMORY_LIMIT=${MEMORY_LIMIT}
OLLAMA_DATA_DIR=${OLLAMA_DATA_DIR}
CLIENT_CONFIG_DIR=${CLIENT_DIR}/ai/ollama
USE_GPU=${USE_GPU}
OLLAMA_VERSION=${OLLAMA_VERSION}
EOF

  # Create Docker Compose file
  cat > "${DOCKER_DIR}/docker-compose.yml" << EOF
version: '3.8'

services:
  ollama:
    image: ollama/ollama:${OLLAMA_VERSION}
    container_name: ollama-${CLIENT_ID}
    restart: unless-stopped
    volumes:
      - ${OLLAMA_DATA_DIR}:/root/.ollama
      - ${CLIENT_DIR}/ai/ollama/config:/config
    environment:
      - OLLAMA_HOST=0.0.0.0
      - OLLAMA_MODELS=/root/.ollama/models
    ports:
      - "${PORT}:11434"
    deploy:
      resources:
        limits:
          memory: ${MEMORY_LIMIT}
EOF

  # Add GPU configuration if requested
  if [ "$USE_GPU" = true ]; then
    cat >> "${DOCKER_DIR}/docker-compose.yml" << EOF
    runtime: nvidia
    environment:
      - NVIDIA_VISIBLE_DEVICES=all
EOF
  fi

  # Add metrics sidecar
  cat >> "${DOCKER_DIR}/docker-compose.yml" << EOF
  
  # Prometheus metrics exporter for Ollama
  ollama-exporter:
    image: ghcr.io/huggingface/ollama-exporter:latest
    container_name: ollama-exporter-${CLIENT_ID}
    restart: unless-stopped
    depends_on:
      - ollama
    environment:
      - OLLAMA_HOST=http://ollama:11434
      - OLLAMA_EXPORTER_PORT=${METRICS_PORT}
    ports:
      - "${METRICS_PORT}:${METRICS_PORT}"
    healthcheck:
      test: ["CMD", "wget", "-qO-", "http://localhost:${METRICS_PORT}/metrics"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 20s

networks:
  default:
    name: ollama_network_${CLIENT_ID}
EOF

  log "INFO" "Created Docker Compose configuration at ${DOCKER_DIR}/docker-compose.yml"
}

# Create model configuration
create_model_config() {
  log "INFO" "Creating model configuration..."
  
  # Create model configuration file
  MODEL_CONFIG="${CLIENT_DIR}/ai/ollama/config/models.json"
  
  # Default to a basic set of models if none specified
  if [ -z "$MODELS" ]; then
    MODELS="llama2"
    log "INFO" "No models specified, defaulting to llama2"
  fi
  
  # Create JSON array of models
  MODELS_JSON="["
  for model in $MODELS; do
    if [ "$MODELS_JSON" != "[" ]; then
      MODELS_JSON+=","
    fi
    MODELS_JSON+="\"$model\""
  done
  MODELS_JSON+="]"
  
  # Save model configuration
  cat > "$MODEL_CONFIG" << EOF
{
  "models": ${MODELS_JSON},
  "defaultModel": "${MODELS%% *}",
  "version": "${OLLAMA_VERSION}",
  "clientId": "${CLIENT_ID}",
  "lastUpdated": "$(date -Iseconds)",
  "autoUpdate": true,
  "useGpu": ${USE_GPU}
}
EOF

  log "INFO" "Created model configuration at ${MODEL_CONFIG}"
}

# Create monitoring script
create_monitoring_script() {
  if [ "$ENABLE_MONITORING" = false ]; then
    log "INFO" "Monitoring integration disabled. Skipping monitoring script creation."
    return
  fi
  
  log "INFO" "Creating monitoring script..."
  
  # Create monitoring directory if it doesn't exist
  MONITORING_DIR="${CONFIG_DIR}/monitoring/scripts"
  mkdir -p "${MONITORING_DIR}"
  
  # Create monitoring script
  MONITORING_SCRIPT="${MONITORING_DIR}/check_ollama-${CLIENT_ID}.sh"
  
  cat > "${MONITORING_SCRIPT}" << 'EOF'
#!/bin/bash
# Ollama Monitoring Script

# Configuration
CLIENT_ID="${1:-default}"
CONTAINER_NAME="ollama-${CLIENT_ID}"
DASHBOARD_DATA="/opt/agency_stack/config/dashboard_data.json"
MODEL_CONFIG="/opt/agency_stack/clients/${CLIENT_ID}/ai/ollama/config/models.json"
METRICS_PORT=$(grep METRICS_PORT /opt/agency_stack/docker/ollama/.env | cut -d= -f2)

# Function to update dashboard data
update_dashboard() {
  local status="$1"
  local health="$2"
  local loaded_models="$3"
  local api_calls="$4"
  local memory_usage="$5"
  
  # Check if jq is installed
  if ! command -v jq &> /dev/null; then
    echo "Error: jq is required for dashboard updates"
    exit 1
  fi
  
  # Ensure dashboard data directory exists
  mkdir -p "$(dirname "$DASHBOARD_DATA")"
  
  # Create dashboard data if it doesn't exist
  if [ ! -f "$DASHBOARD_DATA" ]; then
    echo '{"components":{}}' > "$DASHBOARD_DATA"
  fi
  
  # Check if the ai section exists
  if ! jq -e '.components.ai' "$DASHBOARD_DATA" &> /dev/null; then
    jq '.components.ai = {}' "$DASHBOARD_DATA" > "${DASHBOARD_DATA}.tmp" && mv "${DASHBOARD_DATA}.tmp" "$DASHBOARD_DATA"
  fi
  
  # Create the ollama entry if it doesn't exist
  if ! jq -e '.components.ai.ollama' "$DASHBOARD_DATA" &> /dev/null; then
    jq '.components.ai.ollama = {
      "name": "Ollama",
      "description": "Local LLM server",
      "version": "0.1.27",
      "icon": "brain",
      "status": {
        "running": false,
        "health": "unknown",
        "loaded_models": [],
        "api_calls_24h": 0,
        "memory_usage": "0 MB"
      },
      "client_data": {}
    }' "$DASHBOARD_DATA" > "${DASHBOARD_DATA}.tmp" && mv "${DASHBOARD_DATA}.tmp" "$DASHBOARD_DATA"
  fi
  
  # Create the client data entry if it doesn't exist
  if ! jq -e ".components.ai.ollama.client_data.\"${CLIENT_ID}\"" "$DASHBOARD_DATA" &> /dev/null; then
    jq ".components.ai.ollama.client_data.\"${CLIENT_ID}\" = {
      \"running\": false,
      \"health\": \"unknown\",
      \"loaded_models\": [],
      \"api_calls_24h\": 0,
      \"memory_usage\": \"0 MB\"
    }" "$DASHBOARD_DATA" > "${DASHBOARD_DATA}.tmp" && mv "${DASHBOARD_DATA}.tmp" "$DASHBOARD_DATA"
  fi
  
  # Update the client data
  jq ".components.ai.ollama.client_data.\"${CLIENT_ID}\".running = ${status}" "$DASHBOARD_DATA" > "${DASHBOARD_DATA}.tmp" && mv "${DASHBOARD_DATA}.tmp" "$DASHBOARD_DATA"
  jq ".components.ai.ollama.client_data.\"${CLIENT_ID}\".health = \"${health}\"" "$DASHBOARD_DATA" > "${DASHBOARD_DATA}.tmp" && mv "${DASHBOARD_DATA}.tmp" "$DASHBOARD_DATA"
  
  if [ -n "$loaded_models" ]; then
    jq ".components.ai.ollama.client_data.\"${CLIENT_ID}\".loaded_models = ${loaded_models}" "$DASHBOARD_DATA" > "${DASHBOARD_DATA}.tmp" && mv "${DASHBOARD_DATA}.tmp" "$DASHBOARD_DATA"
  fi
  
  if [ -n "$api_calls" ]; then
    jq ".components.ai.ollama.client_data.\"${CLIENT_ID}\".api_calls_24h = ${api_calls}" "$DASHBOARD_DATA" > "${DASHBOARD_DATA}.tmp" && mv "${DASHBOARD_DATA}.tmp" "$DASHBOARD_DATA"
  fi
  
  if [ -n "$memory_usage" ]; then
    jq ".components.ai.ollama.client_data.\"${CLIENT_ID}\".memory_usage = \"${memory_usage}\"" "$DASHBOARD_DATA" > "${DASHBOARD_DATA}.tmp" && mv "${DASHBOARD_DATA}.tmp" "$DASHBOARD_DATA"
  fi
  
  # Update the main status (use the last client's status)
  jq ".components.ai.ollama.status.running = ${status}" "$DASHBOARD_DATA" > "${DASHBOARD_DATA}.tmp" && mv "${DASHBOARD_DATA}.tmp" "$DASHBOARD_DATA"
  jq ".components.ai.ollama.status.health = \"${health}\"" "$DASHBOARD_DATA" > "${DASHBOARD_DATA}.tmp" && mv "${DASHBOARD_DATA}.tmp" "$DASHBOARD_DATA"
  
  if [ -n "$loaded_models" ]; then
    jq ".components.ai.ollama.status.loaded_models = ${loaded_models}" "$DASHBOARD_DATA" > "${DASHBOARD_DATA}.tmp" && mv "${DASHBOARD_DATA}.tmp" "$DASHBOARD_DATA"
  fi
  
  if [ -n "$api_calls" ]; then
    jq ".components.ai.ollama.status.api_calls_24h = ${api_calls}" "$DASHBOARD_DATA" > "${DASHBOARD_DATA}.tmp" && mv "${DASHBOARD_DATA}.tmp" "$DASHBOARD_DATA"
  fi
  
  if [ -n "$memory_usage" ]; then
    jq ".components.ai.ollama.status.memory_usage = \"${memory_usage}\"" "$DASHBOARD_DATA" > "${DASHBOARD_DATA}.tmp" && mv "${DASHBOARD_DATA}.tmp" "$DASHBOARD_DATA"
  fi
}

# Get container metrics
get_container_metrics() {
  # Get memory usage
  MEMORY_USAGE=$(docker stats --no-stream --format "{{.MemUsage}}" $CONTAINER_NAME 2>/dev/null | awk '{print $1}')
  
  # If metrics exporter is running, try to get API calls from Prometheus metrics
  if [[ -n "$METRICS_PORT" ]] && curl -s "http://localhost:${METRICS_PORT}/metrics" &>/dev/null; then
    # Extract API calls from metrics
    API_CALLS=$(curl -s "http://localhost:${METRICS_PORT}/metrics" | grep 'ollama_requests_total' | grep -v "#" | awk '{sum += $2} END {print sum}')
    API_CALLS=${API_CALLS:-0}
  else
    API_CALLS=0
  fi
  
  echo "$MEMORY_USAGE,$API_CALLS"
}

# Check if container is running
RUNNING="false"
HEALTH="unknown"
LOADED_MODELS="[]"
API_CALLS=0
MEMORY_USAGE="0 MB"

if docker ps -q -f name=$CONTAINER_NAME | grep -q .; then
  RUNNING="true"
  
  # Check container health status
  HEALTH_STATUS=$(docker inspect --format='{{.State.Health.Status}}' $CONTAINER_NAME 2>/dev/null)
  
  case $HEALTH_STATUS in
    "healthy")
      HEALTH="healthy"
      ;;
    "unhealthy")
      HEALTH="error"
      ;;
    "starting")
      HEALTH="starting"
      ;;
    *)
      # If no explicit health status, check if we can reach the API
      if curl -s "http://localhost:11434/api/tags" &>/dev/null; then
        HEALTH="healthy"
      else
        HEALTH="unknown"
      fi
      ;;
  esac
  
  # Try to get loaded models from API
  if [ "$HEALTH" = "healthy" ]; then
    # Get models from API
    MODELS_JSON=$(curl -s "http://localhost:11434/api/tags")
    if [ -n "$MODELS_JSON" ]; then
      # Extract model names using jq if available
      if command -v jq &>/dev/null; then
        LOADED_MODELS=$(echo "$MODELS_JSON" | jq -c '[.models[].name]')
      else
        # Fallback to grep and sed if jq is not available
        LOADED_MODELS="[$(echo "$MODELS_JSON" | grep -o '"name":"[^"]*"' | sed 's/"name":"//g' | sed 's/"//g' | sed 's/^/"/g' | sed 's/$/"/g' | paste -sd "," -)]"
      fi
    fi
    
    # Get container metrics
    METRICS=$(get_container_metrics)
    MEMORY_USAGE=$(echo "$METRICS" | cut -d, -f1)
    API_CALLS=$(echo "$METRICS" | cut -d, -f2)
  fi
else
  HEALTH="stopped"
  RUNNING="false"
fi

# Update dashboard
update_dashboard "$RUNNING" "$HEALTH" "$LOADED_MODELS" "$API_CALLS" "$MEMORY_USAGE"

# Output status
echo "Ollama status for client '${CLIENT_ID}':"
echo "- Running: $RUNNING"
echo "- Health: $HEALTH"
echo "- Loaded models: $LOADED_MODELS"
echo "- API calls (24h): $API_CALLS"
echo "- Memory usage: $MEMORY_USAGE"

exit 0
EOF

  # Make monitoring script executable
  chmod +x "${MONITORING_SCRIPT}"
  
  log "INFO" "Created monitoring script at ${MONITORING_SCRIPT}"
  
  # Create cron job for monitoring
  CRON_DIR="/etc/cron.d"
  if [ -d "$CRON_DIR" ]; then
    CRON_FILE="${CRON_DIR}/ollama-${CLIENT_ID}-monitor"
    echo "*/5 * * * * root ${MONITORING_SCRIPT} ${CLIENT_ID} > /dev/null 2>&1" > "$CRON_FILE"
    log "INFO" "Created cron job for monitoring at ${CRON_FILE}"
  else
    log "WARN" "Cron directory not found. Could not create monitoring cron job."
  fi
}

# Create API helper scripts
create_helper_scripts() {
  log "INFO" "Creating helper scripts..."
  
  # Create scripts directory
  SCRIPTS_DIR="${CLIENT_DIR}/ai/ollama/scripts"
  mkdir -p "$SCRIPTS_DIR"
  
  # Create model pull script
  cat > "${SCRIPTS_DIR}/pull_models.sh" << 'EOF'
#!/bin/bash
# Script to pull Ollama models

# Configuration
CLIENT_ID="${1:-default}"
MODELS_FILE="/opt/agency_stack/clients/${CLIENT_ID}/ai/ollama/config/models.json"
LOG_FILE="/var/log/agency_stack/components/ollama.log"

# Function to log messages
log() {
  local level="$1"
  local message="$2"
  local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
  
  # Log to file
  echo "[$timestamp] [$level] $message" >> "${LOG_FILE}"
  
  # Output to console
  echo "[$level] $message"
}

# Check if models file exists
if [ ! -f "$MODELS_FILE" ]; then
  log "ERROR" "Models file not found: $MODELS_FILE"
  exit 1
fi

# Extract models from JSON file
if ! command -v jq &>/dev/null; then
  log "ERROR" "jq command not found, please install jq"
  exit 1
fi

# Get models list
MODELS=$(jq -r '.models[]' "$MODELS_FILE")

# Check if Ollama is running
if ! curl -s "http://localhost:11434/api/tags" &>/dev/null; then
  log "ERROR" "Ollama API not reachable. Make sure Ollama is running."
  exit 1
fi

# Pull each model
for model in $MODELS; do
  log "INFO" "Pulling model: $model"
  
  # Pull the model using the Ollama API
  curl -X POST "http://localhost:11434/api/pull" \
    -H "Content-Type: application/json" \
    -d "{\"name\":\"$model\"}" \
    | tee >(jq -r '.status' 2>/dev/null | while read status; do
        if [ -n "$status" ]; then
          echo -ne "\r$status"
        fi
      done)
  
  echo ""
  log "INFO" "Model $model download complete"
done

log "INFO" "All models downloaded successfully"
exit 0
EOF

  # Create model list script
  cat > "${SCRIPTS_DIR}/list_models.sh" << 'EOF'
#!/bin/bash
# Script to list available Ollama models

# Configuration
CLIENT_ID="${1:-default}"
LOG_FILE="/var/log/agency_stack/components/ollama.log"

# Function to log messages
log() {
  local level="$1"
  local message="$2"
  local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
  
  # Log to file
  echo "[$timestamp] [$level] $message" >> "${LOG_FILE}"
  
  # Output to console
  echo "[$level] $message"
}

# Check if Ollama is running
if ! curl -s "http://localhost:11434/api/tags" &>/dev/null; then
  log "ERROR" "Ollama API not reachable. Make sure Ollama is running."
  exit 1
fi

# Get models list
log "INFO" "Fetching available models..."
RESPONSE=$(curl -s "http://localhost:11434/api/tags")

# Format and display models
if command -v jq &>/dev/null; then
  echo "Available models:"
  echo "$RESPONSE" | jq -r '.models[] | "\(.name) - \(.size) - \(.modified)"' | \
    awk '{printf "%-20s %-15s %-20s\n", $1, $3, $5}'
else
  echo "$RESPONSE"
fi

exit 0
EOF

  # Create basic API test script
  cat > "${SCRIPTS_DIR}/test_api.sh" << 'EOF'
#!/bin/bash
# Script to test Ollama API

# Configuration
CLIENT_ID="${1:-default}"
MODEL="${2:-llama2}"
PROMPT="${3:-Write a short poem about artificial intelligence.}"
LOG_FILE="/var/log/agency_stack/components/ollama.log"

# Function to log messages
log() {
  local level="$1"
  local message="$2"
  local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
  
  # Log to file
  echo "[$timestamp] [$level] $message" >> "${LOG_FILE}"
  
  # Output to console
  echo "[$level] $message"
}

# Check if Ollama is running
if ! curl -s "http://localhost:11434/api/tags" &>/dev/null; then
  log "ERROR" "Ollama API not reachable. Make sure Ollama is running."
  exit 1
fi

# Check if model is available
if ! curl -s "http://localhost:11434/api/tags" | grep -q "\"name\":\"$MODEL\""; then
  log "WARN" "Model $MODEL not found. Available models:"
  curl -s "http://localhost:11434/api/tags" | grep -o '"name":"[^"]*"' | sed 's/"name":"//g' | sed 's/"//g'
  log "INFO" "You can pull the model using: ./pull_models.sh $CLIENT_ID"
  exit 1
fi

# Run inference
log "INFO" "Testing API with model: $MODEL"
log "INFO" "Prompt: $PROMPT"
echo ""
echo "Response:"
echo "-----------------------------------"

# Non-streaming response
curl -X POST "http://localhost:11434/api/generate" \
  -H "Content-Type: application/json" \
  -d "{
    \"model\": \"$MODEL\",
    \"prompt\": \"$PROMPT\"
  }" | jq -r '.response'

echo "-----------------------------------"
log "INFO" "API test completed"
exit 0
EOF

  # Make scripts executable
  chmod +x "${SCRIPTS_DIR}/pull_models.sh"
  chmod +x "${SCRIPTS_DIR}/list_models.sh"
  chmod +x "${SCRIPTS_DIR}/test_api.sh"
  
  # Create symlinks in /usr/local/bin
  ln -sf "${SCRIPTS_DIR}/pull_models.sh" "/usr/local/bin/ollama-pull-models-${CLIENT_ID}"
  ln -sf "${SCRIPTS_DIR}/list_models.sh" "/usr/local/bin/ollama-list-models-${CLIENT_ID}"
  ln -sf "${SCRIPTS_DIR}/test_api.sh" "/usr/local/bin/ollama-test-api-${CLIENT_ID}"
  
  log "INFO" "Created helper scripts in ${SCRIPTS_DIR}"
}

# Deploy Ollama
deploy_ollama() {
  log "INFO" "Deploying Ollama..."
  
  # Navigate to Docker directory
  cd "${DOCKER_DIR}"
  
  # Start containers
  docker-compose up -d
  
  # Wait for Ollama to start
  log "INFO" "Waiting for Ollama to start..."
  for i in {1..30}; do
    if curl -s "http://localhost:${PORT}/api/tags" &>/dev/null; then
      log "INFO" "Ollama API is up and running"
      break
    fi
    
    if [ $i -eq 30 ]; then
      log "WARN" "Ollama API did not become available within the timeout. Continuing anyway."
    fi
    
    sleep 2
  done
  
  # Pull models if specified
  if [ -n "$MODELS" ]; then
    log "INFO" "Pulling specified models..."
    
    # Call the pull_models script
    "${CLIENT_DIR}/ai/ollama/scripts/pull_models.sh" "${CLIENT_ID}"
  fi
  
  # Update dashboard data
  if [ "$ENABLE_MONITORING" = true ] && [ -f "${CONFIG_DIR}/monitoring/scripts/check_ollama-${CLIENT_ID}.sh" ]; then
    log "INFO" "Updating dashboard data..."
    "${CONFIG_DIR}/monitoring/scripts/check_ollama-${CLIENT_ID}.sh" "${CLIENT_ID}"
  fi
  
  log "INFO" "Ollama deployment completed"
}

# Update component registry
update_registry() {
  log "INFO" "Updating component registry..."
  
  # Update installed components list
  if ! grep -q "ollama" "$INSTALLED_COMPONENTS" 2>/dev/null; then
    mkdir -p "$(dirname "$INSTALLED_COMPONENTS")"
    echo "ollama" >> "$INSTALLED_COMPONENTS"
    log "INFO" "Added ollama to installed components list"
  fi
  
  # Check if registry file exists
  if [ ! -f "$COMPONENT_REGISTRY" ]; then
    mkdir -p "$(dirname "$COMPONENT_REGISTRY")"
    echo '{"components":{}}' > "$COMPONENT_REGISTRY"
    log "INFO" "Created component registry file"
  fi
  
  # Check if jq is installed
  if ! command -v jq &> /dev/null; then
    log "WARN" "jq is not installed. Skipping registry update."
    return
  fi
  
  # Create temporary file for JSON manipulation
  TEMP_FILE=$(mktemp)
  
  # Check if ai section exists
  if ! jq -e '.components.ai' "$COMPONENT_REGISTRY" &> /dev/null; then
    jq '.components.ai = {}' "$COMPONENT_REGISTRY" > "$TEMP_FILE" && mv "$TEMP_FILE" "$COMPONENT_REGISTRY"
  fi
  
  # Add or update ollama entry
  jq '.components.ai.ollama = {
    "name": "Ollama",
    "component_id": "ollama",
    "category": "AI",
    "version": "'"${OLLAMA_VERSION}"'",
    "integration_status": {
      "installed": true,
      "hardened": true,
      "makefile": true,
      "sso_ready": false,
      "dashboard": true,
      "logs": true,
      "docs": true,
      "auditable": true,
      "traefik": false,
      "multi_tenant": true,
      "monitoring": true
    },
    "description": "Local LLM inference server with multi-model support",
    "ports": {
      "api": '${PORT}',
      "metrics": '${METRICS_PORT}'
    }
  }' "$COMPONENT_REGISTRY" > "$TEMP_FILE" && mv "$TEMP_FILE" "$COMPONENT_REGISTRY"
  
  log "INFO" "Updated component registry with ollama entry"
}

# Print summary and usage instructions
print_summary() {
  echo
  echo -e "${BOLD}${GREEN}=== Ollama Installation Complete ===${NC}"
  echo
  echo -e "${BOLD}Configuration Details:${NC}"
  echo -e "  ${CYAN}Client ID:${NC}        ${CLIENT_ID}"
  echo -e "  ${CYAN}API Port:${NC}         ${PORT}"
  echo -e "  ${CYAN}Metrics Port:${NC}     ${METRICS_PORT}"
  echo -e "  ${CYAN}Memory Limit:${NC}     ${MEMORY_LIMIT}"
  echo -e "  ${CYAN}GPU Enabled:${NC}      $([ "$USE_GPU" = true ] && echo "Yes" || echo "No")"
  echo -e "  ${CYAN}Models:${NC}           ${MODELS:-"None (default: llama2)"}"
  echo
  echo -e "${BOLD}Helper Commands:${NC}"
  echo -e "  ${CYAN}Pull Models:${NC}      ollama-pull-models-${CLIENT_ID}"
  echo -e "  ${CYAN}List Models:${NC}      ollama-list-models-${CLIENT_ID}"
  echo -e "  ${CYAN}Test API:${NC}         ollama-test-api-${CLIENT_ID} [model] [prompt]"
  echo
  echo -e "${BOLD}API Usage:${NC}"
  echo -e "  ${CYAN}Generate Text:${NC}"
  echo -e "    curl -X POST http://localhost:${PORT}/api/generate \\"
  echo -e "      -H \"Content-Type: application/json\" \\"
  echo -e "      -d '{\"model\":\"llama2\",\"prompt\":\"Tell me about AgencyStack\"}'"
  echo
  echo -e "  ${CYAN}Chat:${NC}"
  echo -e "    curl -X POST http://localhost:${PORT}/api/chat \\"
  echo -e "      -H \"Content-Type: application/json\" \\"
  echo -e "      -d '{\"model\":\"llama2\",\"messages\":[{\"role\":\"user\",\"content\":\"Hello\"}]}'"
  echo
  echo -e "${BOLD}${GREEN}For more information, see the documentation at:${NC}"
  echo -e "  ${CYAN}https://stack.nerdofmouth.com/docs/ai/ollama.html${NC}"
  echo
}

# Main function
main() {
  # Process command-line arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --client-id)
        CLIENT_ID="$2"
        shift 2
        ;;
      --models)
        MODELS="$2"
        shift 2
        ;;
      --port)
        PORT="$2"
        shift 2
        ;;
      --metrics-port)
        METRICS_PORT="$2"
        shift 2
        ;;
      --memory-limit)
        MEMORY_LIMIT="$2"
        shift 2
        ;;
      --with-deps)
        WITH_DEPS=true
        shift
        ;;
      --force)
        FORCE=true
        shift
        ;;
      --use-gpu)
        USE_GPU=true
        shift
        ;;
      --disable-monitoring)
        ENABLE_MONITORING=false
        shift
        ;;
      --help)
        show_help
        ;;
      *)
        log "ERROR" "Unknown option: $1"
        echo "Use --help for usage information"
        exit 1
        ;;
    esac
  done
  
  # Log the start of installation
  log "INFO" "Starting Ollama installation (version ${OLLAMA_VERSION})..."
  
  # Run installation steps
  setup_client_dir
  check_requirements
  install_dependencies
  create_docker_config
  create_model_config
  create_monitoring_script
  create_helper_scripts
  deploy_ollama
  update_registry
  
  # Print summary
  print_summary
  
  # Log completion
  log "INFO" "Ollama installation completed successfully"
}

# Execute main function
main "$@"
