#!/bin/bash
# port_manager.sh - Centralized port management for FOSS Server Stack
# This script provides functions to manage port allocation and avoid conflicts

# Port allocation database file
PORT_DB="/opt/foss-server-stack/port_allocation.json"
# If the file doesn't exist, initialize it
if [ ! -f "$PORT_DB" ]; then
  mkdir -p /opt/foss-server-stack
  echo '{}' > "$PORT_DB"
fi

# Function to check if a port is free
is_port_free() {
  local port="$1"
  # Check if any process is listening on this port
  ! ss -tuln | grep -q ":$port "
}

# Function to get the next available port
get_next_available_port() {
  local base_port="$1"
  local current_port="$base_port"
  
  # Try up to 100 ports after the base port
  for ((i=0; i<100; i++)); do
    if is_port_free "$current_port"; then
      echo "$current_port"
      return 0
    fi
    ((current_port++))
  done
  
  echo "Error: Could not find an available port after $base_port" >&2
  return 1
}

# Function to register a service's port
register_port() {
  local service_name="$1"
  local preferred_port="$2"
  local allocation_type="$3"  # 'fixed' or 'flexible'
  
  # Read current port allocation
  local port_data=$(cat "$PORT_DB")
  
  # Check if service already has an allocated port
  if echo "$port_data" | grep -q "\"$service_name\""; then
    # Service exists, get its current port
    local current_port=$(echo "$port_data" | grep -o "\"$service_name\":[0-9]*" | cut -d':' -f2)
    
    # Check if the port is still free, otherwise reallocate
    if is_port_free "$current_port"; then
      echo "$current_port"
      return 0
    elif [ "$allocation_type" = "fixed" ]; then
      echo "Warning: Service $service_name requires fixed port $preferred_port but it's in use. Conflicts may occur!" >&2
      echo "$preferred_port"
      return 0
    fi
    # If we're here, we need to reallocate a flexible port
  fi
  
  # Allocate a new port
  local new_port
  if [ "$allocation_type" = "fixed" ]; then
    new_port="$preferred_port"
    if ! is_port_free "$new_port"; then
      echo "Warning: Fixed port $new_port for $service_name is not free. Using it anyway as requested." >&2
    fi
  else
    new_port=$(get_next_available_port "$preferred_port")
  fi
  
  # Update the port database
  # Remove the service if it exists
  port_data=$(echo "$port_data" | sed "s/\"$service_name\":[0-9]*,//g" | sed "s/,\"$service_name\":[0-9]*//g" | sed "s/\"$service_name\":[0-9]*//g")
  
  # Add the service with the new port
  if [ "$port_data" = "{}" ]; then
    port_data="{\"$service_name\":$new_port}"
  else
    # Remove the closing brace, add our entry, and put the brace back
    port_data=${port_data%\}}
    # Check if we need a comma
    if [ "${port_data: -1}" != "{" ]; then
      port_data="$port_data,\"$service_name\":$new_port}"
    else
      port_data="$port_data\"$service_name\":$new_port}"
    fi
  fi
  
  # Save the updated data
  echo "$port_data" > "$PORT_DB"
  
  # Return the allocated port
  echo "$new_port"
}

# Function to get a registered port
get_port() {
  local service_name="$1"
  local default_port="$2"
  
  # If the port database doesn't exist yet, return the default
  if [ ! -f "$PORT_DB" ]; then
    echo "$default_port"
    return 0
  fi
  
  # Read current port allocation
  local port_data=$(cat "$PORT_DB")
  
  # Check if service has an allocated port
  if echo "$port_data" | grep -q "\"$service_name\""; then
    # Get the allocated port
    local allocated_port=$(echo "$port_data" | grep -o "\"$service_name\":[0-9]*" | cut -d':' -f2)
    echo "$allocated_port"
  else
    # Service doesn't exist, return default
    echo "$default_port"
  fi
}

# Function to list all allocated ports
list_ports() {
  echo "Current Port Allocations:"
  echo "========================="
  
  # If the port database doesn't exist, say so
  if [ ! -f "$PORT_DB" ]; then
    echo "No port allocations found."
    return 0
  fi
  
  # Read and format the port data
  local port_data=$(cat "$PORT_DB")
  
  # Remove the brackets
  port_data=${port_data#\{}
  port_data=${port_data%\}}
  
  # Split by comma and format each entry
  IFS=',' read -ra entries <<< "$port_data"
  for entry in "${entries[@]}"; do
    service=$(echo "$entry" | cut -d':' -f1 | tr -d '"')
    port=$(echo "$entry" | cut -d':' -f2)
    printf "%-30s %s\n" "$service" "$port"
  done
}

# If this script is run directly, show the usage
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  case "$1" in
    register)
      if [ "$#" -lt 3 ]; then
        echo "Usage: $0 register SERVICE_NAME PREFERRED_PORT [fixed|flexible]"
        exit 1
      fi
      allocation_type="${4:-flexible}"
      register_port "$2" "$3" "$allocation_type"
      ;;
    get)
      if [ "$#" -lt 3 ]; then
        echo "Usage: $0 get SERVICE_NAME DEFAULT_PORT"
        exit 1
      fi
      get_port "$2" "$3"
      ;;
    list)
      list_ports
      ;;
    *)
      echo "Usage: $0 {register|get|list} [arguments]"
      echo "  register SERVICE_NAME PREFERRED_PORT [fixed|flexible] - Register a service port"
      echo "  get SERVICE_NAME DEFAULT_PORT - Get a registered port or default if not registered"
      echo "  list - List all allocated ports"
      exit 1
      ;;
  esac
fi
