#!/bin/bash
# track_usage.sh
# Scans for usage of files in the given folder across the stack

TARGET_DIR="$1"
if [[ -z "$TARGET_DIR" ]]; then
  echo "Usage: $0 <target_directory>"
  exit 1
fi

echo "📦 Script Usage Report"
echo "Scanning directory: $TARGET_DIR"
echo ""

# Find all scripts in the target folder
find "$TARGET_DIR" -type f -name "*.sh" | while read script_path; do
  script_name=$(basename "$script_path")
  echo "🔍 Checking references to: $script_name"
  
  # Search the entire repo for mentions of this script
  grep -r --include="*.sh" --include="Makefile" --include="*.yml" --include="*.md" --exclude-dir=".git" --exclude-dir="$TARGET_DIR" "$script_name" . > /tmp/usage_tmp.txt
  
  if [[ -s /tmp/usage_tmp.txt ]]; then
    echo "✅ Used in:"
    cat /tmp/usage_tmp.txt
  else
    echo "⚠️  Not found in use."
  fi
  echo "-----------------------------"
done

rm -f /tmp/usage_tmp.txt
