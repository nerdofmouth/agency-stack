#!/bin/bash

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/../utils/common.sh" ]]; then
  source "${SCRIPT_DIR}/../utils/common.sh"
fi

# Enforce containerization (prevent host contamination)
exit_with_warning_if_host

# AgencyStack Component Installer: signing_timestamps.sh
# Path: /scripts/components/install_signing_timestamps.sh
#

# Enforce containerization (prevent host contamination)

# install_signing_timestamps.sh - Decentralized document signing & integrity verification
# https://stack.nerdofmouth.com
#
# This script sets up a document signing and timestamp verification system with:
# - GPG for cryptographic signing
# - OpenTimestamps for blockchain-based timestamping
# - Key management utilities
# - Verification workflow
#
# Author: AgencyStack Team
# Version: 1.0.0
# Created: 2025-04-07

# Set strict error handling
set -euo pipefail

# Define absolute paths - never rely on relative paths
AGENCY_ROOT="/opt/agency_stack"
AGENCY_LOG_DIR="/var/log/agency_stack"
AGENCY_CLIENTS_DIR="${AGENCY_ROOT}/clients"
AGENCY_SCRIPTS_DIR="${AGENCY_ROOT}/repo/scripts"
AGENCY_UTILS_DIR="${AGENCY_SCRIPTS_DIR}/utils"

# Import common utilities
source "${AGENCY_UTILS_DIR}/log_helpers.sh"

# Define component-specific variables
COMPONENT="signing_timestamps"
COMPONENT_DIR="${AGENCY_ROOT}/${COMPONENT}"
COMPONENT_CONFIG_DIR="${COMPONENT_DIR}/config"
COMPONENT_LOG_FILE="${AGENCY_LOG_DIR}/components/${COMPONENT}.log"
COMPONENT_INSTALLED_MARKER="${COMPONENT_DIR}/.installed_ok"

# Default configuration
CLIENT_ID="${CLIENT_ID:-default}"
DOMAIN="${DOMAIN:-localhost}"
ADMIN_EMAIL="${ADMIN_EMAIL:-admin@example.com}"
FORCE=false
WITH_DEPS=false
VERBOSE=false
ENABLE_CLOUD=false
ENABLE_OPENAI=false
USE_GITHUB=false

# Show help
show_help() {
  echo "Usage: $0 [options]"
  echo
  echo "Installs and configures document signing and timestamps for AgencyStack"
  echo
  echo "Options:"
  echo "  --domain DOMAIN        Domain name for the installation"
  echo "  --admin-email EMAIL    Admin email for notifications"
  echo "  --client-id ID         Client ID for multi-tenant setup"
  echo "  --force                Force reinstallation even if already installed"
  echo "  --with-deps            Install dependencies if missing"
  echo "  --verbose              Enable verbose output"
  echo "  --enable-cloud         Enable cloud storage backends"
  echo "  --enable-openai        Enable OpenAI API integration"
  echo "  --use-github           Use GitHub for repository operations"
  echo "  -h, --help             Show this help message"
}

# Parse arguments
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
    --with-deps)
      WITH_DEPS=true
      shift
      ;;
    --verbose)
      VERBOSE=true
      shift
      ;;
    --enable-cloud)
      ENABLE_CLOUD=true
      shift
      ;;
    --enable-openai)
      ENABLE_OPENAI=true
      shift
      ;;
    --use-github)
      USE_GITHUB=true
      shift
      ;;
    -h|--help)
      show_help
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      show_help
      exit 1
      ;;
  esac
done

# Setup logging
mkdir -p "$(dirname "${COMPONENT_LOG_FILE}")"
exec &> >(tee -a "${COMPONENT_LOG_FILE}")

# Log function
log() {
  local level="$1"
  local message="$2"
  local display="$3"
  
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message" >> "${COMPONENT_LOG_FILE}"
  if [[ -n "${display}" ]]; then
    echo -e "${display}"
  fi
}

# Integration log function
integration_log() {
  local message="$1"
  local json_data="$2"
  
  echo "{\"timestamp\":\"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\",\"component\":\"${COMPONENT}\",\"message\":\"${message}\",\"data\":${json_data}}" >> "${AGENCY_LOG_DIR}/integration.log"
}

log "INFO" "Starting signing timestamps installation for domain: ${DOMAIN}" "${BLUE}Starting signing timestamps installation for domain: ${DOMAIN}...${NC}"

# Set up site-specific variables
SITE_NAME=${DOMAIN//./_}
CLIENT_DIR="${AGENCY_CLIENTS_DIR}/${CLIENT_ID}"
INSTALL_DIR="${CLIENT_DIR}/${COMPONENT}"
INSTALL_LOG="${COMPONENT_LOG_FILE}"
SECRETS_DIR="${AGENCY_ROOT}/secrets/${COMPONENT}/${CLIENT_ID}"
GNUPG_DIR="${INSTALL_DIR}/gnupg"
SCRIPTS_DIR="${INSTALL_DIR}/scripts"
LOGS_DIR="${INSTALL_DIR}/logs"
VERIFIED_DIR="${INSTALL_DIR}/verified"

# Check for existing installation
if [[ -f "${COMPONENT_INSTALLED_MARKER}" ]] && [[ "${FORCE}" != "true" ]]; then
  log "INFO" "Signing timestamps already installed" "${GREEN}✅ Signing timestamps already installed.${NC}"
  log "INFO" "Use --force to reinstall" "${CYAN}Use --force to reinstall.${NC}"
  exit 0

# Create necessary directories
log "INFO" "Creating necessary directories" "${CYAN}Creating necessary directories...${NC}"
mkdir -p "${INSTALL_DIR}"
mkdir -p "${GNUPG_DIR}"
mkdir -p "${SCRIPTS_DIR}"
mkdir -p "${LOGS_DIR}"
mkdir -p "${VERIFIED_DIR}"
mkdir -p "${SECRETS_DIR}"

# Set proper permissions
chmod 700 "${GNUPG_DIR}"

# Install dependencies
log "INFO" "Installing required packages" "${CYAN}Installing required packages...${NC}"
apt-get update >> "${INSTALL_LOG}" 2>&1
apt-get install -y gnupg2 python3-pip python3-dev git haveged rng-tools >> "${INSTALL_LOG}" 2>&1

# Improve entropy for key generation
log "INFO" "Configuring entropy services" "${CYAN}Configuring entropy services for secure key generation...${NC}"
systemctl enable haveged >> "${INSTALL_LOG}" 2>&1
systemctl start haveged >> "${INSTALL_LOG}" 2>&1
systemctl enable rng-tools >> "${INSTALL_LOG}" 2>&1
systemctl start rng-tools >> "${INSTALL_LOG}" 2>&1

# Install OpenTimestamps client
log "INFO" "Installing OpenTimestamps client" "${CYAN}Installing OpenTimestamps client...${NC}"
pip3 install opentimestamps-client >> "${INSTALL_LOG}" 2>&1

# Create key generation script
log "INFO" "Creating key generation script" "${CYAN}Creating key generation script...${NC}"
cat > "${SCRIPTS_DIR}/generate-server-key.sh" <<EOL
#!/bin/bash
# This script generates a GPG key for the server

# Set strict error handling
set -euo pipefail

# Check if running as root
if [ "\$(id -u)" -ne 0 ]; then
  echo "This script must be run as root" >&2
  exit 1

# Get hostname for the key
HOSTNAME=\$(hostname)
EMAIL="${ADMIN_EMAIL}"
NAME="AgencyStack \${HOSTNAME}"

# Create batch file for unattended key generation
cat > ${GNUPG_DIR}/key-gen-template <<EOF
%echo Generating GPG key for \$NAME
Key-Type: RSA
Key-Length: 4096
Subkey-Type: RSA
Subkey-Length: 4096
Name-Real: \$NAME
Name-Email: \$EMAIL
Expire-Date: 0
Passphrase: %no-protection%
%commit
%echo Key generation completed
EOF

# Set GNUPGHOME
export GNUPGHOME="${GNUPG_DIR}"

# Generate key
gpg --batch --generate-key ${GNUPG_DIR}/key-gen-template

# Export the public key
KEY_ID=\$(gpg --list-keys --with-colons | grep pub | cut -d':' -f5)
gpg --armor --export \$KEY_ID > ${INSTALL_DIR}/server-public-key.asc

# Export the fingerprint
gpg --fingerprint \$KEY_ID > ${INSTALL_DIR}/server-key-fingerprint.txt

echo "Server GPG key generated with ID: \$KEY_ID"
echo "Public key exported to: ${INSTALL_DIR}/server-public-key.asc"
echo "Fingerprint saved to: ${INSTALL_DIR}/server-key-fingerprint.txt"
EOL

# Create document signing script
log "INFO" "Creating document signing script" "${CYAN}Creating document signing script...${NC}"
cat > "${SCRIPTS_DIR}/sign-document.sh" <<EOL
#!/bin/bash
# This script signs a document with GPG and creates a timestamp

# Set strict error handling
set -euo pipefail

# Check if running as root
if [ "\$(id -u)" -ne 0 ]; then
  echo "This script must be run as root" >&2
  exit 1

# Check if a document was provided
if [ \$# -lt 1 ]; then
  echo "Usage: \$0 <document_path> [description]"
  echo "Example: \$0 /path/to/contract.pdf 'Client X Contract'"
  exit 1

DOCUMENT="\$1"
DESCRIPTION="\${2:-Document signed on \$(date)}"
TIMESTAMP=\$(date +%Y%m%d%H%M%S)
DOCUMENT_NAME=\$(basename "\$DOCUMENT")
OUTPUT_DIR="${INSTALL_DIR}/signed/\$TIMESTAMP"

# Create output directory
mkdir -p "\$OUTPUT_DIR"

# Set GNUPGHOME
export GNUPGHOME="${GNUPG_DIR}"

# Calculate SHA256 hash
echo "Calculating document hash..."
SHA256=\$(sha256sum "\$DOCUMENT" | awk '{print \$1}')

# Copy original document
cp "\$DOCUMENT" "\$OUTPUT_DIR/\$DOCUMENT_NAME"

# Create document metadata
cat > "\$OUTPUT_DIR/metadata.txt" <<EOF
Document: \$DOCUMENT_NAME
Description: \$DESCRIPTION
SHA256: \$SHA256
Timestamp: \$(date -u +"%Y-%m-%dT%H:%M:%SZ")
Signed by: \$(gpg --list-keys --with-colons | grep pub | cut -d':' -f10)
EOF

# Sign the document and metadata
echo "Signing document..."
gpg --detach-sign --armor "\$OUTPUT_DIR/\$DOCUMENT_NAME"
gpg --clearsign "\$OUTPUT_DIR/metadata.txt"

# Create OpenTimestamp
echo "Creating blockchain timestamp..."
ots stamp "\$OUTPUT_DIR/\$DOCUMENT_NAME"

# Create combined verification package
cat "\$OUTPUT_DIR/metadata.txt.asc" > "\$OUTPUT_DIR/verification-package.txt"
echo -e "\n\nSHA256 HASH:\n\$SHA256\n" >> "\$OUTPUT_DIR/verification-package.txt"
echo -e "DETACHED SIGNATURE:" >> "\$OUTPUT_DIR/verification-package.txt"
cat "\$OUTPUT_DIR/\$DOCUMENT_NAME.asc" >> "\$OUTPUT_DIR/verification-package.txt"
echo -e "\n\nTIMESTAMP INFO:" >> "\$OUTPUT_DIR/verification-package.txt"
echo "OpenTimestamps proof file created: \$DOCUMENT_NAME.ots" >> "\$OUTPUT_DIR/verification-package.txt"

echo "✅ Document signed and timestamped successfully"
echo "📂 Output directory: \$OUTPUT_DIR"
echo "📄 Verification package: \$OUTPUT_DIR/verification-package.txt"
EOL

# Create document verification script
log "INFO" "Creating document verification script" "${CYAN}Creating document verification script...${NC}"
cat > "${SCRIPTS_DIR}/verify-document.sh" <<EOL
#!/bin/bash
# This script verifies a signed document and its timestamp

# Set strict error handling
set -euo pipefail

# Check if running as root
if [ "\$(id -u)" -ne 0 ]; then
  echo "This script must be run as root" >&2
  exit 1

# Check if documents were provided
if [ \$# -lt 2 ]; then
  echo "Usage: \$0 <document_path> <signature_path> [timestamp_path]"
  echo "Example: \$0 /path/to/contract.pdf /path/to/contract.pdf.asc /path/to/contract.pdf.ots"
  exit 1

DOCUMENT="\$1"
SIGNATURE="\$2"
TIMESTAMP="\${3:-}"
OUTPUT_DIR="${VERIFIED_DIR}/\$(date +%Y%m%d%H%M%S)"

# Create output directory
mkdir -p "\$OUTPUT_DIR"

# Set GNUPGHOME
export GNUPGHOME="${GNUPG_DIR}"

# Verify GPG signature
echo "Verifying GPG signature..."
VERIFY_OUTPUT=\$(gpg --verify "\$SIGNATURE" "\$DOCUMENT" 2>&1)
GPG_EXIT=\$?

# Calculate SHA256 hash
SHA256=\$(sha256sum "\$DOCUMENT" | awk '{print \$1}')

# Create verification report
cat > "\$OUTPUT_DIR/verification-report.txt" <<EOF
Document Verification Report
===========================
Document: \$(basename "\$DOCUMENT")
SHA256: \$SHA256
Verification Date: \$(date -u +"%Y-%m-%dT%H:%M:%SZ")

GPG Signature Verification
-------------------------
\$VERIFY_OUTPUT
EOF

if [ \$GPG_EXIT -eq 0 ]; then
  echo "GPG Signature: VALID" >> "\$OUTPUT_DIR/verification-report.txt"
  echo "GPG Signature: INVALID" >> "\$OUTPUT_DIR/verification-report.txt"

# Verify timestamp if provided
if [ -n "\$TIMESTAMP" ] && [ -f "\$TIMESTAMP" ]; then
  echo -e "\nTimestamp Verification\n-----------------------" >> "\$OUTPUT_DIR/verification-report.txt"
  OTS_OUTPUT=\$(ots verify "\$TIMESTAMP" 2>&1)
  OTS_EXIT=\$?
  echo "\$OTS_OUTPUT" >> "\$OUTPUT_DIR/verification-report.txt"
  
  if [ \$OTS_EXIT -eq 0 ]; then
    echo "OpenTimestamps: VALID" >> "\$OUTPUT_DIR/verification-report.txt"
  else
    echo "OpenTimestamps: INVALID or INCOMPLETE" >> "\$OUTPUT_DIR/verification-report.txt"
  fi

# Summarize verification result
if [ \$GPG_EXIT -eq 0 ] && ([ -z "\$TIMESTAMP" ] || [ \$OTS_EXIT -eq 0 ]); then
  echo -e "\nOVERALL VERIFICATION: SUCCESSFUL" >> "\$OUTPUT_DIR/verification-report.txt"
  echo "✅ Document verification successful"
  echo -e "\nOVERALL VERIFICATION: FAILED" >> "\$OUTPUT_DIR/verification-report.txt"
  echo "❌ Document verification failed"

echo "📄 Verification report: \$OUTPUT_DIR/verification-report.txt"
EOL

# Create logging utility
log "INFO" "Creating logging utility" "${CYAN}Creating logging utility...${NC}"
cat > "${SCRIPTS_DIR}/signing-log.sh" <<EOL
#!/bin/bash
# Logging utility for document signing operations

# Set up log directory and file
LOG_DIR="${LOGS_DIR}"
LOG_FILE="\${LOG_DIR}/signing.log"

# Ensure log directory exists
mkdir -p "\$LOG_DIR"

# Read from stdin and append to log file
while IFS= read -r line; do
  echo "[\$(date +%Y-%m-%d\ %H:%M:%S)] \$line" >> "\$LOG_FILE"
  echo "\$line"
done
EOL

# Make scripts executable
chmod +x "${SCRIPTS_DIR}/generate-server-key.sh"
chmod +x "${SCRIPTS_DIR}/sign-document.sh"
chmod +x "${SCRIPTS_DIR}/verify-document.sh"
chmod +x "${SCRIPTS_DIR}/signing-log.sh"

# Generate server key if requested
if [ "$WITH_DEPS" = true ]; then
  log "INFO" "Generating server GPG key" "${CYAN}Generating server GPG key...${NC}"
  "${SCRIPTS_DIR}/generate-server-key.sh" >> "${INSTALL_LOG}" 2>&1

# Create installation marker
touch "${COMPONENT_INSTALLED_MARKER}"

# Log integration data
integration_log "Signing timestamps installed" "{\"domain\":\"${DOMAIN}\",\"client_id\":\"${CLIENT_ID}\"}"

log "SUCCESS" "Signing timestamps installation completed" "${GREEN}✅ Signing timestamps installation completed!${NC}"
echo
log "INFO" "Available scripts" "${YELLOW}⚠️ IMPORTANT: Available scripts${NC}"
echo
echo -e "${CYAN}Generate server key: ${SCRIPTS_DIR}/generate-server-key.sh${NC}"
echo -e "${CYAN}Sign document: ${SCRIPTS_DIR}/sign-document.sh <document_path> [description]${NC}"
echo -e "${CYAN}Verify document: ${SCRIPTS_DIR}/verify-document.sh <document_path> <signature_path> [timestamp_path]${NC}"
echo
echo -e "${YELLOW}Run the generate-server-key.sh script first to create a signing key.${NC}"
echo -e "${RED}Keep your server's signing keys secure. They're located in ${GNUPG_DIR}${NC}"

exit 0
