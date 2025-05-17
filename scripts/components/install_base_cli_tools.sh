#!/bin/bash
# AgencyStack Base CLI Tools Installer
# Installs core CLI tools required for all component installs on a new *nix VM
# Idempotent and safe to re-run. Logs to /var/log/agency_stack/components/base_cli_tools.log

set -e
LOGDIR="/var/log/agency_stack/components"
LOGFILE="$LOGDIR/base_cli_tools.log"
mkdir -p "$LOGDIR"
touch "$LOGFILE"

log() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOGFILE"
}

log "Starting base CLI tools installation..."

# Detect OS (Debian/Ubuntu vs. RHEL/CentOS vs. Alpine)
if [ -f /etc/debian_version ]; then
  PKG_UPDATE="apt-get update -y"
  PKG_INSTALL="apt-get install -y"
  PKGS="git curl wget sudo"
  log "Detected Debian/Ubuntu system."
  $PKG_UPDATE >> "$LOGFILE" 2>&1
  $PKG_INSTALL $PKGS >> "$LOGFILE" 2>&1
elif [ -f /etc/redhat-release ]; then
  PKG_UPDATE="yum makecache fast"
  PKG_INSTALL="yum install -y"
  PKGS="git curl wget sudo"
  log "Detected RHEL/CentOS system."
  $PKG_UPDATE >> "$LOGFILE" 2>&1
  $PKG_INSTALL $PKGS >> "$LOGFILE" 2>&1
elif [ -f /etc/alpine-release ]; then
  PKG_UPDATE="apk update"
  PKG_INSTALL="apk add --no-cache"
  PKGS="git curl wget sudo"
  log "Detected Alpine system."
  $PKG_UPDATE >> "$LOGFILE" 2>&1
  $PKG_INSTALL $PKGS >> "$LOGFILE" 2>&1
else
  log "[ERROR] Unsupported OS. Please install git, curl, wget, and sudo manually."
  exit 1
fi

log "Base CLI tools installation complete."
exit 0
