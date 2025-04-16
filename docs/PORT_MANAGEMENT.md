# 🔌 Port Management System

The FOSS Server Stack includes a dynamic port management system to prevent conflicts and ensure smooth operation of all services.

## Overview

When running multiple services on a single server, port conflicts can cause installation failures and difficult-to-debug issues. The port management system:

1. **Automatically allocates ports** to prevent conflicts
2. **Maintains a central registry** of all service ports
3. **Provides flexibility** for both new installations and upgrades
4. **Simplifies troubleshooting** by making port assignments explicit

## How It Works

The port management system assigns and tracks ports in a JSON database at `/opt/foss-server-stack/port_allocation.json`. Each service can request either:

- **Fixed ports** - For services that must use a specific port (e.g., web servers on 80/443)
- **Flexible ports** - For services that can operate on any available port

If a requested port is already in use, the system will automatically assign the next available port.

## Using the Port Manager

### From Installation Scripts

Installation scripts automatically use the port manager:

```bash
# Source the port manager
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$SCRIPT_DIR/../../scripts/port_manager.sh"

# Register a port (returns the assigned port)
SERVICE_PORT=$(register_port "service_name" "8080" "flexible")

# Use the assigned port in configurations
echo "Service will use port: $SERVICE_PORT"
```

### Command Line Usage

You can also manage ports directly from the command line:

```bash
# Register a new port (or get existing allocation)
./scripts/port_manager.sh register service_name preferred_port [fixed|flexible]

# Get an existing port assignment
./scripts/port_manager.sh get service_name default_port

# List all port allocations
./scripts/port_manager.sh list
```

## For Existing Installations

If you're implementing the port manager on an existing installation:

1. Run the port migration script to register current ports:
   ```bash
   ./scripts/migrate_ports.sh
   ```

2. Review the allocated ports and adjust if needed:
   ```bash
   ./scripts/port_manager.sh list
   ./scripts/port_manager.sh register service_name new_port [fixed|flexible]
   ```

## Troubleshooting

### Port Conflicts

If you see a warning about a fixed port being in use, you have options:

1. Stop the process using that port
2. Modify the service to use a flexible port instead
3. Manually update the port in the service's configuration

### Finding Port Information

To see which service is using a particular port:

```bash
ss -tulpn | grep :PORT_NUMBER
```

### Resetting Port Allocations

If needed, you can reset all port allocations:

```bash
rm /opt/foss-server-stack/port_allocation.json
```

New installations will recreate the database with default values.
