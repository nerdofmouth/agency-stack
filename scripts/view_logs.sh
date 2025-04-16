#!/bin/bash
# view_logs.sh - View AgencyStack logs
# https://stack.nerdofmouth.com

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Log directory
LOG_DIR="/var/log/agency_stack"

# Create log directory if it doesn't exist
if [ ! -d "$LOG_DIR" ]; then
  echo -e "${YELLOW}Creating log directory ${LOG_DIR}...${NC}"
  mkdir -p "$LOG_DIR"
  chmod 755 "$LOG_DIR"
fi

# Function to display menu
display_menu() {
  clear
  echo -e "${MAGENTA}${BOLD}📋 AgencyStack Logs Viewer${NC}"
  echo -e "=============================="
  echo
  echo -e "${CYAN}1) Installation logs${NC}"
  echo -e "${CYAN}2) Component logs${NC}"
  echo -e "${CYAN}3) Container logs${NC}"
  echo -e "${CYAN}4) All logs (last 100 lines)${NC}"
  echo -e "${CYAN}5) Live log tail${NC}"
  echo -e "${CYAN}6) Export logs to file${NC}"
  echo -e "${CYAN}0) Exit${NC}"
  echo
  echo -e "Enter your choice: "
}

# Function to view installation logs
view_installation_logs() {
  clear
  echo -e "${BLUE}${BOLD}Installation Logs:${NC}"
  echo -e "=============================="
  
  # List installation logs
  INSTALL_LOGS=$(find "$LOG_DIR" -name "install-*.log" -type f -printf "%T@ %p\n" | sort -nr | cut -d' ' -f2-)
  
  if [ -z "$INSTALL_LOGS" ]; then
    echo -e "${YELLOW}No installation logs found${NC}"
    read -p "Press Enter to continue..."
    return
  fi
  
  # Display options
  echo -e "${CYAN}Available installation logs:${NC}"
  local i=1
  local log_files=()
  
  while IFS= read -r log_file; do
    log_date=$(echo "$log_file" | grep -oP 'install-\K[0-9-]+' | tr '-' '/')
    echo -e "${i}) $(basename "$log_file") - $log_date"
    log_files[$i]="$log_file"
    ((i++))
  done <<< "$INSTALL_LOGS"
  
  echo -e "0) Back to main menu"
  echo
  
  # Get user choice
  read -p "Enter log number to view: " log_choice
  
  if [ "$log_choice" = "0" ]; then
    return
  elif [[ "$log_choice" =~ ^[0-9]+$ ]] && [ "$log_choice" -lt "$i" ]; then
    clear
    echo -e "${BLUE}${BOLD}Viewing ${log_files[$log_choice]}${NC}"
    echo -e "=============================="
    less -R "${log_files[$log_choice]}"
  else
    echo -e "${RED}Invalid choice${NC}"
    sleep 1
  fi
}

# Function to view component logs
view_component_logs() {
  clear
  echo -e "${BLUE}${BOLD}Component Logs:${NC}"
  echo -e "=============================="
  
  # List component logs
  COMPONENT_LOGS=$(find "$LOG_DIR" -name "component-*.log" -type f -printf "%T@ %p\n" | sort -nr | cut -d' ' -f2-)
  
  if [ -z "$COMPONENT_LOGS" ]; then
    echo -e "${YELLOW}No component logs found${NC}"
    read -p "Press Enter to continue..."
    return
  fi
  
  # Display options
  echo -e "${CYAN}Available component logs:${NC}"
  local i=1
  local log_files=()
  
  while IFS= read -r log_file; do
    component=$(basename "$log_file" | sed 's/component-//' | sed 's/.log//')
    echo -e "${i}) $component"
    log_files[$i]="$log_file"
    ((i++))
  done <<< "$COMPONENT_LOGS"
  
  echo -e "0) Back to main menu"
  echo
  
  # Get user choice
  read -p "Enter log number to view: " log_choice
  
  if [ "$log_choice" = "0" ]; then
    return
  elif [[ "$log_choice" =~ ^[0-9]+$ ]] && [ "$log_choice" -lt "$i" ]; then
    clear
    echo -e "${BLUE}${BOLD}Viewing ${log_files[$log_choice]}${NC}"
    echo -e "=============================="
    less -R "${log_files[$log_choice]}"
  else
    echo -e "${RED}Invalid choice${NC}"
    sleep 1
  fi
}

# Function to view container logs
view_container_logs() {
  clear
  echo -e "${BLUE}${BOLD}Container Logs:${NC}"
  echo -e "=============================="
  
  # Check if Docker is installed
  if ! command -v docker &> /dev/null; then
    echo -e "${RED}Docker is not installed${NC}"
    read -p "Press Enter to continue..."
    return
  fi
  
  # Get running containers
  CONTAINERS=$(docker ps --format "{{.Names}}")
  
  if [ -z "$CONTAINERS" ]; then
    echo -e "${YELLOW}No running containers found${NC}"
    read -p "Press Enter to continue..."
    return
  fi
  
  # Display options
  echo -e "${CYAN}Running containers:${NC}"
  local i=1
  local container_names=()
  
  while IFS= read -r container; do
    echo -e "${i}) $container"
    container_names[$i]="$container"
    ((i++))
  done <<< "$CONTAINERS"
  
  echo -e "0) Back to main menu"
  echo
  
  # Get user choice
  read -p "Enter container number to view logs: " container_choice
  
  if [ "$container_choice" = "0" ]; then
    return
  elif [[ "$container_choice" =~ ^[0-9]+$ ]] && [ "$container_choice" -lt "$i" ]; then
    clear
    echo -e "${BLUE}${BOLD}Viewing logs for ${container_names[$container_choice]}${NC}"
    echo -e "=============================="
    
    # Let user choose lines
    read -p "Number of lines to view (default: 100): " lines
    lines=${lines:-100}
    
    docker logs "${container_names[$container_choice]}" --tail "$lines"
    echo
    read -p "Press Enter to continue..."
  else
    echo -e "${RED}Invalid choice${NC}"
    sleep 1
  fi
}

# Function to view all logs
view_all_logs() {
  clear
  echo -e "${BLUE}${BOLD}All Logs (last 100 lines):${NC}"
  echo -e "=============================="
  
  # Check if there are any logs
  if [ ! "$(ls -A "$LOG_DIR" 2>/dev/null)" ]; then
    echo -e "${YELLOW}No logs found${NC}"
    read -p "Press Enter to continue..."
    return
  fi
  
  # View all logs (last 100 lines each)
  for log_file in "$LOG_DIR"/*.log; do
    if [ -f "$log_file" ]; then
      echo -e "${CYAN}${BOLD}$(basename "$log_file"):${NC}"
      echo -e "------------------------------"
      tail -n 100 "$log_file" | grep --color=auto -E "ERROR|WARN|$"
      echo
    fi
  done
  
  read -p "Press Enter to continue..."
}

# Function to tail logs
tail_logs() {
  clear
  echo -e "${BLUE}${BOLD}Live Log Tail:${NC}"
  echo -e "=============================="
  echo -e "${YELLOW}Press Ctrl+C to stop${NC}"
  echo
  
  # Tail all logs
  tail -f "$LOG_DIR"/*.log
}

# Function to export logs
export_logs() {
  clear
  echo -e "${BLUE}${BOLD}Export Logs:${NC}"
  echo -e "=============================="
  
  # Generate archive name
  TIMESTAMP=$(date +%Y%m%d-%H%M%S)
  ARCHIVE_NAME="agency_stack_logs_$TIMESTAMP.tar.gz"
  EXPORT_PATH="$HOME/$ARCHIVE_NAME"
  
  # Create archive
  echo -e "${CYAN}Creating log archive...${NC}"
  tar -czf "$EXPORT_PATH" -C "/var/log" agency_stack
  
  if [ $? -eq 0 ]; then
    echo -e "${GREEN}Logs exported to: $EXPORT_PATH${NC}"
    
    # Option to include Docker logs
    read -p "Include Docker container logs? (y/n): " include_docker
    
    if [[ "$include_docker" =~ ^[Yy]$ ]]; then
      DOCKER_LOGS="$HOME/docker_logs_$TIMESTAMP"
      mkdir -p "$DOCKER_LOGS"
      
      echo -e "${CYAN}Exporting Docker logs...${NC}"
      
      # Get all container names
      CONTAINERS=$(docker ps -a --format "{{.Names}}")
      
      while IFS= read -r container; do
        docker logs "$container" > "$DOCKER_LOGS/$container.log" 2>&1
      done <<< "$CONTAINERS"
      
      # Add to archive
      tar -czf "$EXPORT_PATH" -C "$HOME" "docker_logs_$TIMESTAMP"
      rm -rf "$DOCKER_LOGS"
      
      echo -e "${GREEN}Docker logs added to archive${NC}"
    fi
    
    echo
    echo -e "${CYAN}You can copy this file to your local machine with:${NC}"
    echo -e "scp user@$(hostname):$EXPORT_PATH ."
  else
    echo -e "${RED}Failed to create archive${NC}"
  fi
  
  read -p "Press Enter to continue..."
}

# Main menu loop
while true; do
  display_menu
  read -p "" choice
  
  case $choice in
    0)
      echo -e "${GREEN}Exiting...${NC}"
      exit 0
      ;;
    1)
      view_installation_logs
      ;;
    2)
      view_component_logs
      ;;
    3)
      view_container_logs
      ;;
    4)
      view_all_logs
      ;;
    5)
      tail_logs
      ;;
    6)
      export_logs
      ;;
    *)
      echo -e "${RED}Invalid choice${NC}"
      sleep 1
      ;;
  esac
done
