#!/bin/bash

echo "📦 Bootstrapping local dev environment for AgencyStack installer development..."

# Docker (for validation scripts only)
sudo apt update && sudo apt install -y docker.io docker-compose

# Fake target directory structure for testing
sudo mkdir -p /opt/agency_stack/{clients,secrets}
sudo mkdir -p /var/log/agency_stack/{clients,components,integrations}

# Ensure log file exists
sudo touch /var/log/agency_stack/installer_dev.log

echo "✅ Dev env ready. You can now run make validate or build installer scripts safely."
