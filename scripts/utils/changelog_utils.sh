#!/bin/bash
# AgencyStack Changelog Utilities
# Provides functions for standardized CHANGELOG_SETUP.md updates
# Following AgencyStack Charter v1.0.3 principles

set -euo pipefail

# Source common utilities if available
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/common.sh" ]]; then
  source "${SCRIPT_DIR}/common.sh"
fi

# Define colors for terminal output if not sourced from common.sh
if [[ -z "${GREEN:-}" ]]; then
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[0;33m'
  BLUE='\033[0;34m'
  CYAN='\033[0;36m'
  BOLD='\033[1m'
  NC='\033[0m' # No Color
fi

CHANGELOG_FILE="${REPO_ROOT:-$(dirname "$(dirname "${SCRIPT_DIR}")")}/CHANGELOG_SETUP.md"

# Ensure the changelog file exists
ensure_changelog_exists() {
  if [[ ! -f "$CHANGELOG_FILE" ]]; then
    echo -e "${YELLOW}Changelog file not found. Creating it...${NC}"
    
    # Create the changelog file with header
    cat > "$CHANGELOG_FILE" << 'EOL'
# AgencyStack Setup Changelog

This changelog tracks AI-generated configuration fixes, script refactors, and known edge-case notes to facilitate ongoing improvement and AI-human handoff in the AgencyStack platform.

## Format Guidelines

Each entry should follow this format:
```markdown
### YYYY-MM-DD Component Name

<!-- @agent:category -->
**Change Type**: [Feature|Fix|Refactor|Security]
**Author**: [AI|Human|Collaborative]
**Files Changed**: `/path/to/file1.sh`, `/path/to/file2.sh`

Description of the change, including motivation and context.

**Edge Cases**: Any known limitations or edge cases
**Testing Done**: Description of testing performed
```

## Current Changes
EOL
    
    echo -e "${GREEN}Created changelog file at: ${CHANGELOG_FILE}${NC}"
  fi
}

# Helper function to validate tag
validate_tag() {
  local tag="$1"
  local valid_tags=("critical-fix" "enhancement" "refactor" "security" "documentation" "test" "dependency")
  
  for valid_tag in "${valid_tags[@]}"; do
    if [[ "$tag" == "$valid_tag" ]]; then
      return 0
    fi
  done
  
  echo -e "${YELLOW}Warning: '$tag' is not a standard tag.${NC}"
  echo -e "${YELLOW}Consider using one of: ${valid_tags[*]}${NC}"
  return 0
}

# Function to log an agent fix to the changelog
log_agent_fix() {
  local component="$1"
  local description="$2"
  local tag="${3:-critical-fix}"
  local change_type="${4:-Fix}"
  local files="${5:-}"
  local edge_cases="${6:-None identified at this time.}"
  local testing="${7:-Basic functionality testing completed.}"
  
  validate_tag "$tag"
  ensure_changelog_exists
  
  local date_now=$(date +%Y-%m-%d)
  local entry=$(cat << EOL

### ${date_now} ${component}

<!-- @agent:${tag} -->
**Change Type**: ${change_type}
**Author**: AI
**Files Changed**: ${files}

${description}

**Edge Cases**: ${edge_cases}
**Testing Done**: ${testing}
EOL
)
  
  # Insert the entry after the "Current Changes" header
  local temp_file=$(mktemp)
  awk -v entry="$entry" '
    /^## Current Changes/ {
      print $0
      print entry
      next
    }
    {print}
  ' "$CHANGELOG_FILE" > "$temp_file"
  
  mv "$temp_file" "$CHANGELOG_FILE"
  echo -e "${GREEN}Added agent fix entry to changelog for ${BOLD}${component}${NC}"
}

# Function to log a manual override in the changelog
log_manual_override() {
  local component="$1"
  local description="$2"
  local reason="${3:-Required for operational compatibility.}"
  
  ensure_changelog_exists
  
  local date_now=$(date +%Y-%m-%d)
  local entry=$(cat << EOL

### ${date_now} ${component} Manual Override

<!-- @human:manual-override -->
**Change Type**: Override
**Author**: Human
**Reason**: ${reason}

${description}

**Note**: This override was manually applied and should be reviewed during next refactoring.
EOL
)
  
  # Insert the entry after the "Current Changes" header
  local temp_file=$(mktemp)
  awk -v entry="$entry" '
    /^## Current Changes/ {
      print $0
      print entry
      next
    }
    {print}
  ' "$CHANGELOG_FILE" > "$temp_file"
  
  mv "$temp_file" "$CHANGELOG_FILE"
  echo -e "${GREEN}Added manual override entry to changelog for ${BOLD}${component}${NC}"
}

# Function to log a collaborative change in the changelog
log_collaborative_change() {
  local component="$1"
  local description="$2"
  local change_type="${3:-Enhancement}"
  local files="${4:-}"
  local edge_cases="${5:-None identified at this time.}"
  local testing="${6:-Comprehensive testing completed.}"
  
  ensure_changelog_exists
  
  local date_now=$(date +%Y-%m-%d)
  local entry=$(cat << EOL

### ${date_now} ${component}

<!-- @agent:collaborative -->
<!-- @human:reviewed -->
**Change Type**: ${change_type}
**Author**: Collaborative
**Files Changed**: ${files}

${description}

**Edge Cases**: ${edge_cases}
**Testing Done**: ${testing}
EOL
)
  
  # Insert the entry after the "Current Changes" header
  local temp_file=$(mktemp)
  awk -v entry="$entry" '
    /^## Current Changes/ {
      print $0
      print entry
      next
    }
    {print}
  ' "$CHANGELOG_FILE" > "$temp_file"
  
  mv "$temp_file" "$CHANGELOG_FILE"
  echo -e "${GREEN}Added collaborative change entry to changelog for ${BOLD}${component}${NC}"
}

# Display usage if run directly
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  echo -e "${BOLD}AgencyStack Changelog Utilities${NC}"
  echo "Usage:"
  echo "  source $(basename "$0")"
  echo "  log_agent_fix <component> <description> [tag] [change_type] [files] [edge_cases] [testing]"
  echo "  log_manual_override <component> <description> [reason]"
  echo "  log_collaborative_change <component> <description> [change_type] [files] [edge_cases] [testing]"
  echo ""
  echo "Example:"
  echo "  log_agent_fix 'WordPress' 'Fixed database connection issues' 'critical-fix' 'Fix' '/scripts/install_wordpress.sh'"
fi
