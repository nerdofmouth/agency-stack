# Agent Orchestrator

## Overview

The Agent Orchestrator is an intelligent LLM-powered microservice that monitors system state, identifies patterns, and takes automated actions to maintain optimal system performance. It integrates with Ollama and LangChain to provide AI-powered system management capabilities.

## Features

- **System Monitoring**: Observes logs, events, and system metrics
- **Intelligent Analysis**: Uses LLMs to detect patterns such as errors, slowdowns, and resource usage
- **Automated Actions**: Executes safe, low-risk automations like service restarts and log syncs
- **Recommendations**: Suggests actions and optimizations to system administrators
- **Integration**: Works with Prometheus, Loki, LangChain, and Ollama

## Installation

### Prerequisites

- Docker
- AgencyStack core components
- LangChain service (recommended)
- Ollama service (recommended for on-premise LLM)

### Installation Command

```bash
./scripts/components/install_agent_orchestrator.sh --client-id=<client_id> --domain=<domain> [options]
```

#### Options:

- `--client-id`: Client ID for multi-tenant setup (required)
- `--domain`: Domain for the service (required)
- `--port`: Port for the Agent Orchestrator API (default: 5210)
- `--langchain-port`: Port for LangChain service (default: 5111)
- `--ollama-port`: Port for Ollama service (default: 11434)
- `--with-deps`: Install dependencies if not already installed
- `--force`: Force reinstallation even if already installed
- `--use-ollama`: Use Ollama for LLM access (default)
- `--enable-openai`: Enable OpenAI integration as fallback
- `--enable-monitoring`: Set up Prometheus and Loki monitoring

### Makefile Targets

```bash
# Install Agent Orchestrator
make agent-orchestrator

# Check the status of the Agent Orchestrator
make agent-orchestrator-status

# View logs
make agent-orchestrator-logs

# Restart the service
make agent-orchestrator-restart

# Test the API
make agent-orchestrator-test
```

## API Reference

The Agent Orchestrator provides the following API endpoints:

### Health Check

```
GET /health
```

Returns the current health status of the service and its dependencies.

### Recommendations

```
POST /recommendations
```

Analyzes system state and provides intelligent recommendations based on logs and metrics.

**Request Body:**
```json
{
  "context": {
    "systemInfo": {
      "uptime": "15d 2h 45m",
      "cpu_usage_avg": "35%"
    }
  },
  "logs": [
    "ERROR: Connection to database timed out after 30s",
    "WARN: High memory usage detected (85%)"
  ],
  "metrics": {
    "cpu_usage": [25, 30, 40, 60, 45],
    "memory_usage": [65, 70, 75, 85, 82]
  }
}
```

**Response:**
```json
{
  "recommendations": [
    {
      "title": "Restart Database Service",
      "description": "Database connection timeouts indicate potential issues with the database service",
      "action_type": "restart_service",
      "target": "database",
      "urgency": "high"
    },
    {
      "title": "Clear Cache",
      "description": "High memory usage can be addressed by clearing application caches",
      "action_type": "clear_cache",
      "target": "application",
      "urgency": "medium"
    }
  ],
  "explanation": "System is experiencing database connectivity issues and high memory usage...",
  "timestamp": "2023-04-05T15:30:45.123Z"
}
```

### Execute Action

```
POST /actions
```

Executes an automated action based on recommendations.

**Request Body:**
```json
{
  "action": {
    "action_type": "restart_service",
    "target": "langchain",
    "parameters": {
      "delay": 5
    },
    "description": "Restart LangChain service to resolve API timeout issues"
  }
}
```

**Response:**
```json
{
  "success": true,
  "message": "Service langchain restart initiated",
  "details": {
    "status": "pending"
  }
}
```

### Get Logs

```
GET /logs/{component}?lines=100
```

Retrieves logs for a specific component.

### Get Metrics

```
GET /metrics/{component}
```

Retrieves metrics for a specific component (requires monitoring enabled).

## Supported Actions

The Agent Orchestrator can perform the following actions:

1. **restart_service**: Safely restart a service
2. **sync_logs**: Synchronize and rotate logs
3. **pull_model**: Pull an LLM model for Ollama
4. **clear_cache**: Clear service caches
5. **run_test**: Run diagnostic tests

## Integration with AgencyStack

The Agent Orchestrator integrates with:

- **LangChain**: For AI-powered analysis and recommendations
- **Ollama**: For local LLM inference
- **Prometheus**: For metrics collection (optional)
- **Loki**: For log aggregation (optional)

## Security Considerations

The Agent Orchestrator has been designed with security in mind:

- Only performs safe, low-risk actions
- Actions are explicitly limited to specific targets
- All actions are logged for audit purposes
- No direct access to sensitive system components
- Multi-tenant isolation

## Troubleshooting

### Common Issues

1. **Cannot connect to LangChain/Ollama**: Ensure these services are running and the correct ports are configured.

2. **Recommendations not generating**: Check LangChain logs for errors or issues with the LLM.

3. **Actions failing**: Check permissions and container connectivity in Docker.

### Logs

View logs for troubleshooting:

```bash
make agent-orchestrator-logs
```

## Future Development

Planned enhancements for the Agent Orchestrator include:

- Integration with additional monitoring tools
- Support for more complex workflows and actions
- Enhanced LLM reasoning capabilities
- User-configurable action policies
- Web UI for recommendation management
