#!/bin/bash

# PeaceFestivalUSA WSL Integration Script
# Following AgencyStack Charter v1.0.3 Principles
# - WSL2/Docker Mount Safety
# - Proper Change Workflow
# - Repository as Source of Truth

# This script assumes it's sourced from main.sh
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "ERROR: This script should be sourced from main.sh"
  exit 1
fi

# Check if we have required variables
if [[ -z "$INSTALL_DIR" || -z "$CLIENT_ID" || -z "$TRAEFIK_DIR" || -z "$WORDPRESS_DIR" ]]; then
  log_error "Missing required variables. This script must be sourced from main.sh"
  return 1
fi

log_info "Setting up WSL integration for ${CLIENT_ID}"

# Detect WSL environment
IS_WSL=false
if grep -q Microsoft /proc/version; then
  IS_WSL=true
  log_info "WSL environment detected"
else
  log_info "Not running in WSL, skipping WSL-specific integration"
  return 0
fi

# Detect Windows host IP from WSL
WINDOWS_HOST_IP=$(cat /etc/resolv.conf | grep nameserver | cut -d " " -f 2)
log_info "Windows Host IP detected: ${WINDOWS_HOST_IP}"

# Create environment.json file
log_info "Creating environment configuration"
cat > "${INSTALL_DIR}/environment.json" << EOL
{
  "isWSL": ${IS_WSL},
  "windowsHostIP": "${WINDOWS_HOST_IP}"
}
EOL

# Create Windows hosts file helper
log_info "Creating hosts file helpers for WSL..."
cat > "${INSTALL_DIR}/add_windows_hosts.sh" << EOL
#!/bin/bash

# Windows hosts file update helper for WSL
# Following AgencyStack Charter v1.0.3 Principles

# Get the Windows hosts file path
WINDOWS_HOSTS_PATH=\$(wslpath -w /mnt/c/Windows/System32/drivers/etc/hosts)

echo "This script will help you add host entries to your Windows hosts file."
echo "You will need administrator privileges in Windows to modify the hosts file."
echo ""
echo "Please open a Windows Command Prompt or PowerShell as Administrator"
echo "Then run the following commands:"
echo ""
echo "echo 127.0.0.1 ${CLIENT_ID}.${DOMAIN} >> \${WINDOWS_HOSTS_PATH}"
echo "echo 127.0.0.1 traefik.${CLIENT_ID}.${DOMAIN} >> \${WINDOWS_HOSTS_PATH}"
echo ""
echo "After running these commands, you should be able to access:"
echo "- WordPress: http://${CLIENT_ID}.${DOMAIN}"
echo "- Traefik Dashboard: http://traefik.${CLIENT_ID}.${DOMAIN}"
EOL
chmod +x "${INSTALL_DIR}/add_windows_hosts.sh"

# Create SQLite wrapper for WSL
log_info "Starting SQLite integration..."
log_info "PHASE 2: SQLITE MCP INTEGRATION FOR WSL/WINDOWS"

# Create SQLite wrapper script
cat > "${INSTALL_DIR}/sqlite_wrapper.sh" << 'EOL'
#!/bin/bash

# SQLite Wrapper for WSL/Windows
# Following AgencyStack Charter v1.0.3 Principles

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DB_DIR="${SCRIPT_DIR}/db"

# Create DB directory if it doesn't exist
mkdir -p "${DB_DIR}"

# Detect environment
if grep -q Microsoft /proc/version; then
  # WSL environment
  if docker info 2>/dev/null | grep -q 'windows'; then
    # Windows Docker needs Windows-style paths
    DB_DIR_WIN="$(wslpath -w "${DB_DIR}")"
    VOLUME_MOUNT="-v ${DB_DIR_WIN}:/mcp"
  else
    # WSL Docker can use Linux paths
    VOLUME_MOUNT="-v ${DB_DIR}:/mcp"
  fi
else
  # Native Linux
  VOLUME_MOUNT="-v ${DB_DIR}:/mcp"
fi

# Run SQLite through MCP container
docker run --rm ${VOLUME_MOUNT} mcp/sqlite "$@"
EOL
chmod +x "${INSTALL_DIR}/sqlite_wrapper.sh"

# Create WSL-specific lessons schema
mkdir -p "${INSTALL_DIR}/db"
cat > "${INSTALL_DIR}/db/wsl_lessons.sql" << EOL
-- WSL Integration Lessons Schema
-- Following AgencyStack Charter v1.0.3 Principles

CREATE TABLE IF NOT EXISTS wsl_lessons (
  id INTEGER PRIMARY KEY,
  category TEXT NOT NULL,
  lesson TEXT NOT NULL,
  solution TEXT NOT NULL,
  timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Insert lessons learned from WSL integration
INSERT INTO wsl_lessons (category, lesson, solution)
VALUES
  ('path_resolution', 'Windows and WSL use different path formats', 'Use wslpath -w for Windows paths and proper volume mounts'),
  ('networking', 'Hostname resolution differs between WSL and Windows host', 'Use IP address from /etc/resolv.conf nameserver entry to access services'),
  ('docker_mounts', 'Docker volume mounts may have inconsistent behavior across environments', 'Use named volumes instead of path-based volumes when possible'),
  ('port_forwarding', 'WSL services may not be automatically accessible from Windows host', 'Use proper port forwarding and update Windows hosts file');
EOL

# Apply the schema
log_info "Applying WSL lessons schema"
cat "${INSTALL_DIR}/db/wsl_lessons.sql" | "${INSTALL_DIR}/sqlite_wrapper.sh"

# Create cross-environment test script
mkdir -p "${INSTALL_DIR}/tests"
cat > "${INSTALL_DIR}/tests/cross_env_test.sh" << 'EOL'
#!/bin/bash

# Cross-Environment Test Script
# Following AgencyStack Charter v1.0.3 Principles

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLIENT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
CLIENT_ID="$(basename "${CLIENT_DIR}")"
DOMAIN="${DOMAIN:-localhost}"
RESULTS_FILE="${SCRIPT_DIR}/cross_env_results.log"

# Check if running in WSL
IS_WSL=false
if grep -q Microsoft /proc/version; then
  IS_WSL=true
  WINDOWS_HOST_IP=$(cat /etc/resolv.conf | grep nameserver | cut -d " " -f 2)
fi

echo "Cross-Environment Test Results - $(date)" > "${RESULTS_FILE}"
echo "=============================================" >> "${RESULTS_FILE}"
echo "Environment: $(if $IS_WSL; then echo "WSL"; else echo "Native Linux"; fi)" >> "${RESULTS_FILE}"
echo "Client ID: ${CLIENT_ID}" >> "${RESULTS_FILE}"
echo "Domain: ${DOMAIN}" >> "${RESULTS_FILE}"
if $IS_WSL; then
  echo "Windows Host IP: ${WINDOWS_HOST_IP}" >> "${RESULTS_FILE}"
fi
echo "=============================================\n" >> "${RESULTS_FILE}"

# Test function
run_test() {
  local name="$1"
  local command="$2"
  local expected_result="$3"
  
  echo "Testing $name..." >> "${RESULTS_FILE}"
  echo "Command: $command" >> "${RESULTS_FILE}"
  
  local result
  result=$($command 2>&1)
  local exit_code=$?
  
  echo "Exit Code: $exit_code" >> "${RESULTS_FILE}"
  echo "Output: $result" >> "${RESULTS_FILE}"
  
  if [[ "$result" == *"$expected_result"* ]]; then
    echo "Result: PASSED" >> "${RESULTS_FILE}"
  else
    echo "Result: FAILED" >> "${RESULTS_FILE}"
    echo "Expected: $expected_result" >> "${RESULTS_FILE}"
  fi
  echo "---------------------------------------------" >> "${RESULTS_FILE}"
}

# WSL-specific tests for Windows access
if $IS_WSL; then
  echo "\nWSL-to-Windows Tests:" >> "${RESULTS_FILE}"
  
  # Test Windows host access
  run_test "Windows Host Access" "curl -s -o /dev/null -w '%{http_code}' http://${WINDOWS_HOST_IP}:80" "200"
  
  # Test Windows hostname resolution
  run_test "Windows Hostname Resolution with Host Header" \
    "curl -s -o /dev/null -w '%{http_code}' -H 'Host: ${CLIENT_ID}.${DOMAIN}' http://${WINDOWS_HOST_IP}:80" "200"
    
  # Test Traefik dashboard access through Windows host
  run_test "Traefik Dashboard through Windows host" \
    "curl -s -o /dev/null -w '%{http_code}' -H 'Host: traefik.${CLIENT_ID}.${DOMAIN}' http://${WINDOWS_HOST_IP}:80" "401"
fi

# Standard tests (work in both environments)
echo "\nStandard Environment Tests:" >> "${RESULTS_FILE}"

# Check if Docker is running
run_test "Docker Running" "docker ps -q" ""

# Check if Traefik container is running
run_test "Traefik Container Running" \
  "docker ps --filter name=${CLIENT_ID}_traefik --format '{{.Status}}'" "Up"

# Check if WordPress container is running
run_test "WordPress Container Running" \
  "docker ps --filter name=${CLIENT_ID}_wordpress --format '{{.Status}}'" "Up"

# Check localhost access
run_test "Local Traefik Access" "curl -s -o /dev/null -w '%{http_code}' http://localhost:80" "200"

# Check localhost WordPress access with host header
run_test "Local WordPress Access" \
  "curl -s -o /dev/null -w '%{http_code}' -H 'Host: ${CLIENT_ID}.${DOMAIN}' http://localhost:80" "200"

echo "\nTest Results Summary: see ${RESULTS_FILE} for details" 

# Display a quick summary
echo "Cross-environment tests completed. See ${RESULTS_FILE} for full results."
EOL
chmod +x "${INSTALL_DIR}/tests/cross_env_test.sh"

# Run cross-environment tests
log_info "Running cross-environment tests"
"${INSTALL_DIR}/tests/cross_env_test.sh"

log_info "WSL integration complete"
