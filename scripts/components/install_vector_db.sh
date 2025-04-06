#!/bin/bash
# install_vector_db.sh - AgencyStack Vector Database Component Installer
# https://stack.nerdofmouth.com
#
# Installs and configures a vector database (ChromaDB by default) with hardened security
# Part of the AgencyStack AI & Search suite
#
# Author: AgencyStack Team
# Version: 1.0.0
# Date: April 5, 2025

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
VECTORDB_LOG="${COMPONENT_LOG_DIR}/vector_db.log"
INSTALLED_COMPONENTS="${CONFIG_DIR}/installed_components.txt"
DASHBOARD_DATA="${CONFIG_DIR}/dashboard_data.json"
INTEGRATION_STATUS="${CONFIG_DIR}/integration_status.json"
CLIENT_ID_FILE="${CONFIG_DIR}/client_id"

# Default to ChromaDB
VECTORDB_TYPE="chromadb"  # Options: chromadb, qdrant, weaviate
VECTORDB_VERSION="0.4.22"  # Latest stable version for ChromaDB
VECTORDB_PORT=8000
VECTORDB_ADMIN_EMAIL=""
VECTORDB_API_KEY=$(openssl rand -hex 32)
DOMAIN=""
CLIENT_ID=""
CLIENT_DIR=""
VECTORDB_CONFIG_DIR="${CONFIG_DIR}/vector_db"
DOCKER_COMPOSE_DIR="${VECTORDB_CONFIG_DIR}/docker"
WITH_DEPS=false
FORCE=false
VERBOSE=false
ADMIN_EMAIL=""

# Function to log messages
log() {
  local level="$1"
  local message="$2"
  local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
  
  # Ensure log directory exists
  mkdir -p "${COMPONENT_LOG_DIR}"
  
  # Log to file
  echo "[$timestamp] [$level] $message" >> "${VECTORDB_LOG}"
  
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
  echo -e "${BOLD}${MAGENTA}AgencyStack Vector Database Installer${NC}"
  echo -e "${BOLD}Usage:${NC} $0 [OPTIONS]"
  echo
  echo -e "${BOLD}Options:${NC}"
  echo -e "  ${CYAN}--domain${NC} <domain>        Domain name for Vector DB (e.g., vectordb.yourdomain.com)"
  echo -e "  ${CYAN}--client-id${NC} <id>         Client ID for multi-tenant setup"
  echo -e "  ${CYAN}--admin-email${NC} <email>    Admin email for notifications"
  echo -e "  ${CYAN}--vector-db${NC} <type>       Vector DB type (chromadb, qdrant, weaviate, default: chromadb)"
  echo -e "  ${CYAN}--with-deps${NC}              Install dependencies"
  echo -e "  ${CYAN}--force${NC}                  Force installation even if already installed"
  echo -e "  ${CYAN}--verbose${NC}                Show verbose output"
  echo -e "  ${CYAN}--help${NC}                   Show this help message and exit"
  echo
  echo -e "${BOLD}Examples:${NC}"
  echo -e "  $0 --domain vectordb.example.com --admin-email admin@example.com --with-deps"
  echo -e "  $0 --domain vectordb.client1.com --client-id client1 --admin-email admin@client1.com --vector-db qdrant --with-deps"
  echo -e "  $0 --domain vectordb.client2.com --client-id client2 --admin-email admin@client2.com --force"
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
  mkdir -p "${CLIENT_DIR}/vector_db/config"
  mkdir -p "${CLIENT_DIR}/vector_db/data"
  mkdir -p "${DOCKER_COMPOSE_DIR}"
  
  log "INFO" "Set up client directory at ${CLIENT_DIR}/vector_db"
}

# Parse command line arguments
while [ "$#" -gt 0 ]; do
  case "$1" in
    --domain)
      DOMAIN="$2"
      shift 2
      ;;
    --client-id)
      CLIENT_ID="$2"
      shift 2
      ;;
    --admin-email)
      ADMIN_EMAIL="$2"
      VECTORDB_ADMIN_EMAIL="$2"
      shift 2
      ;;
    --vector-db)
      VECTORDB_TYPE="$2"
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
    --verbose)
      VERBOSE=true
      shift
      ;;
    --help)
      show_help
      ;;
    *)
      log "ERROR" "Unknown parameter passed: $1"
      show_help
      ;;
  esac
done

# Check if domain is provided
if [ -z "$DOMAIN" ]; then
  log "ERROR" "Domain is required. Use --domain to specify it."
  show_help
fi

# Check if admin email is provided
if [ -z "$ADMIN_EMAIL" ]; then
  log "ERROR" "Admin email is required. Use --admin-email to specify it."
  show_help
fi

# Validate vector DB type
if [[ "$VECTORDB_TYPE" != "chromadb" && "$VECTORDB_TYPE" != "qdrant" && "$VECTORDB_TYPE" != "weaviate" ]]; then
  log "ERROR" "Invalid vector database type: $VECTORDB_TYPE. Must be one of: chromadb, qdrant, weaviate."
  show_help
fi

# Set variables based on vector DB type
case "$VECTORDB_TYPE" in
  "chromadb")
    VECTORDB_VERSION="0.4.22"
    VECTORDB_PORT=8000
    ;;
  "qdrant")
    VECTORDB_VERSION="v1.5.0"
    VECTORDB_PORT=6333
    ;;
  "weaviate")
    VECTORDB_VERSION="1.23.0"
    VECTORDB_PORT=8080
    ;;
esac

# Set up directories
log "INFO" "Setting up directories for $VECTORDB_TYPE installation"
setup_client_dir

# Check if Vector DB is already installed
VECTORDB_CONTAINER="${CLIENT_ID}_vectordb"
if docker ps -a --format '{{.Names}}' | grep -q "$VECTORDB_CONTAINER"; then
  if [ "$FORCE" = true ]; then
    log "WARN" "Vector DB container '$VECTORDB_CONTAINER' already exists, will reinstall because --force was specified"
    # Stop and remove existing containers
    log "INFO" "Stopping and removing existing Vector DB containers"
    cd "${DOCKER_COMPOSE_DIR}" && docker-compose down || true
  else
    log "INFO" "Vector DB container '$VECTORDB_CONTAINER' already exists"
    log "INFO" "To reinstall, use --force flag"
    
    # Check if the container is running
    if docker ps --format '{{.Names}}' | grep -q "$VECTORDB_CONTAINER"; then
      log "INFO" "Vector DB container is running"
      echo -e "${GREEN}Vector DB ($VECTORDB_TYPE) is already installed and running for $DOMAIN${NC}"
      echo -e "${CYAN}Vector DB URL: https://${DOMAIN}${NC}"
      echo -e "${CYAN}To make changes, use --force to reinstall${NC}"
      exit 0
    else
      log "WARN" "Vector DB container exists but is not running"
      echo -e "${YELLOW}Vector DB ($VECTORDB_TYPE) is installed but not running for $DOMAIN${NC}"
      echo -e "${CYAN}Starting Vector DB containers...${NC}"
      cd "${DOCKER_COMPOSE_DIR}" && docker-compose up -d
      echo -e "${GREEN}Vector DB has been started for $DOMAIN${NC}"
      echo -e "${CYAN}Vector DB URL: https://${DOMAIN}${NC}"
      exit 0
    fi
  fi
fi

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
  log "ERROR" "Docker is not installed. Please install Docker first."
  if [ "$WITH_DEPS" = true ]; then
    log "INFO" "Installing Docker with --with-deps flag"
    if [ -f "${ROOT_DIR}/scripts/components/install_docker.sh" ]; then
      bash "${ROOT_DIR}/scripts/components/install_docker.sh" || {
        log "ERROR" "Failed to install Docker. Please install it manually."
        exit 1
      }
    else
      log "ERROR" "Cannot find install_docker.sh script. Please install Docker manually."
      exit 1
    fi
  else
    log "INFO" "Use --with-deps to automatically install dependencies"
    exit 1
  fi
fi

# Check if Docker Compose is installed
if ! command -v docker-compose &> /dev/null; then
  log "ERROR" "Docker Compose is not installed. Please install Docker Compose first."
  if [ "$WITH_DEPS" = true ]; then
    log "INFO" "Installing Docker Compose with --with-deps flag"
    if [ -f "${ROOT_DIR}/scripts/components/install_docker_compose.sh" ]; then
      bash "${ROOT_DIR}/scripts/components/install_docker_compose.sh" || {
        log "ERROR" "Failed to install Docker Compose. Please install it manually."
        exit 1
      }
    else
      log "ERROR" "Cannot find install_docker_compose.sh script. Please install Docker Compose manually."
      exit 1
    fi
  else
    log "INFO" "Use --with-deps to automatically install dependencies"
    exit 1
  fi
fi

# Create Docker network if it doesn't exist
NETWORK_NAME="${CLIENT_ID}_network"
if ! docker network inspect "$NETWORK_NAME" &> /dev/null; then
  log "INFO" "Creating Docker network $NETWORK_NAME"
  docker network create "$NETWORK_NAME" || {
    log "ERROR" "Failed to create Docker network $NETWORK_NAME."
    exit 1
  }
fi

# Create Docker Compose file based on vector DB type
log "INFO" "Creating Docker Compose configuration for $VECTORDB_TYPE"

case "$VECTORDB_TYPE" in
  "chromadb")
    cat > "${DOCKER_COMPOSE_DIR}/docker-compose.yml" << EOF
version: '3.8'

services:
  chromadb:
    image: ghcr.io/chroma-core/chroma:${VECTORDB_VERSION}
    container_name: ${VECTORDB_CONTAINER}
    restart: unless-stopped
    volumes:
      - ${CLIENT_DIR}/vector_db/data:/chroma/chroma
    environment:
      - ALLOW_RESET=false
      - CHROMA_SERVER_AUTH_CREDENTIALS_PROVIDER=chromadb.auth.token.TokenAuthCredentialsProvider
      - CHROMA_SERVER_AUTH_CREDENTIALS=${VECTORDB_API_KEY}
      - CHROMA_SERVER_AUTH_PROVIDER=chromadb.auth.token.TokenAuthServerProvider
      - CHROMA_SERVER_AUTH_TOKEN_TRANSPORT_HEADER=X-Chroma-Token
    ports:
      - "${VECTORDB_PORT}:8000"
    networks:
      - ${NETWORK_NAME}
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.${CLIENT_ID}-vectordb.rule=Host(\`${DOMAIN}\`)"
      - "traefik.http.routers.${CLIENT_ID}-vectordb.entrypoints=websecure"
      - "traefik.http.routers.${CLIENT_ID}-vectordb.tls=true"
      - "traefik.http.routers.${CLIENT_ID}-vectordb.tls.certresolver=letsencrypt"
      - "traefik.http.services.${CLIENT_ID}-vectordb.loadbalancer.server.port=8000"
      - "traefik.http.middlewares.${CLIENT_ID}-vectordb-headers.headers.stsSeconds=31536000"
      - "traefik.http.middlewares.${CLIENT_ID}-vectordb-headers.headers.stsIncludeSubdomains=true"
      - "traefik.http.middlewares.${CLIENT_ID}-vectordb-headers.headers.stsPreload=true"
      - "traefik.http.middlewares.${CLIENT_ID}-vectordb-headers.headers.forceSTSHeader=true"
      - "traefik.http.routers.${CLIENT_ID}-vectordb.middlewares=${CLIENT_ID}-vectordb-headers"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/api/v1/heartbeat"]
      interval: 30s
      timeout: 10s
      retries: 5

networks:
  ${NETWORK_NAME}:
    external: true
EOF
    ;;
    
  "qdrant")
    cat > "${DOCKER_COMPOSE_DIR}/docker-compose.yml" << EOF
version: '3.8'

services:
  qdrant:
    image: qdrant/qdrant:${VECTORDB_VERSION}
    container_name: ${VECTORDB_CONTAINER}
    restart: unless-stopped
    volumes:
      - ${CLIENT_DIR}/vector_db/data:/qdrant/storage
    environment:
      - QDRANT__SERVICE__API_KEY=${VECTORDB_API_KEY}
    ports:
      - "${VECTORDB_PORT}:6333"
      - "6334:6334"
    networks:
      - ${NETWORK_NAME}
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.${CLIENT_ID}-vectordb.rule=Host(\`${DOMAIN}\`)"
      - "traefik.http.routers.${CLIENT_ID}-vectordb.entrypoints=websecure"
      - "traefik.http.routers.${CLIENT_ID}-vectordb.tls=true"
      - "traefik.http.routers.${CLIENT_ID}-vectordb.tls.certresolver=letsencrypt"
      - "traefik.http.services.${CLIENT_ID}-vectordb.loadbalancer.server.port=6333"
      - "traefik.http.middlewares.${CLIENT_ID}-vectordb-headers.headers.stsSeconds=31536000"
      - "traefik.http.middlewares.${CLIENT_ID}-vectordb-headers.headers.stsIncludeSubdomains=true"
      - "traefik.http.middlewares.${CLIENT_ID}-vectordb-headers.headers.stsPreload=true"
      - "traefik.http.middlewares.${CLIENT_ID}-vectordb-headers.headers.forceSTSHeader=true"
      - "traefik.http.routers.${CLIENT_ID}-vectordb.middlewares=${CLIENT_ID}-vectordb-headers"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:6333/healthz"]
      interval: 30s
      timeout: 10s
      retries: 5

networks:
  ${NETWORK_NAME}:
    external: true
EOF
    ;;
    
  "weaviate")
    cat > "${DOCKER_COMPOSE_DIR}/docker-compose.yml" << EOF
version: '3.8'

services:
  weaviate:
    image: semitechnologies/weaviate:${VECTORDB_VERSION}
    container_name: ${VECTORDB_CONTAINER}
    restart: unless-stopped
    volumes:
      - ${CLIENT_DIR}/vector_db/data:/var/lib/weaviate
    environment:
      - AUTHENTICATION_ANONYMOUS_ACCESS_ENABLED=false
      - AUTHENTICATION_APIKEY_ENABLED=true
      - AUTHENTICATION_APIKEY_ALLOWED_KEYS=${VECTORDB_API_KEY}
      - AUTHENTICATION_APIKEY_USERS=admin@${DOMAIN}
      - PERSISTENCE_DATA_PATH=/var/lib/weaviate
      - ENABLE_MODULES=text2vec-transformers
      - DEFAULT_VECTORIZER_MODULE=text2vec-transformers
      - CLUSTER_HOSTNAME=node1
    ports:
      - "${VECTORDB_PORT}:8080"
    networks:
      - ${NETWORK_NAME}
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.${CLIENT_ID}-vectordb.rule=Host(\`${DOMAIN}\`)"
      - "traefik.http.routers.${CLIENT_ID}-vectordb.entrypoints=websecure"
      - "traefik.http.routers.${CLIENT_ID}-vectordb.tls=true"
      - "traefik.http.routers.${CLIENT_ID}-vectordb.tls.certresolver=letsencrypt"
      - "traefik.http.services.${CLIENT_ID}-vectordb.loadbalancer.server.port=8080"
      - "traefik.http.middlewares.${CLIENT_ID}-vectordb-headers.headers.stsSeconds=31536000"
      - "traefik.http.middlewares.${CLIENT_ID}-vectordb-headers.headers.stsIncludeSubdomains=true"
      - "traefik.http.middlewares.${CLIENT_ID}-vectordb-headers.headers.stsPreload=true"
      - "traefik.http.middlewares.${CLIENT_ID}-vectordb-headers.headers.forceSTSHeader=true"
      - "traefik.http.routers.${CLIENT_ID}-vectordb.middlewares=${CLIENT_ID}-vectordb-headers"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/v1/.well-known/ready"]
      interval: 30s
      timeout: 10s
      retries: 5

  transformers:
    image: semitechnologies/transformers-inference:sentence-transformers-multi-qa-MiniLM-L6-cos-v1
    container_name: ${CLIENT_ID}_vectordb_transformers
    restart: unless-stopped
    environment:
      - ENABLE_CUDA=0
    networks:
      - ${NETWORK_NAME}

networks:
  ${NETWORK_NAME}:
    external: true
EOF
    ;;
esac

# Create .env file for docker-compose
cat > "${DOCKER_COMPOSE_DIR}/.env" << EOF
VECTORDB_TYPE=${VECTORDB_TYPE}
VECTORDB_VERSION=${VECTORDB_VERSION}
VECTORDB_PORT=${VECTORDB_PORT}
VECTORDB_API_KEY=${VECTORDB_API_KEY}
DOMAIN=${DOMAIN}
CLIENT_ID=${CLIENT_ID}
NETWORK_NAME=${NETWORK_NAME}
EOF

# Save credentials to a secure location
mkdir -p "${CONFIG_DIR}/secrets/vector_db"
cat > "${CONFIG_DIR}/secrets/vector_db/${DOMAIN}.env" << EOF
VECTORDB_TYPE=${VECTORDB_TYPE}
VECTORDB_URL=https://${DOMAIN}
VECTORDB_API_KEY=${VECTORDB_API_KEY}
EOF

# Start Vector DB
log "INFO" "Starting Vector DB ($VECTORDB_TYPE)"
cd "${DOCKER_COMPOSE_DIR}" && docker-compose up -d || {
  log "ERROR" "Failed to start Vector DB"
  exit 1
}

# Wait for Vector DB to be ready
log "INFO" "Waiting for Vector DB to be ready"
timeout=120
counter=0
echo -n "Waiting for Vector DB to start"

# Define healthcheck endpoint based on vector DB type
case "$VECTORDB_TYPE" in
  "chromadb")
    HEALTH_URL="http://localhost:${VECTORDB_PORT}/api/v1/heartbeat"
    ;;
  "qdrant")
    HEALTH_URL="http://localhost:${VECTORDB_PORT}/healthz"
    ;;
  "weaviate")
    HEALTH_URL="http://localhost:${VECTORDB_PORT}/v1/.well-known/ready"
    ;;
esac

while [ $counter -lt $timeout ]; do
  if curl -s "${HEALTH_URL}" > /dev/null; then
    break
  fi
  echo -n "."
  sleep 2
  counter=$((counter+2))
done
echo

if [ $counter -ge $timeout ]; then
  log "WARN" "Timed out waiting for Vector DB to fully start, but containers are running"
  log "INFO" "You can check the status manually after a few minutes"
else
  log "INFO" "Vector DB is now ready"
fi

# Update installation records
if ! grep -q "vector_db" "${INSTALLED_COMPONENTS}" 2>/dev/null; then
  echo "vector_db" >> "${INSTALLED_COMPONENTS}"
fi

# Update dashboard data
if [ -f "${DASHBOARD_DATA}" ]; then
  # Check if jq is installed
  if command -v jq &> /dev/null; then
    # Create temporary file
    TEMP_FILE=$(mktemp)
    
    # Update dashboard data with jq
    jq --arg domain "${DOMAIN}" \
       --arg port "${VECTORDB_PORT}" \
       --arg type "${VECTORDB_TYPE}" \
       --arg version "${VECTORDB_VERSION}" \
       --arg timestamp "$(date +"%Y-%m-%d %H:%M:%S")" \
       '.components.vector_db = {
         "name": "Vector DB (" + $type + ")",
         "url": "https://" + $domain,
         "port": $port,
         "type": $type,
         "version": $version,
         "status": "running",
         "last_updated": $timestamp
       }' "${DASHBOARD_DATA}" > "${TEMP_FILE}"
       
    # Replace original file with updated data
    mv "${TEMP_FILE}" "${DASHBOARD_DATA}"
  else
    log "WARN" "jq is not installed. Skipping dashboard data update."
  fi
fi

# Update integration status
if [ -f "${INTEGRATION_STATUS}" ]; then
  if command -v jq &> /dev/null; then
    TEMP_FILE=$(mktemp)
    
    jq --arg domain "${DOMAIN}" \
       --arg type "${VECTORDB_TYPE}" \
       --arg timestamp "$(date +"%Y-%m-%d %H:%M:%S")" \
       '.vector_db = {
         "integrated": true,
         "type": $type,
         "domain": $domain,
         "last_updated": $timestamp
       }' "${INTEGRATION_STATUS}" > "${TEMP_FILE}"
       
    mv "${TEMP_FILE}" "${INTEGRATION_STATUS}"
  else
    log "WARN" "jq is not installed. Skipping integration status update."
  fi
fi

# Generate a Python example file for using the vector database
mkdir -p "${CLIENT_DIR}/vector_db/examples"

case "$VECTORDB_TYPE" in
  "chromadb")
    cat > "${CLIENT_DIR}/vector_db/examples/chromadb_example.py" << EOF
#!/usr/bin/env python3
# Example for using ChromaDB with the AgencyStack installation

import chromadb
from chromadb.config import Settings

# Connect to the ChromaDB instance
client = chromadb.HttpClient(
    host="${DOMAIN}",
    port=443,
    ssl=True,
    headers={"X-Chroma-Token": "${VECTORDB_API_KEY}"}
)

# Create a collection
collection = client.create_collection(name="example_collection")

# Add documents to the collection
collection.add(
    documents=["This is a document about cats", "This is a document about dogs"],
    metadatas=[{"source": "article1"}, {"source": "article2"}],
    ids=["doc1", "doc2"]
)

# Query the collection
results = collection.query(
    query_texts=["Tell me about cats"],
    n_results=1
)

print(results)
EOF
    ;;
  "qdrant")
    cat > "${CLIENT_DIR}/vector_db/examples/qdrant_example.py" << EOF
#!/usr/bin/env python3
# Example for using Qdrant with the AgencyStack installation

from qdrant_client import QdrantClient
from qdrant_client.http import models
import numpy as np

# Connect to the Qdrant instance
client = QdrantClient(
    url=f"https://${DOMAIN}",
    api_key="${VECTORDB_API_KEY}"
)

# Create a collection
client.create_collection(
    collection_name="example_collection",
    vectors_config=models.VectorParams(size=768, distance=models.Distance.COSINE)
)

# Generate some random vectors for the example
vector1 = np.random.rand(768).tolist()
vector2 = np.random.rand(768).tolist()

# Add vectors to the collection
client.upsert(
    collection_name="example_collection",
    points=[
        models.PointStruct(
            id=1,
            vector=vector1,
            payload={"text": "This is a document about cats", "source": "article1"}
        ),
        models.PointStruct(
            id=2,
            vector=vector2,
            payload={"text": "This is a document about dogs", "source": "article2"}
        )
    ]
)

# Query the collection (with a random search vector for demonstration)
search_vector = np.random.rand(768).tolist()
results = client.search(
    collection_name="example_collection",
    query_vector=search_vector,
    limit=1
)

print(results)
EOF
    ;;
  "weaviate")
    cat > "${CLIENT_DIR}/vector_db/examples/weaviate_example.py" << EOF
#!/usr/bin/env python3
# Example for using Weaviate with the AgencyStack installation

import weaviate
from weaviate.auth import AuthApiKey

# Connect to the Weaviate instance
client = weaviate.Client(
    url=f"https://${DOMAIN}",
    auth_client_secret=AuthApiKey(api_key="${VECTORDB_API_KEY}")
)

# Create a schema for articles
class_obj = {
    "class": "Article",
    "properties": [
        {
            "name": "content",
            "dataType": ["text"]
        },
        {
            "name": "source",
            "dataType": ["string"]
        }
    ]
}

# Add the schema to Weaviate
client.schema.create_class(class_obj)

# Add data objects
client.data_object.create(
    class_name="Article",
    data_object={
        "content": "This is a document about cats",
        "source": "article1"
    }
)

client.data_object.create(
    class_name="Article",
    data_object={
        "content": "This is a document about dogs",
        "source": "article2"
    }
)

# Query the data
result = client.query.get(
    "Article", ["content", "source"]
).with_near_text({
    "concepts": ["cats"]
}).with_limit(1).do()

print(result)
EOF
    ;;
esac

chmod +x "${CLIENT_DIR}/vector_db/examples/${VECTORDB_TYPE}_example.py"

# Display completion message
echo -e "${GREEN}${BOLD}✅ Vector DB (${VECTORDB_TYPE}) has been successfully installed!${NC}"
echo -e "${CYAN}Domain: https://${DOMAIN}${NC}"
echo -e "${CYAN}Port: ${VECTORDB_PORT}${NC}"
echo -e "${CYAN}Version: ${VECTORDB_VERSION}${NC}"
echo -e ""
echo -e "${YELLOW}Credentials:${NC}"
echo -e "API Key: ${VECTORDB_API_KEY}"
echo -e ""
echo -e "${YELLOW}IMPORTANT: Please save these credentials safely!${NC}"
echo -e "${CYAN}Credentials saved to: ${CONFIG_DIR}/secrets/vector_db/${DOMAIN}.env${NC}"
echo -e ""
echo -e "${YELLOW}Example usage:${NC}"
echo -e "A Python example has been created at:"
echo -e "${CYAN}${CLIENT_DIR}/vector_db/examples/${VECTORDB_TYPE}_example.py${NC}"

log "INFO" "Vector DB (${VECTORDB_TYPE}) installation completed successfully"
exit 0
