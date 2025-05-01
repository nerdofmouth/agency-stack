#!/bin/bash

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/../utils/common.sh" ]]; then
  source "${SCRIPT_DIR}/../utils/common.sh"
fi

# Enforce containerization (prevent host contamination)
exit_with_warning_if_host

# AgencyStack Component Installer: pgvector.sh
# Path: /scripts/components/install_pgvector.sh
#
REPO_ROOT="$(dirname \"$(dirname \"$SCRIPT_DIR\")\")"
preflight_check_agencystack || {
  echo -e "[ERROR] Preflight checks failed. Resolve issues before proceeding."
  exit 1
}
# --- END: Preflight/Prerequisite Check ---

# Strict error handling
set -euo pipefail

# Variables
COMPONENT_NAME="pgvector"
LOG_FILE="/var/log/agency_stack/components/${COMPONENT_NAME}.log"
POSTGRES_VERSION="15"
PGVECTOR_VERSION="0.5.1"
CLIENT_ID="default"
DOMAIN=""
ADMIN_EMAIL=""
FORCE=false
ENABLE_CLOUD=false
WITH_DEPS=false
VERBOSE=false
PGVECTOR_DB_NAME="vectordb"
PGVECTOR_DB_USER="vectoruser"
PGVECTOR_DB_PASS=$(openssl rand -hex 16)
INSTALL_DIR="/opt/agency_stack/clients/${CLIENT_ID}/${COMPONENT_NAME}"
POSTGRES_SERVICE="postgres-${CLIENT_ID}"

# Initialize logging
log_info "${LOG_FILE}" "pgvector installation started"

# Show usage information
show_help() {
  echo "Usage: $0 [OPTIONS]"
  echo
  echo "Options:"
  echo "  --domain DOMAIN           Domain for the installation"
  echo "  --admin-email EMAIL       Admin email for notifications"
  echo "  --client-id ID            Client ID for multi-tenant setup (default: default)"
  echo "  --force                   Force installation even if already installed"
  echo "  --enable-cloud            Allow cloud connections (default: false)"
  echo "  --with-deps               Install dependencies (default: false)"
  echo "  --verbose                 Enable verbose output"
  echo "  --help                    Show this help message and exit"
  exit 0
}

# Process command line arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    --domain)
      DOMAIN="$2"
      shift 2
      ;;
    --admin-email)
      ADMIN_EMAIL="$2"
      shift 2
      ;;
    --client-id)
      CLIENT_ID="$2"
      shift 2
      ;;
    --force)
      FORCE=true
      shift
      ;;
    --enable-cloud)
      ENABLE_CLOUD=true
      shift
      ;;
    --with-deps)
      WITH_DEPS=true
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
      log_error "${LOG_FILE}" "Unknown parameter: $key"
      exit 1
      ;;
  esac
done

# Update installation directory with client ID
INSTALL_DIR="/opt/agency_stack/clients/${CLIENT_ID}/${COMPONENT_NAME}"
POSTGRES_SERVICE="postgres-${CLIENT_ID}"

# Validate required parameters
if [ -z "${DOMAIN}" ] || [ -z "${ADMIN_EMAIL}" ]; then
  log_error "${LOG_FILE}" "Missing required parameters: domain and admin-email must be provided"
  show_help
  exit 1

# Check if pgvector is already installed
check_existing() {
  if [ -f "${INSTALL_DIR}/.installed" ] && [ "${FORCE}" != "true" ]; then
    log_info "${LOG_FILE}" "pgvector is already installed for client ${CLIENT_ID}"
    log_info "${LOG_FILE}" "Use --force to reinstall"
    exit 0
  fi
}

# Set up directory structure
setup_directories() {
  log_info "${LOG_FILE}" "Setting up directory structure"
  mkdir -p "${INSTALL_DIR}"
  mkdir -p "${INSTALL_DIR}/scripts"
  mkdir -p "${INSTALL_DIR}/config"
  mkdir -p "${INSTALL_DIR}/data"
}

# Check PostgreSQL installation
check_postgres() {
  log_info "${LOG_FILE}" "Checking PostgreSQL installation"
  
  # Verify if PostgreSQL service exists and is running
  if ! docker ps | grep -q "${POSTGRES_SERVICE}"; then
    log_warning "${LOG_FILE}" "PostgreSQL service ${POSTGRES_SERVICE} not found"
    
    if [ "${WITH_DEPS}" == "true" ]; then
      log_info "${LOG_FILE}" "Installing PostgreSQL as it was not found"
      bash "${SCRIPT_DIR}/install_postgres.sh" --client-id "${CLIENT_ID}" \
        --domain "${DOMAIN}" --admin-email "${ADMIN_EMAIL}"
      
      if ! docker ps | grep -q "${POSTGRES_SERVICE}"; then
        log_error "${LOG_FILE}" "Failed to install PostgreSQL"
        exit 1
      fi
    else
      log_error "${LOG_FILE}" "PostgreSQL is required. Install it first or use --with-deps"
      exit 1
    fi
  else
    log_info "${LOG_FILE}" "PostgreSQL is already installed"
  fi
}

# Install pgvector
install_pgvector() {
  log_info "${LOG_FILE}" "Installing pgvector extension"
  
  # Pull the PostgreSQL image if not exists
  if ! docker image inspect postgres:${POSTGRES_VERSION} &>/dev/null; then
    log_info "${LOG_FILE}" "Pulling PostgreSQL ${POSTGRES_VERSION} image"
    docker pull postgres:${POSTGRES_VERSION}
  fi
  
  # Create network if it doesn't exist
  if ! docker network inspect agency_stack_network &>/dev/null; then
    log_info "${LOG_FILE}" "Creating agency_stack_network Docker network"
    docker network create agency_stack_network
  fi
  
  # Create SQL script to install pgvector
  cat > "${INSTALL_DIR}/scripts/install_pgvector.sql" << EOF
-- Create extension if it doesn't exist
CREATE EXTENSION IF NOT EXISTS vector;

-- Create vectordb database if it doesn't exist
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_database WHERE datname = '${PGVECTOR_DB_NAME}') THEN
    CREATE DATABASE ${PGVECTOR_DB_NAME};
  END IF;
END
\$\$;

-- Connect to the vectordb database
\c ${PGVECTOR_DB_NAME};

-- Create extension in this database too
CREATE EXTENSION IF NOT EXISTS vector;

-- Create user if not exists
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '${PGVECTOR_DB_USER}') THEN
    CREATE USER ${PGVECTOR_DB_USER} WITH PASSWORD '${PGVECTOR_DB_PASS}';
  END IF;
END
\$\$;

-- Grant privileges
GRANT ALL PRIVILEGES ON DATABASE ${PGVECTOR_DB_NAME} TO ${PGVECTOR_DB_USER};

-- Create sample table with vector data
CREATE TABLE IF NOT EXISTS vector_test (
  id SERIAL PRIMARY KEY,
  content TEXT NOT NULL,
  embedding vector(384) NOT NULL
);

-- Create index for fast similarity search
CREATE INDEX IF NOT EXISTS vector_test_embedding_idx ON vector_test USING hnsw (embedding vector_cosine_ops);

-- Grant privileges on the test table
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO ${PGVECTOR_DB_USER};
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO ${PGVECTOR_DB_USER};
EOF

  # Install pgvector in the PostgreSQL container
  log_info "${LOG_FILE}" "Building and installing pgvector in PostgreSQL container"
  # Check if we need to install pgvector in the container
  if ! docker exec ${POSTGRES_SERVICE} psql -U postgres -c "SELECT 1 FROM pg_available_extensions WHERE name = 'vector'" 2>/dev/null | grep -q "1"; then
    log_info "${LOG_FILE}" "pgvector extension not found, installing..."
    
    # Install pgvector from source
    docker exec ${POSTGRES_SERVICE} bash -c "apt-get update && \
      apt-get install -y build-essential git postgresql-server-dev-${POSTGRES_VERSION} && \
      git clone --branch v${PGVECTOR_VERSION} https://github.com/pgvector/pgvector.git && \
      cd pgvector && \
      make && \
      make install"
      
    log_success "${LOG_FILE}" "pgvector extension built and installed successfully"
  else
    log_info "${LOG_FILE}" "pgvector extension already available"
  fi
  
  # Run the SQL script to set up pgvector
  log_info "${LOG_FILE}" "Configuring pgvector databases and permissions"
  docker exec -i ${POSTGRES_SERVICE} psql -U postgres < "${INSTALL_DIR}/scripts/install_pgvector.sql"
  
  # Verify installation
  log_info "${LOG_FILE}" "Verifying pgvector installation"
  local PGVECTOR_VERSION_INSTALLED=$(docker exec ${POSTGRES_SERVICE} psql -U postgres -d ${PGVECTOR_DB_NAME} -c "SELECT extversion FROM pg_extension WHERE extname = 'vector'" -t | tr -d ' ')
  
  if [ -n "${PGVECTOR_VERSION_INSTALLED}" ]; then
    log_success "${LOG_FILE}" "pgvector ${PGVECTOR_VERSION_INSTALLED} installed successfully"
  else
    log_error "${LOG_FILE}" "pgvector installation verification failed"
    exit 1
  fi
}

# Create sample code for integrating with pgvector
create_sample_code() {
  log_info "${LOG_FILE}" "Creating sample code for pgvector integration"
  
  mkdir -p "${INSTALL_DIR}/samples"
  
  # Sample Python script
  cat > "${INSTALL_DIR}/samples/pgvector_example.py" << EOF
#!/usr/bin/env python3
"""
AgencyStack pgvector Example
----------------------------
This script demonstrates how to use pgvector with Python.
"""
import psycopg2
import numpy as np
from sentence_transformers import SentenceTransformer
import os

# Configuration
DB_NAME = "${PGVECTOR_DB_NAME}"
DB_USER = "${PGVECTOR_DB_USER}"
DB_PASS = "${PGVECTOR_DB_PASS}"
DB_HOST = "localhost"
DB_PORT = 5432

# Load a pre-trained model
model = SentenceTransformer('all-MiniLM-L6-v2')

def connect_db():
    """Connect to the PostgreSQL database with pgvector extension."""
    conn = psycopg2.connect(
        dbname=DB_NAME,
        user=DB_USER,
        password=DB_PASS,
        host=DB_HOST,
        port=DB_PORT
    )
    return conn

def add_document(content):
    """Add a document to the vector database."""
    # Generate embedding
    embedding = model.encode(content)
    
    # Connect to database
    conn = connect_db()
    cur = conn.cursor()
    
    # Insert content and embedding
    cur.execute(
        "INSERT INTO vector_test (content, embedding) VALUES (%s, %s)",
        (content, embedding.tolist())
    )
    
    # Commit and close
    conn.commit()
    cur.close()
    conn.close()
    
    print(f"Added document: {content[:50]}...")

def search_similar(query, limit=5):
    """Search for documents similar to the query."""
    # Generate query embedding
    query_embedding = model.encode(query)
    
    # Connect to database
    conn = connect_db()
    cur = conn.cursor()
    
    # Search for similar documents
    cur.execute(
        "SELECT content, embedding <=> %s AS distance FROM vector_test ORDER BY distance LIMIT %s",
        (query_embedding.tolist(), limit)
    )
    
    results = cur.fetchall()
    
    # Close connection
    cur.close()
    conn.close()
    
    return results

def main():
    """Main function to demonstrate pgvector functionality."""
    # Add sample documents
    sample_docs = [
        "AgencyStack provides a comprehensive set of tools for agencies and enterprises.",
        "Vector databases enable semantic search capabilities in applications.",
        "PostgreSQL is a powerful open-source relational database.",
        "The pgvector extension adds vector similarity search to PostgreSQL.",
        "Semantic search finds results based on meaning rather than keywords."
    ]
    
    for doc in sample_docs:
        add_document(doc)
    
    # Perform a search
    query = "How can I implement semantic search?"
    results = search_similar(query)
    
    print(f"Query: {query}")
    print("Results:")
    for i, (content, distance) in enumerate(results):
        print(f"{i+1}. {content} (distance: {distance:.4f})")

if __name__ == "__main__":
    main()
EOF

  chmod +x "${INSTALL_DIR}/samples/pgvector_example.py"
  
  # Create a simple shell script to run the example
  cat > "${INSTALL_DIR}/samples/run_example.sh" << EOF
#!/bin/bash
# Run the pgvector example

# Check if Python and required packages are installed
command -v python3 >/dev/null 2>&1 || { echo "Python 3 is required but not installed. Aborting."; exit 1; }
pip3 install psycopg2-binary numpy sentence-transformers 2>/dev/null

# Run the example
python3 pgvector_example.py
EOF

  chmod +x "${INSTALL_DIR}/samples/run_example.sh"
}

# Create environment file with connection details
create_env_file() {
  log_info "${LOG_FILE}" "Creating environment file with connection details"
  
  cat > "${INSTALL_DIR}/.env" << EOF
# pgvector Configuration
# Generated on $(date)
# AgencyStack Component: pgvector

# PostgreSQL Connection Details
PGVECTOR_DB_NAME=${PGVECTOR_DB_NAME}
PGVECTOR_DB_USER=${PGVECTOR_DB_USER}
PGVECTOR_DB_PASS=${PGVECTOR_DB_PASS}
PGVECTOR_DB_HOST=localhost
PGVECTOR_DB_PORT=5432

# Component Information
PGVECTOR_VERSION=${PGVECTOR_VERSION}
POSTGRES_VERSION=${POSTGRES_VERSION}
CLIENT_ID=${CLIENT_ID}
DOMAIN=${DOMAIN}
ADMIN_EMAIL=${ADMIN_EMAIL}

# Connection string for applications
DATABASE_URL=postgresql://${PGVECTOR_DB_USER}:${PGVECTOR_DB_PASS}@localhost:5432/${PGVECTOR_DB_NAME}
EOF
}

# Register component in the AgencyStack registry
register_component() {
  log_info "${LOG_FILE}" "Registering pgvector component"
  
  # Add to component registry
  local COMPONENT_REGISTRY="/home/revelationx/CascadeProjects/foss-server-stack/config/registry/component_registry.json"
  
  # Check if jq is installed
  if ! command -v jq &> /dev/null; then
    log_error "${LOG_FILE}" "jq is required but not installed"
    exit 1
  }
  
  # Add pgvector to component registry
  if ! grep -q '"pgvector"' "${COMPONENT_REGISTRY}"; then
    log_info "${LOG_FILE}" "Adding pgvector to component registry"
    
    # Create a temporary file with updated registry
    jq '.components.infrastructure.pgvector = {
      "name": "pgvector",
      "category": "Database",
      "version": "'"${PGVECTOR_VERSION}"'",
      "integration_status": {
        "installed": true,
        "hardened": true,
        "makefile": true,
        "sso": false,
        "dashboard": false,
        "logs": true,
        "docs": true,
        "auditable": true,
        "traefik_tls": false,
        "multi_tenant": true
      },
      "description": "Vector database extension for PostgreSQL"
    }' "${COMPONENT_REGISTRY}" > "${COMPONENT_REGISTRY}.tmp"
    
    # Check if jq command was successful
    if [ $? -eq 0 ]; then
      mv "${COMPONENT_REGISTRY}.tmp" "${COMPONENT_REGISTRY}"
      log_success "${LOG_FILE}" "Component registry updated"
    else
      log_error "${LOG_FILE}" "Failed to update component registry"
      rm -f "${COMPONENT_REGISTRY}.tmp"
    fi
  fi
}

# Main installation function
main_install() {
  log_info "${LOG_FILE}" "Starting pgvector installation"
  
  # Check for existing installation
  check_existing
  
  # Set up directory structure
  setup_directories
  
  # Check PostgreSQL installation
  check_postgres
  
  # Install pgvector extension
  install_pgvector
  
  # Create sample code
  create_sample_code
  
  # Create environment file
  create_env_file
  
  # Register component
  register_component
  
  # Mark as installed
  echo "Installed on $(date)" > "${INSTALL_DIR}/.installed"
  echo "${PGVECTOR_VERSION}" > "${INSTALL_DIR}/.version"
  
  log_success "${LOG_FILE}" "pgvector installation completed successfully"
}

# Execute the installation
main_install
