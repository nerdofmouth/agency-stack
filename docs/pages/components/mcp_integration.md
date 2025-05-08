# AgencyStack MCP Integration Guide

**Version: 1.0.0**  
**Last Updated: 2025-05-07**

## Overview

This document outlines how to leverage the Model Context Protocol (MCP) server setup to enhance AgencyStack development within the constraints of the AgencyStack Charter. The MCP integration follows all core principles: repository as source of truth, idempotency, proper containerization, and auditability.

## Directory Structure

Following AgencyStack conventions, the MCP-related files are organized as:

```
/scripts/components/install_mcp_server.sh     # Installation script
/scripts/components/mcp_health_check.sh        # Health check execution script
/scripts/utils/mcp_client_lib.sh              # Utility functions for interacting with MCP
/docs/pages/components/mcp_integration.md     # This documentation
/var/log/agency_stack/components/mcp_server/  # MCP server logs
/opt/agency_stack/clients/${CLIENT_ID}/mcp/   # Installation output
```

## Installation

### Prerequisites

- Docker and Docker Compose
- Basic understanding of AgencyStack principles
- Access to AgencyStack repository

### Setup Process

1. Clone the MCP server setup to a temporary location:

```bash
mkdir -p /tmp/mcp-servers
git clone https://github.com/agencystack/mcp-server.git /tmp/mcp-servers
```

2. Run the installation script:

```bash
# From the agency-stack repository root
./scripts/components/install_mcp_server.sh
```

The installation script:
- Creates a containerized MCP server environment
- Configures the required endpoints (puppeteer, taskmaster-ai)
- Mounts the repository for proper access
- Updates Windsurf configuration to use local MCP servers

## Configuration

### Windsurf MCP Configuration

The MCP servers are configured in `~/.codeium/windsurf/mcp_config.json`:

```json
{
  "mcpServers": {
    "puppeteer": {
      "command": "curl",
      "args": ["-X", "POST", "-H", "Content-Type: application/json", "-d", "{}", "http://localhost:3000/puppeteer"],
      "env": {}
    },
    "taskmaster-ai": {
      "command": "curl",
      "args": ["-X", "POST", "-H", "Content-Type: application/json", "-d", "{}", "http://localhost:3000/taskmaster"],
      "env": {
        "ANTHROPIC_API_KEY": "your-key-here",
        "PERPLEXITY_API_KEY": "your-key-here",
        "MODEL": "claude-3-7-sonnet-20250219",
        "PERPLEXITY_MODEL": "sonar-pro",
        "MAX_TOKENS": "64000",
        "TEMPERATURE": "0.2",
        "DEFAULT_SUBTASKS": "5",
        "DEFAULT_PRIORITY": "medium"
      }
    }
  }
}
```

### Server Docker Compose

The MCP server is deployed using Docker Compose, with the repository properly mounted:

```yaml
version: '3'
services:
  mcp-server:
    build: .
    container_name: mcp-server
    ports:
      - "3000:3000"
    volumes:
      - ./:/app
      - /path/to/agency-stack:/agency-stack
    restart: unless-stopped
    environment:
      - NODE_ENV=development
    networks:
      - mcp-network
networks:
  mcp-network:
    driver: bridge
```

## Usage Patterns

### 1. Automated Compliance Validation

Execute compliance checks against the AgencyStack Charter:

```bash
# From the agency-stack repository root
./scripts/components/mcp_health_check.sh \
  --output=/var/log/agency_stack/components/mcp_server/compliance_report.log
```

The health check verifies:
- Repository structure integrity
- Script compliance with AgencyStack patterns
- Proper documentation for all components
- Idempotency of installation scripts
- Containerization compliance

### 2. UI Development Integration

For UI-focused development (agency_stack_ui branch):

```bash
# Run UI component validation
source ./scripts/utils/mcp_client_lib.sh
mcp_validate_ui_components --component=NextJSControlPanel
```

This validates:
- UI component documentation
- CLI-to-GUI mappings
- Dashboard configuration
- State management patterns

### 3. TDD Protocol Enforcement

Enforce Test-Driven Development Protocol:

```bash
# Verify TDD compliance for a component
source ./scripts/utils/mcp_client_lib.sh
mcp_verify_tdd_compliance --component=client_wordpress
```

This ensures all components follow the TDD Protocol as defined in `tdd_protocol.md`, with:
- Unit tests
- Integration tests
- System tests
- Documented test cases

### 4. Component Registry Integration

Validate and update component registry entries:

```bash
# Validate registry entries
source ./scripts/utils/mcp_client_lib.sh
mcp_validate_registry --component=client_wordpress
```

### 5. Operational Validation

Validate operational procedures using MCP:

```bash
# Validate configuration consistency
source ./scripts/utils/mcp_client_lib.sh
mcp_validate_configs --component=traefik
```

## Development Workflow Integration

### CI/CD Pipeline

Integrate MCP validation into CI/CD processes:

```bash
# In CI/CD pipeline script
#!/bin/bash
set -e

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../utils/common.sh"

# Run MCP health check
log_info "Running AgencyStack compliance validation"
"${SCRIPT_DIR}/mcp_health_check.sh"

# Validate results
if [ $? -ne 0 ]; then
  log_error "AgencyStack compliance check failed"
  exit 1
fi

log_info "AgencyStack compliance validation passed"
```

### Pre-commit Hook

Add a pre-commit hook that leverages MCP validation:

```bash
# In .git/hooks/pre-commit
#!/bin/bash

# Source MCP utilities
source ./scripts/utils/mcp_client_lib.sh

# Run quick compliance check
mcp_quick_compliance_check

if [ $? -ne 0 ]; then
  echo "ERROR: Changes do not comply with AgencyStack Charter"
  echo "Run ./scripts/components/mcp_health_check.sh for details"
  exit 1
fi
```

## Advanced Features

### Cross-Instance Collaboration

Coordinate work between UI-focused instances and other instances:

```bash
# Sync UI changes with backend components
source ./scripts/utils/mcp_client_lib.sh
mcp_sync_instances --from=ui --to=backend --component=version_manager
```

### Deployment Validation

Verify deployment readiness:

```bash
# Validate deployment readiness
source ./scripts/utils/mcp_client_lib.sh
mcp_validate_deployment --client=${CLIENT_ID} --component=client_wordpress
```

## Troubleshooting

### MCP Server Issues

If MCP server is unresponsive:

```bash
# Restart MCP server
cd /opt/agency_stack/clients/${CLIENT_ID}/mcp
docker-compose restart

# Verify health
curl http://localhost:3000/health
```

### Configuration Problems

For MCP configuration issues:

```bash
# Validate configuration
source ./scripts/utils/mcp_client_lib.sh
mcp_validate_config
```

## Best Practices

1. **Repository Integrity**: All MCP-related changes must be tracked in the repository.
2. **Idempotency**: MCP operations must be rerunnable without harmful side effects.
3. **Documentation**: Document all MCP-related changes in this file.
4. **Containerization**: Never modify the host system directly; use containers.
5. **Logging**: Ensure all MCP operations are logged to `/var/log/agency_stack/components/mcp_server/`.

## Conclusion

The MCP server integration enables automated validation of AgencyStack principles while accelerating development workflows. By following this guide, you ensure that all development activities maintain the sovereignty, auditability, and repeatability that define AgencyStack.

---

*This document is part of the AgencyStack documentation and follows all Charter requirements for human-readable documentation.*
