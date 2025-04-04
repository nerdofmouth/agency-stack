#!/bin/bash
# config_diff.sh - Wrapper script for config diff
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
echo -e "\033[0;33mEnter the first commit hash to compare:\033[0m"
read -p "> " commit1

if [ -z "$commit1" ]; then
  echo -e "\033[0;31mNo commit hash provided. Aborting.\033[0m"
  exit 1
fi

echo -e "\033[0;33mEnter the second commit hash to compare (or press Enter to show just the first commit):\033[0m"
read -p "> " commit2

# Execute diff
if [ -z "$commit2" ]; then
  "$CONFIG_SNAPSHOT" diff "$commit1"
else
  "$CONFIG_SNAPSHOT" diff "$commit1" "$commit2"
fi
