#!/bin/bash
# AgencyStack Base CLI Tools Installer
# Installs core CLI tools required for all component installs on a new *nix VM
# Idempotent and safe to re-run. Logs to /var/log/agency_stack/components/base_cli_tools.log

set -e
LOGDIR="/var/log/agency_stack/components"
LOGFILE="$LOGDIR/base_cli_tools.log"
sudo mkdir -p "$LOGDIR"
sudo touch "$LOGFILE"

log() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | sudo tee -a "$LOGFILE"
}

log "Starting base CLI tools installation..."

# Detect OS (Debian/Ubuntu vs. RHEL/CentOS vs. Alpine)
if [ -f /etc/debian_version ]; then
  PKG_UPDATE="sudo apt-get update -y"
  PKG_INSTALL="sudo apt-get install -y"
  PKGS="git curl wget sudo"
  log "Detected Debian/Ubuntu system."
  $PKG_UPDATE | sudo tee -a "$LOGFILE"
  $PKG_INSTALL $PKGS | sudo tee -a "$LOGFILE"
elif [ -f /etc/redhat-release ]; then
  PKG_UPDATE="sudo yum makecache fast"
  PKG_INSTALL="sudo yum install -y"
  PKGS="git curl wget sudo"
  log "Detected RHEL/CentOS system."
  $PKG_UPDATE | sudo tee -a "$LOGFILE"
  $PKG_INSTALL $PKGS | sudo tee -a "$LOGFILE"
elif [ -f /etc/alpine-release ]; then
  PKG_UPDATE="sudo apk update"
  PKG_INSTALL="sudo apk add --no-cache"
  PKGS="git curl wget sudo"
  log "Detected Alpine system."
  $PKG_UPDATE | sudo tee -a "$LOGFILE"
  $PKG_INSTALL $PKGS | sudo tee -a "$LOGFILE"
else
  log "[ERROR] Unsupported OS. Please install git, curl, wget, and sudo manually."
  exit 1
fi

log "Base CLI tools installation complete."
exit 0
