# Portainer

## Overview
Container management UI

## Installation

### Prerequisites
- List of prerequisites

### Installation Process
The installation is handled by the `install_portainer.sh` script, which can be executed using:

```bash
make portainer
```

## Configuration

### Default Configuration
- Configuration details

### Customization
- How to customize

Configuration files can be found at `/opt/agency_stack/clients/${CLIENT_ID}/portainer/config/`.

## Usage

### Accessing Portainer

Access the Portainer web interface through your browser:

```bash
# Open Portainer interface
open https://portainer.yourdomain.com

# Login using:
# - Keycloak SSO (if enabled)
# - Local admin credentials created during installation
```

### Managing Docker Containers

Portainer provides a comprehensive UI for container management:

```bash
# View all containers
# Navigate to Containers → List
# Filter by status, name, or network

# Container operations
# Start/Stop/Restart: Use buttons in the Actions column
# Logs: Click container name → Logs tab
# Console: Click container name → Console tab
# Stats: Click container name → Stats tab
```

### Working with Docker Stacks

Deploy and manage multi-container applications:

```bash
# Create a new stack
# Stacks → Add stack
# Enter stack name and compose file
# Click "Deploy the stack"

# Update existing stack
# Stacks → Select stack → Editor
# Modify compose file
# Click "Update the stack"
```

### Managing Docker Volumes

Persistent data management:

```bash
# Create a volume
# Volumes → Add volume
# Specify name and driver options

# Attach volume to container
# When creating/updating container
# Add volume mapping in the Volumes tab
```

### Managing Docker Networks

Configure container networking:

```bash
# Create a network
# Networks → Add network
# Specify name, driver, and subnet

# Connect containers to network
# When creating/updating container
# Select network in the Network tab
```

### Using Portainer API

Automate Portainer operations via API:

```bash
# Generate API key
# User profile → API keys → Add API key

# Example API usage (curl)
curl -X GET "https://portainer.yourdomain.com/api/endpoints" \
  -H "X-API-Key: YOUR_API_KEY"
```

### Multi-tenant Administration

For environments with multiple clients:

```bash
# Create separate Portainer teams
# Settings → Users & Teams → Teams → Add team
# Assign users to teams

# Create environment groups
# Environments → Groups → Add group
# Assign access rights to teams
```

## Ports & Endpoints

| Service | Port | Protocol | Description |
|---------|------|----------|-------------|
| Web UI  | XXXX | HTTP/S   | Main web interface |

## Logs & Monitoring

### Log Files
- `/var/log/agency_stack/components/portainer.log`

### Monitoring
- Metrics and monitoring information

## Troubleshooting

### Common Issues
- List of common issues and their solutions

## Makefile Targets

| Target | Description |
|--------|-------------|
| `make portainer` | Install portainer |
| `make portainer-status` | Check status of portainer |
| `make portainer-logs` | View portainer logs |
| `make portainer-restart` | Restart portainer services |
