---
layout: default
title: LangChain - AgencyStack Documentation
---

# LangChain

## Overview

LangChain is an AI orchestration framework that enables the creation of powerful applications using large language models (LLMs). In AgencyStack, LangChain serves as the middleware between your applications and LLM providers (either local via Ollama or external).

## Features

- **LLM Integration**: Connect to Ollama or external LLM providers
- **Prompt Templates**: Create and manage reusable prompt templates
- **Chains**: Build complex reasoning chains for sophisticated AI workflows
- **Agent Tools**: Create tools that LLMs can use to interact with your systems 
- **Memory**: Implement conversation memory for stateful interactions
- **Document Processing**: Handle document retrieval and question-answering

## Prerequisites

- Docker and Docker Compose
- Ollama (recommended for local LLM capabilities)
- Vector DB (for document embeddings and retrieval)

## Installation

Install LangChain using the Makefile:

```bash
make langchain
```

Options:

- `--domain=<domain>`: Domain name for the deployment
- `--client-id=<client-id>`: Client ID for multi-tenant installations
- `--with-deps`: Install dependencies (Ollama and Vector DB)
- `--force`: Override existing installation

## Configuration

LangChain configuration is stored in:

```
/opt/agency_stack/clients/${CLIENT_ID}/langchain/config/
```

Environment variables:

| Variable | Description | Default |
|----------|-------------|---------|
| `LANGCHAIN_API_KEY` | API key for LangChain service | Auto-generated |
| `VECTOR_DB_TYPE` | Vector DB type (chroma, qdrant, weaviate) | `chroma` |
| `VECTOR_DB_HOST` | Vector DB host | `vector_db` |
| `OLLAMA_HOST` | Ollama host | `ollama` |
| `ENABLE_OPENAI` | Enable OpenAI integration | `false` |

## Usage

### Management Commands

```bash
# Check status
make langchain-status

# View logs
make langchain-logs

# Restart service
make langchain-restart
```

### API Endpoints

The LangChain service exposes the following endpoints:

- `https://api.yourdomain.com/langchain/v1/chat`: For chat completions
- `https://api.yourdomain.com/langchain/v1/embeddings`: For generating embeddings
- `https://api.yourdomain.com/langchain/v1/chains`: For running predefined chains

## Security

LangChain in AgencyStack implements the following security measures:

- API key authentication for all requests
- TLS encryption via Traefik
- Rate limiting to prevent abuse
- IP-based access controls
- No external API calls unless explicitly configured

## Monitoring

All LangChain operations are logged to:

```
/var/log/agency_stack/components/langchain.log
```

Metrics are exposed on the `/metrics` endpoint for Prometheus integration.

Dashboard panels are automatically added to Grafana, including:

- Request volume
- Response times
- Error rates
- Token usage

## Troubleshooting

### Common Issues

1. **Connection to Ollama fails**:
   - Ensure Ollama is installed and running
   - Verify network connectivity between containers

2. **Vector DB connection errors**:
   - Check vector DB status with `make vector-db-status`
   - Verify connection settings in configuration

3. **API requests timeout**:
   - Check if LLM models are properly downloaded
   - For large operations, increase timeouts in configuration

### Logs

For detailed logs:

```bash
tail -f /var/log/agency_stack/components/langchain.log
```

## Integration with Other Components

LangChain integrates with:

1. **Ollama**: For local LLM inference
2. **Vector DB**: For document retrieval and embeddings
3. **Agent Orchestrator**: For complex AI automation workflows
4. **AI Dashboard**: For monitoring and configuration

## Advanced Customization

For advanced configurations, edit:

```
/opt/agency_stack/clients/${CLIENT_ID}/langchain/config/settings.json
```

## API Examples

```python
import requests

headers = {
    "Content-Type": "application/json",
    "Authorization": f"Bearer {API_KEY}"
}

# Chat completion
response = requests.post(
    "https://api.yourdomain.com/langchain/v1/chat",
    headers=headers,
    json={
        "messages": [
            {"role": "user", "content": "Hello, how can you help me?"}
        ],
        "model": "llama2"
    }
)

print(response.json())
```
