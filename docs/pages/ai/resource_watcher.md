# Resource Watcher

## Overview

The Resource Watcher is an AI system monitoring agent that collects and analyzes resource usage for AI components in the AgencyStack ecosystem. It provides real-time metrics and status information to the Agent Orchestrator, enabling intelligent resource management and proactive issue resolution.

## Features

- **Resource Monitoring**: Tracks CPU, memory, disk, and network usage of AI components
- **Performance Metrics**: Collects and aggregates performance data for analysis
- **Model Usage Tracking**: Monitors LLM model usage, including token counts and inference times
- **Status Reporting**: Provides real-time status updates to the Agent Orchestrator
- **Alert Generation**: Creates alerts when resource thresholds are exceeded
- **Multi-tenant Aware**: Isolates and tracks resources per client
- **Prometheus Integration**: Exposes metrics for Prometheus scraping
- **Loki Integration**: Forwards logs to Loki for aggregation

## Installation

### Prerequisites

- Docker
- AgencyStack core components
- Agent Orchestrator (recommended)
- Prometheus/Loki monitoring (optional but recommended)

### Installation Command

```bash
./scripts/components/install_resource_watcher.sh --client-id=<client_id> --domain=<domain> [options]
```

#### Options:

- `--client-id`: Client ID for multi-tenant setup (required)
- `--domain`: Domain for the service (required)
- `--port`: Port for the Resource Watcher API (default: 5220)
- `--metrics-port`: Port for Prometheus metrics (default: 5221)
- `--with-deps`: Install dependencies if not already installed
- `--force`: Force reinstallation even if already installed
- `--enable-monitoring`: Set up Prometheus and Loki monitoring

### Makefile Targets

```bash
# Install Resource Watcher
make resource-watcher

# Check the status of the Resource Watcher
make resource-watcher-status

# View logs
make resource-watcher-logs
```

## API Reference

The Resource Watcher provides the following API endpoints:

### Health Check

```
GET /health
```

Returns the current health status of the service.

**Response:**
```json
{
  "status": "healthy",
  "version": "1.0.0",
  "timestamp": "2025-04-05T19:45:00Z"
}
```

### Resource Metrics

```
GET /metrics/components
```

Retrieves the current resource usage metrics for all monitored AI components.

**Request:**
```
GET /metrics/components?client_id=client1
```

**Response:**
```json
{
  "metrics": [
    {
      "component": "ollama",
      "resources": {
        "cpu_usage": 15.2,
        "memory_usage": 1245.6,
        "memory_usage_percent": 35.8,
        "disk_usage": 10240,
        "network_in": 12.5,
        "network_out": 8.3
      },
      "status": "healthy"
    },
    {
      "component": "langchain",
      "resources": {
        "cpu_usage": 8.7,
        "memory_usage": 512.3,
        "memory_usage_percent": 14.6,
        "disk_usage": 1024,
        "network_in": 5.2,
        "network_out": 3.1
      },
      "status": "healthy"
    }
  ],
  "timestamp": "2025-04-05T19:45:00Z"
}
```

### Model Usage

```
GET /metrics/models
```

Retrieves usage statistics for LLM models.

**Request:**
```
GET /metrics/models?client_id=client1
```

**Response:**
```json
{
  "models": [
    {
      "name": "llama2",
      "provider": "ollama",
      "requests_count": 124,
      "tokens_input": 15678,
      "tokens_output": 32456,
      "avg_latency_ms": 235.6,
      "last_used": "2025-04-05T19:40:00Z"
    },
    {
      "name": "mistral",
      "provider": "ollama",
      "requests_count": 56,
      "tokens_input": 7890,
      "tokens_output": 12345,
      "avg_latency_ms": 185.2,
      "last_used": "2025-04-05T19:42:00Z"
    }
  ],
  "timestamp": "2025-04-05T19:45:00Z"
}
```

### Resource Alerts

```
GET /alerts
```

Retrieves active resource alerts.

**Request:**
```
GET /alerts?client_id=client1
```

**Response:**
```json
{
  "alerts": [
    {
      "component": "ollama",
      "alert_type": "high_memory_usage",
      "value": 85.2,
      "threshold": 80.0,
      "timestamp": "2025-04-05T19:43:00Z",
      "severity": "warning"
    }
  ]
}
```

## Configuration

The Resource Watcher can be configured through environment variables or a configuration file:

### Environment Variables

```
RESOURCE_WATCHER_PORT=5220
RESOURCE_WATCHER_METRICS_PORT=5221
RESOURCE_WATCHER_POLL_INTERVAL=15
RESOURCE_WATCHER_LOG_LEVEL=info
RESOURCE_WATCHER_ORCHESTRATOR_URL=http://localhost:5210
```

### Configuration File

Located at `/opt/agency_stack/resource_watcher/config.json`:

```json
{
  "port": 5220,
  "metrics_port": 5221,
  "poll_interval_seconds": 15,
  "log_level": "info",
  "orchestrator_url": "http://localhost:5210",
  "alerts": {
    "cpu_threshold_percent": 80,
    "memory_threshold_percent": 80,
    "disk_threshold_percent": 90
  },
  "components": [
    {
      "name": "ollama",
      "container_name": "ollama",
      "ports": [11434, 11435],
      "custom_metrics": ["model_load_time", "inference_time"]
    },
    {
      "name": "langchain",
      "container_name": "langchain",
      "ports": [5111, 5112],
      "custom_metrics": ["chain_execution_time", "embedding_time"]
    }
  ]
}
```

## Integration with AgencyStack

The Resource Watcher integrates with:

- **Agent Orchestrator**: Provides resource data for intelligent automation
- **Prometheus**: Exposes metrics for long-term storage and visualization
- **Loki**: Forwards logs for aggregation and search
- **AI Dashboard**: Stats are visible through the AI control panel

## Architecture Diagram

```
                                +---------------+
                                | AI Dashboard  |
                                +---------------+
                                       ^
                                       |
      +---------------+        +-------------------+        +---------------+
      |   Prometheus  |<------>| Resource Watcher  |<------>|     Loki     |
      +---------------+        +-------------------+        +---------------+
                                       ^
                                       |
                   +-----------------+-----------------+
                   |                 |                 |
           +---------------+  +---------------+  +---------------+
           |    Ollama     |  |   LangChain   |  |  Other AI     |
           +---------------+  +---------------+  |  Components   |
                                                 +---------------+
```

## Monitoring

### Prometheus Metrics

The Resource Watcher exposes the following Prometheus metrics:

- `resource_watcher_component_cpu_usage`: CPU usage percentage by component
- `resource_watcher_component_memory_usage`: Memory usage in MB by component
- `resource_watcher_component_memory_usage_percent`: Memory usage percentage by component
- `resource_watcher_component_disk_usage`: Disk usage in MB by component
- `resource_watcher_model_request_count`: Request count by model
- `resource_watcher_model_tokens_processed`: Token count by model and direction (input/output)
- `resource_watcher_model_latency`: Average latency in milliseconds by model

### Grafana Dashboard

A Grafana dashboard template is provided for visualizing Resource Watcher metrics. Import the dashboard from:

```
/opt/agency_stack/resource_watcher/grafana/dashboard.json
```

## Troubleshooting

### Common Issues

1. **Cannot connect to Docker**: Ensure Docker is running and the Resource Watcher has proper permissions.
   ```bash
   systemctl status docker
   ```

2. **No metrics data**: Check if components are properly tagged for monitoring.
   ```bash
   docker ps --format "{{.Names}}"
   ```

3. **High resource usage**: Adjust resource limits for AI components in their respective configurations.

### Logs

View Resource Watcher logs with:

```bash
make resource-watcher-logs
```

Or directly:

```bash
docker logs resource-watcher
```

## Security Considerations

- Resource Watcher runs with limited privileges
- API endpoints require client_id authentication
- Metrics are isolated per tenant
- No sensitive data is exposed via metrics

## Upgrade Procedure

To upgrade the Resource Watcher:

1. Backup the configuration:
   ```bash
   cp /opt/agency_stack/resource_watcher/config.json /tmp/resource_watcher_config_backup.json
   ```

2. Run the installation with the force flag:
   ```bash
   make resource-watcher FORCE=true
   ```

3. Verify the upgrade:
   ```bash
   make resource-watcher-status
   ```
