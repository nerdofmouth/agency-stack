#!/bin/bash

# PeaceFestivalUSA Lessons Import Script
# Following AgencyStack Charter v1.0.3 Principles
# - Repository as Source of Truth
# - Component Consistency
# - Auditability & Documentation

set -e

# Script location and common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MCP_DIR="${SCRIPT_DIR}"
COMPONENTS_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${COMPONENTS_DIR}/.." && pwd)"

# Source common utilities
if [[ -f "${REPO_ROOT}/scripts/utils/common.sh" ]]; then
  source "${REPO_ROOT}/scripts/utils/common.sh"
else
  echo "ERROR: Could not find common.sh"
  exit 1
fi

# Ensure MCP SQLite container is running
ensure_mcp_running() {
  if ! docker ps --filter "ancestor=mcp/sqlite" --format "{{.Names}}" | grep -q .; then
    log_info "Starting MCP SQLite container..."
    docker run -d --name mcp_sqlite -v "${REPO_ROOT}/data/mcp:/data" mcp/sqlite
    sleep 2
  else
    log_info "MCP SQLite container is already running"
  fi
}

# Import schema and lessons into SQLite
import_lessons() {
  log_info "Importing PeaceFestivalUSA lessons into MCP SQLite..."
  
  # Create a temporary container to execute SQL
  docker run --rm -v "${MCP_DIR}:/mcp" mcp/sqlite /bin/sh -c \
    "cat /mcp/peacefestivalusa_lessons.sql | sqlite3 /mcp/agency_lessons.db"
  
  log_info "Lessons successfully imported into SQLite database"
}

# Verify import
verify_import() {
  log_info "Verifying lesson import..."
  
  # Count lessons in database
  LESSON_COUNT=$(docker run --rm -v "${MCP_DIR}:/mcp" mcp/sqlite \
    sqlite3 /mcp/agency_lessons.db "SELECT COUNT(*) FROM deployment_lessons;")
  
  log_info "Found ${LESSON_COUNT} lessons in database"
  
  # Sample some lessons
  log_info "Sample lessons:"
  docker run --rm -v "${MCP_DIR}:/mcp" mcp/sqlite \
    sqlite3 -column -header /mcp/agency_lessons.db \
    "SELECT component, issue_context, substr(lesson, 1, 50) || '...' FROM deployment_lessons LIMIT 3;"
}

# Main execution flow
log_info "Starting PeaceFestivalUSA lesson import"

# Create SQLite database directory
mkdir -p "${MCP_DIR}/data"

# Run import process
ensure_mcp_running
import_lessons
verify_import

log_info "PeaceFestivalUSA lessons successfully imported to SQLite"
