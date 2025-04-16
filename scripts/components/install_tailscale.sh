#!/bin/bash
# AgencyStack Component Installer: Tailscale
# Path: /scripts/components/install_tailscale.sh
#
# Installs and configures Tailscale Mesh VPN for secure agency networking
# This follows the standard AgencyStack component structure and conventions.

# Set strict error handling
set -euo pipefail

# Define absolute paths - never rely on relative paths
AGENCY_ROOT="/opt/agency_stack"
AGENCY_LOG_DIR="/var/log/agency_stack"
AGENCY_CLIENTS_DIR="${AGENCY_ROOT}/clients"
AGENCY_SCRIPTS_DIR="${AGENCY_ROOT}/repo/scripts"
AGENCY_UTILS_DIR="${AGENCY_SCRIPTS_DIR}/utils"

# Import common utilities
source "${AGENCY_UTILS_DIR}/common.sh"
source "${AGENCY_UTILS_DIR}/log_helpers.sh"

# Define component-specific variables
COMPONENT="tailscale"
COMPONENT_DIR="${AGENCY_ROOT}/${COMPONENT}"
COMPONENT_CONFIG_DIR="${COMPONENT_DIR}/config"
COMPONENT_LOG_FILE="${AGENCY_LOG_DIR}/components/${COMPONENT}.log"
COMPONENT_INSTALLED_MARKER="${COMPONENT_DIR}/.installed_ok"

# Parse arguments
ENABLE_CLOUD=false
ENABLE_OPENAI=false
USE_GITHUB=false
VERBOSE=false
FORCE=false
WITH_DEPS=false
EXIT_NODE=false
ADVERTISE_ROUTES=""
HOSTNAME=""
DOMAIN="${DOMAIN:-example.com}"
CLIENT_ID="${CLIENT_ID:-default}"

# Function to show help message
show_help() {
    log_banner "AgencyStack Tailscale Component Installation" "${COMPONENT_LOG_FILE}"
    log_info "Usage: $0 [options]"
    log_info "Options:"
    log_info "  --enable-cloud      Enable cloud interactions"
    log_info "  --enable-openai     Enable OpenAI integrations"
    log_info "  --use-github        Use GitHub for components"
    log_info "  --domain DOMAIN     Set domain name (default: ${DOMAIN})"
    log_info "  --client-id ID      Set client ID (default: ${CLIENT_ID})"
    log_info "  --exit-node         Configure this machine as an exit node"
    log_info "  --routes ROUTES     Advertise routes (comma-separated CIDR format)"
    log_info "  --hostname NAME     Set the hostname on Tailscale network"
    log_info "  --force             Force installation even if already installed"
    log_info "  --with-deps         Install dependencies"
    log_info "  --verbose           Show detailed output"
    log_info "  --help              Show this help message"
    exit 0
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
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
        --domain)
            DOMAIN="$2"
            shift 2
            ;;
        --client-id)
            CLIENT_ID="$2"
            shift 2
            ;;
        --exit-node)
            EXIT_NODE=true
            shift
            ;;
        --routes)
            ADVERTISE_ROUTES="$2"
            shift 2
            ;;
        --hostname)
            HOSTNAME="$2"
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
        --help)
            show_help
            ;;
        *)
            log_error "Unknown option: $key"
            show_help
            ;;
    esac
done

# Setup client-specific paths
if [ "$CLIENT_ID" != "default" ]; then
    CLIENT_DIR="${AGENCY_CLIENTS_DIR}/${CLIENT_ID}"
    COMPONENT_CLIENT_DIR="${CLIENT_DIR}/${COMPONENT}"
    mkdir -p "${COMPONENT_CLIENT_DIR}" 2>/dev/null || true
fi

# Start installation banner
log_banner "AgencyStack Tailscale Installation" "${COMPONENT_LOG_FILE}"

# Check for existing installation
if [[ -f "${COMPONENT_INSTALLED_MARKER}" && "${FORCE}" != "true" ]]; then
    log_info "Tailscale is already installed. Use --force to reinstall." "${COMPONENT_LOG_FILE}"
    exit 0
fi

# Create component directories
log_info "Creating Tailscale directories" "${COMPONENT_LOG_FILE}"
mkdir -p "${COMPONENT_DIR}" 2>/dev/null || true
mkdir -p "${COMPONENT_CONFIG_DIR}" 2>/dev/null || true
mkdir -p "$(dirname "${COMPONENT_LOG_FILE}")" 2>/dev/null || true

# Install Tailscale
log_info "Installing Tailscale package" "${COMPONENT_LOG_FILE}"

# Detect OS distribution
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_DISTRO="$ID"
    OS_VERSION="$VERSION_CODENAME"
    log_info "Detected OS: $OS_DISTRO $OS_VERSION" "${COMPONENT_LOG_FILE}"
else
    OS_DISTRO="ubuntu"
    OS_VERSION="focal"
    log_warning "Could not detect OS distribution. Defaulting to Ubuntu Focal." "${COMPONENT_LOG_FILE}"
fi

# Add Tailscale's package signing key and repository according to OS
case "$OS_DISTRO" in
    debian)
        log_info "Setting up Tailscale repository for Debian" "${COMPONENT_LOG_FILE}"
        curl -fsSL https://pkgs.tailscale.com/stable/debian/$OS_VERSION.gpg | apt-key add - >> "${COMPONENT_LOG_FILE}" 2>&1
        curl -fsSL https://pkgs.tailscale.com/stable/debian/$OS_VERSION.list | tee /etc/apt/sources.list.d/tailscale.list >> "${COMPONENT_LOG_FILE}" 2>&1
        ;;
    ubuntu)
        log_info "Setting up Tailscale repository for Ubuntu" "${COMPONENT_LOG_FILE}"
        curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/focal.gpg | apt-key add - >> "${COMPONENT_LOG_FILE}" 2>&1
        curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/focal.list | tee /etc/apt/sources.list.d/tailscale.list >> "${COMPONENT_LOG_FILE}" 2>&1
        ;;
    *)
        log_warning "Unsupported OS distribution: $OS_DISTRO. Attempting Ubuntu repository." "${COMPONENT_LOG_FILE}"
        curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/focal.gpg | apt-key add - >> "${COMPONENT_LOG_FILE}" 2>&1
        curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/focal.list | tee /etc/apt/sources.list.d/tailscale.list >> "${COMPONENT_LOG_FILE}" 2>&1
        ;;
esac

# Update package lists
log_info "Updating package lists" "${COMPONENT_LOG_FILE}"
apt-get update >> "${COMPONENT_LOG_FILE}" 2>&1

# Install Tailscale
log_info "Installing Tailscale package" "${COMPONENT_LOG_FILE}"
apt-get install -y tailscale >> "${COMPONENT_LOG_FILE}" 2>&1 || {
    log_error "Failed to install Tailscale package" "${COMPONENT_LOG_FILE}"
    exit 1
}

# Enable and start the Tailscale service
log_info "Enabling Tailscale service" "${COMPONENT_LOG_FILE}"
systemctl enable --now tailscaled >> "${COMPONENT_LOG_FILE}" 2>&1 || {
    log_error "Failed to enable Tailscale service" "${COMPONENT_LOG_FILE}"
    exit 1
}

# Create a setup script for connecting to Tailscale
log_info "Creating Tailscale setup script" "${COMPONENT_LOG_FILE}"
cat > "${COMPONENT_CONFIG_DIR}/setup-tailscale.sh" <<EOL
#!/bin/bash
# Tailscale setup script for AgencyStack

# Check if we're running as root
if [ "\$(id -u)" -ne 0 ]; then
  echo "This script must be run as root" >&2
  exit 1
fi

# Parse command line options
ADVERTISE_ROUTES="${ADVERTISE_ROUTES}"
ADVERTISE_EXIT_NODE=${EXIT_NODE}
HOSTNAME="${HOSTNAME:-$(hostname)}"

print_usage() {
  echo "Usage: \$0 [options]"
  echo "Options:"
  echo "  --routes ROUTES    Advertise routes (comma-separated CIDR format)"
  echo "  --exit-node        Configure this machine as an exit node"
  echo "  --hostname NAME    Set the hostname on Tailscale network"
  echo "  --help             Display this help message"
}

while [ \$# -gt 0 ]; do
  case "\$1" in
    --routes)
      ADVERTISE_ROUTES="\$2"
      shift 2
      ;;
    --exit-node)
      ADVERTISE_EXIT_NODE=true
      shift
      ;;
    --hostname)
      HOSTNAME="\$2"
      shift 2
      ;;
    --help)
      print_usage
      exit 0
      ;;
    *)
      echo "Unknown option: \$1" >&2
      print_usage
      exit 1
      ;;
  esac
done

# Construct Tailscale options
TAILSCALE_OPTS=""

if [ -n "\$ADVERTISE_ROUTES" ]; then
  TAILSCALE_OPTS="\$TAILSCALE_OPTS --advertise-routes=\$ADVERTISE_ROUTES"
fi

if [ "\$ADVERTISE_EXIT_NODE" = true ]; then
  TAILSCALE_OPTS="\$TAILSCALE_OPTS --advertise-exit-node"
fi

if [ -n "\$HOSTNAME" ]; then
  TAILSCALE_OPTS="\$TAILSCALE_OPTS --hostname=\$HOSTNAME"
fi

# Setup Tailscale authentication
echo "🔑 Starting Tailscale authentication..."
echo "🌐 You will need to authenticate this machine to your Tailscale account."
echo "🔗 A browser window will open for authentication (or use the provided URL)."

# Run tailscale up with the configured options
if [ -n "\$TAILSCALE_OPTS" ]; then
  echo "🛰 Running: tailscale up \$TAILSCALE_OPTS"
  tailscale up \$TAILSCALE_OPTS
else
  echo "🛰 Running: tailscale up"
  tailscale up
fi

# Check if tailscale is running and authenticated
if tailscale status | grep -q "authenticated"; then
  echo "✅ Tailscale setup completed successfully!"
  
  # Show the current status
  echo "📊 Current Tailscale status:"
  tailscale status
  
  # Show the tailscale IP address
  TAILSCALE_IP=\$(tailscale ip -4)
  echo "🌐 Tailscale IPv4 address: \$TAILSCALE_IP"
else
  echo "❌ Tailscale setup failed or was not completed."
  echo "🔄 You can try again by running: tailscale up"
fi
EOL

# Make the setup script executable
chmod +x "${COMPONENT_CONFIG_DIR}/setup-tailscale.sh"

# Create a symbolic link to make it available system-wide
ln -sf "${COMPONENT_CONFIG_DIR}/setup-tailscale.sh" /usr/local/bin/setup-tailscale

# Create a systemd service to start Tailscale at boot
log_info "Creating Tailscale autoconnect service" "${COMPONENT_LOG_FILE}"
cat > /etc/systemd/system/tailscale-autoconnect.service <<EOL
[Unit]
Description=Ensure Tailscale is connected
After=network-online.target tailscaled.service
Wants=network-online.target tailscaled.service

[Service]
Type=oneshot
ExecStart=/usr/sbin/tailscale up --accept-routes
RemainAfterExit=yes
StandardOutput=journal

[Install]
WantedBy=multi-user.target
EOL

# Reload systemd and enable the service
log_info "Enabling Tailscale autoconnect service" "${COMPONENT_LOG_FILE}"
systemctl daemon-reload >> "${COMPONENT_LOG_FILE}" 2>&1
systemctl enable tailscale-autoconnect.service >> "${COMPONENT_LOG_FILE}" 2>&1

# Mark component as installed
log_info "Marking Tailscale as installed" "${COMPONENT_LOG_FILE}"
echo "Installed on: $(date)" > "${COMPONENT_INSTALLED_MARKER}"
echo "Version: $(tailscale version 2>/dev/null || echo 'Unknown')" >> "${COMPONENT_INSTALLED_MARKER}"
echo "Installed by: $(whoami)" >> "${COMPONENT_INSTALLED_MARKER}"
echo "Client ID: ${CLIENT_ID}" >> "${COMPONENT_INSTALLED_MARKER}"
echo "Domain: ${DOMAIN}" >> "${COMPONENT_INSTALLED_MARKER}"

# Installation complete
log_success "Tailscale installed successfully!" "${COMPONENT_LOG_FILE}"
log_info "To complete setup, run: sudo setup-tailscale" "${COMPONENT_LOG_FILE}"
log_info "For advanced configuration options, run: sudo setup-tailscale --help" "${COMPONENT_LOG_FILE}"
log_info "After setup, you can access your Tailscale network at https://login.tailscale.com/" "${COMPONENT_LOG_FILE}"

exit 0
