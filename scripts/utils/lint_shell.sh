#!/bin/bash
# lint_shell.sh - Utility script to lint all AgencyStack shell scripts using shellcheck
# Usage: ./scripts/utils/lint_shell.sh [path]
# If no path is provided, defaults to scripts/components and scripts/utils

set -e

LINT_PATHS=("scripts/components" "scripts/utils")

if [ -n "$1" ]; then
    LINT_PATHS=("$1")
fi

# Check for shellcheck
if ! command -v shellcheck &>/dev/null; then
    echo "[ERROR] shellcheck is not installed. Please install it (apt-get install shellcheck or brew install shellcheck)." >&2
    exit 1
fi

EXIT_CODE=0

for path in "${LINT_PATHS[@]}"; do
    echo "[INFO] Linting shell scripts in $path..."
    find "$path" -type f -name '*.sh' | while read -r script; do
        echo "Linting $script..."
        shellcheck "$script" || EXIT_CODE=1
    done
done

if [ "$EXIT_CODE" -eq 0 ]; then
    echo "[SUCCESS] All shell scripts passed shellcheck."
else
    echo "[FAIL] Some shell scripts failed shellcheck. Review the output above."
fi

exit $EXIT_CODE
