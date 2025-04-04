#!/bin/bash
# config_rollback.sh - Wrapper script for config rollback
# https://stack.nerdofmouth.com

SCRIPTS_DIR="$(dirname "$0")"
CONFIG_SNAPSHOT="${SCRIPTS_DIR}/config_snapshot.sh"

if [ ! -f "$CONFIG_SNAPSHOT" ]; then
  echo -e "\033[0;31mError: config_snapshot.sh not found\033[0m"
  exit 1
fi

# List available snapshots
echo -e "\033[0;34mAvailable configuration snapshots:\033[0m"
"$CONFIG_SNAPSHOT" list

echo
echo -e "\033[0;33mEnter the commit hash to roll back to:\033[0m"
read -p "> " commit_hash

if [ -z "$commit_hash" ]; then
  echo -e "\033[0;31mNo commit hash provided. Aborting.\033[0m"
  exit 1
fi

# Execute rollback
"$CONFIG_SNAPSHOT" rollback "$commit_hash"
