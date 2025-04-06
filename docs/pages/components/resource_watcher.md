---
layout: default
title: Resource Watcher - AgencyStack Documentation
---

# Resource Watcher

## Overview

Resource Watcher is a sovereign monitoring system for AI components that tracks compute resource usage, manages allocation, and provides intelligent scaling for LLM workloads in AgencyStack. It acts as both a protector against resource exhaustion and an optimizer for AI performance.

## Features

- **Resource Monitoring**: Track CPU, RAM, GPU, and disk usage across AI components
- **LLM Process Management**: Monitor and manage Ollama and other LLM processes
- **Adaptive Scaling**: Automatically adjust resources based on workload and priorities
- **Container Management**: Interface with Docker for container-level controls
- **Alerting**: Trigger alerts when thresholds are exceeded
- **Component Prioritization**: Apply resource policies based on priority tiers
- **Multi-tenant Isolation**: Ensure fair resource allocation in multi-tenant environments

## Prerequisites

- Docker and Docker Compose
- Python 3.9+
- Access to host metrics (privileged container)
- Prometheus (optional, for metrics storage)

## Installation

Install Resource Watcher using the Makefile:

```bash
make resource-watcher
```

Options:

- `--domain=<domain>`: Domain name for the deployment
- `--client-id=<client-id>`: Client ID for multi-tenant installations
- `--with-deps`: Install dependencies
- `--force`: Override existing installation

## Configuration

Resource Watcher configuration is stored in:

```
/opt/agency_stack/clients/${CLIENT_ID}/resource_watcher/config/
```

Environment variables:

| Variable | Description | Default |
|----------|-------------|---------|
| `RESOURCE_WATCHER_PORT` | Port for API access | `3032` |
| `MONITORING_INTERVAL` | Seconds between checks | `10` |
| `CPU_THRESHOLD` | CPU usage threshold (%) | `85` |
| `RAM_THRESHOLD` | RAM usage threshold (%) | `80` |
| `DISK_THRESHOLD` | Disk usage threshold (%) | `90` |
| `ENABLE_GPU_MONITORING` | Monitor GPU resources if available | `true` |
| `ENABLE_AUTO_SCALING` | Enable automatic resource scaling | `true` |
| `ACTION_LOGGING` | Log all actions taken | `true` |

## Usage

### Management Commands

```bash
# Check status
make resource-watcher-status

# View logs
make resource-watcher-logs

# Restart service
make resource-watcher-restart
```

### Resource Policies

Resource policies are defined in YAML configuration:

```yaml
components:
  ollama:
    priority: high
    max_cpu: 8
    max_memory: "8g"
    gpu_allocation: "4g"
    scaling:
      enabled: true
      min_instances: 1
      max_instances: 3
      scale_up_threshold: 80
      scale_down_threshold: 30
  
  langchain:
    priority: medium
    max_cpu: 4
    max_memory: "4g"
    scaling:
      enabled: true
      min_instances: 1
      max_instances: 2
  
  vector_db:
    priority: medium
    max_cpu: 2
    max_memory: "4g"
    disk_quota: "20g"
```

## Security

Resource Watcher implements the following security measures:

- Strict container resource limits
- Privileged mode restricted to minimal required capabilities
- Host resource protection mechanisms
- Authentication for API access
- Audit logging of all actions

## Monitoring

All Resource Watcher operations are logged to:

```
/var/log/agency_stack/components/resource_watcher.log
```

Metrics are exposed on the `/metrics` endpoint for Prometheus integration.

## Troubleshooting

### Common Issues

1. **Service fails to start**:
   - Check if Docker API access is available
   - Verify permissions on monitoring directories
   - Ensure Python dependencies are installed

2. **Resource limits not applied**:
   - Verify Docker is configured to accept resource constraints
   - Check if container runtime supports the specified limits
   - Verify policy configuration syntax

3. **High CPU usage by the watcher itself**:
   - Increase monitoring interval
   - Reduce the number of monitored metrics
   - Check for logging verbosity issues

### Logs

For detailed logs:

```bash
tail -f /var/log/agency_stack/components/resource_watcher.log
```

## Integration with Other Components

Resource Watcher integrates with:

1. **Ollama**: To manage LLM resource allocation
2. **LangChain**: To monitor AI workflow resources
3. **AI Dashboard**: For resource visualization and management
4. **Agent Orchestrator**: For agent resource policy enforcement
5. **Prometheus/Grafana**: For long-term metrics and visualization

## Advanced Customization

For advanced configurations, edit:

```
/opt/agency_stack/clients/${CLIENT_ID}/resource_watcher/config/settings.json
```

Custom monitoring plugins can be added to:

```
/opt/agency_stack/clients/${CLIENT_ID}/resource_watcher/plugins/
```

## API Reference

The Resource Watcher exposes a REST API:

```
https://api.yourdomain.com/resources/v1/
```

API endpoints:

- `GET /metrics`: Current resource metrics
- `GET /components`: List monitored components
- `GET /components/{component_id}`: Get component details
- `PUT /components/{component_id}/limits`: Update resource limits
- `POST /components/{component_id}/restart`: Restart a component
- `GET /policies`: List resource policies
- `PUT /policies`: Update resource policies
- `GET /events`: Get resource-related events

## Custom Resource Monitoring

For specialized AI hardware (specific GPUs, TPUs, etc.), custom monitoring modules can be implemented and configured through the settings file.
