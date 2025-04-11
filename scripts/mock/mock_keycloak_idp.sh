#!/bin/bash
# mock_keycloak_idp.sh - Mock Keycloak Identity Provider flows
# https://stack.nerdofmouth.com
#
# This script simulates OAuth login flows for Keycloak Identity Providers
# for testing and demonstration purposes.
#
# Author: AgencyStack Team
# Version: 1.0.0
# Created: $(date +%Y-%m-%d)

# Colors
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
LOG_DIR="/var/log/agency_stack"
MOCK_LOG_DIR="${LOG_DIR}/mock"
LOG_FILE="${MOCK_LOG_DIR}/keycloak_idp_mock.log"
DOMAIN=""
CLIENT_ID=""
PROVIDER=""
REALM="agency"
MOCK_USER_EMAIL=""
MOCK_USER_NAME=""
MOCK_SERVER_PORT=8088
OUTPUT_HTML=""

# Ensure log directory exists
mkdir -p "$MOCK_LOG_DIR"
touch "$LOG_FILE"

# Log function
log() {
  local message="$1"
  local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  echo -e "[$timestamp] $message" >> "$LOG_FILE"
  echo -e "$message"
}

# Show help message
show_help() {
  echo -e "${MAGENTA}${BOLD}AgencyStack Keycloak IdP Mock${NC}"
  echo -e "================================="
  echo -e "This script simulates OAuth login flows for testing and demonstration."
  echo -e ""
  echo -e "${CYAN}Usage:${NC}"
  echo -e "  $0 [options]"
  echo -e ""
  echo -e "${CYAN}Options:${NC}"
  echo -e "  ${BOLD}--domain${NC} <domain>       Keycloak domain (required)"
  echo -e "  ${BOLD}--client-id${NC} <client_id> Client ID for multi-tenant setup (optional)"
  echo -e "  ${BOLD}--provider${NC} <provider>   OAuth provider to simulate (google, github, apple)"
  echo -e "  ${BOLD}--realm${NC} <realm>         Keycloak realm (default: agency)"
  echo -e "  ${BOLD}--user-email${NC} <email>    Mock user email (default: mock.user@example.com)"
  echo -e "  ${BOLD}--user-name${NC} <name>      Mock user name (default: Mock User)"
  echo -e "  ${BOLD}--output${NC} <path>         Path to output HTML file (optional)"
  echo -e "  ${BOLD}--help${NC}                  Show this help message and exit"
  echo -e ""
  echo -e "${CYAN}Example:${NC}"
  echo -e "  $0 --domain auth.example.com --provider google --realm agency"
  exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    --domain)
      DOMAIN="$2"
      shift
      shift
      ;;
    --client-id)
      CLIENT_ID="$2"
      shift
      shift
      ;;
    --provider)
      PROVIDER="$2"
      shift
      shift
      ;;
    --realm)
      REALM="$2"
      shift
      shift
      ;;
    --user-email)
      MOCK_USER_EMAIL="$2"
      shift
      shift
      ;;
    --user-name)
      MOCK_USER_NAME="$2"
      shift
      shift
      ;;
    --output)
      OUTPUT_HTML="$2"
      shift
      shift
      ;;
    --help|-h)
      show_help
      ;;
    *)
      echo -e "${RED}Unknown option: $key${NC}"
      echo -e "Use --help for usage information"
      exit 1
      ;;
  esac
done

# Check required parameters
if [ -z "$DOMAIN" ]; then
  echo -e "${RED}Error: --domain is required${NC}"
  echo -e "Use --help for usage information"
  exit 1
fi

if [ -z "$PROVIDER" ]; then
  echo -e "${RED}Error: --provider is required${NC}"
  echo -e "Use --help for usage information"
  exit 1
fi

# Set default values
if [ -n "$CLIENT_ID" ]; then
  REALM="$CLIENT_ID"
fi

if [ -z "$MOCK_USER_EMAIL" ]; then
  MOCK_USER_EMAIL="mock.user@example.com"
fi

if [ -z "$MOCK_USER_NAME" ]; then
  MOCK_USER_NAME="Mock User"
fi

# Validate provider
case "$PROVIDER" in
  google|github|apple)
    # Valid provider
    ;;
  *)
    echo -e "${RED}Error: Invalid provider '$PROVIDER'${NC}"
    echo -e "Valid providers: google, github, apple"
    exit 1
    ;;
esac

# Welcome message
echo -e "${MAGENTA}${BOLD}Keycloak Identity Provider Mock${NC}"
echo -e "===================================="
echo -e "Domain: ${CYAN}${DOMAIN}${NC}"
echo -e "Realm: ${CYAN}${REALM}${NC}"
echo -e "Provider: ${CYAN}${PROVIDER}${NC}"
echo -e "Mock User: ${CYAN}${MOCK_USER_NAME} (${MOCK_USER_EMAIL})${NC}"
echo

# Generate provider-specific content
generate_provider_content() {
  case "$PROVIDER" in
    google)
      PROVIDER_COLOR="#4285F4"
      PROVIDER_LOGO='<svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="#fff"><path d="M12.24 10.285V14.4h6.806c-.275 1.765-2.056 5.174-6.806 5.174-4.095 0-7.439-3.389-7.439-7.574s3.345-7.574 7.439-7.574c2.33 0 3.891.989 4.785 1.849l3.254-3.138C18.189 1.186 15.479 0 12.24 0c-6.635 0-12 5.365-12 12s5.365 12 12 12c6.926 0 11.52-4.869 11.52-11.726 0-.788-.085-1.39-.189-1.989H12.24z"/></svg>'
      OAUTH_LOGO_HTML="<div style=\"background-color: ${PROVIDER_COLOR}; border-radius: 2px; padding: 10px; display: inline-flex; align-items: center;\">${PROVIDER_LOGO} <span style=\"margin-left: 10px; color: white; font-weight: 500;\">Sign in with Google</span></div>"
      ;;
    github)
      PROVIDER_COLOR="#24292e"
      PROVIDER_LOGO='<svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="#fff"><path d="M12 0c-6.626 0-12 5.373-12 12 0 5.302 3.438 9.8 8.207 11.387.599.111.793-.261.793-.577v-2.234c-3.338.726-4.033-1.416-4.033-1.416-.546-1.387-1.333-1.756-1.333-1.756-1.089-.745.083-.729.083-.729 1.205.084 1.839 1.237 1.839 1.237 1.07 1.834 2.807 1.304 3.492.997.107-.775.418-1.305.762-1.604-2.665-.305-5.467-1.334-5.467-5.931 0-1.311.469-2.381 1.236-3.221-.124-.303-.535-1.524.117-3.176 0 0 1.008-.322 3.301 1.23.957-.266 1.983-.399 3.003-.404 1.02.005 2.047.138 3.006.404 2.291-1.552 3.297-1.23 3.297-1.23.653 1.653.242 2.874.118 3.176.77.84 1.235 1.911 1.235 3.221 0 4.609-2.807 5.624-5.479 5.921.43.372.823 1.102.823 2.222v3.293c0 .319.192.694.801.576 4.765-1.589 8.199-6.086 8.199-11.386 0-6.627-5.373-12-12-12z"/></svg>'
      OAUTH_LOGO_HTML="<div style=\"background-color: ${PROVIDER_COLOR}; border-radius: 6px; padding: 10px; display: inline-flex; align-items: center;\">${PROVIDER_LOGO} <span style=\"margin-left: 10px; color: white; font-weight: 500;\">Sign in with GitHub</span></div>"
      ;;
    apple)
      PROVIDER_COLOR="#000000"
      PROVIDER_LOGO='<svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="#fff"><path d="M22.5 12.5c0-1.58-.875-2.95-2.148-3.6.154-.435.238-.905.238-1.4 0-2.21-1.71-3.998-3.818-3.998-.47 0-.92.084-1.336.25C14.818 2.415 13.51 1.5 12 1.5s-2.816.917-3.437 2.25c-.415-.165-.866-.25-1.336-.25-2.11 0-3.818 1.79-3.818 4 0 .494.083.964.237 1.4-1.272.65-2.147 2.018-2.147 3.6 0 1.495.782 2.798 1.942 3.486-.02.17-.032.34-.032.514 0 2.21 1.708 4 3.818 4 .47 0 .92-.086 1.335-.25.62 1.334 1.926 2.25 3.437 2.25 1.512 0 2.818-.916 3.437-2.25.415.163.865.248 1.336.248 2.11 0 3.818-1.79 3.818-4 0-.174-.012-.344-.033-.513 1.158-.687 1.943-1.99 1.943-3.484zm-6.616-3.334l-4.334 4.316-2.18-2.16-1.485 1.486 3.65 3.663 5.816-5.81-1.466-1.483z"/></svg>'
      OAUTH_LOGO_HTML="<div style=\"background-color: ${PROVIDER_COLOR}; border-radius: 6px; padding: 10px; display: inline-flex; align-items: center;\">${PROVIDER_LOGO} <span style=\"margin-left: 10px; color: white; font-weight: 500;\">Sign in with Apple</span></div>"
      ;;
  esac
}

# Generate HTML for the mock login flow
generate_html() {
  # Get provider-specific content
  generate_provider_content
  
  # Create HTML file
  HTML_CONTENT=$(cat <<EOF
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>AgencyStack - Mock Keycloak IdP Login</title>
  <style>
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Oxygen-Sans, Ubuntu, Cantarell, "Helvetica Neue", sans-serif;
      margin: 0;
      padding: 0;
      background-color: #f5f5f5;
      color: #333;
    }
    .container {
      max-width: 600px;
      margin: 50px auto;
      padding: 20px;
      background-color: white;
      border-radius: 8px;
      box-shadow: 0 2px 10px rgba(0,0,0,0.1);
    }
    h1 {
      color: #4a4a4a;
      text-align: center;
      margin-bottom: 30px;
    }
    .header {
      text-align: center;
      margin-bottom: 20px;
    }
    .header img {
      max-width: 200px;
      margin-bottom: 20px;
    }
    .login-container {
      text-align: center;
    }
    .auth-flow {
      margin-top: 30px;
      padding: 20px;
      border: 1px solid #e0e0e0;
      border-radius: 5px;
      background-color: #fafafa;
    }
    .auth-flow h3 {
      margin-top: 0;
    }
    .auth-step {
      text-align: left;
      margin: 15px 0;
      padding: 10px;
      border-left: 3px solid #2196F3;
      background-color: #f0f8ff;
    }
    .auth-step.error {
      border-left-color: #f44336;
      background-color: #ffebee;
    }
    .auth-step.success {
      border-left-color: #4CAF50;
      background-color: #e8f5e9;
    }
    .auth-step pre {
      margin: 10px 0;
      padding: 10px;
      background-color: #f5f5f5;
      border-radius: 4px;
      overflow-x: auto;
    }
    .log-output {
      margin-top: 20px;
      height: 200px;
      overflow-y: auto;
      padding: 10px;
      background-color: #2b2b2b;
      color: #f0f0f0;
      font-family: monospace;
      border-radius: 4px;
    }
    .button {
      display: inline-block;
      padding: 10px 20px;
      margin: 10px 5px;
      background-color: #2196F3;
      color: white;
      border: none;
      border-radius: 4px;
      cursor: pointer;
      text-decoration: none;
      font-weight: 500;
    }
    .button:hover {
      background-color: #0b7dda;
    }
    .button.success {
      background-color: #4CAF50;
    }
    .button.success:hover {
      background-color: #45a049;
    }
    .button.error {
      background-color: #f44336;
    }
    .button.error:hover {
      background-color: #d32f2f;
    }
    .profile-card {
      margin-top: 30px;
      text-align: center;
      padding: 20px;
      border: 1px solid #e0e0e0;
      border-radius: 5px;
      background-color: white;
      box-shadow: 0 2px 5px rgba(0,0,0,0.05);
    }
    .profile-card img {
      width: 80px;
      height: 80px;
      border-radius: 50%;
      margin-bottom: 15px;
    }
    .profile-card .name {
      font-size: 1.2em;
      font-weight: bold;
      margin-bottom: 5px;
    }
    .profile-card .email {
      color: #666;
      margin-bottom: 15px;
    }
    .token {
      font-family: monospace;
      word-break: break-all;
      background-color: #f5f5f5;
      padding: 10px;
      border-radius: 5px;
      margin: 10px 0;
      text-align: left;
      max-height: 100px;
      overflow-y: auto;
    }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>AgencyStack Mock OAuth</h1>
      <p>Simulating <strong>${PROVIDER}</strong> login flow for Keycloak</p>
    </div>
    
    <div class="login-container">
      <p>Click the button below to simulate logging in with ${PROVIDER}:</p>
      <div id="oauth-button">
        ${OAUTH_LOGO_HTML}
      </div>
      
      <div class="auth-flow" id="auth-flow" style="display: none;">
        <h3>Authentication Flow</h3>
        <div class="auth-step" id="step1">
          <strong>Step 1:</strong> User initiates login with ${PROVIDER}
        </div>
        <div class="auth-step" id="step2" style="display: none;">
          <strong>Step 2:</strong> Redirect to ${PROVIDER} login
          <pre>GET https://${PROVIDER}.com/auth?client_id=[MOCK_CLIENT_ID]&redirect_uri=https://${DOMAIN}/auth/realms/${REALM}/broker/${PROVIDER}/endpoint</pre>
        </div>
        <div class="auth-step" id="step3" style="display: none;">
          <strong>Step 3:</strong> User authenticates with ${PROVIDER}
        </div>
        <div class="auth-step" id="step4" style="display: none;">
          <strong>Step 4:</strong> ${PROVIDER} sends authorization code to Keycloak
          <pre>POST https://${DOMAIN}/auth/realms/${REALM}/broker/${PROVIDER}/endpoint
code=[MOCK_AUTH_CODE]</pre>
        </div>
        <div class="auth-step" id="step5" style="display: none;">
          <strong>Step 5:</strong> Keycloak exchanges code for tokens with ${PROVIDER}
          <pre>POST https://${PROVIDER}.com/oauth/token
client_id=[MOCK_CLIENT_ID]
client_secret=[MOCK_CLIENT_SECRET]
code=[MOCK_AUTH_CODE]
grant_type=authorization_code</pre>
        </div>
        <div class="auth-step" id="step6" style="display: none;">
          <strong>Step 6:</strong> Keycloak receives user info from ${PROVIDER}
        </div>
        <div class="auth-step success" id="step7" style="display: none;">
          <strong>Success:</strong> User logged in via ${PROVIDER}
        </div>
        
        <div class="profile-card" id="profile-card" style="display: none;">
          <img src="data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIyNCIgaGVpZ2h0PSIyNCIgdmlld0JveD0iMCAwIDI0IDI0IiBmaWxsPSJub25lIiBzdHJva2U9IiM0YTRhNGEiIHN0cm9rZS13aWR0aD0iMiIgc3Ryb2tlLWxpbmVjYXA9InJvdW5kIiBzdHJva2UtbGluZWpvaW49InJvdW5kIj48cGF0aCBkPSJNMjAgMjF2LTJhNCA0IDAgMCAwLTQtNEg4YTQgNCAwIDAgMC00IDR2MiI+PC9wYXRoPjxjaXJjbGUgY3g9IjEyIiBjeT0iNyIgcj0iNCIgZmlsbD0iI2UwZTBlMCI+PC9jaXJjbGU+PC9zdmc+" alt="User Avatar">
          <div class="name">${MOCK_USER_NAME}</div>
          <div class="email">${MOCK_USER_EMAIL}</div>
          <div style="text-align: left;"><strong>ID Token:</strong></div>
          <div class="token" id="id-token">eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiZW1haWwiOiJqb2huQGV4YW1wbGUuY29tIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c</div>
        </div>
        
        <div class="log-output" id="log-output">
          > Starting mock authentication flow for ${PROVIDER}...
        </div>
        
        <button id="reset-btn" class="button" style="display: none;">Reset Simulation</button>
      </div>
    </div>
  </div>

  <script>
    const mockFlow = () => {
      const logOutput = document.getElementById('log-output');
      const authFlow = document.getElementById('auth-flow');
      const oauthButton = document.getElementById('oauth-button');
      const resetBtn = document.getElementById('reset-btn');
      const profileCard = document.getElementById('profile-card');
      const idToken = document.getElementById('id-token');
      
      let currentStep = 1;
      
      const addLog = (message) => {
        logOutput.innerHTML += \`<br>> \${message}\`;
        logOutput.scrollTop = logOutput.scrollHeight;
      };
      
      const showStep = (step) => {
        document.getElementById(\`step\${step}\`).style.display = 'block';
      };
      
      const simulateFlow = () => {
        authFlow.style.display = 'block';
        oauthButton.style.cursor = 'default';
        oauthButton.style.opacity = '0.7';
        oauthButton.onclick = null;
        
        setTimeout(() => {
          currentStep = 2;
          showStep(2);
          addLog("Redirecting to ${PROVIDER} login page...");
          
          setTimeout(() => {
            currentStep = 3;
            showStep(3);
            addLog("User authenticated with ${PROVIDER}");
            
            setTimeout(() => {
              currentStep = 4;
              showStep(4);
              addLog("Received authorization code: MOCK_AUTH_CODE_${Math.random().toString(36).substring(2, 10)}");
              
              setTimeout(() => {
                currentStep = 5;
                showStep(5);
                addLog("Keycloak exchanging code for tokens...");
                
                setTimeout(() => {
                  currentStep = 6;
                  showStep(6);
                  addLog("Received user profile from ${PROVIDER}");
                  addLog(\`Name: ${MOCK_USER_NAME}\`);
                  addLog(\`Email: ${MOCK_USER_EMAIL}\`);
                  
                  setTimeout(() => {
                    currentStep = 7;
                    showStep(7);
                    addLog("Authentication successful!");
                    addLog("User logged in via ${PROVIDER}");
                    
                    // Generate mock ID token with user info
                    const header = btoa(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
                    const payload = btoa(JSON.stringify({ 
                      sub: '123456' + Math.floor(Math.random() * 1000), 
                      name: '${MOCK_USER_NAME}', 
                      email: '${MOCK_USER_EMAIL}',
                      iss: 'https://${DOMAIN}/auth/realms/${REALM}',
                      aud: 'account',
                      exp: Math.floor(Date.now() / 1000) + 3600,
                      iat: Math.floor(Date.now() / 1000),
                      auth_time: Math.floor(Date.now() / 1000) - 60,
                      azp: 'account-console',
                      nonce: Math.random().toString(36).substring(2, 15)
                    }));
                    const signature = btoa('MOCK_SIGNATURE');
                    const mockToken = \`\${header}.\${payload}.\${signature}\`;
                    
                    idToken.textContent = mockToken;
                    profileCard.style.display = 'block';
                    resetBtn.style.display = 'inline-block';
                  }, 1000);
                }, 1000);
              }, 1000);
            }, 1000);
          }, 1000);
        }, 1000);
      };
      
      resetBtn.onclick = () => {
        // Reset the simulation
        for (let i = 2; i <= 7; i++) {
          document.getElementById(\`step\${i}\`).style.display = 'none';
        }
        authFlow.style.display = 'none';
        profileCard.style.display = 'none';
        resetBtn.style.display = 'none';
        oauthButton.style.cursor = 'pointer';
        oauthButton.style.opacity = '1';
        oauthButton.onclick = simulateFlow;
        logOutput.innerHTML = "> Starting mock authentication flow for ${PROVIDER}...";
        currentStep = 1;
      };
      
      // Initialize
      oauthButton.onclick = simulateFlow;
    };
    
    // Start the mock flow when the page loads
    document.addEventListener('DOMContentLoaded', mockFlow);
  </script>
</body>
</html>
EOF
)

  # Output the HTML to file or return it
  if [ -n "$OUTPUT_HTML" ]; then
    echo "$HTML_CONTENT" > "$OUTPUT_HTML"
    echo -e "${GREEN}Output HTML saved to: ${OUTPUT_HTML}${NC}"
  else
    # Create a temporary file
    TEMP_HTML_FILE=$(mktemp --suffix=.html)
    echo "$HTML_CONTENT" > "$TEMP_HTML_FILE"
    echo -e "${GREEN}HTML saved to temporary file: ${TEMP_HTML_FILE}${NC}"
    echo -e "${YELLOW}This file will be deleted when the script exits${NC}"
    
    # Start a temporary web server
    start_mock_server "$TEMP_HTML_FILE"
    
    # Clean up temp file on exit
    trap 'rm -f "$TEMP_HTML_FILE"' EXIT
  fi
}

# Start a mock web server to display the HTML
start_mock_server() {
  local html_file="$1"
  
  echo -e "${CYAN}Starting mock web server on port ${MOCK_SERVER_PORT}...${NC}"
  
  # Check if python is available
  if command -v python3 &> /dev/null; then
    # Python 3
    echo -e "${GREEN}Using Python 3 to serve the mock page${NC}"
    echo -e "${BLUE}Visit: http://localhost:${MOCK_SERVER_PORT} in your browser${NC}"
    echo -e "${YELLOW}Press Ctrl+C to stop the server${NC}"
    echo
    
    # Start the server
    (cd "$(dirname "$html_file")" && python3 -m http.server "$MOCK_SERVER_PORT") &
    SERVER_PID=$!
    
    # Wait for server to start
    sleep 1
    
    # Open the browser if xdg-open is available
    if command -v xdg-open &> /dev/null; then
      xdg-open "http://localhost:${MOCK_SERVER_PORT}/$(basename "$html_file")"
    elif command -v open &> /dev/null; then
      open "http://localhost:${MOCK_SERVER_PORT}/$(basename "$html_file")"
    else
      echo -e "${YELLOW}Unable to open browser automatically. Please open this URL:${NC}"
      echo -e "${CYAN}http://localhost:${MOCK_SERVER_PORT}/$(basename "$html_file")${NC}"
    fi
    
    # Wait for user to press Ctrl+C
    echo -e "${YELLOW}Press Enter to stop the server...${NC}"
    read -r
    
    # Kill the server
    kill $SERVER_PID 2>/dev/null
  else
    echo -e "${RED}Python 3 is not installed. Unable to start mock server.${NC}"
    echo -e "${YELLOW}You can view the HTML file directly:${NC}"
    echo -e "${CYAN}${html_file}${NC}"
  fi
}

# Generate the mock login flow
generate_html

exit 0
