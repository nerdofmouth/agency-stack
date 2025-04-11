#!/bin/bash
# mock_keycloak_idp.sh
#
# This script simulates Keycloak OAuth Identity Provider flows for testing and demonstration
# purposes without requiring actual external OAuth providers.
#
# Part of AgencyStack | Security Components
# 
# Usage:
#   ./mock_keycloak_idp.sh --domain example.com [options]

set -e

# Color codes for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
GRAY='\033[0;37m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
MOCK_DATA_DIR="${SCRIPT_DIR}/data"
LOG_DIR="/var/log/agency_stack"
COMPONENTS_LOG_DIR="${LOG_DIR}/components"
LOG_FILE="${COMPONENTS_LOG_DIR}/keycloak_idp_mock.log"

# Check if log directories are writable, use local paths for development if not
if [ ! -w "$LOG_DIR" ] && [ ! -w "/var/log" ]; then
  LOG_DIR="${ROOT_DIR}/logs"
  COMPONENTS_LOG_DIR="${LOG_DIR}/components"
  LOG_FILE="${COMPONENTS_LOG_DIR}/keycloak_idp_mock.log"
  echo "Notice: Using local log directory for development: ${LOG_DIR}"
fi

# Ensure log directory exists
mkdir -p "$COMPONENTS_LOG_DIR"
touch "$LOG_FILE"

DOMAIN=""
PROVIDER="google"
VERBOSE=false
SLOW_MODE=false
PORT=8899
MOCK_USER_EMAIL="mock.user@example.com"
MOCK_USER_NAME="Mock User"
BROWSER_CMD=""

# Check for installed browsers
if command -v xdg-open &> /dev/null; then
    BROWSER_CMD="xdg-open"
elif command -v google-chrome &> /dev/null; then
    BROWSER_CMD="google-chrome"
elif command -v firefox &> /dev/null; then
    BROWSER_CMD="firefox"
fi

# Log function with timestamp and level
log() {
  local level="$1"
  local message="$2"
  local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  
  case "$level" in
    INFO)
      echo -e "[$timestamp] [INFO] $message" >> "$LOG_FILE"
      if [ "$VERBOSE" = true ]; then
        echo -e "${BLUE}[INFO] $message${NC}"
      fi
      ;;
    WARN)
      echo -e "[$timestamp] [WARNING] $message" >> "$LOG_FILE"
      echo -e "${YELLOW}[WARNING] $message${NC}"
      ;;
    ERROR)
      echo -e "[$timestamp] [ERROR] $message" >> "$LOG_FILE"
      echo -e "${RED}[ERROR] $message${NC}"
      ;;
    SUCCESS)
      echo -e "[$timestamp] [SUCCESS] $message" >> "$LOG_FILE"
      echo -e "${GREEN}[SUCCESS] $message${NC}"
      ;;
    DEBUG)
      echo -e "[$timestamp] [DEBUG] $message" >> "$LOG_FILE"
      if [ "$VERBOSE" = true ]; then
        echo -e "${GRAY}[DEBUG] $message${NC}"
      fi
      ;;
    *)
      echo -e "[$timestamp] $message" >> "$LOG_FILE"
      echo -e "$message"
      ;;
  esac
}

# Print help information
print_help() {
  cat << EOF
${CYAN}${BOLD}Keycloak OAuth Identity Provider Mock Script${NC}

Usage: 
  ./mock_keycloak_idp.sh --domain example.com [options]

Options:
  --domain DOMAIN         Domain for Keycloak (required)
  --provider PROVIDER     OAuth provider to simulate (google, github, apple) 
                         Default: google
  --port PORT             Port to run the mock server on
                         Default: 8899
  --slow-mode             Simulate network latency in responses
  --verbose               Show detailed output
  --help                  Show this help message

Example:
  ./mock_keycloak_idp.sh --domain keycloak.example.com --provider github --verbose

This script simulates OAuth Identity Provider flows for Keycloak testing.
EOF
}

# Process command line arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --domain)
      DOMAIN="$2"
      shift 2
      ;;
    --provider)
      PROVIDER="$2"
      shift 2
      ;;
    --port)
      PORT="$2"
      shift 2
      ;;
    --slow-mode)
      SLOW_MODE=true
      shift
      ;;
    --verbose)
      VERBOSE=true
      shift
      ;;
    --help)
      print_help
      exit 0
      ;;
    *)
      echo -e "${RED}Unknown option: $1${NC}" >&2
      print_help
      exit 1
      ;;
  esac
done

# Check for required arguments
if [ -z "$DOMAIN" ]; then
  echo -e "${RED}Error: --domain is required${NC}" >&2
  print_help
  exit 1
fi

# Validate provider
if [[ "$PROVIDER" != "google" && "$PROVIDER" != "github" && "$PROVIDER" != "apple" ]]; then
  echo -e "${RED}Error: Invalid provider. Must be one of: google, github, apple${NC}" >&2
  print_help
  exit 1
fi

# Check for netcat
if ! command -v nc &> /dev/null; then
  echo -e "${RED}Error: netcat (nc) is not installed. Please install it first:${NC}" >&2
  echo -e "${CYAN}sudo apt-get install netcat${NC}" >&2
  exit 1
fi

# Check for socat (for more advanced HTTP server capabilities)
if ! command -v socat &> /dev/null; then
  echo -e "${YELLOW}Warning: socat is not installed. Some features may be limited.${NC}" >&2
  echo -e "${CYAN}For full functionality, install socat:${NC}" >&2
  echo -e "${CYAN}sudo apt-get install socat${NC}" >&2
fi

# Generate mock data based on provider
generate_mock_data() {
  local provider="$1"
  local data_file="${MOCK_DATA_DIR}/${provider}_mock_data.json"
  
  case "$provider" in
    google)
      cat > "$data_file" << EOF
{
  "provider": "google",
  "id": "mock_google_id_$(date +%s)",
  "email": "${MOCK_USER_EMAIL}",
  "verified_email": true,
  "name": "${MOCK_USER_NAME}",
  "given_name": "Mock",
  "family_name": "User",
  "picture": "https://ui-avatars.com/api/?name=Mock+User&background=0D8ABC&color=fff",
  "locale": "en"
}
EOF
      ;;
    github)
      cat > "$data_file" << EOF
{
  "provider": "github",
  "login": "mockuser",
  "id": $(( 1000000 + RANDOM % 9000000 )),
  "node_id": "MDQ6VXNlcjEyMzQ1Njc=",
  "avatar_url": "https://ui-avatars.com/api/?name=Mock+User&background=171515&color=fff",
  "html_url": "https://github.com/mockuser",
  "name": "${MOCK_USER_NAME}",
  "email": "${MOCK_USER_EMAIL}",
  "bio": "Mock GitHub user for testing",
  "public_repos": $(( RANDOM % 20 )),
  "followers": $(( RANDOM % 100 )),
  "following": $(( RANDOM % 50 ))
}
EOF
      ;;
    apple)
      cat > "$data_file" << EOF
{
  "provider": "apple",
  "sub": "mock.apple.$(date +%s).$(( RANDOM % 9000 + 1000 ))",
  "email": "${MOCK_USER_EMAIL}",
  "email_verified": true,
  "is_private_email": false,
  "name": {
    "firstName": "Mock",
    "lastName": "User"
  }
}
EOF
      ;;
  esac
  
  log "INFO" "Generated mock data for $provider provider"
  if [ "$VERBOSE" = true ]; then
    cat "$data_file"
  fi
}

# Generate mock tokens
generate_mock_tokens() {
  local auth_code="MOCK_AUTH_CODE_$(date +%s)_$(( RANDOM % 900000 + 100000 ))"
  local access_token="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJtb2NrX3VzZXJfaWQiLCJuYW1lIjoiTW9jayBVc2VyIiwiZW1haWwiOiJtb2NrLnVzZXJAZXhhbXBsZS5jb20iLCJwcm92aWRlciI6IiR7UFJPVklERVJ9IiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c"
  local id_token="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJtb2NrX3VzZXJfaWQiLCJuYW1lIjoiTW9jayBVc2VyIiwiZW1haWwiOiJtb2NrLnVzZXJAZXhhbXBsZS5jb20iLCJnaXZlbl9uYW1lIjoiTW9jayIsImZhbWlseV9uYW1lIjoiVXNlciIsInByb3ZpZGVyIjoiJHtQUk9WSURFUn0iLCJpYXQiOjE1MTYyMzkwMjJ9.UXM6sYAw9omtCR-6yRGXMSAZySPPs5Gm7j7MovMQQmA"
  local refresh_token="MOCK_REFRESH_$(date +%s)_$(( RANDOM % 900000 + 100000 ))"
  
  echo "{\"auth_code\":\"$auth_code\",\"access_token\":\"$access_token\",\"id_token\":\"$id_token\",\"refresh_token\":\"$refresh_token\"}"
}

# Simulate provider authorization endpoint
simulate_authorization_endpoint() {
  local redirect_uri="$1"
  local state="$2"
  local tokens=$(generate_mock_tokens)
  local auth_code=$(echo "$tokens" | jq -r '.auth_code')
  
  if [ "$SLOW_MODE" = true ]; then
    log "DEBUG" "Simulating network delay..."
    sleep 2
  fi
  
  log "INFO" "Simulating authorization code grant flow"
  log "DEBUG" "Redirect URI: $redirect_uri"
  log "DEBUG" "State: $state"
  log "DEBUG" "Generated auth code: $auth_code"
  
  # Construct the redirect URL
  local redirect_url="${redirect_uri}?code=${auth_code}&state=${state}"
  
  # Create HTML with automatic redirect
  cat << EOF
HTTP/1.1 200 OK
Content-Type: text/html

<!DOCTYPE html>
<html>
<head>
  <title>${PROVIDER^} OAuth Mock Login</title>
  <meta http-equiv="refresh" content="5; url=${redirect_url}">
  <style>
    body {
      font-family: Arial, sans-serif;
      margin: 40px;
      line-height: 1.6;
      color: #333;
    }
    .container {
      max-width: 600px;
      margin: 0 auto;
      border: 1px solid #ddd;
      padding: 20px;
      border-radius: 5px;
      box-shadow: 0 0 10px rgba(0,0,0,0.1);
    }
    h1 {
      color: #4285f4;
      border-bottom: 1px solid #eee;
      padding-bottom: 10px;
    }
    .provider-logo {
      width: 50px;
      height: 50px;
      float: left;
      margin-right: 20px;
    }
    .btn {
      display: inline-block;
      background-color: #4285f4;
      color: white;
      padding: 10px 20px;
      text-decoration: none;
      border-radius: 5px;
      margin-top: 20px;
    }
    .info {
      background-color: #f8f9fa;
      padding: 10px;
      border-radius: 5px;
      font-family: monospace;
      margin-top: 20px;
    }
    .progress-bar {
      width: 100%;
      background-color: #e0e0e0;
      height: 20px;
      margin-top: 20px;
      border-radius: 10px;
      overflow: hidden;
    }
    .progress {
      width: 0%;
      height: 100%;
      background-color: #4285f4;
      animation: progressAnimation 5s linear;
    }
    @keyframes progressAnimation {
      0% { width: 0%; }
      100% { width: 100%; }
    }
  </style>
</head>
<body>
  <div class="container">
    <h1><img src="https://ui-avatars.com/api/?name=${PROVIDER}&background=4285f4&color=fff" class="provider-logo"> ${PROVIDER^} OAuth Mock Login</h1>
    <p>This page simulates a successful login with ${PROVIDER^} OAuth Identity Provider.</p>
    <p>You will be automatically redirected back to Keycloak in 5 seconds...</p>
    
    <div class="progress-bar">
      <div class="progress"></div>
    </div>
    
    <p>Not redirecting? <a href="${redirect_url}" class="btn">Click here</a></p>
    
    <div class="info">
      <strong>Provider:</strong> ${PROVIDER}<br>
      <strong>User:</strong> ${MOCK_USER_NAME} (${MOCK_USER_EMAIL})<br>
      <strong>Auth Code:</strong> ${auth_code}<br>
      <strong>Redirect URI:</strong> ${redirect_uri}<br>
    </div>
  </div>
  
  <script>
    console.log("Mock ${PROVIDER^} OAuth Login");
    console.log("Auth Code: ${auth_code}");
    console.log("Redirecting to: ${redirect_url}");
    
    // Track this redirection
    setTimeout(function() {
      console.log("Redirecting now...");
      window.location.href = "${redirect_url}";
    }, 5000);
  </script>
</body>
</html>
EOF
}

# Simulate token endpoint
simulate_token_endpoint() {
  local code="$1"
  local tokens=$(generate_mock_tokens)
  local access_token=$(echo "$tokens" | jq -r '.access_token')
  local id_token=$(echo "$tokens" | jq -r '.id_token')
  local refresh_token=$(echo "$tokens" | jq -r '.refresh_token')
  
  if [ "$SLOW_MODE" = true ]; then
    log "DEBUG" "Simulating network delay..."
    sleep 1
  fi
  
  log "INFO" "Simulating token endpoint response"
  log "DEBUG" "Code: $code"
  log "DEBUG" "Generated access token: $access_token"
  
  # Create token response
  cat << EOF
HTTP/1.1 200 OK
Content-Type: application/json

{
  "access_token": "${access_token}",
  "token_type": "Bearer",
  "expires_in": 3600,
  "id_token": "${id_token}",
  "refresh_token": "${refresh_token}"
}
EOF
}

# Simulate userinfo endpoint
simulate_userinfo_endpoint() {
  local token="$1"
  local data_file="${MOCK_DATA_DIR}/${PROVIDER}_mock_data.json"
  
  if [ "$SLOW_MODE" = true ]; then
    log "DEBUG" "Simulating network delay..."
    sleep 1
  fi
  
  log "INFO" "Simulating userinfo endpoint response"
  log "DEBUG" "Token: $token"
  
  # Return user data
  cat << EOF
HTTP/1.1 200 OK
Content-Type: application/json

$(cat "$data_file")
EOF
}

# Configure Keycloak for this mock server
configure_keycloak_for_mock() {
  # This is a placeholder for future enhancement
  # In a full implementation, this would configure Keycloak to use
  # our mock server instead of the real provider
  
  log "INFO" "Keycloak configuration for mock server would happen here"
  log "INFO" "For now, you need to manually configure Keycloak to use http://localhost:${PORT} as endpoints"
}

# Generate the API docs for the mock endpoints
generate_api_docs() {
  cat << EOF
HTTP/1.1 200 OK
Content-Type: text/html

<!DOCTYPE html>
<html>
<head>
  <title>Keycloak OAuth Mock Server</title>
  <style>
    body {
      font-family: Arial, sans-serif;
      margin: 40px;
      line-height: 1.6;
      color: #333;
    }
    .container {
      max-width: 800px;
      margin: 0 auto;
    }
    h1 {
      color: #4285f4;
      border-bottom: 1px solid #eee;
      padding-bottom: 10px;
    }
    h2 {
      color: #5f6368;
      margin-top: 30px;
    }
    code {
      background-color: #f8f9fa;
      padding: 2px 5px;
      border-radius: 3px;
      font-family: monospace;
    }
    pre {
      background-color: #f8f9fa;
      padding: 15px;
      border-radius: 5px;
      overflow-x: auto;
    }
    table {
      border-collapse: collapse;
      width: 100%;
      margin: 20px 0;
    }
    th, td {
      border: 1px solid #ddd;
      padding: 8px;
      text-align: left;
    }
    th {
      background-color: #f8f9fa;
    }
    .method {
      display: inline-block;
      padding: 3px 6px;
      border-radius: 3px;
      color: white;
      font-weight: bold;
      width: 60px;
      text-align: center;
    }
    .get {
      background-color: #4CAF50;
    }
    .post {
      background-color: #2196F3;
    }
  </style>
</head>
<body>
  <div class="container">
    <h1>Keycloak OAuth Mock Server</h1>
    <p>This server simulates OAuth Identity Provider responses for Keycloak testing.</p>
    <p>Currently simulating: <strong>${PROVIDER^}</strong> provider on port <strong>${PORT}</strong></p>
    
    <h2>Available Endpoints</h2>
    
    <table>
      <tr>
        <th>Method</th>
        <th>Endpoint</th>
        <th>Description</th>
      </tr>
      <tr>
        <td><span class="method get">GET</span></td>
        <td><code>/</code></td>
        <td>This documentation</td>
      </tr>
      <tr>
        <td><span class="method get">GET</span></td>
        <td><code>/authorize</code></td>
        <td>Authorization endpoint</td>
      </tr>
      <tr>
        <td><span class="method post">POST</span></td>
        <td><code>/token</code></td>
        <td>Token endpoint</td>
      </tr>
      <tr>
        <td><span class="method get">GET</span></td>
        <td><code>/userinfo</code></td>
        <td>User info endpoint</td>
      </tr>
      <tr>
        <td><span class="method get">GET</span></td>
        <td><code>/.well-known/openid-configuration</code></td>
        <td>OpenID Connect discovery document</td>
      </tr>
    </table>
    
    <h2>Usage with Keycloak</h2>
    
    <p>To use this mock server with Keycloak:</p>
    <ol>
      <li>Configure a new Identity Provider in Keycloak</li>
      <li>Use <code>http://localhost:${PORT}</code> as the base URL</li>
      <li>Set the following endpoints in the provider configuration:
        <ul>
          <li>Authorization URL: <code>http://localhost:${PORT}/authorize</code></li>
          <li>Token URL: <code>http://localhost:${PORT}/token</code></li>
          <li>User Info URL: <code>http://localhost:${PORT}/userinfo</code></li>
        </ul>
      </li>
      <li>Use any Client ID and Client Secret (they will be ignored)</li>
    </ol>
    
    <h2>Sample Request</h2>
    
    <h3>Authorization Request</h3>
    <pre>GET /authorize?client_id=test&redirect_uri=http://localhost/callback&response_type=code&scope=openid%20profile%20email&state=abc123</pre>
    
    <h3>Token Request</h3>
    <pre>POST /token
Content-Type: application/x-www-form-urlencoded

grant_type=authorization_code&code=MOCK_AUTH_CODE_123&redirect_uri=http://localhost/callback&client_id=test&client_secret=test</pre>
    
    <h3>User Info Request</h3>
    <pre>GET /userinfo
Authorization: Bearer MOCK_ACCESS_TOKEN_123</pre>
    
    <h2>Mock User Details</h2>
    
    <p>The mock server will always return the following user:</p>
    <pre>${MOCK_USER_NAME} (${MOCK_USER_EMAIL})</pre>
    
    <p>
      <small>Running in: <code>${SCRIPT_DIR}</code></small><br>
      <small>Log file: <code>${LOG_FILE}</code></small>
    </p>
  </div>
</body>
</html>
EOF
}

# Generate OpenID Connect discovery document
generate_discovery_document() {
  cat << EOF
HTTP/1.1 200 OK
Content-Type: application/json

{
  "issuer": "http://localhost:${PORT}",
  "authorization_endpoint": "http://localhost:${PORT}/authorize",
  "token_endpoint": "http://localhost:${PORT}/token",
  "userinfo_endpoint": "http://localhost:${PORT}/userinfo",
  "jwks_uri": "http://localhost:${PORT}/jwks",
  "response_types_supported": ["code", "token", "id_token", "code token", "code id_token", "token id_token", "code token id_token"],
  "subject_types_supported": ["public"],
  "id_token_signing_alg_values_supported": ["RS256"],
  "scopes_supported": ["openid", "profile", "email"],
  "token_endpoint_auth_methods_supported": ["client_secret_basic", "client_secret_post"],
  "claims_supported": ["sub", "iss", "name", "email", "given_name", "family_name", "picture"]
}
EOF
}

# Run a simple HTTP server to handle requests
run_http_server() {
  log "INFO" "Starting mock OAuth server for ${PROVIDER} on port ${PORT}"
  log "INFO" "Log file: ${LOG_FILE}"
  
  # Generate mock data for the provider
  generate_mock_data "$PROVIDER"
  
  # Open the documentation in a browser if possible
  if [ -n "$BROWSER_CMD" ]; then
    log "INFO" "Opening documentation in browser..."
    $BROWSER_CMD "http://localhost:${PORT}" &> /dev/null &
  fi
  
  echo -e "${GREEN}${BOLD}Keycloak OAuth Mock Server Started${NC}"
  echo -e "Provider: ${CYAN}${PROVIDER}${NC}"
  echo -e "Port: ${CYAN}${PORT}${NC}"
  echo -e "Visit ${CYAN}http://localhost:${PORT}${NC} for API documentation"
  echo -e "\nPress Ctrl+C to stop the server\n"
  
  # Use socat if available for better HTTP parsing, otherwise fall back to netcat
  if command -v socat &> /dev/null; then
    while true; do
      socat TCP-LISTEN:${PORT},fork,reuseaddr EXEC:"bash -c \"read -r request; echo \\\"\$request\\\" >> ${LOG_FILE}; if echo \\\"\$request\\\" | grep -q \\\"GET / HTTP\\\"; then generate_api_docs; elif echo \\\"\$request\\\" | grep -q \\\"GET /authorize\\\"; then simulate_authorization_endpoint \\\"http://localhost/callback\\\" \\\"state123\\\"; elif echo \\\"\$request\\\" | grep -q \\\"POST /token\\\"; then simulate_token_endpoint \\\"MOCK_CODE\\\"; elif echo \\\"\$request\\\" | grep -q \\\"GET /userinfo\\\"; then simulate_userinfo_endpoint \\\"MOCK_TOKEN\\\"; elif echo \\\"\$request\\\" | grep -q \\\"GET /.well-known/openid-configuration\\\"; then generate_discovery_document; else echo -e \\\"HTTP/1.1 404 Not Found\\\\r\\\\nContent-Type: text/plain\\\\r\\\\n\\\\r\\\\n404 Not Found\\\"; fi\""
    done
  else
    # Simple netcat server - less capable but works without socat
    while true; do
      echo -e "${GRAY}Waiting for connection...${NC}"
      nc -l -p ${PORT} < <(
        read -r request
        echo "$request" >> "${LOG_FILE}"
        log "DEBUG" "Received request: $request"
        
        if echo "$request" | grep -q "GET / HTTP"; then
          log "INFO" "Serving API documentation"
          generate_api_docs
        elif echo "$request" | grep -q "GET /authorize"; then
          log "INFO" "Received authorization request"
          redirect_uri=$(echo "$request" | grep -o 'redirect_uri=[^&]*' | cut -d= -f2-)
          state=$(echo "$request" | grep -o 'state=[^&]*' | cut -d= -f2-)
          # URL decode the redirect_uri
          redirect_uri=$(echo "$redirect_uri" | sed 's/%3A/:/g' | sed 's/%2F/\//g')
          simulate_authorization_endpoint "$redirect_uri" "$state"
        elif echo "$request" | grep -q "POST /token"; then
          log "INFO" "Received token request"
          code=$(echo "$request" | grep -o 'code=[^&]*' | cut -d= -f2-)
          simulate_token_endpoint "$code"
        elif echo "$request" | grep -q "GET /userinfo"; then
          log "INFO" "Received userinfo request"
          auth_header=$(echo "$request" | grep -i 'Authorization:' | cut -d' ' -f3-)
          simulate_userinfo_endpoint "$auth_header"
        elif echo "$request" | grep -q "GET /.well-known/openid-configuration"; then
          log "INFO" "Received discovery document request"
          generate_discovery_document
        else
          log "WARN" "Unknown request: $request"
          echo -e "HTTP/1.1 404 Not Found\r\nContent-Type: text/plain\r\n\r\n404 Not Found: Unknown endpoint"
        fi
      )
    done
  fi
}

# Main execution
run_http_server
