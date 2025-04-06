#!/bin/bash
# AgencyStack - Alpha Check Script
# Comprehensive validation for all AgencyStack components
# v0.1.0-alpha

# Colors
BOLD="\033[1m"
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
MAGENTA="\033[35m"
CYAN="\033[36m"
RESET="\033[0m"

# File paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
LOGS_DIR="/var/log/agency_stack"
ALPHA_LOG="${LOGS_DIR}/alpha_check.log"

# Ensure log directory exists
mkdir -p "$LOGS_DIR" 2>/dev/null || true

# Component registry
COMPONENT_REGISTRY="${BASE_DIR}/component_registry.json"

# Track statistics
TOTAL_COMPONENTS=0
PASSED_COMPONENTS=0
WARNED_COMPONENTS=0
FAILED_COMPONENTS=0

# Parse command line arguments
VERBOSE=false

while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    --verbose)
      VERBOSE=true
      shift
      ;;
    *)
      shift
      ;;
  esac
done

# Log alpha check start
log_start() {
  echo "$(date): AgencyStack Alpha Check started" > "$ALPHA_LOG"
  echo "----------------------------------------" >> "$ALPHA_LOG"
}

# Log alpha check completion
log_completion() {
  echo "----------------------------------------" >> "$ALPHA_LOG"
  echo "$(date): AgencyStack Alpha Check completed" >> "$ALPHA_LOG"
  echo "Total components: $TOTAL_COMPONENTS" >> "$ALPHA_LOG"
  echo "Passed: $PASSED_COMPONENTS" >> "$ALPHA_LOG"
  echo "Warnings: $WARNED_COMPONENTS" >> "$ALPHA_LOG"
  echo "Failed: $FAILED_COMPONENTS" >> "$ALPHA_LOG"
}

# Log a component check
log_component_check() {
  local component="$1"
  local status="$2"
  local message="$3"
  
  echo "$(date): [$component] $status - $message" >> "$ALPHA_LOG"
}

# Check if a component has required targets in Makefile
check_makefile_targets() {
  local component="$1"
  local makefile="${BASE_DIR}/Makefile"
  local missing_targets=()
  
  # Required targets
  local targets=(
    "$component"
    "$component-status"
    "$component-logs"
    "$component-restart"
  )
  
  for target in "${targets[@]}"; do
    if ! grep -q "^$target:" "$makefile"; then
      missing_targets+=("$target")
    fi
  done
  
  if [ ${#missing_targets[@]} -eq 0 ]; then
    if [ "$VERBOSE" = true ]; then
      echo -e "  ${GREEN}✓ All Makefile targets implemented${RESET}"
    fi
    log_component_check "$component" "PASS" "All Makefile targets implemented"
    return 0
  else
    echo -e "  ${YELLOW}⚠️ Missing Makefile targets: ${missing_targets[*]}${RESET}"
    log_component_check "$component" "WARN" "Missing Makefile targets: ${missing_targets[*]}"
    return 1
  fi
}

# Check if component has documentation
check_documentation() {
  local component="$1"
  local docs_file="${BASE_DIR}/docs/pages/components/${component}.md"
  
  if [ -f "$docs_file" ]; then
    if [ "$VERBOSE" = true ]; then
      echo -e "  ${GREEN}✓ Documentation exists${RESET}"
    fi
    log_component_check "$component" "PASS" "Documentation exists"
    return 0
  else
    echo -e "  ${YELLOW}⚠️ Missing documentation: $docs_file${RESET}"
    log_component_check "$component" "WARN" "Missing documentation: $docs_file"
    return 1
  fi
}

# Check if component has an install script
check_install_script() {
  local component="$1"
  local install_script="${SCRIPT_DIR}/components/install_${component}.sh"
  
  if [ -f "$install_script" ]; then
    if [ "$VERBOSE" = true ]; then
      echo -e "  ${GREEN}✓ Install script exists${RESET}"
    fi
    log_component_check "$component" "PASS" "Install script exists"
    return 0
  else
    echo -e "  ${YELLOW}⚠️ Missing install script: $install_script${RESET}"
    log_component_check "$component" "WARN" "Missing install script: $install_script"
    return 1
  fi
}

# Check if component is running (if it's installed)
check_running_status() {
  local component="$1"
  local result
  
  # Try to run the status check via make
  result=$(make -f "${BASE_DIR}/Makefile" "$component-status" 2>&1)
  
  if echo "$result" | grep -q "successfully" || echo "$result" | grep -q "running"; then
    if [ "$VERBOSE" = true ]; then
      echo -e "  ${GREEN}✓ Component is running${RESET}"
    fi
    log_component_check "$component" "PASS" "Component is running"
    return 0
  elif echo "$result" | grep -q "not installed"; then
    echo -e "  ${YELLOW}⚠️ Component is not installed${RESET}"
    log_component_check "$component" "WARN" "Component is not installed"
    return 1
  else
    echo -e "  ${RED}❌ Component is not running${RESET}"
    log_component_check "$component" "FAIL" "Component is not running"
    return 2
  fi
}

# Check component's log files
check_log_files() {
  local component="$1"
  local component_log="${LOGS_DIR}/components/${component}.log"
  
  if [ -f "$component_log" ]; then
    if [ "$VERBOSE" = true ]; then
      echo -e "  ${GREEN}✓ Log file exists${RESET}"
    fi
    log_component_check "$component" "PASS" "Log file exists"
    return 0
  else
    echo -e "  ${YELLOW}⚠️ Missing log file: $component_log${RESET}"
    log_component_check "$component" "WARN" "Missing log file: $component_log"
    return 1
  fi
}

# Check integration status
check_integration_status() {
  local component="$1"
  
  # Check if there's an integration status file
  local integration_status="${BASE_DIR}/integration_status.json"
  
  if [ -f "$integration_status" ]; then
    if grep -q "\"$component\":" "$integration_status"; then
      if [ "$VERBOSE" = true ]; then
        echo -e "  ${GREEN}✓ Found in integration status${RESET}"
      fi
      log_component_check "$component" "PASS" "Found in integration status"
      return 0
    else
      echo -e "  ${YELLOW}⚠️ Not found in integration status${RESET}"
      log_component_check "$component" "WARN" "Not found in integration status"
      return 1
    fi
  else
    echo -e "  ${YELLOW}⚠️ Integration status file not found${RESET}"
    log_component_check "$component" "WARN" "Integration status file not found"
    return 1
  fi
}

# Perform a full check on a component
check_component() {
  local component="$1"
  local component_name="$2"
  local warnings=0
  local failures=0
  
  echo -e "${CYAN}${BOLD}Checking ${component_name}...${RESET}"
  
  # Increment total components
  TOTAL_COMPONENTS=$((TOTAL_COMPONENTS + 1))
  
  # Check Makefile targets
  check_makefile_targets "$component"
  warnings=$((warnings + $?))
  
  # Check documentation
  check_documentation "$component"
  warnings=$((warnings + $?))
  
  # Check install script
  check_install_script "$component"
  warnings=$((warnings + $?))
  
  # Check running status
  check_running_status "$component"
  status=$?
  if [ $status -eq 2 ]; then
    failures=$((failures + 1))
  elif [ $status -eq 1 ]; then
    warnings=$((warnings + 1))
  fi
  
  # Check log files
  check_log_files "$component"
  warnings=$((warnings + $?))
  
  # Check integration status
  check_integration_status "$component"
  warnings=$((warnings + $?))
  
  # Display result
  if [ $failures -gt 0 ]; then
    echo -e "${RED}${BOLD}✘ ${component_name} has $failures failures and $warnings warnings${RESET}\n"
    FAILED_COMPONENTS=$((FAILED_COMPONENTS + 1))
  elif [ $warnings -gt 0 ]; then
    echo -e "${YELLOW}${BOLD}⚠️ ${component_name} has $warnings warnings${RESET}\n"
    WARNED_COMPONENTS=$((WARNED_COMPONENTS + 1))
  else
    echo -e "${GREEN}${BOLD}✓ ${component_name} passed all checks${RESET}\n"
    PASSED_COMPONENTS=$((PASSED_COMPONENTS + 1))
  fi
}

# Check core infrastructure components
check_core_infrastructure() {
  echo -e "${MAGENTA}${BOLD}🏗️ Checking Core Infrastructure Components...${RESET}\n"
  
  check_component "docker" "Docker"
  check_component "docker_compose" "Docker Compose"
  check_component "traefik_ssl" "Traefik SSL"
  check_component "portainer" "Portainer"
}

# Check security components
check_security_components() {
  echo -e "${MAGENTA}${BOLD}🔒 Checking Security Components...${RESET}\n"
  
  check_component "keycloak" "Keycloak"
  check_component "fail2ban" "Fail2Ban"
  check_component "crowdsec" "CrowdSec"
  check_component "security" "Security Infrastructure"
}

# Check monitoring components
check_monitoring_components() {
  echo -e "${MAGENTA}${BOLD}📊 Checking Monitoring Components...${RESET}\n"
  
  check_component "prometheus" "Prometheus"
  check_component "grafana" "Grafana"
  check_component "loki" "Loki"
  check_component "netdata" "Netdata"
}

# Check content & media components
check_content_components() {
  echo -e "${MAGENTA}${BOLD}📄 Checking Content & Media Components...${RESET}\n"
  
  check_component "wordpress" "WordPress"
  check_component "ghost" "Ghost"
  check_component "peertube" "PeerTube"
  check_component "seafile" "Seafile"
  check_component "focalboard" "Focalboard"
  check_component "builderio" "Builder.io"
}

# Check database components
check_database_components() {
  echo -e "${MAGENTA}${BOLD}🗄️ Checking Database Components...${RESET}\n"
  
  check_component "elasticsearch" "ElasticSearch"
  check_component "etcd" "ETCD"
  check_component "vector_db" "Vector DB"
}

# Check communication components
check_communication_components() {
  echo -e "${MAGENTA}${BOLD}📧 Checking Communication Components...${RESET}\n"
  
  check_component "mailu" "Mailu"
  check_component "listmonk" "Listmonk"
  check_component "chatwoot" "Chatwoot"
  check_component "webpush" "WebPush"
}

# Check integration components
check_integration_components() {
  echo -e "${MAGENTA}${BOLD}🔄 Checking Integration Components...${RESET}\n"
  
  check_component "n8n" "n8n"
  check_component "openintegrationhub" "OpenIntegrationHub"
  check_component "droneci" "DroneCI"
}

# Check AI components
check_ai_components() {
  echo -e "${MAGENTA}${BOLD}🧠 Checking AI Components...${RESET}\n"
  
  check_component "ollama" "Ollama"
  check_component "langchain" "LangChain"
  check_component "ai_dashboard" "AI Dashboard"
  check_component "agent_orchestrator" "Agent Orchestrator"
  check_component "resource_watcher" "Resource Watcher"
}

# Check utility components
check_utility_components() {
  echo -e "${MAGENTA}${BOLD}🛠️ Checking Utility Components...${RESET}\n"
  
  check_component "multi_tenancy" "Multi-Tenancy"
  check_component "taskwarrior_calcure" "TaskWarrior/Calcure"
  check_component "backup_strategy" "Backup Strategy"
  check_component "launchpad_dashboard" "Launchpad Dashboard"
  check_component "tailscale" "Tailscale"
}

# Main function
main() {
  echo -e "${MAGENTA}${BOLD}🚀 AgencyStack Alpha Check v0.1.0-alpha${RESET}"
  echo -e "${BLUE}Running comprehensive validation of all components...${RESET}\n"
  
  # Start logging
  log_start
  
  # Check all component categories
  check_core_infrastructure
  check_security_components
  check_monitoring_components
  check_content_components
  check_database_components
  check_communication_components
  check_integration_components
  check_ai_components
  check_utility_components
  
  # Display summary
  echo -e "${MAGENTA}${BOLD}📊 Alpha Check Summary${RESET}"
  echo -e "${BLUE}----------------------------------------${RESET}"
  echo -e "${BLUE}Total components checked:${RESET} ${BOLD}$TOTAL_COMPONENTS${RESET}"
  echo -e "${GREEN}✓ Passed:${RESET} ${BOLD}$PASSED_COMPONENTS${RESET}"
  echo -e "${YELLOW}⚠️ Warnings:${RESET} ${BOLD}$WARNED_COMPONENTS${RESET}"
  echo -e "${RED}✘ Failed:${RESET} ${BOLD}$FAILED_COMPONENTS${RESET}"
  echo -e "${BLUE}----------------------------------------${RESET}"
  
  # Complete logging
  log_completion
  
  # Display results
  if [ $FAILED_COMPONENTS -gt 0 ]; then
    echo -e "${RED}${BOLD}✘ Alpha check detected $FAILED_COMPONENTS component failures.${RESET}"
    echo -e "${YELLOW}Please fix these issues before proceeding to release.${RESET}"
    exit 1
  elif [ $WARNED_COMPONENTS -gt 0 ]; then
    echo -e "${YELLOW}${BOLD}⚠️ Alpha check completed with $WARNED_COMPONENTS component warnings.${RESET}"
    echo -e "${BLUE}These are not critical but should be addressed before final release.${RESET}"
    echo -e "${GREEN}✓ All critical components are functioning properly.${RESET}"
    exit 0
  else
    echo -e "${GREEN}${BOLD}✓ Alpha check completed successfully! All components passed.${RESET}"
    echo -e "${BLUE}AgencyStack v0.1.0-alpha is ready for release.${RESET}"
    exit 0
  fi
}

# Run main function
main "$@"
