#!/bin/bash
# vm_test_report.sh - Generate formatted reports for remote VM testing
# 
# This utility provides rich, colorful output for remote VM testing
# with clear success/failure indicators and timing information.
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

# Symbols
CHECK="✅"
CROSS="❌"
WARNING="⚠️"
INFO="ℹ️"
CLOCK="⏱️"

# Paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
REPORT_FILE="${PROJECT_ROOT}/vm_test_report.md"

# Results counters
PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

# Usage information
show_usage() {
  echo -e "${MAGENTA}${BOLD}VM Test Reporter${NC}"
  echo -e "Usage: $0 [options] <component>"
  echo
  echo "Options:"
  echo "  --verbose        Show detailed output"
  echo "  --markdown       Generate markdown report"
  echo "  --client-id      Set the CLIENT_ID for installation (default: default)"
  echo "  --help           Show this help message"
  echo
  echo "Examples:"
  echo "  $0 prerequisites"
  echo "  $0 --verbose traefik"
  echo "  $0 --markdown all"
  echo "  $0 --client-id=demo all"
}

# Parse arguments
VERBOSE=false
MARKDOWN=false
COMPONENT=""
CLIENT_ID="default"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --verbose)
      VERBOSE=true
      shift
      ;;
    --markdown)
      MARKDOWN=true
      shift
      ;;
    --client-id=*)
      CLIENT_ID="${1#*=}"
      shift
      ;;
    --help)
      show_usage
      exit 0
      ;;
    *)
      COMPONENT="$1"
      shift
      ;;
  esac
done

if [[ -z "$COMPONENT" ]]; then
  echo -e "${RED}Error: Component name required${NC}"
  show_usage
  exit 1
fi

# Check for SSH connection info
if [[ -z "${REMOTE_VM_SSH}" ]]; then
  echo -e "${RED}${BOLD}Error: REMOTE_VM_SSH environment variable not set${NC}"
  echo -e "Please set it with: ${YELLOW}export REMOTE_VM_SSH=user@vm-hostname${NC}"
  exit 1
fi

# Initialize report
init_report() {
  if [[ "$MARKDOWN" == "true" ]]; then
    cat > "$REPORT_FILE" << EOF
# AgencyStack VM Test Report
Generated: $(date '+%Y-%m-%d %H:%M:%S')

## Test Environment
- **Local Machine**: $(hostname)
- **Remote VM**: ${REMOTE_VM_SSH}
- **Component**: ${COMPONENT}
- **Client ID**: ${CLIENT_ID}

## Test Results
EOF
  fi
  
  echo -e "${MAGENTA}${BOLD}⚙️  AgencyStack VM Test Report${NC}"
  echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${CYAN}📊 Test Environment${NC}"
  echo -e "Local Machine: ${YELLOW}$(hostname)${NC}"
  echo -e "Remote VM:     ${YELLOW}${REMOTE_VM_SSH}${NC}"
  echo -e "Component:     ${YELLOW}${COMPONENT}${NC}"
  echo -e "Client ID:     ${YELLOW}${CLIENT_ID}${NC}"
  echo -e "Date:          ${YELLOW}$(date '+%Y-%m-%d %H:%M:%S')${NC}"
  echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Generate markdown report
generate_markdown_report() {
  # Add summary to report
  cat >> "$REPORT_FILE" << EOF

## Summary
- **Tests Passed**: ${PASS_COUNT}
- **Tests Failed**: ${FAIL_COUNT}
- **Warnings**: ${WARN_COUNT}

EOF

  if [[ $FAIL_COUNT -gt 0 ]]; then
    cat >> "$REPORT_FILE" << EOF
⚠️ **Some tests failed. Review the details above.**
EOF
  else
    cat >> "$REPORT_FILE" << EOF
🎉 **All tests passed successfully!**
EOF
  fi
  
  echo -e "${GREEN}${BOLD}Report generated:${NC} $REPORT_FILE"
}

# Add test result to report
add_result() {
  local test_name="$1"
  local status="$2"
  local message="$3"
  local duration="$4"
  
  local status_color=""
  local status_icon=""
  
  case "$status" in
    "PASS")
      status_color="${GREEN}"
      status_icon="${CHECK}"
      ((PASS_COUNT++))
      ;;
    "FAIL")
      status_color="${RED}"
      status_icon="${CROSS}"
      ((FAIL_COUNT++))
      ;;
    "WARN")
      status_color="${YELLOW}"
      status_icon="${WARNING}"
      ((WARN_COUNT++))
      ;;
    *)
      status_color="${BLUE}"
      status_icon="${INFO}"
      ;;
  esac
  
  if [[ "$MARKDOWN" == "true" ]]; then
    echo "### $test_name" >> "$REPORT_FILE"
    echo "**Status**: $status_icon $status" >> "$REPORT_FILE"
    echo "**Duration**: $duration" >> "$REPORT_FILE"
    echo "**Details**: $message" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
  fi
  
  echo -e "${CYAN}${BOLD}$test_name${NC}"
  echo -e "${status_color}${status_icon} ${BOLD}$status${NC} ${YELLOW}${CLOCK} $duration${NC}"
  echo -e "$message"
  echo -e "${CYAN}${BOLD}────────────────────────────────────────────────${NC}"
}

# Run a command on the remote VM and capture results
run_remote() {
  local cmd="$1"
  local test_name="$2"
  
  # Print command being executed
  echo -e "${YELLOW}Running: ${cmd}${NC}"
  
  # Set up SSH with proper terminal environment
  local ssh_options="-o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 -o BatchMode=no"
  local ssh_env="export TERM=xterm-256color && export CLIENT_ID=${CLIENT_ID}"
  
  local start_time=$(date +%s)
  
  # Run command and capture output
  local output
  local status="PASS"
  
  output=$(ssh $ssh_options ${REMOTE_VM_SSH} "${ssh_env} && cd /opt/agency_stack && ${cmd}" 2>&1)
  local exit_code=$?
  
  # Set status based on exit code
  if [[ $exit_code -ne 0 ]]; then
    status="FAIL"
  fi
  
  local end_time=$(date +%s)
  local duration=$((end_time - start_time))
  
  if [[ "$VERBOSE" == "true" ]]; then
    echo -e "${YELLOW}Output:${NC}"
    echo "$output"
  fi
  
  # Truncate output if it's too long
  local truncated_output
  if [[ ${#output} -gt 500 ]]; then
    truncated_output="${output:0:500}..."
  else
    truncated_output="$output"
  fi
  
  add_result "$test_name" "$status" "$truncated_output" "${duration}s"
  
  if [[ "$status" == "FAIL" ]]; then
    echo -e "${RED}Command failed with status $exit_code${NC}"
    if [[ "$VERBOSE" != "true" ]]; then
      echo -e "${YELLOW}Full output:${NC}"
      echo "$output"
    fi
  fi
}

# Test component installation
test_installation() {
  local component="$1"
  
  # Check connection
  run_remote "echo 'Connection test'" "VM Connection Test"
  
  # Check environment
  run_remote "uname -a && df -h /" "Environment Information"
  
  # Run component installation
  if [[ "$component" == "all" ]]; then
    run_remote "cd /opt/agency_stack && make install-all" "Full Installation"
  else
    run_remote "cd /opt/agency_stack && make $component" "Component Installation"
  fi
  
  # Test idempotence
  run_remote "cd /opt/agency_stack && make $component" "Idempotence Test"
  
  # Check component status
  run_remote "cd /opt/agency_stack && make $component-status" "Status Check"
  
  # Run alpha-check
  run_remote "cd /opt/agency_stack && make alpha-check" "Alpha Check"
}

# Default tests for vm-test-rich
run_default_tests() {
  echo -e "${MAGENTA}⚙️  Running VM Validation Tests${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  
  # Connection test
  run_remote "echo \"Connection test successful\"" "VM Connection Test"
  
  # Environment information
  run_remote "uname -a && df -h / && whoami && hostname" "Environment Information"
  
  # Check if we have a repo
  run_remote "test -d /opt/agency_stack && echo \"Directory exists\"" "Agency Stack Directory Check"
  
  echo -e "${MAGENTA}🔍 Running Standard Installation Tests${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  
  # Standard installation flow per the AgencyStack documentation
  run_remote "make prep-dirs" "Prepare Directories"
  run_remote "make env-check" "Environment Check"
  
  # Test individual components if specified
  if [[ -n "$COMPONENT" && "$COMPONENT" != "all" ]]; then
    run_remote "make $COMPONENT" "Component Installation: $COMPONENT"
    run_remote "make $COMPONENT-status" "Component Status: $COMPONENT"
    run_remote "make $COMPONENT" "Component Idempotence: $COMPONENT"
  else
    # Run complete installation flow
    run_remote "make install-all" "Complete Installation"
    run_remote "make alpha-check" "Alpha Validation"
  fi
  
  echo -e "${MAGENTA}📋 Final Report${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  
  echo -e "${GREEN}✅ Tests Passed: $PASS_COUNT${NC}"
  echo -e "${RED}❌ Tests Failed: $FAIL_COUNT${NC}"
  echo -e "${YELLOW}⚠️ Warnings: $WARN_COUNT${NC}"
  
  if [[ $FAIL_COUNT -gt 0 ]]; then
    echo -e "${RED}⚠️ Some tests failed. Review the output above for details.${NC}"
    echo -e "${YELLOW}Suggestion: Try running 'make vm-shell' to connect to the VM and debug manually.${NC}"
    return 1
  else
    echo -e "${GREEN}🎉 All tests passed successfully!${NC}"
    return 0
  fi
}

# Main function
main() {
  init_report
  
  if [[ "$COMPONENT" == "all" ]]; then
    run_default_tests
    result=$?
  else
    test_installation "$COMPONENT"
    result=$?
  fi
  
  if [[ "$MARKDOWN" == "true" ]]; then
    generate_markdown_report
  fi
  
  exit $result
}

main "$@"
