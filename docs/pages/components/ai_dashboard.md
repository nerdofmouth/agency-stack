---
layout: default
title: AI Dashboard - AgencyStack Documentation
---

# AI Dashboard

## Overview

The AI Dashboard provides a centralized management interface for all AI components in AgencyStack. It enables monitoring, configuration, and control of LLMs, vector databases, agents, and AI-powered workflows from a single unified interface.

## Features

- **Model Management**: Track, configure, and deploy LLM models
- **Component Status**: Monitor all AI components at a glance
- **Usage Analytics**: Track token usage, request volume, and performance
- **Agent Management**: Configure and monitor AI agents
- **Prompt Library**: Create, test, and manage prompt templates
- **Integration Settings**: Configure connections to external AI services

## Prerequisites

- Docker and Docker Compose
- Traefik for routing
- Ollama and LangChain (for full functionality)
- Keycloak (for authentication)

## Installation

Install the AI Dashboard using the Makefile:

```bash
make ai-dashboard
```

Options:

- `--domain=<domain>`: Domain name for the deployment
- `--client-id=<client-id>`: Client ID for multi-tenant installations
- `--with-deps`: Install dependencies (Ollama, LangChain, etc.)
- `--force`: Override existing installation

## Configuration

AI Dashboard configuration is stored in:

```
/opt/agency_stack/clients/${CLIENT_ID}/ai_dashboard/config/
```

Environment variables:

| Variable | Description | Default |
|----------|-------------|---------|
| `AI_DASHBOARD_PORT` | Port for web interface | `3030` |
| `ENABLE_SSO` | Enable authentication with Keycloak | `true` |
| `LANGCHAIN_API_URL` | URL of LangChain service | `http://langchain:7860` |
| `OLLAMA_API_URL` | URL of Ollama service | `http://ollama:11434` |
| `VECTORDB_API_URL` | URL of Vector DB service | `http://vector_db:8000` |
| `METRICS_RETENTION_DAYS` | Days to retain usage metrics | `30` |

## Usage

### Management Commands

```bash
# Check status
make ai-dashboard-status

# View logs
make ai-dashboard-logs

# Restart service
make ai-dashboard-restart
```

### Web Interface

The AI Dashboard is accessible at:

```
https://ai.yourdomain.com
```

Main sections:

1. **Overview**: System status and key metrics
2. **Models**: LLM model management
3. **Agents**: AI agent configuration
4. **Prompts**: Prompt template library
5. **Analytics**: Usage and performance data
6. **Settings**: System configuration

## Security

The AI Dashboard implements the following security measures:

- Authentication via Keycloak SSO
- Role-based access control
- TLS encryption via Traefik
- API rate limiting
- Audit logging of all administrative actions

## Monitoring

All AI Dashboard operations are logged to:

```
/var/log/agency_stack/components/ai_dashboard.log
```

Metrics are exposed on the `/metrics` endpoint for Prometheus integration.

## Troubleshooting

### Common Issues

1. **Dashboard not loading**:
   - Check Traefik routing with `make traefik-status`
   - Verify Docker container status with `docker ps`

2. **Components showing as offline**:
   - Ensure AI components (Ollama, LangChain) are running
   - Check network connectivity between containers

3. **Authentication failures**:
   - Verify Keycloak integration settings
   - Check SSO configuration and realm settings

### Logs

For detailed logs:

```bash
tail -f /var/log/agency_stack/components/ai_dashboard.log
```

## Integration with Other Components

The AI Dashboard integrates with:

1. **Ollama**: For LLM model management
2. **LangChain**: For AI workflow orchestration
3. **Vector DB**: For embedding and knowledge base management
4. **Agent Orchestrator**: For agent configuration
5. **Resource Watcher**: For resource monitoring
6. **Prometheus/Grafana**: For advanced monitoring

## Advanced Customization

For advanced configurations, edit:

```
/opt/agency_stack/clients/${CLIENT_ID}/ai_dashboard/config/settings.json
```

Custom dashboards can be added to:

```
/opt/agency_stack/clients/${CLIENT_ID}/ai_dashboard/dashboards/
```

## API Access

The AI Dashboard exposes a REST API for programmatic control:

```
https://ai.yourdomain.com/api/v1/
```

API endpoints:

- `/api/v1/status`: System status
- `/api/v1/models`: Model management
- `/api/v1/agents`: Agent configuration
- `/api/v1/prompts`: Prompt template library
- `/api/v1/metrics`: Usage metrics

Authentication requires a valid JWT token from Keycloak.
