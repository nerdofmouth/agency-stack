# MCP Server - AgencyStack Validation Component

![AgencyStack Component](https://img.shields.io/badge/AgencyStack-MCP%20Server-blue)
![Version](https://img.shields.io/badge/Version-1.0.0-green)
![Charter Compliant](https://img.shields.io/badge/Charter-v1.0.3-orange)

## Overview

The Model Context Protocol (MCP) server provides validation, verification, and monitoring capabilities for AgencyStack deployments. It ensures Charter compliance for scripts, validates WordPress deployments, and provides a centralized monitoring system for deployment operations.

## Installation & Requirements

### Prerequisites
- Docker & Docker Compose
- Node.js 18+
- Properly configured Docker networks for container communication

### Installation Location
Following AgencyStack Charter directory conventions:
- Installation scripts: `/scripts/components/mcp/`
- Documentation: `/docs/pages/components/mcp_server.md`
- Logs: `/var/log/agency_stack/components/mcp/`
- Installation output: `/opt/agency_stack/clients/${CLIENT_ID}/mcp/`

### Installation Commands
```bash
# Install MCP server for a client
make install-mcp CLIENT_ID=peacefestivalusa

# Or directly using the installation script
bash /scripts/components/install_mcp_server.sh peacefestivalusa
```

## Configuration

The MCP server is configured through environment variables:

| Variable | Description | Default |
|----------|-------------|---------|
| `MCP_PORT` | Port for MCP server | `3000` |
| `CLIENT_ID` | Client ID for deployment tracking | `agencystack` |
| `LOG_LEVEL` | Logging detail level | `info` |

## Component Features

### 1. Script Validation
Validates scripts against AgencyStack Charter principles including:
- Containerization enforcement
- Repository integrity
- Idempotency patterns
- Proper logging

### 2. WordPress Validation
Validates WordPress deployments by checking:
- Frontend accessibility
- Admin interface accessibility
- WordPress installation detection
- Configuration consistency

### 3. Deployment Tracking
Monitors deployment operations with:
- Start/completion notifications
- Success/failure status
- Detailed deployment metadata
- Component relationship mapping

## AgencyStack Three-Layer Architecture Model

The MCP server is designed to operate within AgencyStack's three-layer architecture model:

1. **Outer Layer: Windows/Host OS**
   - Serves as the development and management environment
   - Interacts with the MCP server through mapped ports (3000)
   - Provides browser-based access to MCP server dashboards and APIs
   - Uses repository code as the single source of truth

2. **Middle Layer: Ubuntu VM**
   - Provides the containerization environment 
   - Hosts the Docker engine and container infrastructure
   - Maintains filesystem paths following Charter standards
   - Manages logs, configurations, and persistent storage

3. **Lower Layer: Containerized Services**
   - MCP server runs in a dedicated Docker container
   - Strictly isolated from host system per Charter requirements
   - Communicates with other containers through Docker networks
   - Uses container-specific network resolution for service discovery

### Network Flow Across Layers

```
┌─────────────────────┐
│  Windows/Host OS    │
│  (Outer Layer)      │
│  - Browser access   │
│  - Repository mgmt  │
└─────────┬───────────┘
          │ HTTP ports
          ▼
┌─────────────────────┐
│  Ubuntu VM          │
│  (Middle Layer)     │
│  - Docker engine    │
│  - File storage     │
└─────────┬───────────┘
          │ docker exec
          ▼
┌─────────────────────┐
│  Docker Containers  │
│  (Lower Layer)      │
│  - MCP Server       │
│  - WordPress        │
└─────────────────────┘
```

## Integration with Other Components

The MCP server integrates with other AgencyStack components through:

1. **Docker Network Integration**
   - Container-to-container communication using Docker's internal DNS
   - Container-to-host communication using host.docker.internal
   - Strict network isolation for security
   - Custom handling for WordPress container redirects

2. **WordPress Deployment Integration**
   - Validates WordPress installations post-deployment
   - Ensures configuration consistency
   - Verifies accessibility across network boundaries
   - Handles multi-layer network translations

3. **CI/CD Pipeline Integration**
   - Validates scripts before deployment
   - Records deployment history
   - Provides build status and health metrics
   - Follows proper Charter deployment workflows

## Logs & Monitoring

Logs are stored following AgencyStack Charter standards:
- Component logs: `/var/log/agency_stack/components/mcp/mcp_server.log`
- Access logs: `/var/log/agency_stack/components/mcp/access.log`
- Audit logs: `/var/log/agency_stack/components/mcp/audit.log`

## Troubleshooting

Common issues and solutions across the three-layer architecture:

### Outer Layer (Windows/Host) Issues

1. **Browser Access Problems**
   - Verify port mapping (3000) is properly exposed in Docker Compose
   - Check that Windows firewall isn't blocking connections
   - Ensure host.docker.internal resolution is working
   - Use `curl http://localhost:3000/health` to verify server responds

### Middle Layer (Ubuntu VM) Issues

1. **Docker Network Connectivity**
   - Check Docker networks with `docker network ls`
   - Verify MCP server container is properly connected to WordPress networks
   - Use `docker network inspect pfusa_network` to verify IP assignments
   - Ensure logs are being properly written to `/var/log/agency_stack/components/mcp/`

### Lower Layer (Container) Issues

1. **Container-to-Container Communication**
   - WordPress container often redirects to wrong ports (8082 instead of 80)
   - The MCP validator handles this with custom redirect logic
   - Check WordPress container environment variables with `docker exec -it pfusa_rebuilt_wordpress env`
   - Verify networking with `docker exec -it mcp-server curl http://pfusa_rebuilt_wordpress:80`

### Cross-Layer Validation Issues

1. **WordPress Validation Failures**
   - Check the HTTP validator logs for detailed error information
   - Verify the MCP server can resolve WordPress container hostnames
   - Try alternative access methods (IP address vs. container name)
   - Use `docker logs mcp-server` to view detailed networking attempts

2. **Script Compliance Issues**
   - Update scripts to include containerization checks following the Charter
   - Add proper idempotency patterns across all three layers
   - Follow Charter directory structure rigidly

## Charter Compliance

This component adheres to AgencyStack Charter principles:
- ✅ **Repository as Source of Truth**: All code tracked in repository
- ✅ **Strict Containerization**: Runs exclusively in containers
- ✅ **Idempotency & Automation**: Installation scripts are rerunnable
- ✅ **Auditability & Documentation**: Complete documentation with logs
- ✅ **Multi-Tenancy & Security**: Network isolation between clients
- ✅ **Component Consistency**: Standard directory structure and interfaces
