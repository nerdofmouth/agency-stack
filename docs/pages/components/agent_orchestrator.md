---
layout: default
title: Agent Orchestrator - AgencyStack Documentation
---

# Agent Orchestrator

## Overview

The Agent Orchestrator is a sovereign, self-hosted system that manages intelligent AI agents within the AgencyStack ecosystem. It enables the creation, deployment, and monitoring of autonomous AI agents that can perform tasks, respond to events, and interact with other components in your infrastructure.

## Features

- **Agent Lifecycle Management**: Create, configure, deploy, and monitor AI agents
- **Tool Integration**: Connect agents to external tools and APIs
- **Workflow Automation**: Define complex workflows spanning multiple agents
- **Multi-Agent Collaboration**: Enable agent-to-agent communication and coordination
- **Event-Based Triggers**: Respond to system events and scheduled tasks
- **Security Controls**: Enforce strict permissions and operational boundaries
- **Multi-tenancy Support**: Isolate agent resources between clients

## Prerequisites

- Docker and Docker Compose
- LangChain and Ollama (for LLM capabilities)
- Vector DB (for agent memory)
- 4GB+ RAM recommended for multiple active agents

## Installation

Install the Agent Orchestrator using the Makefile:

```bash
make agent-orchestrator
```

Options:

- `--domain=<domain>`: Domain name for the deployment
- `--client-id=<client-id>`: Client ID for multi-tenant installations
- `--with-deps`: Install dependencies (LangChain, Ollama, Vector DB)
- `--force`: Override existing installation

## Configuration

Agent Orchestrator configuration is stored in:

```
/opt/agency_stack/clients/${CLIENT_ID}/agent_orchestrator/config/
```

Environment variables:

| Variable | Description | Default |
|----------|-------------|---------|
| `AGENT_ORCH_PORT` | Port for API access | `3031` |
| `AGENT_ORCH_LOG_LEVEL` | Logging level | `info` |
| `LANGCHAIN_API_URL` | URL of LangChain service | `http://langchain:7860` |
| `VECTOR_DB_URL` | URL of Vector DB service | `http://vector_db:8000` |
| `MAX_AGENTS` | Maximum number of concurrent agents | `10` |
| `DEFAULT_AGENT_TIMEOUT` | Default timeout for agent tasks (seconds) | `300` |
| `ENABLE_REMOTE_TOOLS` | Allow access to remote tools | `false` |

## Usage

### Management Commands

```bash
# Check status
make agent-orchestrator-status

# View logs
make agent-orchestrator-logs

# Restart service
make agent-orchestrator-restart
```

### Agent Definition

Agents are defined using YAML configuration files:

```yaml
name: data-processor
description: "Processes and analyzes data files"
model: llama2
tools:
  - name: file_reader
    description: "Reads data files"
    permissions: ["read"]
    paths: ["/opt/agency_stack/clients/${CLIENT_ID}/data/"]
  - name: data_analyzer
    description: "Analyzes data"
    permissions: ["read", "execute"]
memory:
  type: vector_db
  collection: "data_processor_memory"
triggers:
  - type: file_change
    path: "/opt/agency_stack/clients/${CLIENT_ID}/data/incoming/"
  - type: schedule
    cron: "0 * * * *"  # Hourly
constraints:
  max_runtime: 600  # seconds
  max_tokens: 8000
  allowed_domains: ["local"]
```

## Security

The Agent Orchestrator enforces strong security controls:

- Strict permission boundaries for each agent
- Resource usage limits and timeouts
- Tool access controls and authentication
- Action logging and audit trails
- Sandboxed execution environments
- No external API access unless explicitly allowed

## Monitoring

All Agent Orchestrator operations are logged to:

```
/var/log/agency_stack/components/agent_orchestrator.log
```

Individual agent logs are stored in:

```
/var/log/agency_stack/components/agents/${AGENT_NAME}.log
```

Metrics are exposed on the `/metrics` endpoint for Prometheus integration.

## Troubleshooting

### Common Issues

1. **Agents failing to start**:
   - Check LangChain and Ollama connectivity
   - Verify model availability
   - Check agent configuration for errors

2. **Tool access failures**:
   - Verify tool permissions and paths
   - Check if required tools are installed
   - Ensure file system permissions are correct

3. **High resource usage**:
   - Adjust MAX_AGENTS setting
   - Configure resource limits in agent definitions
   - Consider spreading agents across nodes

### Logs

For detailed logs:

```bash
# Main service logs
tail -f /var/log/agency_stack/components/agent_orchestrator.log

# Specific agent logs
tail -f /var/log/agency_stack/components/agents/${AGENT_NAME}.log
```

## Integration with Other Components

The Agent Orchestrator integrates with:

1. **LangChain**: For LLM-based agent reasoning
2. **Vector DB**: For agent memory and knowledge bases
3. **Resource Watcher**: For monitoring agent resource usage
4. **AI Dashboard**: For agent management interface
5. **Traefik**: For secure API access
6. **Prometheus/Grafana**: For monitoring and alerting

## Advanced Customization

For advanced configurations, edit:

```
/opt/agency_stack/clients/${CLIENT_ID}/agent_orchestrator/config/settings.json
```

Custom agent tools can be added by placing Python modules in:

```
/opt/agency_stack/clients/${CLIENT_ID}/agent_orchestrator/tools/
```

## API Reference

The Agent Orchestrator exposes a REST API:

```
https://api.yourdomain.com/agents/v1/
```

API endpoints:

- `GET /agents`: List all agents
- `POST /agents`: Create a new agent
- `GET /agents/{agent_id}`: Get agent details
- `PUT /agents/{agent_id}`: Update agent configuration
- `DELETE /agents/{agent_id}`: Delete an agent
- `POST /agents/{agent_id}/start`: Start an agent
- `POST /agents/{agent_id}/stop`: Stop an agent
- `GET /agents/{agent_id}/logs`: Get agent logs
- `GET /tools`: List available tools
- `GET /metrics`: Get performance metrics
