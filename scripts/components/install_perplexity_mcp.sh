#!/usr/bin/env bash
# AgencyStack Component Installer: Perplexity MCP
# Installs uvx and perplexity-mcp for use in MCP server stack
# Logs to /var/log/agency_stack/components/perplexity_mcp.log
# Follows repo integrity and idempotency policy

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/var/log/agency_stack/components/perplexity_mcp.log"

# Source common utilities if available
if [[ -f "${SCRIPT_DIR}/../utils/common.sh" ]]; then
  source "${SCRIPT_DIR}/../utils/common.sh"
fi

log_info() {
  echo "[INFO] $1" | tee -a "$LOG_FILE"
}
log_error() {
  echo "[ERROR] $1" | tee -a "$LOG_FILE" >&2
}

log_info "Starting Perplexity MCP install..."

# Ensure Python 3 and pip are installed
if ! command -v python3 >/dev/null 2>&1; then
  log_error "Python3 not found. Please install Python3."
  exit 1
fi
if ! command -v pip3 >/dev/null 2>&1; then
  log_error "pip3 not found. Please install pip3."
  exit 1
fi

# Ensure pipx is installed
if ! command -v pipx >/dev/null 2>&1; then
  log_info "pipx not found, attempting to install via apt..."
  if command -v apt-get >/dev/null 2>&1; then
    sudo apt-get update && sudo apt-get install -y pipx || {
      log_error "Failed to install pipx via apt."
      # Try pip as a last resort
      log_info "Attempting to install pipx via pip with --break-system-packages (not recommended)..."
      python3 -m pip install --break-system-packages --user pipx || {
        log_error "Failed to install pipx via pip even with --break-system-packages."
        exit 1
      }
      export PATH="$HOME/.local/bin:$PATH"
    }
    export PATH="/usr/local/bin:$PATH"
  else
    log_error "apt-get not found. Please install pipx manually."
    exit 1
  fi
fi

# Ensure uvx is installed via pipx
if ! command -v uvx >/dev/null 2>&1; then
  log_info "Installing uvx via pipx..."
  pipx install uvx || {
    log_error "Failed to install uvx via pipx."
    exit 1
  }
else
  log_info "uvx already installed."
fi

# Install perplexity-mcp CLI via pipx if not present
if ! command -v perplexity-mcp >/dev/null 2>&1; then
  log_info "Installing perplexity-mcp CLI via pipx..."
  pipx install perplexity-mcp || {
    log_error "Failed to install perplexity-mcp CLI via pipx."
    exit 1
  }
else
  log_info "perplexity-mcp CLI already available in PATH."
fi

# Log the installed path for perplexity-mcp
if command -v perplexity-mcp >/dev/null 2>&1; then
  CLI_PATH=$(command -v perplexity-mcp)
  log_info "perplexity-mcp CLI path: $CLI_PATH"
else
  log_error "perplexity-mcp CLI not found after install."
  exit 1
fi

log_info "Perplexity MCP install complete."
exit 0
