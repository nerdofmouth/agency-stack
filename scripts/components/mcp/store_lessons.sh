#!/bin/bash
# store_lessons.sh - Store deployment lessons in SQLite database
# Following AgencyStack Charter v1.0.3 principles of Repository as Source of Truth,
# Auditability & Documentation, and Proper Change Workflow

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

# Source common utilities if available
if [[ -f "${REPO_ROOT}/scripts/utils/common.sh" ]]; then
  source "${REPO_ROOT}/scripts/utils/common.sh"
else
  # Minimal logging if common.sh is not available
  log_info() { echo "[INFO] $1"; }
  log_error() { echo "[ERROR] $1"; }
  log_success() { echo "[SUCCESS] $1"; }
fi

# Constants
DB_DIR="${REPO_ROOT}/data/mcp"
DB_FILE="${DB_DIR}/lessons.db"
SQL_FILE="${SCRIPT_DIR}/create_lessons_db.sql"
MCP_VOLUME="mcp-lessons"

# Ensure directory exists
mkdir -p "${DB_DIR}"

log_info "Checking if SQLite MCP Docker image exists..."
if ! docker images | grep -q "mcp/sqlite"; then
  log_error "SQLite MCP Docker image not found. Please build it first."
  exit 1
fi

log_info "Creating SQLite database volume if it doesn't exist..."
if ! docker volume ls | grep -q "${MCP_VOLUME}"; then
  docker volume create "${MCP_VOLUME}"
fi

log_info "Creating and populating the lessons database..."
# Create SQLite database using the Docker container
cat "${SQL_FILE}" | docker run --rm -i \
  -v "${MCP_VOLUME}:/mcp" \
  mcp/sqlite --db-path "/mcp/lessons.db"

log_success "Lessons database created and populated successfully!"

log_info "Creating a query script to test the database..."
cat > "${SCRIPT_DIR}/query_lessons.sh" << 'EOF'
#!/bin/bash
# Query the lessons database

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MCP_VOLUME="mcp-lessons"

# Default query - list all lessons with categories and principles
DEFAULT_QUERY="
SELECT 
  l.id, l.title, c.name as category, l.lesson, l.solution, 
  p.name as project, l.date,
  GROUP_CONCAT(cp.name, ', ') as principles
FROM lessons l
JOIN categories c ON l.category_id = c.id
JOIN projects p ON l.project_id = p.id
LEFT JOIN lesson_principles lp ON l.id = lp.lesson_id
LEFT JOIN charter_principles cp ON lp.principle_id = cp.id
GROUP BY l.id
ORDER BY l.id;
"

# Use provided query or default
QUERY="${1:-$DEFAULT_QUERY}"

# Run the query
echo "$QUERY" | docker run --rm -i \
  -v "${MCP_VOLUME}:/mcp" \
  mcp/sqlite --db-path "/mcp/lessons.db" \
  -header -column
EOF

chmod +x "${SCRIPT_DIR}/query_lessons.sh"

log_info "Querying the database to verify contents..."
"${SCRIPT_DIR}/query_lessons.sh"

log_info "Export lessons to JSON..."
# Export query results to JSON
JSON_QUERY="
SELECT json_group_array(
  json_object(
    'id', l.id,
    'title', l.title,
    'category', c.name,
    'lesson', l.lesson,
    'solution', l.solution,
    'project', p.name,
    'date', l.date,
    'principles', (
      SELECT json_group_array(cp.name)
      FROM lesson_principles lp
      JOIN charter_principles cp ON lp.principle_id = cp.id
      WHERE lp.lesson_id = l.id
    )
  )
) as json_output
FROM lessons l
JOIN categories c ON l.category_id = c.id
JOIN projects p ON l.project_id = p.id
ORDER BY l.id;
"

echo "${JSON_QUERY}" | docker run --rm -i \
  -v "${MCP_VOLUME}:/mcp" \
  mcp/sqlite --db-path "/mcp/lessons.db" > "${SCRIPT_DIR}/lessons_export.json"

log_success "Database created and exported successfully!"
log_info "To query the database, run: ${SCRIPT_DIR}/query_lessons.sh"
log_info "JSON export available at: ${SCRIPT_DIR}/lessons_export.json"
