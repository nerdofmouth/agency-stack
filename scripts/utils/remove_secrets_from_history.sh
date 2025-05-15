#!/bin/bash
set -e

# === 1. Check for git-filter-repo ===
if ! command -v git-filter-repo &>/dev/null; then
  echo "git-filter-repo not found! Installing via pip..."
  pip install git-filter-repo
fi

echo "=== 2. Removing secrets from commit history... ==="

# === 3. Create a secrets replacement file ===
cat > .git-secrets-replacements.txt <<EOF
REMOVED_SECRET==>REMOVED_SECRET
REMOVED_SECRET==>REMOVED_SECRET
EOF

# === 4. Run git filter-repo to replace secrets in all history ===
git filter-repo --replace-text .git-secrets-replacements.txt

# === 5. Remove the replacement file ===
rm .git-secrets-replacements.txt

echo "=== 6. Review and re-add cleaned files ==="
git status

echo "You should now review the affected files and ensure secrets are gone."
echo "If all is good, stage and commit the changes:"
echo "    git add scripts/components/mcp/mcp_dev_config.json scripts/components/mcp/restart_mcp.sh scripts/components/mcp/run_mcp_dev.sh scripts/components/taskmaster/test.js"
echo "    git commit -m 'Remove secrets from config and scripts'"

echo "=== 7. Force push to overwrite remote branch ==="
echo "    git push --force origin client/peacefestivalusa:client/peacefestivalusa"

echo

echo "=== 8. IMPORTANT: Rotate any exposed API keys immediately! ==="
echo "Visit your provider dashboards (Anthropic, OpenAI, etc.) and generate new keys."
