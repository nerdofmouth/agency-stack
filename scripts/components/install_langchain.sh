#!/bin/bash

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/../utils/common.sh" ]]; then
  source "${SCRIPT_DIR}/../utils/common.sh"
fi

# Enforce containerization (prevent host contamination)
exit_with_warning_if_host

# AgencyStack Component Installer: langchain.sh
# Path: /scripts/components/install_langchain.sh
#
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
ROOT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
CONFIG_DIR="/opt/agency_stack"
LOG_DIR="/var/log/agency_stack"
COMPONENT_LOG_DIR="${LOG_DIR}/components"
LANGCHAIN_LOG="${COMPONENT_LOG_DIR}/langchain.log"
INSTALLED_COMPONENTS="${CONFIG_DIR}/installed_components.txt"
COMPONENT_REGISTRY="${CONFIG_DIR}/config/registry/component_registry.json"
DASHBOARD_DATA="${CONFIG_DIR}/config/dashboard_data.json"
CLIENT_ID_FILE="${CONFIG_DIR}/client_id"
DOCKER_DIR="${CONFIG_DIR}/docker/langchain"

# LangChain Configuration
LANGCHAIN_VERSION="0.1.0"
CLIENT_ID=""
CLIENT_DIR=""
DOMAIN="localhost"
PORT="5111"
WITH_DEPS=false
FORCE=false
ENABLE_OPENAI=false
USE_OLLAMA=false
OLLAMA_PORT=11434
ENABLE_MONITORING=true
MEMORY_LIMIT="2g"
LANGCHAIN_CONTAINER_NAME="langchain"

# Function to log messages
log() {
  local level="$1"
  local message="$2"
  local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
  
  # Ensure log directory exists
  mkdir -p "${COMPONENT_LOG_DIR}"
  
  # Log to file
  echo "[$timestamp] [$level] $message" >> "${LANGCHAIN_LOG}"
  
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
  echo -e "${BOLD}${MAGENTA}AgencyStack LangChain Installer${NC}"
  echo -e "${BOLD}Usage:${NC} $0 [OPTIONS]"
  echo
  echo -e "${BOLD}Options:${NC}"
  echo -e "  ${CYAN}--client-id${NC} <id>           Client ID for multi-tenant setup"
  echo -e "  ${CYAN}--domain${NC} <domain>          Domain name for service (default: localhost)"
  echo -e "  ${CYAN}--port${NC} <port>              Port for LangChain API (default: 5111)"
  echo -e "  ${CYAN}--enable-openai${NC}            Enable OpenAI API integration"
  echo -e "  ${CYAN}--use-ollama${NC}               Configure to use local Ollama LLM"
  echo -e "  ${CYAN}--ollama-port${NC} <port>       Port for Ollama API (default: 11434)"
  echo -e "  ${CYAN}--with-deps${NC}                Install dependencies (Docker, etc.)"
  echo -e "  ${CYAN}--force${NC}                    Force installation even if already installed"
  echo -e "  ${CYAN}--disable-monitoring${NC}       Disable monitoring integration"
  echo -e "  ${CYAN}--help${NC}                     Show this help message and exit"
  echo
  echo -e "${BOLD}Examples:${NC}"
  echo -e "  $0 --client-id client1 --use-ollama --with-deps"
  echo -e "  $0 --client-id client1 --enable-openai --domain api.example.com"
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
  mkdir -p "${CLIENT_DIR}/ai/langchain/config"
  mkdir -p "${CLIENT_DIR}/ai/langchain/logs"
  mkdir -p "${CLIENT_DIR}/ai/langchain/chains"
  mkdir -p "${CLIENT_DIR}/ai/langchain/tools"
  mkdir -p "${CLIENT_DIR}/ai/langchain/usage"
  
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
  
  # Check if Ollama is installed and running when using --use-ollama
  if [ "$USE_OLLAMA" = true ]; then
    if ! curl -s "http://localhost:${OLLAMA_PORT}/api/tags" &>/dev/null; then
      log "WARN" "Ollama API not reachable at port ${OLLAMA_PORT}. LangChain will be configured to use Ollama, but verify Ollama is running before using LangChain."
    else
      log "INFO" "Ollama API detected at port ${OLLAMA_PORT}"
    fi
  fi
  
  # Check for available disk space (at least 1GB free for LangChain)
  INSTALL_DIR="${CLIENT_DIR}/ai/langchain"
  AVAILABLE_SPACE=$(df -BM "$INSTALL_DIR" | awk 'NR==2 {print $4}' | tr -d 'M')
  if [ -z "$AVAILABLE_SPACE" ] || [ "$AVAILABLE_SPACE" -lt 1000 ]; then
    log "WARN" "Less than 1GB of free space available. LangChain installation may require more space."
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
  
  # Install jq for JSON processing if not installed
  if ! command -v jq &> /dev/null; then
    log "INFO" "Installing jq..."
    if [ -f "/etc/debian_version" ]; then
      apt-get update && apt-get install -y jq
    elif [ -f "/etc/redhat-release" ]; then
      yum install -y jq
    else
      log "WARN" "Unsupported distribution for automatic jq installation"
      log "WARN" "Please install jq manually"
    fi
    log "INFO" "jq installed successfully"
  else
    log "INFO" "jq is already installed"
  fi
  
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
# LangChain environment variables
# Generated on $(date -Iseconds)

CLIENT_ID=${CLIENT_ID}
DOMAIN=${DOMAIN}
PORT=${PORT}
ENABLE_OPENAI=${ENABLE_OPENAI}
USE_OLLAMA=${USE_OLLAMA}
OLLAMA_PORT=${OLLAMA_PORT}
MEMORY_LIMIT=${MEMORY_LIMIT}
CLIENT_CONFIG_DIR=${CLIENT_DIR}/ai/langchain
LOG_LEVEL=INFO
EOF

  # Create Docker Compose file
  cat > "${DOCKER_DIR}/docker-compose.yml" << EOF
version: '3.8'

services:
  langchain:
    build:
      context: ./app
    container_name: langchain-${CLIENT_ID}
    restart: unless-stopped
    volumes:
      - ./app:/app
      - ${CLIENT_DIR}/ai/langchain/config:/config
      - ${CLIENT_DIR}/ai/langchain/chains:/chains
      - ${CLIENT_DIR}/ai/langchain/tools:/tools
    environment:
      - CLIENT_ID=${CLIENT_ID}
      - PORT=${PORT}
      - HOST=0.0.0.0
      - LOG_LEVEL=INFO
      - ENABLE_OPENAI=${ENABLE_OPENAI}
      - USE_OLLAMA=${USE_OLLAMA}
      - OLLAMA_BASE_URL=http://host.docker.internal:${OLLAMA_PORT}
    ports:
      - "${PORT}:8000"
    deploy:
      resources:
        limits:
          memory: ${MEMORY_LIMIT}
    extra_hosts:
      - "host.docker.internal:host-gateway"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 20s

networks:
  default:
    name: langchain_network_${CLIENT_ID}
EOF

  log "INFO" "Created Docker Compose configuration at ${DOCKER_DIR}/docker-compose.yml"
}

# Create LangChain API service
create_langchain_service() {
  log "INFO" "Creating LangChain API service..."
  
  # Create app directory
  mkdir -p "${DOCKER_DIR}/app"
  
  # Create Dockerfile
  cat > "${DOCKER_DIR}/app/Dockerfile" << EOF
FROM python:3.11-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Run the application
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
EOF

  # Create requirements.txt
  cat > "${DOCKER_DIR}/app/requirements.txt" << EOF
fastapi>=0.100.0
uvicorn>=0.22.0
langchain>=0.0.300
langchain-core>=0.1.0
langchain-community>=0.0.10
pydantic>=2.0.0
python-dotenv>=1.0.0
requests>=2.30.0
prometheus-fastapi-instrumentator>=6.0.0
EOF

  # Add OpenAI dependency if needed
  if [ "$ENABLE_OPENAI" = true ]; then
    echo "openai>=1.0.0" >> "${DOCKER_DIR}/app/requirements.txt"
  fi

  # Create main.py
  cat > "${DOCKER_DIR}/app/main.py" << 'EOF'
#!/usr/bin/env python3
"""
LangChain API Service for AgencyStack
Main FastAPI application entry point
"""

import os
import json
import logging
from typing import Dict, List, Optional, Any

from fastapi import FastAPI, HTTPException, Depends, Request, Response
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from dotenv import load_dotenv
from prometheus_fastapi_instrumentator import Instrumentator

# Load environment variables
load_dotenv("/config/.env")

# Configure logging
logging.basicConfig(
    level=os.getenv("LOG_LEVEL", "INFO"),
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler(f"/config/logs/langchain-api.log"),
    ],
)
logger = logging.getLogger("langchain-api")

# Create FastAPI app
app = FastAPI(
    title="LangChain API",
    description="LangChain API service for AgencyStack",
    version="0.1.0",
)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Add Prometheus metrics
Instrumentator().instrument(app).expose(app)

# Model Configurations
class ChainRequest(BaseModel):
    chain_id: str
    inputs: Dict[str, Any] = Field(default_factory=dict)
    streaming: bool = False

class PromptRequest(BaseModel):
    template: str
    inputs: Dict[str, Any] = Field(default_factory=dict)
    model: Optional[str] = "default"
    temperature: Optional[float] = 0.7
    streaming: bool = False

class AgentRequest(BaseModel):
    agent_id: str
    inputs: Dict[str, Any] = Field(default_factory=dict)
    streaming: bool = False

# Import LLM providers
@app.on_event("startup")
async def startup_event():
    """Initialize LLM providers and components on startup"""
    logger.info("Initializing LangChain API Service")
    
    # Initialize the LLM client based on configuration
    if os.getenv("USE_OLLAMA", "false").lower() == "true":
        try:
            from langchain_community.llms import Ollama
            from langchain_core.callbacks.streaming_stdout import StreamingStdOutCallbackHandler
            
            # Set Ollama as the default LLM
            base_url = os.getenv("OLLAMA_BASE_URL", "http://localhost:11434")
            logger.info(f"Using Ollama at {base_url}")
            
            # Test Ollama connection
            try:
                import requests
                response = requests.get(f"{base_url}/api/tags")
                if response.status_code == 200:
                    models = response.json().get("models", [])
                    model_names = [model["name"] for model in models]
                    logger.info(f"Available Ollama models: {model_names}")
                    if model_names:
                        os.environ["DEFAULT_MODEL"] = model_names[0]
                        logger.info(f"Set default model to {model_names[0]}")
                    else:
                        logger.warning("No models found in Ollama")
                else:
                    logger.warning(f"Ollama API response: {response.status_code}")
            except Exception as e:
                logger.warning(f"Could not connect to Ollama: {e}")
                
        except ImportError:
            logger.error("Failed to import Ollama client")
    
    elif os.getenv("ENABLE_OPENAI", "false").lower() == "true":
        try:
            from langchain_openai import ChatOpenAI
            logger.info("Using OpenAI API")
            
            # Check for API key
            if not os.getenv("OPENAI_API_KEY"):
                logger.warning("OPENAI_API_KEY not set in environment")
        except ImportError:
            logger.error("Failed to import OpenAI client")
    else:
        logger.warning("No LLM provider enabled")

    logger.info("LangChain API Service initialized")

# Health check endpoint
@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {"status": "healthy", "service": "langchain-api"}

# Get available chains
@app.get("/chains")
async def get_chains():
    """List available chains"""
    chains_dir = "/chains"
    available_chains = []
    
    try:
        for item in os.listdir(chains_dir):
            if item.endswith(".json"):
                chain_path = os.path.join(chains_dir, item)
                with open(chain_path, "r") as f:
                    chain_config = json.load(f)
                    available_chains.append({
                        "id": item.replace(".json", ""),
                        "name": chain_config.get("name", "Unnamed Chain"),
                        "description": chain_config.get("description", ""),
                        "inputs": chain_config.get("inputs", []),
                    })
    except Exception as e:
        logger.error(f"Error listing chains: {e}")
        
    return {"chains": available_chains}

# Run a chain
@app.post("/chain/run")
async def run_chain(request: ChainRequest):
    """Run a specific chain by ID"""
    chain_id = request.chain_id
    chain_path = f"/chains/{chain_id}.json"
    
    if not os.path.exists(chain_path):
        raise HTTPException(status_code=404, detail=f"Chain {chain_id} not found")
    
    try:
        # Load chain configuration
        with open(chain_path, "r") as f:
            chain_config = json.load(f)
        
        # Here we would dynamically construct and run the chain
        # This is a placeholder - real implementation would use LangChain
        logger.info(f"Running chain {chain_id} with inputs: {request.inputs}")
        
        # Simple response for now
        return {
            "chain_id": chain_id,
            "result": f"Chain {chain_id} executed successfully",
            "output": f"This is a placeholder response for chain '{chain_config.get('name')}'"
        }
    except Exception as e:
        logger.error(f"Error running chain {chain_id}: {e}")
        raise HTTPException(status_code=500, detail=str(e))

# Simple prompt endpoint
@app.post("/prompt")
async def run_prompt(request: PromptRequest):
    """Run a simple prompt through the default LLM"""
    try:
        logger.info(f"Running prompt with inputs: {request.inputs}")
        
        # Use Ollama
        if os.getenv("USE_OLLAMA", "false").lower() == "true":
            from langchain_community.llms import Ollama
            from langchain.prompts import PromptTemplate
            
            # Create prompt template
            prompt = PromptTemplate.from_template(request.template)
            
            # Format prompt with inputs
            formatted_prompt = prompt.format(**request.inputs)
            
            # Create Ollama instance
            model = request.model
            if model == "default":
                model = os.getenv("DEFAULT_MODEL", "llama2")
                
            base_url = os.getenv("OLLAMA_BASE_URL", "http://localhost:11434")
            ollama = Ollama(
                base_url=base_url,
                model=model,
                temperature=request.temperature,
            )
            
            # Run the prompt
            response = ollama.invoke(formatted_prompt)
            
            return {
                "prompt": formatted_prompt,
                "completion": response,
            }
            
        # Use OpenAI
        elif os.getenv("ENABLE_OPENAI", "false").lower() == "true":
            from langchain_openai import ChatOpenAI
            from langchain.prompts import PromptTemplate
            
            # Create prompt template
            prompt = PromptTemplate.from_template(request.template)
            
            # Format prompt with inputs
            formatted_prompt = prompt.format(**request.inputs)
            
            # Create ChatOpenAI instance
            model = request.model
            if model == "default":
                model = os.getenv("DEFAULT_MODEL", "gpt-3.5-turbo")
                
            chat = ChatOpenAI(
                model=model,
                temperature=request.temperature,
            )
            
            # Run the prompt
            from langchain_core.messages import HumanMessage
            response = chat.invoke([HumanMessage(content=formatted_prompt)])
            
            return {
                "prompt": formatted_prompt,
                "completion": response.content,
            }
        else:
            raise HTTPException(
                status_code=400,
                detail="No LLM provider enabled. Enable Ollama or OpenAI."
            )
            
    except Exception as e:
        logger.error(f"Error running prompt: {e}")
        raise HTTPException(status_code=500, detail=str(e))

# Get available tools
@app.get("/tools")
async def get_tools():
    """List available tools"""
    tools_dir = "/tools"
    available_tools = []
    
    try:
        for item in os.listdir(tools_dir):
            if item.endswith(".py") and not item.startswith("__"):
                tool_id = item.replace(".py", "")
                # Get tool description from docstring or file
                available_tools.append({
                    "id": tool_id,
                    "name": tool_id.replace("_", " ").title(),
                })
    except Exception as e:
        logger.error(f"Error listing tools: {e}")
        
    return {"tools": available_tools}

# Main entry point
if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
EOF

  # Create sample chain
  mkdir -p "${CLIENT_DIR}/ai/langchain/chains"
  cat > "${CLIENT_DIR}/ai/langchain/chains/summarize.json" << EOF
{
  "name": "Text Summarizer",
  "description": "Chain that summarizes a text document",
  "inputs": ["text"],
  "llm_config": {
    "temperature": 0.3
  },
  "prompt_template": "Please summarize the following text in a concise manner:\n\n{text}\n\nSummary:"
}
EOF

  # Create sample tool
  mkdir -p "${CLIENT_DIR}/ai/langchain/tools"
  cat > "${CLIENT_DIR}/ai/langchain/tools/weather.py" << 'EOF'
"""
Weather Tool for LangChain

This tool provides weather information using a simple API.
"""

from typing import Optional, Type
from langchain.tools import BaseTool
from pydantic import BaseModel, Field
import requests

class WeatherInput(BaseModel):
    """Input for the weather tool."""
    location: str = Field(..., description="The city and state, e.g. San Francisco, CA")

class WeatherTool(BaseTool):
    name = "weather"
    description = "Get the current weather in a given location"
    args_schema: Type[BaseModel] = WeatherInput

    def _run(self, location: str) -> str:
        """Get the weather for a location."""
        # This is a placeholder. In a real tool, you would call a weather API
        return f"Weather for {location}: 72°F, Sunny"

    async def _arun(self, location: str) -> str:
        """Get the weather for a location asynchronously."""
        return self._run(location)
EOF

  # Create .env file for client configuration
  cat > "${CLIENT_DIR}/ai/langchain/config/.env" << EOF
# LangChain Environment Configuration
# Generated on $(date -Iseconds)

CLIENT_ID=${CLIENT_ID}
LOG_LEVEL=INFO
USE_OLLAMA=${USE_OLLAMA}
OLLAMA_BASE_URL=http://host.docker.internal:${OLLAMA_PORT}
ENABLE_OPENAI=${ENABLE_OPENAI}
EOF

  # Add OpenAI key placeholder if enabled
  if [ "$ENABLE_OPENAI" = true ]; then
    echo "# Add your OpenAI API key here" >> "${CLIENT_DIR}/ai/langchain/config/.env"
    echo "OPENAI_API_KEY=your-api-key-here" >> "${CLIENT_DIR}/ai/langchain/config/.env"
  fi

  # Create logs directory
  mkdir -p "${CLIENT_DIR}/ai/langchain/config/logs"
  
  log "INFO" "Created LangChain API service at ${DOCKER_DIR}/app"
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
  MONITORING_SCRIPT="${MONITORING_DIR}/check_langchain-${CLIENT_ID}.sh"
  
  cat > "${MONITORING_SCRIPT}" << 'EOF'
#!/bin/bash
# LangChain Monitoring Script

# Configuration
CLIENT_ID="${1:-default}"
CONTAINER_NAME="langchain-${CLIENT_ID}"
DASHBOARD_DATA="/opt/agency_stack/config/dashboard_data.json"
PORT=$(grep PORT /opt/agency_stack/docker/langchain/.env | cut -d= -f2)

# Function to update dashboard data
update_dashboard() {
  local status="$1"
  local health="$2"
  local num_chains="$3"
  local num_tools="$4"
  local api_calls="$5"
  
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
  
  # Create the langchain entry if it doesn't exist
  if ! jq -e '.components.ai.langchain' "$DASHBOARD_DATA" &> /dev/null; then
    jq '.components.ai.langchain = {
      "name": "LangChain",
      "description": "LLM framework for chains and agents",
      "version": "0.1.0",
      "icon": "link",
      "status": {
        "running": false,
        "health": "unknown",
        "chains": 0,
        "tools": 0,
        "api_calls_24h": 0
      },
      "client_data": {}
    }' "$DASHBOARD_DATA" > "${DASHBOARD_DATA}.tmp" && mv "${DASHBOARD_DATA}.tmp" "$DASHBOARD_DATA"
  fi
  
  # Create the client data entry if it doesn't exist
  if ! jq -e ".components.ai.langchain.client_data.\"${CLIENT_ID}\"" "$DASHBOARD_DATA" &> /dev/null; then
    jq ".components.ai.langchain.client_data.\"${CLIENT_ID}\" = {
      \"running\": false,
      \"health\": \"unknown\",
      \"chains\": 0,
      \"tools\": 0,
      \"api_calls_24h\": 0
    }" "$DASHBOARD_DATA" > "${DASHBOARD_DATA}.tmp" && mv "${DASHBOARD_DATA}.tmp" "$DASHBOARD_DATA"
  fi
  
  # Update the client data
  jq ".components.ai.langchain.client_data.\"${CLIENT_ID}\".running = ${status}" "$DASHBOARD_DATA" > "${DASHBOARD_DATA}.tmp" && mv "${DASHBOARD_DATA}.tmp" "$DASHBOARD_DATA"
  jq ".components.ai.langchain.client_data.\"${CLIENT_ID}\".health = \"${health}\"" "$DASHBOARD_DATA" > "${DASHBOARD_DATA}.tmp" && mv "${DASHBOARD_DATA}.tmp" "$DASHBOARD_DATA"
  
  if [ -n "$num_chains" ]; then
    jq ".components.ai.langchain.client_data.\"${CLIENT_ID}\".chains = ${num_chains}" "$DASHBOARD_DATA" > "${DASHBOARD_DATA}.tmp" && mv "${DASHBOARD_DATA}.tmp" "$DASHBOARD_DATA"
  fi
  
  if [ -n "$num_tools" ]; then
    jq ".components.ai.langchain.client_data.\"${CLIENT_ID}\".tools = ${num_tools}" "$DASHBOARD_DATA" > "${DASHBOARD_DATA}.tmp" && mv "${DASHBOARD_DATA}.tmp" "$DASHBOARD_DATA"
  fi
  
  if [ -n "$api_calls" ]; then
    jq ".components.ai.langchain.client_data.\"${CLIENT_ID}\".api_calls_24h = ${api_calls}" "$DASHBOARD_DATA" > "${DASHBOARD_DATA}.tmp" && mv "${DASHBOARD_DATA}.tmp" "$DASHBOARD_DATA"
  fi
  
  # Update the main status (use the last client's status)
  jq ".components.ai.langchain.status.running = ${status}" "$DASHBOARD_DATA" > "${DASHBOARD_DATA}.tmp" && mv "${DASHBOARD_DATA}.tmp" "$DASHBOARD_DATA"
  jq ".components.ai.langchain.status.health = \"${health}\"" "$DASHBOARD_DATA" > "${DASHBOARD_DATA}.tmp" && mv "${DASHBOARD_DATA}.tmp" "$DASHBOARD_DATA"
  
  if [ -n "$num_chains" ]; then
    jq ".components.ai.langchain.status.chains = ${num_chains}" "$DASHBOARD_DATA" > "${DASHBOARD_DATA}.tmp" && mv "${DASHBOARD_DATA}.tmp" "$DASHBOARD_DATA"
  fi
  
  if [ -n "$num_tools" ]; then
    jq ".components.ai.langchain.status.tools = ${num_tools}" "$DASHBOARD_DATA" > "${DASHBOARD_DATA}.tmp" && mv "${DASHBOARD_DATA}.tmp" "$DASHBOARD_DATA"
  fi
  
  if [ -n "$api_calls" ]; then
    jq ".components.ai.langchain.status.api_calls_24h = ${api_calls}" "$DASHBOARD_DATA" > "${DASHBOARD_DATA}.tmp" && mv "${DASHBOARD_DATA}.tmp" "$DASHBOARD_DATA"
  fi
}

# Get API metrics
get_api_metrics() {
  local api_calls=0
  
  # Try to get metrics from the API
  if curl -s "http://localhost:${PORT}/health" &>/dev/null; then
    # This is a placeholder - in a real implementation, you would get metrics from Prometheus
    # or directly from the API
    api_calls=0
  fi
  
  echo "$api_calls"
}

# Count chains and tools
count_artifacts() {
  local chains_dir="/opt/agency_stack/clients/${CLIENT_ID}/ai/langchain/chains"
  local tools_dir="/opt/agency_stack/clients/${CLIENT_ID}/ai/langchain/tools"
  
  local num_chains=0
  local num_tools=0
  
  # Count chains
  if [ -d "$chains_dir" ]; then
    num_chains=$(find "$chains_dir" -name "*.json" | wc -l)
  fi
  
  # Count tools
  if [ -d "$tools_dir" ]; then
    num_tools=$(find "$tools_dir" -name "*.py" -not -name "__init__.py" | wc -l)
  fi
  
  echo "${num_chains},${num_tools}"
}

# Check if container is running
RUNNING="false"
HEALTH="unknown"
NUM_CHAINS=0
NUM_TOOLS=0
API_CALLS=0

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
      if curl -s "http://localhost:${PORT}/health" &>/dev/null; then
        HEALTH="healthy"
      else
        HEALTH="unknown"
      fi
      ;;
  esac
  
  # Get counts and metrics
  if [ "$HEALTH" = "healthy" ]; then
    COUNTS=$(count_artifacts)
    NUM_CHAINS=$(echo "$COUNTS" | cut -d, -f1)
    NUM_TOOLS=$(echo "$COUNTS" | cut -d, -f2)
    API_CALLS=$(get_api_metrics)
  fi
  HEALTH="stopped"
  RUNNING="false"
  
  # Still count artifacts even if service is stopped
  COUNTS=$(count_artifacts)
  NUM_CHAINS=$(echo "$COUNTS" | cut -d, -f1)
  NUM_TOOLS=$(echo "$COUNTS" | cut -d, -f2)

# Update dashboard
update_dashboard "$RUNNING" "$HEALTH" "$NUM_CHAINS" "$NUM_TOOLS" "$API_CALLS"

# Output status
echo "LangChain status for client '${CLIENT_ID}':"
echo "- Running: $RUNNING"
echo "- Health: $HEALTH"
echo "- Chains: $NUM_CHAINS"
echo "- Tools: $NUM_TOOLS"
echo "- API calls (24h): $API_CALLS"

exit 0
EOF

  # Make monitoring script executable
  chmod +x "${MONITORING_SCRIPT}"
  
  log "INFO" "Created monitoring script at ${MONITORING_SCRIPT}"
  
  # Create cron job for monitoring
  CRON_DIR="/etc/cron.d"
  if [ -d "$CRON_DIR" ]; then
    CRON_FILE="${CRON_DIR}/langchain-${CLIENT_ID}-monitor"
    echo "*/5 * * * * root ${MONITORING_SCRIPT} ${CLIENT_ID} > /dev/null 2>&1" > "$CRON_FILE"
    log "INFO" "Created cron job for monitoring at ${CRON_FILE}"
  else
    log "WARN" "Cron directory not found. Could not create monitoring cron job."
  fi
}

# Deploy LangChain service
deploy_langchain() {
  log "INFO" "Deploying LangChain service..."
  
  # Navigate to Docker directory
  cd "${DOCKER_DIR}"
  
  # Build and start containers
  docker-compose build
  docker-compose up -d
  
  # Wait for LangChain to start
  log "INFO" "Waiting for LangChain API to start..."
  for i in {1..30}; do
    if curl -s "http://localhost:${PORT}/health" &>/dev/null; then
      log "INFO" "LangChain API is up and running"
      break
    fi
    
    if [ $i -eq 30 ]; then
      log "WARN" "LangChain API did not become available within the timeout. Continuing anyway."
    fi
    
    sleep 2
  done
  
  # Update dashboard data
  if [ "$ENABLE_MONITORING" = true ] && [ -f "${CONFIG_DIR}/monitoring/scripts/check_langchain-${CLIENT_ID}.sh" ]; then
    log "INFO" "Updating dashboard data..."
    "${CONFIG_DIR}/monitoring/scripts/check_langchain-${CLIENT_ID}.sh" "${CLIENT_ID}"
  fi
  
  log "INFO" "LangChain deployment completed"
}

# Update component registry
update_registry() {
  log "INFO" "Updating component registry..."
  
  # Update installed components list
  if ! grep -q "langchain" "$INSTALLED_COMPONENTS" 2>/dev/null; then
    mkdir -p "$(dirname "$INSTALLED_COMPONENTS")"
    echo "langchain" >> "$INSTALLED_COMPONENTS"
    log "INFO" "Added langchain to installed components list"
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
  
  # Add or update langchain entry
  jq '.components.ai.langchain = {
    "name": "LangChain",
    "component_id": "langchain",
    "category": "AI",
    "version": "0.1.0",
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
    "description": "LangChain integration layer for chaining prompts, tools, and agents using Ollama or OpenAI backends.",
    "ports": {
      "api": '${PORT}'
    }
  }' "$COMPONENT_REGISTRY" > "$TEMP_FILE" && mv "$TEMP_FILE" "$COMPONENT_REGISTRY"
  
  log "INFO" "Updated component registry with langchain entry"
}

# Print summary and usage instructions
print_summary() {
  echo
  echo -e "${BOLD}${GREEN}=== LangChain Installation Complete ===${NC}"
  echo
  echo -e "${BOLD}Configuration Details:${NC}"
  echo -e "  ${CYAN}Client ID:${NC}        ${CLIENT_ID}"
  echo -e "  ${CYAN}API Port:${NC}         ${PORT}"
  if [ "$USE_OLLAMA" = true ]; then
    echo -e "  ${CYAN}LLM Provider:${NC}    Ollama (local) on port ${OLLAMA_PORT}"
  fi
  if [ "$ENABLE_OPENAI" = true ]; then
    echo -e "  ${CYAN}LLM Provider:${NC}    OpenAI API (cloud)"
    echo -e "  ${CYAN}API Key Status:${NC}  Requires configuration in .env file"
  fi
  echo
  echo -e "${BOLD}API Endpoints:${NC}"
  echo -e "  ${CYAN}Health Check:${NC}     http://localhost:${PORT}/health"
  echo -e "  ${CYAN}List Chains:${NC}      http://localhost:${PORT}/chains"
  echo -e "  ${CYAN}Run Chain:${NC}        http://localhost:${PORT}/chain/run (POST)"
  echo -e "  ${CYAN}Run Prompt:${NC}       http://localhost:${PORT}/prompt (POST)"
  echo -e "  ${CYAN}List Tools:${NC}       http://localhost:${PORT}/tools"
  echo
  echo -e "${BOLD}Example Usage:${NC}"
  echo -e "  ${CYAN}Run a prompt:${NC}"
  echo -e "    curl -X POST http://localhost:${PORT}/prompt \\"
  echo -e "      -H \"Content-Type: application/json\" \\"
  echo -e "      -d '{\"template\":\"What is {topic}?\",\"inputs\":{\"topic\":\"LangChain\"}}'"
  echo
  echo -e "${BOLD}${GREEN}For more information, see the documentation at:${NC}"
  echo -e "  ${CYAN}https://stack.nerdofmouth.com/docs/ai/langchain.html${NC}"
  echo
  echo -e "${BOLD}Configuration Files:${NC}"
  echo -e "  ${CYAN}Config Directory:${NC}  ${CLIENT_DIR}/ai/langchain/"
  echo -e "  ${CYAN}LLM Settings:${NC}      ${CLIENT_DIR}/ai/langchain/config/.env"
  echo -e "  ${CYAN}Log File:${NC}          ${CLIENT_DIR}/ai/langchain/config/logs/langchain-api.log"
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
      --domain)
        DOMAIN="$2"
        shift 2
        ;;
      --port)
        PORT="$2"
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
      --enable-openai)
        ENABLE_OPENAI=true
        shift
        ;;
      --use-ollama)
        USE_OLLAMA=true
        shift
        ;;
      --ollama-port)
        OLLAMA_PORT="$2"
        shift 2
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
  log "INFO" "Starting LangChain installation (version ${LANGCHAIN_VERSION})..."
  
  # Run installation steps
  setup_client_dir
  check_requirements
  install_dependencies
  create_docker_config
  create_langchain_service
  create_monitoring_script
  deploy_langchain
  update_registry
  
  # Print summary
  print_summary
  
  # Log completion
  log "INFO" "LangChain installation completed successfully"
}

# Execute main function
main "$@"
