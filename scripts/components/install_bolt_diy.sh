#!/bin/bash
# Bolt DIY Installation Script
# AgencyStack Component: bolt-diy

set -euo pipefail

# Source common utilities
source "$(dirname "$0")/../utils/common.sh"

# Component configuration
COMPONENT_NAME="bolt-diy"
LOG_FILE="/var/log/agency_stack/components/${COMPONENT_NAME}.log"
INSTALL_DIR="/opt/agency_stack/clients/${CLIENT_ID:-default}/${COMPONENT_NAME}"

# Initialize logging
log_start "${LOG_FILE}" "Bolt DIY installation started"

# Check for existing installation
if [ -f "${INSTALL_DIR}/.installed" ]; then
    log_info "${LOG_FILE}" "Bolt DIY already installed, skipping"
    exit 0
fi

# Create installation directory
mkdir -p "${INSTALL_DIR}"
cd "${INSTALL_DIR}"

# Install dependencies
log_info "${LOG_FILE}" "Installing dependencies"
apt-get update
apt-get install -y git python3 python3-pip python3-venv

# Clone repository
log_info "${LOG_FILE}" "Cloning Bolt DIY repository"
git clone https://github.com/bolt-diy/core.git .

# Setup virtual environment
log_info "${LOG_FILE}" "Setting up Python virtual environment"
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# Create systemd service
log_info "${LOG_FILE}" "Creating systemd service"
cat > /etc/systemd/system/bolt-diy.service <<EOF
[Unit]
Description=Bolt DIY Service
After=network.target

[Service]
User=bolt-diy
Group=bolt-diy
WorkingDirectory=${INSTALL_DIR}
ExecStart=${INSTALL_DIR}/venv/bin/python app.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Create service user
useradd --system --home-dir "${INSTALL_DIR}" --shell /bin/false bolt-diy
chown -R bolt-diy:bolt-diy "${INSTALL_DIR}"

# Enable and start service
systemctl daemon-reload
systemctl enable bolt-diy
systemctl start bolt-diy

# Mark installation complete
touch "${INSTALL_DIR}/.installed"

log_success "${LOG_FILE}" "Bolt DIY installed successfully"
