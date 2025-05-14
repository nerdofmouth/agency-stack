#!/bin/bash

# Simple PeaceFestivalUSA Lessons Import Script
# Following AgencyStack Charter v1.0.3 Principles

set -e

# Script location 
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MCP_DIR="${SCRIPT_DIR}"

echo "[INFO] Starting PeaceFestivalUSA lesson import"

# Create MCP database directory if it doesn't exist
mkdir -p "${MCP_DIR}/data"

# Ensure MCP SQLite container is available
echo "[INFO] Checking for SQLite image..."
if ! docker images | grep -q "mcp/sqlite"; then
  echo "[ERROR] mcp/sqlite image not found"
  exit 1
fi

# Import schema and lessons into SQLite
echo "[INFO] Importing PeaceFestivalUSA lessons into SQLite..."
docker run --rm -v "${MCP_DIR}:/mcp" mcp/sqlite /bin/sh -c \
  "cat /mcp/peacefestivalusa_lessons.sql | sqlite3 /mcp/data/agency_lessons.db"

# Verify import
echo "[INFO] Verifying lesson import..."
LESSON_COUNT=$(docker run --rm -v "${MCP_DIR}:/mcp" mcp/sqlite \
  sqlite3 /mcp/data/agency_lessons.db "SELECT COUNT(*) FROM deployment_lessons;")

echo "[INFO] Found ${LESSON_COUNT} lessons in database"

# Sample some lessons
echo "[INFO] Sample lessons:"
docker run --rm -v "${MCP_DIR}:/mcp" mcp/sqlite \
  sqlite3 -column -header /mcp/data/agency_lessons.db \
  "SELECT component, issue_context, substr(lesson, 1, 50) || '...' FROM deployment_lessons LIMIT 3;"

echo "[SUCCESS] PeaceFestivalUSA lessons successfully imported to SQLite"
