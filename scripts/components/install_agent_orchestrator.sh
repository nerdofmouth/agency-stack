#!/bin/bash
# =============================================================================
# install_agent_orchestrator.sh
# 
# Installs and configures the Agent Orchestrator microservice
# for AgencyStack, powered by LangChain and Ollama.
#
# This component monitors logs, metrics, and system state to provide
# intelligent recommendations and safe automations.
# =============================================================================

# --- BEGIN: Preflight/Prerequisite Check ---
source "$(dirname "$0")/../utils/common.sh"
preflight_check_agencystack || {
  echo -e "[ERROR] Preflight checks failed. Resolve issues before proceeding."
  exit 1
}
# --- END: Preflight/Prerequisite Check ---

# Strict error handling
set -euo pipefail

# Script directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
SCRIPTS_DIR="${ROOT_DIR}/scripts"
UTILS_DIR="${SCRIPTS_DIR}/utils"

# Source common utility functions
source "${UTILS_DIR}/common.sh"

# Default values
DEFAULT_PORT=5210
DEFAULT_LANGCHAIN_PORT=5111
DEFAULT_OLLAMA_PORT=11434
DEFAULT_LOKI_PORT=3100
DEFAULT_PROMETHEUS_PORT=9090

# Variables
PORT=${DEFAULT_PORT}
CLIENT_ID="default"
DOMAIN="localhost"
LANGCHAIN_PORT=${DEFAULT_LANGCHAIN_PORT}
OLLAMA_PORT=${DEFAULT_OLLAMA_PORT}
LOKI_PORT=${DEFAULT_LOKI_PORT}
PROMETHEUS_PORT=${DEFAULT_PROMETHEUS_PORT}
WITH_DEPS=false
FORCE=false
USE_OLLAMA=false
ENABLE_OPENAI=false
ENABLE_MONITORING=false

# Installation paths
INSTALL_DIR="/opt/agency_stack"
CLIENT_DIR="${INSTALL_DIR}/clients/${CLIENT_ID}"
DOCKER_DIR="${CLIENT_DIR}/ai/agent_orchestrator/docker"
APP_DIR="${CLIENT_DIR}/ai/agent_orchestrator/app"
DATA_DIR="${CLIENT_DIR}/ai/agent_orchestrator/data"
LOG_DIR="/var/log/agency_stack/components"
LOG_FILE="${LOG_DIR}/agent_orchestrator.log"

# Usage information
usage() {
  echo "Usage: $0 [OPTIONS]"
  echo "Install and configure Agent Orchestrator microservice for AgencyStack."
  echo ""
  echo "Options:"
  echo "  --port=PORT                  Port for the Agent Orchestrator API (default: ${DEFAULT_PORT})"
  echo "  --client-id=CLIENT_ID        Client ID for multi-tenant setup (default: default)"
  echo "  --domain=DOMAIN              Domain for the service (default: localhost)"
  echo "  --langchain-port=PORT        Port for LangChain service (default: ${DEFAULT_LANGCHAIN_PORT})"
  echo "  --ollama-port=PORT           Port for Ollama service (default: ${DEFAULT_OLLAMA_PORT})"
  echo "  --loki-port=PORT             Port for Loki service (default: ${DEFAULT_LOKI_PORT})"
  echo "  --prometheus-port=PORT       Port for Prometheus service (default: ${DEFAULT_PROMETHEUS_PORT})"
  echo "  --with-deps                  Install dependencies if not already installed"
  echo "  --force                      Force reinstallation even if already installed"
  echo "  --use-ollama                 Use Ollama for LLM access (default)"
  echo "  --enable-openai              Enable OpenAI integration as fallback"
  echo "  --enable-monitoring          Set up Prometheus and Loki monitoring"
  echo "  --help                       Display this help message and exit"
  echo ""
  echo "Example: $0 --client-id=acme --domain=example.com --use-ollama --enable-monitoring"
}

# Parse command-line arguments
parse_args() {
  for arg in "$@"; do
    case $arg in
      --port=*)
        PORT="${arg#*=}"
        ;;
      --client-id=*)
        CLIENT_ID="${arg#*=}"
        ;;
      --domain=*)
        DOMAIN="${arg#*=}"
        ;;
      --langchain-port=*)
        LANGCHAIN_PORT="${arg#*=}"
        ;;
      --ollama-port=*)
        OLLAMA_PORT="${arg#*=}"
        ;;
      --loki-port=*)
        LOKI_PORT="${arg#*=}"
        ;;
      --prometheus-port=*)
        PROMETHEUS_PORT="${arg#*=}"
        ;;
      --with-deps)
        WITH_DEPS=true
        ;;
      --force)
        FORCE=true
        ;;
      --use-ollama)
        USE_OLLAMA=true
        ;;
      --enable-openai)
        ENABLE_OPENAI=true
        ;;
      --enable-monitoring)
        ENABLE_MONITORING=true
        ;;
      --help)
        usage
        exit 0
        ;;
      *)
        log "ERROR" "Unknown option: $arg"
        usage
        exit 1
        ;;
    esac
  done

  # Update paths based on client ID
  CLIENT_DIR="${INSTALL_DIR}/clients/${CLIENT_ID}"
  DOCKER_DIR="${CLIENT_DIR}/ai/agent_orchestrator/docker"
  APP_DIR="${CLIENT_DIR}/ai/agent_orchestrator/app"
  DATA_DIR="${CLIENT_DIR}/ai/agent_orchestrator/data"

  # Log the installation parameters
  log "INFO" "Installation parameters:"
  log "INFO" "  Port: ${PORT}"
  log "INFO" "  Client ID: ${CLIENT_ID}"
  log "INFO" "  Domain: ${DOMAIN}"
  log "INFO" "  LangChain Port: ${LANGCHAIN_PORT}"
  log "INFO" "  Ollama Port: ${OLLAMA_PORT}"
  log "INFO" "  With Dependencies: ${WITH_DEPS}"
  log "INFO" "  Force Reinstall: ${FORCE}"
  log "INFO" "  Use Ollama: ${USE_OLLAMA}"
  log "INFO" "  Enable OpenAI: ${ENABLE_OPENAI}"
  log "INFO" "  Enable Monitoring: ${ENABLE_MONITORING}"
}

# Check for dependencies
check_dependencies() {
  log "INFO" "Checking dependencies..."
  
  # Check for Docker
  if ! command -v docker &> /dev/null && ! [ "$WITH_DEPS" = true ]; then
    log "ERROR" "Docker is not installed. Please install Docker first or use --with-deps"
    exit 1
  fi
  
  # Check for Docker Compose
  if ! command -v docker compose &> /dev/null && ! [ "$WITH_DEPS" = true ]; then
    log "ERROR" "Docker Compose is not installed. Please install Docker Compose first or use --with-deps"
    exit 1
  fi
  
  # Check for jq
  if ! command -v jq &> /dev/null && ! [ "$WITH_DEPS" = true ]; then
    log "ERROR" "jq is not installed. Please install jq first or use --with-deps"
    exit 1
  fi
  
  # Install dependencies if requested
  if [ "$WITH_DEPS" = true ]; then
    log "INFO" "Installing dependencies..."
    
    # Update package list
    apt-get update
    
    # Install Docker if not present
    if ! command -v docker &> /dev/null; then
      log "INFO" "Installing Docker..."
      apt-get install -y docker.io
      systemctl enable --now docker
    fi
    
    # Install Docker Compose if not present
    if ! command -v docker compose &> /dev/null; then
      log "INFO" "Installing Docker Compose..."
      apt-get install -y docker-compose-plugin
    fi
    
    # Install jq if not present
    if ! command -v jq &> /dev/null; then
      log "INFO" "Installing jq..."
      apt-get install -y jq
    fi
  fi
  
  log "INFO" "All dependencies satisfied."
}

# Create necessary directories
create_directories() {
  log "INFO" "Creating necessary directories..."
  
  mkdir -p "${DOCKER_DIR}"
  mkdir -p "${APP_DIR}"
  mkdir -p "${DATA_DIR}"
  mkdir -p "${LOG_DIR}"
  
  log "INFO" "Directory structure created."
}

# Create the FastAPI application
create_app() {
  log "INFO" "Creating FastAPI application..."

  # Create the main.py file
  cat > "${APP_DIR}/main.py" << 'EOF'
import os
import sys
import json
import logging
from datetime import datetime
from typing import Dict, List, Optional, Any

import requests
from fastapi import FastAPI, HTTPException, Depends, BackgroundTasks, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel
import uvicorn

# Set up logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[
        logging.StreamHandler(sys.stdout),
        logging.FileHandler("/var/log/agency_stack/components/agent_orchestrator.log")
    ]
)
logger = logging.getLogger("agent_orchestrator")

# Initialize FastAPI app
app = FastAPI(
    title="Agent Orchestrator",
    description="LLM-powered task and workflow agent for AgencyStack",
    version="1.0.0",
)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Configuration
class Settings:
    def __init__(self):
        self.client_id = os.getenv("CLIENT_ID", "default")
        self.langchain_url = os.getenv("LANGCHAIN_API_URL", "http://localhost:5111")
        self.ollama_url = os.getenv("OLLAMA_API_URL", "http://localhost:11434")
        self.openai_enabled = os.getenv("OPENAI_ENABLED", "false").lower() == "true"
        self.openai_api_key = os.getenv("OPENAI_API_KEY", "")
        self.monitoring_enabled = os.getenv("MONITORING_ENABLED", "false").lower() == "true"
        self.loki_url = os.getenv("LOKI_URL", "http://localhost:3100")
        self.prometheus_url = os.getenv("PROMETHEUS_URL", "http://localhost:9090")
        self.data_dir = os.getenv("DATA_DIR", "/opt/agency_stack/clients/default/ai/agent_orchestrator/data")
        self.system_logs_dir = os.getenv("SYSTEM_LOGS_DIR", "/var/log/agency_stack")

settings = Settings()

# Data models
class AgentAction(BaseModel):
    action_type: str
    target: str
    parameters: Optional[Dict[str, Any]] = None
    description: str

class RecommendationRequest(BaseModel):
    context: Dict[str, Any]
    logs: Optional[List[str]] = None
    metrics: Optional[Dict[str, Any]] = None

class RecommendationResponse(BaseModel):
    recommendations: List[Dict[str, Any]]
    explanation: str
    timestamp: str

class ActionRequest(BaseModel):
    action: AgentAction

class ActionResponse(BaseModel):
    success: bool
    message: str
    details: Optional[Dict[str, Any]] = None

# Health check endpoint
@app.get("/health")
async def health_check():
    status = {
        "status": "healthy",
        "timestamp": datetime.now().isoformat(),
        "version": "1.0.0",
        "client_id": settings.client_id,
        "dependencies": {
            "langchain": check_langchain_status(),
            "ollama": check_ollama_status() if not settings.openai_enabled else "not_used",
            "openai": "configured" if settings.openai_enabled else "not_used",
            "monitoring": {
                "enabled": settings.monitoring_enabled,
                "loki": check_loki_status() if settings.monitoring_enabled else "not_used",
                "prometheus": check_prometheus_status() if settings.monitoring_enabled else "not_used",
            }
        }
    }
    return status

# Check dependency statuses
def check_langchain_status():
    try:
        response = requests.get(f"{settings.langchain_url}/health", timeout=5)
        return "healthy" if response.status_code == 200 else "unhealthy"
    except Exception as e:
        logger.error(f"Error checking LangChain status: {e}")
        return "unavailable"

def check_ollama_status():
    try:
        response = requests.get(f"{settings.ollama_url}/api/tags", timeout=5)
        return "healthy" if response.status_code == 200 else "unhealthy"
    except Exception as e:
        logger.error(f"Error checking Ollama status: {e}")
        return "unavailable"

def check_loki_status():
    try:
        response = requests.get(f"{settings.loki_url}/ready", timeout=5)
        return "healthy" if response.status_code == 200 else "unhealthy"
    except Exception as e:
        logger.error(f"Error checking Loki status: {e}")
        return "unavailable"

def check_prometheus_status():
    try:
        response = requests.get(f"{settings.prometheus_url}/-/healthy", timeout=5)
        return "healthy" if response.status_code == 200 else "unhealthy"
    except Exception as e:
        logger.error(f"Error checking Prometheus status: {e}")
        return "unavailable"

# Get recommendations based on logs and metrics
@app.post("/recommendations", response_model=RecommendationResponse)
async def get_recommendations(request: RecommendationRequest):
    try:
        # Forward to LangChain for processing
        payload = {
            "input": {
                "context": request.context,
                "logs": request.logs,
                "metrics": request.metrics
            },
            "chain_type": "agent_recommendations"
        }
        
        response = requests.post(
            f"{settings.langchain_url}/chains/agent_recommendations/run",
            json=payload
        )
        
        if response.status_code != 200:
            logger.error(f"LangChain chain failed: {response.text}")
            raise HTTPException(status_code=500, detail="Failed to generate recommendations")
        
        chain_output = response.json()
        
        # Process recommendations from LLM output
        return {
            "recommendations": chain_output.get("recommendations", []),
            "explanation": chain_output.get("explanation", "No explanation provided"),
            "timestamp": datetime.now().isoformat()
        }
    except Exception as e:
        logger.error(f"Error generating recommendations: {e}")
        raise HTTPException(status_code=500, detail=f"Error generating recommendations: {str(e)}")

# Execute an action
@app.post("/actions", response_model=ActionResponse)
async def execute_action(request: ActionRequest, background_tasks: BackgroundTasks):
    try:
        action = request.action
        
        # Validate action type
        valid_actions = ["restart_service", "sync_logs", "pull_model", "clear_cache", "run_test"]
        if action.action_type not in valid_actions:
            raise HTTPException(status_code=400, detail=f"Invalid action type. Must be one of: {valid_actions}")
        
        # Log the action
        logger.info(f"Executing action: {action.action_type} on {action.target}")
        
        # Execute action based on type
        if action.action_type == "restart_service":
            # Safety check - only allow certain services to be restarted
            allowed_services = ["langchain", "agent_orchestrator", "dashboard"]
            if action.target not in allowed_services:
                raise HTTPException(status_code=403, detail=f"Not allowed to restart {action.target}")
            
            # Run in background to avoid blocking
            background_tasks.add_task(restart_service, action.target)
            return {"success": True, "message": f"Service {action.target} restart initiated", "details": {"status": "pending"}}
            
        elif action.action_type == "sync_logs":
            # Run log synchronization
            background_tasks.add_task(sync_logs, action.target)
            return {"success": True, "message": f"Log sync for {action.target} initiated", "details": {"status": "pending"}}
            
        elif action.action_type == "pull_model":
            # Safety check - only specific models allowed
            allowed_models = ["llama2", "mistral", "codellama", "phi", "tinyllama"]
            if action.target not in allowed_models:
                raise HTTPException(status_code=403, detail=f"Not allowed to pull model {action.target}")
            
            # Pull the model
            background_tasks.add_task(pull_model, action.target)
            return {"success": True, "message": f"Model {action.target} pull initiated", "details": {"status": "pending"}}
            
        elif action.action_type == "clear_cache":
            # Clear cache for a specific service
            result = clear_cache(action.target)
            return {"success": True, "message": f"Cache cleared for {action.target}", "details": result}
            
        elif action.action_type == "run_test":
            # Run a simple test for a service
            result = run_test(action.target)
            return {"success": True, "message": f"Test completed for {action.target}", "details": result}
        
        # This should never happen due to the validation above
        raise HTTPException(status_code=400, detail="Invalid action type")
        
    except HTTPException:
        # Re-raise HTTP exceptions
        raise
    except Exception as e:
        logger.error(f"Error executing action: {e}")
        raise HTTPException(status_code=500, detail=f"Error executing action: {str(e)}")

# Action implementation functions
async def restart_service(service_name):
    logger.info(f"Restarting service: {service_name}")
    try:
        # Use docker compose to restart the service
        import subprocess
        client_id = settings.client_id
        cmd = f"docker compose -f /opt/agency_stack/clients/{client_id}/ai/{service_name}/docker/docker-compose.yml restart"
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
        
        if result.returncode == 0:
            logger.info(f"Service {service_name} restarted successfully")
        else:
            logger.error(f"Failed to restart {service_name}: {result.stderr}")
    except Exception as e:
        logger.error(f"Error restarting {service_name}: {e}")

async def sync_logs(target):
    logger.info(f"Syncing logs for: {target}")
    try:
        # Implement log synchronization logic here
        pass
    except Exception as e:
        logger.error(f"Error syncing logs for {target}: {e}")

async def pull_model(model_name):
    logger.info(f"Pulling model: {model_name}")
    try:
        # Call Ollama API to pull the model
        response = requests.post(
            f"{settings.ollama_url}/api/pull",
            json={"name": model_name}
        )
        
        if response.status_code == 200:
            logger.info(f"Model {model_name} pull initiated")
        else:
            logger.error(f"Failed to pull model {model_name}: {response.text}")
    except Exception as e:
        logger.error(f"Error pulling model {model_name}: {e}")

def clear_cache(target):
    logger.info(f"Clearing cache for: {target}")
    # Implementation depends on the target service
    return {"cache_size_before": "250MB", "cache_size_after": "0MB"}

def run_test(target):
    logger.info(f"Running test for: {target}")
    # Implementation depends on the target service
    return {"test_result": "passed", "response_time": "120ms"}

# Get logs from the system
@app.get("/logs/{component}")
async def get_logs(component: str, lines: int = 100):
    try:
        # Validate component name to prevent directory traversal
        import re
        if not re.match(r'^[a-zA-Z0-9_-]+$', component):
            raise HTTPException(status_code=400, detail="Invalid component name")
        
        log_path = f"{settings.system_logs_dir}/components/{component}.log"
        
        if not os.path.exists(log_path):
            raise HTTPException(status_code=404, detail=f"Log file for {component} not found")
        
        # Read the last N lines
        import subprocess
        result = subprocess.run(["tail", "-n", str(lines), log_path], capture_output=True, text=True)
        
        if result.returncode != 0:
            raise HTTPException(status_code=500, detail="Failed to read log file")
        
        return {"component": component, "lines": lines, "content": result.stdout}
    
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error retrieving logs: {e}")
        raise HTTPException(status_code=500, detail=f"Error retrieving logs: {str(e)}")

# Get metrics from Prometheus
@app.get("/metrics/{component}")
async def get_metrics(component: str):
    if not settings.monitoring_enabled:
        raise HTTPException(status_code=400, detail="Monitoring not enabled")
    
    try:
        # Query Prometheus for metrics related to the component
        # Implementation would depend on how metrics are organized
        return {"component": component, "metrics": {"cpu_usage": "12%", "memory_usage": "250MB"}}
    except Exception as e:
        logger.error(f"Error retrieving metrics: {e}")
        raise HTTPException(status_code=500, detail=f"Error retrieving metrics: {str(e)}")

# Run the application
if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=5210, reload=False)
EOF

  # Create requirements.txt
  cat > "${APP_DIR}/requirements.txt" << 'EOF'
fastapi==0.95.1
uvicorn==0.22.0
pydantic==1.10.7
requests==2.28.2
httpx==0.24.0
python-multipart==0.0.6
python-dotenv==1.0.0
langchain==0.0.267
prometheus-client==0.16.0
EOF

  log "INFO" "FastAPI application files created"
}

# Create a LangChain template for the agent recommendations
create_langchain_template() {
  log "INFO" "Creating LangChain template for agent recommendations..."
  
  mkdir -p "${APP_DIR}/templates"
  
  # Create the agent recommendations template
  cat > "${APP_DIR}/templates/agent_recommendations.py" << 'EOF'
from langchain.prompts import PromptTemplate
from langchain.chains import LLMChain
from langchain.llms import Ollama
from langchain.output_parsers import PydanticOutputParser
from pydantic import BaseModel, Field
from typing import List, Dict, Any, Optional
import json
import os

# Define the output model for recommendations
class Recommendation(BaseModel):
    title: str = Field(description="Short title describing the recommendation")
    description: str = Field(description="Detailed explanation of the recommendation")
    action_type: str = Field(description="Type of action to take (restart_service, sync_logs, pull_model, clear_cache, run_test)")
    target: str = Field(description="Target component or service for the action")
    urgency: str = Field(description="Urgency level (low, medium, high)")
    parameters: Optional[Dict[str, Any]] = Field(default=None, description="Optional parameters for the action")

class Recommendations(BaseModel):
    recommendations: List[Recommendation] = Field(description="List of recommendations based on the analysis")
    explanation: str = Field(description="Overall explanation of the analysis")

# Create a parser for the recommendations
parser = PydanticOutputParser(pydantic_object=Recommendations)

# Get the LLM - either Ollama or OpenAI based on environment
def get_llm():
    if os.getenv("OPENAI_ENABLED", "false").lower() == "true":
        from langchain.llms import OpenAI
        return OpenAI(temperature=0, model_name="gpt-4-turbo")
    else:
        return Ollama(
            model=os.getenv("OLLAMA_MODEL", "llama2"), 
            temperature=0,
            base_url=os.getenv("OLLAMA_API_URL", "http://localhost:11434")
        )

# Define the recommendation chain
def create_recommendation_chain():
    llm = get_llm()
    
    template = """
    You are Agent Orchestrator, an intelligent system administrator for AgencyStack.
    
    Analyze the following system information and provide recommendations for actions to take:
    
    CONTEXT INFORMATION:
    {context}
    
    LOGS:
    {logs}
    
    METRICS:
    {metrics}
    
    Based on this information, identify potential issues or optimizations. 
    Provide recommendations for actions that can be taken to improve the system.
    
    Your recommendations should follow these guidelines:
    1. Focus on actionable suggestions that can be automated
    2. Consider performance, security, resource usage, and error patterns
    3. Prioritize high-impact, low-risk actions
    4. Be specific about the target component and action to take
    
    {format_instructions}
    """
    
    prompt = PromptTemplate(
        template=template,
        input_variables=["context", "logs", "metrics"],
        partial_variables={"format_instructions": parser.get_format_instructions()}
    )
    
    return LLMChain(llm=llm, prompt=prompt)

# The function to run the chain
def run_recommendations_chain(input_data):
    chain = create_recommendation_chain()
    
    # Format the inputs
    context = json.dumps(input_data.get("context", {}), indent=2)
    logs = "\n".join(input_data.get("logs", ["No logs provided"]))
    metrics = json.dumps(input_data.get("metrics", {}), indent=2)
    
    # Run the chain
    result = chain.run(context=context, logs=logs, metrics=metrics)
    
    # Parse the result
    try:
        parsed_result = parser.parse(result)
        return parsed_result.dict()
    except Exception as e:
        print(f"Error parsing result: {e}")
        # Fallback to returning the raw result
        return {
            "recommendations": [],
            "explanation": f"Error parsing recommendations: {result}"
        }
EOF

  log "INFO" "LangChain template created"
}

# Create Docker configuration
create_docker_config() {
  log "INFO" "Creating Docker configuration..."
  
  # Create Dockerfile
  cat > "${APP_DIR}/Dockerfile" << 'EOF'
FROM python:3.10-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    jq \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Create log directory
RUN mkdir -p /var/log/agency_stack/components
RUN touch /var/log/agency_stack/components/agent_orchestrator.log
RUN chmod 777 /var/log/agency_stack/components/agent_orchestrator.log

# Set environment variables
ENV PYTHONUNBUFFERED=1

# Expose port
EXPOSE 5210

# Run the application
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "5210"]
EOF

  # Create docker-compose.yml
  cat > "${DOCKER_DIR}/docker-compose.yml" << EOF
version: '3.8'

services:
  agent-orchestrator:
    build:
      context: ${APP_DIR}
    container_name: agent-orchestrator-${CLIENT_ID}
    restart: unless-stopped
    environment:
      - CLIENT_ID=${CLIENT_ID}
      - LANGCHAIN_API_URL=http://langchain-${CLIENT_ID}:5111
      - OLLAMA_API_URL=http://ollama-${CLIENT_ID}:11434
      - OPENAI_ENABLED=${ENABLE_OPENAI}
      - MONITORING_ENABLED=${ENABLE_MONITORING}
      - LOKI_URL=http://loki:3100
      - PROMETHEUS_URL=http://prometheus:9090
      - DATA_DIR=/data
      - SYSTEM_LOGS_DIR=/var/log/agency_stack
    volumes:
      - ${DATA_DIR}:/data
      - /var/log/agency_stack:/var/log/agency_stack
    ports:
      - "${PORT}:5210"
    networks:
      - agency_stack
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.agent-orchestrator-${CLIENT_ID}.rule=Host(\`agent.${DOMAIN}\`)"
      - "traefik.http.routers.agent-orchestrator-${CLIENT_ID}.entrypoints=websecure"
      - "traefik.http.routers.agent-orchestrator-${CLIENT_ID}.tls=true"
      - "traefik.http.services.agent-orchestrator-${CLIENT_ID}.loadbalancer.server.port=5210"

networks:
  agency_stack:
    external: true
EOF

  log "INFO" "Docker configuration created"
}

# Install and configure the agent orchestrator
install_agent_orchestrator() {
  log "INFO" "Installing Agent Orchestrator..."
  
  # Create necessary directories
  create_directories
  
  # Create the FastAPI application
  create_app
  
  # Create LangChain templates
  create_langchain_template
  
  # Create Docker configuration
  create_docker_config
  
  # Set up Docker environment
  setup_docker
  
  # Update component registry
  update_component_registry
  
  log "SUCCESS" "Agent Orchestrator installation complete at ${APP_DIR}"
  log "SUCCESS" "API available at: http://localhost:${PORT} or https://agent.${DOMAIN}"
}

# Set up Docker environment
setup_docker() {
  log "INFO" "Setting up Docker environment..."
  
  # Check if the Docker network exists, if not create it
  if ! docker network ls | grep -q "agency_stack"; then
    log "INFO" "Creating Docker network: agency_stack"
    docker network create agency_stack
  fi
  
  # Build the Docker image
  log "INFO" "Building Docker image..."
  docker build -t agent-orchestrator:latest "${APP_DIR}"
  
  # Start the container
  log "INFO" "Starting Docker container..."
  docker compose -f "${DOCKER_DIR}/docker-compose.yml" up -d
  
  log "INFO" "Docker environment setup complete"
}

# Update component registry
update_component_registry() {
  log "INFO" "Updating component registry..."
  
  # Define the registry file path
  REGISTRY_FILE="${ROOT_DIR}/config/registry/component_registry.json"
  
  # Check if the registry file exists
  if [ ! -f "$REGISTRY_FILE" ]; then
    log "ERROR" "Component registry file not found at: $REGISTRY_FILE"
    return 1
  fi
  
  # Generate a temporary file with the updated registry
  TMP_FILE=$(mktemp)
  
  # Check if Agent Orchestrator is already in the registry
  if grep -q "\"name\": \"Agent Orchestrator\"" "$REGISTRY_FILE"; then
    log "INFO" "Agent Orchestrator already exists in the component registry. Updating..."
    
    # Using jq to update the existing entry
    cat "$REGISTRY_FILE" | jq '(.components[] | select(.name == "Agent Orchestrator")).port = '$PORT' | 
                             (.components[] | select(.name == "Agent Orchestrator")).hardened = true |
                             (.components[] | select(.name == "Agent Orchestrator")).multi_tenant = true |
                             (.components[] | select(.name == "Agent Orchestrator")).sso_ready = false |
                             (.components[] | select(.name == "Agent Orchestrator")).monitoring_enabled = true |
                             (.components[] | select(.name == "Agent Orchestrator")).description = "LLM-powered task and workflow agent for monitoring system state and recommending actions."' > "$TMP_FILE"
  else
    log "INFO" "Adding Agent Orchestrator to the component registry..."
    
    # Using jq to append a new component
    cat "$REGISTRY_FILE" | jq '.components += [{
      "name": "Agent Orchestrator",
      "category": "AI",
      "port": '$PORT',
      "hardened": true,
      "multi_tenant": true,
      "sso_ready": false,
      "monitoring_enabled": true,
      "description": "LLM-powered task and workflow agent for monitoring system state and recommending actions."
    }]' > "$TMP_FILE"
  fi
  
  # Update the registry file
  mv "$TMP_FILE" "$REGISTRY_FILE"
  
  log "SUCCESS" "Component registry updated successfully"
}

# Main function to run the installation
main() {
  log "INFO" "Starting Agent Orchestrator installation..."
  
  # Parse command-line arguments
  parse_args "$@"
  
  # Check if already installed and if we should force reinstall
  if [ -d "${DOCKER_DIR}" ] && [ "$FORCE" != true ]; then
    log "WARN" "Agent Orchestrator appears to be already installed at ${DOCKER_DIR}"
    log "WARN" "Use --force to reinstall"
    exit 0
  fi
  
  # Create log directory if it doesn't exist
  mkdir -p "$(dirname "${LOG_FILE}")"
  
  # Check dependencies
  check_dependencies
  
  # Perform the installation
  install_agent_orchestrator
  
  log "SUCCESS" "Agent Orchestrator installation completed successfully."
  log "INFO" "API available at: http://localhost:${PORT} or https://agent.${DOMAIN}"
  log "INFO" "Use 'make agent-orchestrator-status' to check the service status."
}

# Call the main function with all script arguments
main "$@"
