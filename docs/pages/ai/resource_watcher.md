# Resource Watcher

The Resource Watcher is a microservice component of AgencyStack that monitors system resources and provides metrics, alerts, and intelligent recommendations based on resource usage patterns.

## Features

- **Real-time Resource Monitoring**: Tracks CPU, memory, disk, and network usage
- **Docker Container Monitoring**: Monitors Docker container resource utilization
- **Prometheus Integration**: Exposes metrics in Prometheus format
- **Intelligent Analysis**: Uses LLMs to provide insights and recommendations (optional)
- **Alert Generation**: Generates alerts based on configurable thresholds
- **REST API**: Provides a comprehensive API for accessing metrics and insights
- **Multi-tenant Support**: Supports multiple clients with isolated environments

## Installation

The Resource Watcher can be installed using the installation script:

```bash
./scripts/components/install_resource_watcher.sh --client-id=your_client_id --domain=your_domain.com
```

### Installation Options

| Option | Description | Default |
|--------|-------------|---------|
| `--port` | Port for the Resource Watcher API | 5211 |
| `--client-id` | Client ID for multi-tenant setup | default |
| `--domain` | Domain for the service | localhost |
| `--langchain-port` | Port for LangChain service | 5111 |
| `--ollama-port` | Port for Ollama service | 11434 |
| `--prometheus-port` | Port for Prometheus service | 9090 |
| `--with-deps` | Install dependencies if not already installed | false |
| `--force` | Force reinstallation even if already installed | false |
| `--use-ollama` | Use Ollama for LLM analysis | false |
| `--enable-llm` | Enable LLM-enhanced analysis | false |
| `--enable-prometheus` | Enable Prometheus integration | false |
| `--help` | Display help message and exit | - |

## API Endpoints

The Resource Watcher provides the following API endpoints:

### Health Check

```
GET /healthz
```

Returns the current health status of the service.

**Example Response:**
```json
{
  "status": "healthy",
  "timestamp": "2023-05-23T14:30:45.123456"
}
```

### Status

```
GET /status
```

Returns detailed status information about the Resource Watcher and its components.

**Example Response:**
```json
{
  "system": {
    "hostname": "agency-server",
    "platform": "Linux",
    "platform_version": "5.15.0-1019-azure",
    "client_id": "acme"
  },
  "current": {
    "cpu_usage": 12.5,
    "memory_usage": 45.2,
    "load_avg": 0.8
  },
  "metrics_collection": {
    "is_active": true,
    "interval_seconds": 60,
    "metrics_count": 1440,
    "retention_minutes": 1440
  },
  "alerts": {
    "total": 5,
    "by_level": {
      "warning": 3,
      "critical": 2
    },
    "by_resource": {
      "cpu": 2,
      "memory": 2,
      "disk": 1
    }
  },
  "dependencies": {
    "llm": "healthy",
    "prometheus": "healthy",
    "docker": true
  },
  "timestamp": "2023-05-23T14:30:45.123456"
}
```

### Current Metrics

```
GET /metrics
```

Returns the current system metrics.

**Example Response:**
```json
{
  "timestamp": "2023-05-23T14:30:45.123456",
  "system": {
    "hostname": "agency-server",
    "platform": "Linux",
    "platform_version": "5.15.0-1019-azure",
    "client_id": "acme"
  },
  "cpu": {
    "usage_percent": 12.5,
    "load_avg_1min": 0.5,
    "load_avg_5min": 0.8,
    "load_avg_15min": 1.2
  },
  "memory": {
    "total_gb": 16.0,
    "available_gb": 8.7,
    "used_percent": 45.2
  },
  "disks": [
    {
      "device": "/dev/sda1",
      "mountpoint": "/",
      "total_gb": 256.0,
      "free_gb": 180.5,
      "used_percent": 29.5
    }
  ],
  "network": [
    {
      "interface": "eth0",
      "bytes_sent": 1024000,
      "bytes_recv": 2048000
    }
  ],
  "docker": [
    {
      "name": "nginx",
      "image": "nginx:latest",
      "status": "running",
      "cpu_percent": 0.5,
      "memory_percent": 1.2
    }
  ]
}
```

### Prometheus Metrics

```
GET /metrics/prometheus
```

Returns the current metrics in Prometheus format for scraping.

### Historical Metrics

```
GET /metrics/history
```

Returns historical metrics within a specified time range.

**Query Parameters:**
- `start`: ISO format start time (optional)
- `end`: ISO format end time (optional)
- `limit`: Maximum number of metrics to return (default: 100)

### Alerts

```
GET /alerts
```

Returns alerts within a specified time range and filtering criteria.

**Query Parameters:**
- `level`: Filter by alert level (optional, e.g., "warning", "critical")
- `resource_type`: Filter by resource type (optional, e.g., "cpu", "memory")
- `start`: ISO format start time (optional)
- `end`: ISO format end time (optional)
- `limit`: Maximum number of alerts to return (default: 100)

### Resource Summary

```
GET /summary
```

Returns a summary of resource usage with optional LLM-enhanced insights.

**Query Parameters:**
- `time_range`: Time range for the summary (default: "1h", options: "1h", "6h", "24h", "7d")
- `include_insights`: Whether to include LLM-enhanced insights (default: false)

**Example Response:**
```json
{
  "start_time": "2023-05-23T13:30:45.123456",
  "end_time": "2023-05-23T14:30:45.123456",
  "system": {
    "hostname": "agency-server",
    "platform": "Linux",
    "platform_version": "5.15.0-1019-azure",
    "client_id": "acme"
  },
  "cpu_avg": 15.3,
  "cpu_max": 45.2,
  "memory_avg": 42.8,
  "memory_max": 48.5,
  "disk_usage_avg": {
    "/": 29.5
  },
  "network_traffic_mb": {
    "eth0": {
      "sent": 5.2,
      "received": 12.8
    }
  },
  "alerts": [
    {
      "timestamp": "2023-05-23T14:15:23.123456",
      "level": "warning",
      "resource_type": "cpu",
      "message": "CPU usage exceeded 40% threshold (45.2%)"
    }
  ],
  "anomalies": [
    {
      "title": "CPU spike detected",
      "description": "A significant CPU spike occurred at 14:15, reaching 45.2%",
      "severity": "medium"
    }
  ],
  "recommendations": [
    {
      "title": "Investigate CPU usage",
      "description": "The CPU usage spike correlates with scheduled backup processes",
      "action": "Consider rescheduling backups to off-peak hours"
    }
  ]
}
```

## Integration with Prometheus

The Resource Watcher can be integrated with Prometheus for long-term metrics storage and alerting:

1. Enable Prometheus integration during installation:
   ```bash
   ./scripts/components/install_resource_watcher.sh --enable-prometheus
   ```

2. Configure Prometheus to scrape metrics from the Resource Watcher:
   ```yaml
   scrape_configs:
     - job_name: 'resource-watcher'
       scrape_interval: 15s
       static_configs:
         - targets: ['resource-watcher:5211']
   ```

## LLM-Enhanced Mode

The Resource Watcher can use LLMs (Large Language Models) to provide intelligent analysis and recommendations:

1. Enable LLM integration during installation:
   ```bash
   ./scripts/components/install_resource_watcher.sh --enable-llm
   ```

2. Choose between LangChain or Ollama for LLM processing:
   ```bash
   # LangChain (default)
   ./scripts/components/install_resource_watcher.sh --enable-llm
   
   # Ollama
   ./scripts/components/install_resource_watcher.sh --enable-llm --use-ollama
   ```

3. Access LLM-enhanced insights via the API:
   ```
   GET /summary?include_insights=true
   ```

## Makefile Integration

The Resource Watcher provides Makefile targets for easy management:

```bash
# Installation
make resource-watcher

# Check status
make resource-watcher-status

# View logs
make resource-watcher-logs

# Restart service
make resource-watcher-restart

# View metrics
make resource-watcher-metrics
```

## Security Considerations

The Resource Watcher implements the following security measures:

- Runs in an isolated Docker container
- Uses non-root user within the container
- Read-only access to system resources via volume mounts
- Client isolation for multi-tenant deployments
- TLS encryption with Traefik integration (when using domains)
- Configurable rate limiting

## Troubleshooting

Common issues and their solutions:

1. **Service fails to start**:
   - Check the logs: `make resource-watcher-logs`
   - Ensure Docker is running: `systemctl status docker`
   - Verify port availability: `netstat -tuln | grep 5211`

2. **Missing metrics**:
   - Check collection interval: `docker exec resource-watcher-{client_id} env | grep COLLECTION`
   - Verify data directory permissions: `ls -la /opt/agency_stack/clients/{client_id}/monitoring/resource_watcher/data`

3. **LLM integration not working**:
   - Verify LLM service is running: `make ollama-status` or `make langchain-status`
   - Check connection URLs in environment variables: `docker exec resource-watcher-{client_id} env | grep URL`
