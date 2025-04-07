#!/bin/bash
# generate_makefile_targets.sh - Create Makefile targets for AgencyStack components
# 
# This utility generates standardized Makefile targets for components that
# are registered in the component registry but missing their required targets.
#
# Author: AgencyStack Team
# Date: 2025-04-07

set -e

# Colors for output
BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
MAKEFILE="$PROJECT_ROOT/Makefile"
REGISTRY_FILE="$PROJECT_ROOT/config/registry/component_registry.json"
OUTPUT_FILE="$PROJECT_ROOT/makefile_targets.generated"
LOCAL_DEV_FILE="$PROJECT_ROOT/docs/LOCAL_DEVELOPMENT.md"

# Check dependencies
check_dependencies() {
  if ! command -v jq &> /dev/null; then
    echo -e "${RED}Error: jq is required but not installed.${NC}"
    echo "Please install jq with: sudo apt-get install jq"
    exit 1
  fi
}

# Verify local development documentation exists
check_local_dev_docs() {
  if [[ ! -f "$LOCAL_DEV_FILE" ]]; then
    echo -e "${YELLOW}Warning: Local development documentation not found at $LOCAL_DEV_FILE${NC}"
    echo -e "${YELLOW}This documentation is important for understanding the local/remote testing workflow${NC}"
    echo -e "${YELLOW}Consider adding it with 'make alpha-fix --add-local-dev-docs'${NC}"
    return 1
  else
    echo -e "${GREEN}✓ Local/Remote workflow documentation found${NC}"
    return 0
  fi
}

# Get components from registry
get_all_components() {
  jq -r '.components | to_entries[] | .value | to_entries[] | .key' "$REGISTRY_FILE" | sort -u
}

# Check if a component has Makefile targets
has_makefile_targets() {
  local component="$1"
  local target_base="${component//_/-}"
  
  # Check for primary target
  grep -q "^$target_base:" "$MAKEFILE" || grep -q "^$target_base[[:space:]]" "$MAKEFILE"
  return $?
}

# Generate Makefile targets for a component
generate_targets() {
  local component="$1"
  local target_base="${component//_/-}"
  local script_name="install_${component}.sh"
  local component_path="${component//-/_}"
  
  cat << EOF >> "$OUTPUT_FILE"
# $component component targets
$target_base:
	@echo "\$(MAGENTA)\$(BOLD)Installing $component component...\$(RESET)"
	@\$(SCRIPTS_DIR)/components/$script_name \$(CLIENT_PARAM) \$(DOMAIN_PARAM) \$(VERBOSE_PARAM)
	@echo "\$(GREEN)✅ $component installation complete!\$(RESET)"

$target_base-status:
	@echo "\$(CYAN)Checking $component status...\$(RESET)"
	@if [ -f "\$(CLIENT_DIR)/$component_path/.installed_ok" ]; then \\
		echo "\$(GREEN)✅ $component is installed\$(RESET)"; \\
	else \\
		echo "\$(RED)❌ $component is not installed\$(RESET)"; \\
	fi
	@if [ -f "\$(SCRIPTS_DIR)/components/status_$component.sh" ]; then \\
		\$(SCRIPTS_DIR)/components/status_$component.sh \$(CLIENT_PARAM); \\
	fi

$target_base-logs:
	@echo "\$(CYAN)Displaying $component logs...\$(RESET)"
	@if [ -f "\$(LOG_DIR)/components/$component.log" ]; then \\
		tail -n 50 "\$(LOG_DIR)/components/$component.log"; \\
	else \\
		echo "\$(YELLOW)⚠️ No logs found for $component\$(RESET)"; \\
	fi

$target_base-restart:
	@echo "\$(CYAN)Restarting $component...\$(RESET)"
	@if [ -f "\$(SCRIPTS_DIR)/components/restart_$component.sh" ]; then \\
		\$(SCRIPTS_DIR)/components/restart_$component.sh \$(CLIENT_PARAM); \\
	else \\
		echo "\$(YELLOW)⚠️ No restart script found for $component\$(RESET)"; \\
		echo "\$(YELLOW)Consider creating \$(SCRIPTS_DIR)/components/restart_$component.sh\$(RESET)"; \\
	fi

$target_base-test-remote:
	@echo "\$(CYAN)Testing $component in a remote VM environment...\$(RESET)"
	@if [ -z "\$\${REMOTE_VM_SSH}" ]; then \\
		echo "\$(YELLOW)⚠️ REMOTE_VM_SSH environment variable not set\$(RESET)"; \\
		echo "\$(YELLOW)Set it with: export REMOTE_VM_SSH=user@vm-hostname\$(RESET)"; \\
		exit 1; \\
	fi
	@echo "\$(CYAN)Copying component script to remote VM for testing...\$(RESET)"
	@scp \$(SCRIPTS_DIR)/components/$script_name \$\${REMOTE_VM_SSH}:/tmp/
	@ssh \$\${REMOTE_VM_SSH} "cd /opt/agency_stack && bash /tmp/$script_name --verbose; echo \$\$?"
	@echo "\$(CYAN)VM test complete. Check output for errors.\$(RESET)"

EOF
}

# Add local/remote environment testing information to Makefile
generate_vm_test_targets() {
  cat << EOF >> "$OUTPUT_FILE"
# =============================================================================
# REMOTE VM TESTING TARGETS 
# =============================================================================

# Set up connection to test VM and verify environment
setup-vm-connection:
	@echo "\$(MAGENTA)\$(BOLD)Setting up remote VM connection...\$(RESET)"
	@if [ -z "\$\${REMOTE_VM_SSH}" ]; then \\
		echo "\$(YELLOW)⚠️ REMOTE_VM_SSH environment variable not set\$(RESET)"; \\
		echo "\$(YELLOW)Set it with: export REMOTE_VM_SSH=user@vm-hostname\$(RESET)"; \\
		exit 1; \\
	fi
	@echo "\$(CYAN)Testing SSH connection to \$\${REMOTE_VM_SSH}...\$(RESET)"
	@ssh \$\${REMOTE_VM_SSH} "echo Connected to \\\$(hostname) successfully"
	@echo "\$(GREEN)✅ Connection successful\$(RESET)"

# Deploy current repository to VM for testing
deploy-to-vm: setup-vm-connection
	@echo "\$(MAGENTA)\$(BOLD)Deploying current codebase to remote VM...\$(RESET)"
	@echo "\$(CYAN)Creating temporary archive...\$(RESET)"
	@tar czf /tmp/agency-stack-deploy.tar.gz -C \$(PWD) --exclude=".git" .
	@echo "\$(CYAN)Copying files to remote VM...\$(RESET)"
	@scp /tmp/agency-stack-deploy.tar.gz \$\${REMOTE_VM_SSH}:/tmp/
	@echo "\$(CYAN)Extracting on remote VM...\$(RESET)"
	@ssh \$\${REMOTE_VM_SSH} "mkdir -p ~/agency-stack && tar xzf /tmp/agency-stack-deploy.tar.gz -C ~/agency-stack"
	@echo "\$(GREEN)✅ Deployment complete. Files in ~/agency-stack on remote VM\$(RESET)"

# Run alpha-check on remote VM
vm-alpha-check: setup-vm-connection
	@echo "\$(MAGENTA)\$(BOLD)Running alpha-check on remote VM...\$(RESET)"
	@ssh \$\${REMOTE_VM_SSH} "cd ~/agency-stack && make alpha-check"

# Test one-line installer on remote VM (CAUTION: wipes existing installation!)
vm-test-installer: setup-vm-connection
	@echo "\$(MAGENTA)\$(BOLD)Testing one-line installer on remote VM...\$(RESET)"
	@echo "\$(RED)⚠️ WARNING: This will replace any existing installation!\$(RESET)"
	@echo "\$(YELLOW)Waiting 5 seconds - press Ctrl+C to abort\$(RESET)"
	@sleep 5
	@ssh \$\${REMOTE_VM_SSH} "curl -L https://stack.nerdofmouth.com/install.sh | bash"

EOF
}

# Main function
main() {
  check_dependencies
  
  echo -e "${MAGENTA}${BOLD}AgencyStack Makefile Target Generator${NC}"
  echo -e "${BLUE}Scanning component registry for missing targets...${NC}"
  
  # Clear output file
  > "$OUTPUT_FILE"
  
  # Add header to output file
  cat << EOF >> "$OUTPUT_FILE"
# =============================================================================
# GENERATED MAKEFILE TARGETS
# Generated by generate_makefile_targets.sh on $(date)
# =============================================================================
# This file contains targets for components that were missing in the Makefile.
# To use these targets, you can either:
# 1. Copy them directly into your Makefile, or
# 2. Use 'make alpha-fix' to automatically apply them.
# =============================================================================

EOF
  
  local missing_count=0
  local total_count=0
  
  # Check for local development documentation
  check_local_dev_docs
  
  while read -r component; do
    ((total_count++))
    if ! has_makefile_targets "$component"; then
      echo -e "${YELLOW}✘ Missing Makefile targets for: ${BOLD}$component${NC}"
      generate_targets "$component"
      ((missing_count++))
    else
      echo -e "${GREEN}✓ Found Makefile targets for: ${BOLD}$component${NC}"
    fi
  done < <(get_all_components)
  
  # Add VM testing targets
  generate_vm_test_targets
  
  echo
  echo -e "${BLUE}${BOLD}Summary:${NC}"
  echo -e "${BLUE}Total components: $total_count${NC}"
  echo -e "${BLUE}Components with missing targets: $missing_count${NC}"
  
  if [[ $missing_count -gt 0 ]]; then
    echo -e "${GREEN}Generated targets saved to: ${BOLD}$OUTPUT_FILE${NC}"
    echo -e "${YELLOW}To add these targets to your Makefile, run:${NC}"
    echo -e "${CYAN}  cat $OUTPUT_FILE >> $MAKEFILE${NC}"
    echo -e "${YELLOW}Or use the alpha-fix target:${NC}"
    echo -e "${CYAN}  make alpha-fix${NC}"
  else
    echo -e "${GREEN}All components have required Makefile targets!${NC}"
    # Still keep the VM testing targets
    if [[ -f "$OUTPUT_FILE" && $(wc -l < "$OUTPUT_FILE") -gt 50 ]]; then
      echo -e "${YELLOW}Added VM testing targets to: ${BOLD}$OUTPUT_FILE${NC}"
    else
      rm -f "$OUTPUT_FILE"
    fi
  fi
}

main "$@"
