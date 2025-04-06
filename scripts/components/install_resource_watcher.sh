#!/bin/bash
# =============================================================================
# install_resource_watcher.sh
# 
# Installs and configures the Resource Watcher microservice
# for AgencyStack, providing metrics collection and analysis
# with optional LLM-enhanced insights.
# =============================================================================

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
DEFAULT_PORT=5211
DEFAULT_LANGCHAIN_PORT=5111
DEFAULT_OLLAMA_PORT=11434
DEFAULT_PROMETHEUS_PORT=9090

# Variables
PORT=${DEFAULT_PORT}
CLIENT_ID="default"
DOMAIN="localhost"
LANGCHAIN_PORT=${DEFAULT_LANGCHAIN_PORT}
OLLAMA_PORT=${DEFAULT_OLLAMA_PORT}
PROMETHEUS_PORT=${DEFAULT_PROMETHEUS_PORT}
WITH_DEPS=false
FORCE=false
USE_OLLAMA=false
ENABLE_LLM=false
ENABLE_PROMETHEUS=false

# Installation paths
INSTALL_DIR="/opt/agency_stack"
CLIENT_DIR="${INSTALL_DIR}/clients/${CLIENT_ID}"
DOCKER_DIR="${CLIENT_DIR}/monitoring/resource_watcher/docker"
APP_DIR="${CLIENT_DIR}/monitoring/resource_watcher/app"
DATA_DIR="${CLIENT_DIR}/monitoring/resource_watcher/data"
LOG_DIR="/var/log/agency_stack/components"
LOG_FILE="${LOG_DIR}/resource_watcher.log"
CONFIG_DIR="${CLIENT_DIR}/monitoring/resource_watcher/config"

# Usage information
usage() {
  echo "Usage: $0 [OPTIONS]"
  echo "Install and configure Resource Watcher microservice for AgencyStack."
  echo ""
  echo "Options:"
  echo "  --port=PORT                  Port for the Resource Watcher API (default: ${DEFAULT_PORT})"
  echo "  --client-id=CLIENT_ID        Client ID for multi-tenant setup (default: default)"
  echo "  --domain=DOMAIN              Domain for the service (default: localhost)"
  echo "  --langchain-port=PORT        Port for LangChain service (default: ${DEFAULT_LANGCHAIN_PORT})"
  echo "  --ollama-port=PORT           Port for Ollama service (default: ${DEFAULT_OLLAMA_PORT})"
  echo "  --prometheus-port=PORT       Port for Prometheus service (default: ${DEFAULT_PROMETHEUS_PORT})"
  echo "  --with-deps                  Install dependencies if not already installed"
  echo "  --force                      Force reinstallation even if already installed"
  echo "  --use-ollama                 Use Ollama for LLM analysis"
  echo "  --enable-llm                 Enable LLM-enhanced analysis"
  echo "  --enable-prometheus          Enable Prometheus integration"
  echo "  --help                       Display this help message and exit"
  echo ""
  echo "Example: $0 --client-id=acme --domain=example.com --enable-llm --enable-prometheus"
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
      --enable-llm)
        ENABLE_LLM=true
        ;;
      --enable-prometheus)
        ENABLE_PROMETHEUS=true
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
  DOCKER_DIR="${CLIENT_DIR}/monitoring/resource_watcher/docker"
  APP_DIR="${CLIENT_DIR}/monitoring/resource_watcher/app"
  DATA_DIR="${CLIENT_DIR}/monitoring/resource_watcher/data"
  CONFIG_DIR="${CLIENT_DIR}/monitoring/resource_watcher/config"

  # Log the installation parameters
  log "INFO" "Installation parameters:"
  log "INFO" "  Port: ${PORT}"
  log "INFO" "  Client ID: ${CLIENT_ID}"
  log "INFO" "  Domain: ${DOMAIN}"
  log "INFO" "  LangChain Port: ${LANGCHAIN_PORT}"
  log "INFO" "  Ollama Port: ${OLLAMA_PORT}"
  log "INFO" "  Prometheus Port: ${PROMETHEUS_PORT}"
  log "INFO" "  With Dependencies: ${WITH_DEPS}"
  log "INFO" "  Force Reinstall: ${FORCE}"
  log "INFO" "  Use Ollama: ${USE_OLLAMA}"
  log "INFO" "  Enable LLM: ${ENABLE_LLM}"
  log "INFO" "  Enable Prometheus: ${ENABLE_PROMETHEUS}"
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
  mkdir -p "${CONFIG_DIR}"
  
  log "INFO" "Directory structure created."
}

# Create the FastAPI application
create_app() {
  log "INFO" "Creating FastAPI application..."
  
  # Create main.py with FastAPI application
  cat > "${APP_DIR}/main.py" << 'EOF'
#!/usr/bin/env python3
# Resource Watcher - FastAPI Application
# Part of AgencyStack

import os
import json
import time
import psutil
import asyncio
import logging
import platform
import requests
from typing import List, Dict, Optional
from datetime import datetime, timedelta
from pydantic import BaseModel, Field

# Import FastAPI
from fastapi import FastAPI, HTTPException, Depends, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware

# Set up logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler("/app/data/resource_watcher.log")
    ]
)
logger = logging.getLogger("resource_watcher")

# Import Docker if available
try:
    import docker
    docker_available = True
except ImportError:
    docker_available = False
    logger.warning("Docker Python module not available. Docker stats will be disabled.")

# Create FastAPI app
app = FastAPI(
    title="Resource Watcher",
    description="AgencyStack Resource Watcher API",
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

# Settings
class Settings:
    def __init__(self):
        self.client_id = os.getenv("CLIENT_ID", "default")
        self.metrics_path = os.getenv("METRICS_PATH", "/app/data/metrics")
        self.alerts_path = os.getenv("ALERTS_PATH", "/app/data/alerts")
        self.llm_enabled = os.getenv("LLM_ENABLED", "false").lower() == "true"
        self.use_ollama = os.getenv("USE_OLLAMA", "false").lower() == "true"
        self.ollama_url = os.getenv("OLLAMA_API_URL", "http://ollama:11434")
        self.langchain_url = os.getenv("LANGCHAIN_API_URL", "http://langchain:7860")
        self.prometheus_enabled = os.getenv("PROMETHEUS_ENABLED", "false").lower() == "true"
        self.prometheus_url = os.getenv("PROMETHEUS_URL", "http://prometheus:9090")
        self.docker_enabled = os.getenv("DOCKER_ENABLED", "false").lower() == "true" and docker_available
        self.collection_interval = int(os.getenv("COLLECTION_INTERVAL", "60"))
        self.retention_period = int(os.getenv("RETENTION_PERIOD", "1440"))
        self.cpu_threshold = float(os.getenv("CPU_THRESHOLD", "80"))
        self.memory_threshold = float(os.getenv("MEMORY_THRESHOLD", "80"))
        self.disk_threshold = float(os.getenv("DISK_THRESHOLD", "90"))

settings = Settings()

# Data models
class SystemInfo(BaseModel):
    hostname: str
    platform: str
    platform_version: str
    client_id: str
    cpu_count: int
    total_memory_gb: float

class CPUMetrics(BaseModel):
    usage_percent: float
    load_avg_1min: float
    load_avg_5min: float
    load_avg_15min: float

class MemoryMetrics(BaseModel):
    total_gb: float
    available_gb: float
    used_percent: float

class DiskMetrics(BaseModel):
    device: str
    mountpoint: str
    total_gb: float
    free_gb: float
    used_percent: float

class NetworkMetrics(BaseModel):
    interface: str
    bytes_sent: int
    bytes_recv: int

class DockerContainerMetrics(BaseModel):
    name: str
    image: str
    status: str
    cpu_percent: float
    memory_percent: float
    memory_usage_mb: float

class ResourceMetrics(BaseModel):
    timestamp: str
    system: SystemInfo
    cpu: CPUMetrics
    memory: MemoryMetrics
    disks: List[DiskMetrics]
    network: List[NetworkMetrics]
    docker: Optional[List[DockerContainerMetrics]] = None

class Alert(BaseModel):
    timestamp: str
    level: str  # info, warning, critical
    resource_type: str  # cpu, memory, disk, network, docker
    message: str
    metrics: dict = {}

class ResourceSummary(BaseModel):
    start_time: str
    end_time: str
    system: SystemInfo
    cpu_avg: float
    cpu_max: float
    memory_avg: float
    memory_max: float
    disk_usage_avg: Dict[str, float]
    network_traffic_mb: Dict[str, Dict[str, float]]
    alerts: List[Alert]
    anomalies: Optional[List[Dict]] = None
    recommendations: Optional[List[Dict]] = None

# In-memory data store
metrics_history = []
alerts_history = []
is_collecting = False

# Helper functions for metrics collection
def get_system_info():
    return SystemInfo(
        hostname=platform.node(),
        platform=platform.system(),
        platform_version=platform.release(),
        client_id=settings.client_id,
        cpu_count=psutil.cpu_count(),
        total_memory_gb=psutil.virtual_memory().total / (1024**3)
    )

def get_cpu_metrics():
    load_avg = psutil.getloadavg() if hasattr(psutil, 'getloadavg') else (0, 0, 0)
    return CPUMetrics(
        usage_percent=psutil.cpu_percent(interval=1),
        load_avg_1min=load_avg[0],
        load_avg_5min=load_avg[1],
        load_avg_15min=load_avg[2]
    )

def get_memory_metrics():
    memory = psutil.virtual_memory()
    return MemoryMetrics(
        total_gb=memory.total / (1024**3),
        available_gb=memory.available / (1024**3),
        used_percent=memory.percent
    )

def get_disk_metrics():
    disks = []
    for partition in psutil.disk_partitions():
        try:
            usage = psutil.disk_usage(partition.mountpoint)
            disks.append(DiskMetrics(
                device=partition.device,
                mountpoint=partition.mountpoint,
                total_gb=usage.total / (1024**3),
                free_gb=usage.free / (1024**3),
                used_percent=usage.percent
            ))
        except (PermissionError, OSError):
            pass
    return disks

def get_network_metrics():
    network = []
    io_counters = psutil.net_io_counters(pernic=True)
    for interface, stats in io_counters.items():
        if interface != 'lo':  # Skip loopback interface
            network.append(NetworkMetrics(
                interface=interface,
                bytes_sent=stats.bytes_sent,
                bytes_recv=stats.bytes_recv
            ))
    return network

def get_docker_metrics():
    if not settings.docker_enabled:
        return None
    
    try:
        client = docker.from_env()
        containers = []
        
        for container in client.containers.list():
            try:
                stats = container.stats(stream=False)
                
                # Extract CPU stats
                cpu_delta = stats["cpu_stats"]["cpu_usage"]["total_usage"] - stats["precpu_stats"]["cpu_usage"]["total_usage"]
                system_delta = stats["cpu_stats"]["system_cpu_usage"] - stats["precpu_stats"]["system_cpu_usage"]
                cpu_percent = 0.0
                if system_delta > 0 and cpu_delta > 0:
                    cpu_percent = (cpu_delta / system_delta) * psutil.cpu_count() * 100.0
                
                # Extract memory stats
                memory_usage = stats["memory_stats"]["usage"] if "usage" in stats["memory_stats"] else 0
                memory_limit = stats["memory_stats"]["limit"] if "limit" in stats["memory_stats"] else 1
                memory_percent = (memory_usage / memory_limit) * 100.0 if memory_limit > 0 else 0.0
                
                containers.append(DockerContainerMetrics(
                    name=container.name,
                    image=container.image.tags[0] if container.image.tags else "untagged",
                    status=container.status,
                    cpu_percent=round(cpu_percent, 2),
                    memory_percent=round(memory_percent, 2),
                    memory_usage_mb=round(memory_usage / (1024**2), 2)
                ))
            except Exception as e:
                logger.warning(f"Error collecting stats for container {container.name}: {e}")
        
        return containers
    except Exception as e:
        logger.error(f"Error connecting to Docker: {e}")
        return None

# Collect metrics and generate alerts
async def collect_metrics_and_alerts():
    global is_collecting
    is_collecting = True
    
    try:
        logger.info("Starting metrics collection")
        
        while is_collecting:
            try:
                # Collect system metrics
                system_info = get_system_info()
                cpu_metrics = get_cpu_metrics()
                memory_metrics = get_memory_metrics()
                disk_metrics = get_disk_metrics()
                network_metrics = get_network_metrics()
                docker_metrics = get_docker_metrics() if settings.docker_enabled else None
                
                # Create metrics record
                timestamp = datetime.now().isoformat()
                metrics = ResourceMetrics(
                    timestamp=timestamp,
                    system=system_info,
                    cpu=cpu_metrics,
                    memory=memory_metrics,
                    disks=disk_metrics,
                    network=network_metrics,
                    docker=docker_metrics
                )
                
                # Add to history and limit retention
                metrics_history.append(metrics)
                if len(metrics_history) > settings.retention_period:
                    metrics_history.pop(0)
                
                # Check for alerts
                check_alerts(metrics)
                
                # Wait for next collection interval
                await asyncio.sleep(settings.collection_interval)
            except Exception as e:
                logger.error(f"Error in metrics collection: {e}")
                await asyncio.sleep(10)  # Sleep on error
    except Exception as e:
        logger.error(f"Fatal error in metrics collector task: {e}")
    finally:
        is_collecting = False
        logger.info("Metrics collection stopped")

# Check for alert conditions
def check_alerts(metrics: ResourceMetrics):
    alerts = []
    timestamp = metrics.timestamp
    
    # Check CPU alert
    if metrics.cpu.usage_percent > settings.cpu_threshold:
        alerts.append(Alert(
            timestamp=timestamp,
            level="warning" if metrics.cpu.usage_percent < settings.cpu_threshold + 10 else "critical",
            resource_type="cpu",
            message=f"CPU usage exceeded {settings.cpu_threshold}% threshold ({metrics.cpu.usage_percent:.1f}%)",
            metrics={"cpu_percent": metrics.cpu.usage_percent}
        ))
    
    # Check memory alert
    if metrics.memory.used_percent > settings.memory_threshold:
        alerts.append(Alert(
            timestamp=timestamp,
            level="warning" if metrics.memory.used_percent < settings.memory_threshold + 10 else "critical",
            resource_type="memory",
            message=f"Memory usage exceeded {settings.memory_threshold}% threshold ({metrics.memory.used_percent:.1f}%)",
            metrics={"memory_percent": metrics.memory.used_percent}
        ))
    
    # Check disk alerts
    for disk in metrics.disks:
        if disk.used_percent > settings.disk_threshold:
            alerts.append(Alert(
                timestamp=timestamp,
                level="warning" if disk.used_percent < settings.disk_threshold + 5 else "critical",
                resource_type="disk",
                message=f"Disk usage on {disk.mountpoint} exceeded {settings.disk_threshold}% threshold ({disk.used_percent:.1f}%)",
                metrics={"disk_percent": disk.used_percent, "mountpoint": disk.mountpoint}
            ))
    
    # Check Docker container alerts
    if metrics.docker:
        for container in metrics.docker:
            if container.cpu_percent > settings.cpu_threshold:
                alerts.append(Alert(
                    timestamp=timestamp,
                    level="warning" if container.cpu_percent < settings.cpu_threshold + 10 else "critical",
                    resource_type="docker_cpu",
                    message=f"Container {container.name} CPU usage exceeded {settings.cpu_threshold}% threshold ({container.cpu_percent:.1f}%)",
                    metrics={"container": container.name, "cpu_percent": container.cpu_percent}
                ))
            
            if container.memory_percent > settings.memory_threshold:
                alerts.append(Alert(
                    timestamp=timestamp,
                    level="warning" if container.memory_percent < settings.memory_threshold + 10 else "critical",
                    resource_type="docker_memory",
                    message=f"Container {container.name} memory usage exceeded {settings.memory_threshold}% threshold ({container.memory_percent:.1f}%)",
                    metrics={"container": container.name, "memory_percent": container.memory_percent}
                ))
    
    # Add alerts to history
    for alert in alerts:
        alerts_history.append(alert)
        logger.warning(f"Alert: {alert.message}")
    
    # Limit retention
    while len(alerts_history) > settings.retention_period:
        alerts_history.pop(0)

# Background task to collect metrics
@app.on_event("startup")
async def startup_event():
    asyncio.create_task(collect_metrics_and_alerts())
    logger.info("Resource Watcher started")

# Shutdown event
@app.on_event("shutdown")
async def shutdown_event():
    global is_collecting
    is_collecting = False
    logger.info("Resource Watcher shutdown")
EOF

  # Import the API endpoints
  cat "${SCRIPT_DIR}/components/resource_watcher_api.py" >> "${APP_DIR}/main.py"

  # Create requirements.txt
  cat > "${APP_DIR}/requirements.txt" << 'EOF'
fastapi==0.95.1
uvicorn==0.22.0
pydantic==1.10.7
psutil==5.9.5
docker==6.1.3
requests==2.28.2
httpx==0.24.0
python-multipart==0.0.6
asyncio==3.4.3
prometheus-client==0.16.0
python-dotenv==1.0.0
EOF

  log "INFO" "Created FastAPI application with API endpoints"
}

# Create Docker configuration
create_docker_config() {
  log "INFO" "Creating Docker configuration..."
  
  # Import Docker configuration functions
  source "${SCRIPT_DIR}/components/resource_watcher_docker.py"
  
  # Create Dockerfile
  create_dockerfile "${APP_DIR}"
  
  # Create docker-compose.yml
  ADD_TRAEFIK=false
  if [ "${DOMAIN}" != "localhost" ]; then
    ADD_TRAEFIK=true
  fi
  
  create_docker_compose "${APP_DIR}" "${CLIENT_ID}" "${PORT}" "${LOG_DIR}" "${DATA_DIR}" "${ADD_TRAEFIK}" "${DOMAIN}"
  
  # Create Docker .env file
  create_docker_env "${APP_DIR}" \
    "http://ollama:${OLLAMA_PORT}" \
    "http://langchain:${LANGCHAIN_PORT}" \
    "http://prometheus:${PROMETHEUS_PORT}" \
    "${ENABLE_LLM}" "${USE_OLLAMA}" "${ENABLE_PROMETHEUS}"
  
  log "INFO" "Docker configuration created"
}

# Main function to run the installation
main() {
  log "INFO" "Starting Resource Watcher installation..."
  
  # Parse command-line arguments
  parse_args "$@"
  
  # Check if already installed and if we should force reinstall
  if [ -d "${DOCKER_DIR}" ] && [ "$FORCE" != true ]; then
    log "WARN" "Resource Watcher appears to be already installed at ${DOCKER_DIR}"
    log "WARN" "Use --force to reinstall"
    exit 0
  fi
  
  # Create log directory if it doesn't exist
  mkdir -p "$(dirname "${LOG_FILE}")"
  
  # Check dependencies
  check_dependencies
  
  # Create necessary directories
  create_directories
  
  # Create the FastAPI application
  create_app
  
  # Perform the installation
  install_resource_watcher
  
  log "SUCCESS" "Resource Watcher installation completed successfully."
  log "INFO" "API available at: http://localhost:${PORT} or https://resources.${DOMAIN}"
  log "INFO" "Use 'make resource-watcher-status' to check the service status."
}

# Call the main function with all script arguments
main "$@"
