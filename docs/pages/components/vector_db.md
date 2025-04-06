---
layout: default
title: Vector Database - AgencyStack Documentation
---

# Vector Database

## Overview

The Vector Database component provides storage and retrieval capabilities for vector embeddings, enabling semantic search and AI knowledge bases within AgencyStack. It supports multiple vector database backends (Chroma, Qdrant, or Weaviate) depending on your needs.

## Features

- **Vector Storage**: Store and retrieve high-dimensional embeddings for text, images, and other data
- **Semantic Search**: Find similar content based on meaning rather than exact text matching
- **Multiple Backends**: Choose between Chroma, Qdrant, or Weaviate based on your requirements
- **Integration with LLMs**: Connect directly with LangChain and Ollama for AI applications
- **Persistent Storage**: All embeddings are preserved across restarts
- **Multi-tenant Support**: Isolate data between clients in multi-tenant deployments

## Prerequisites

- Docker and Docker Compose
- 4GB+ RAM recommended for production use
- SSD storage recommended for large vector collections

## Installation

Install the Vector Database using the Makefile:

```bash
make vector-db
```

Options:

- `--db-type=<chroma|qdrant|weaviate>`: Vector database backend to use (default: chroma)
- `--domain=<domain>`: Domain name for the deployment
- `--client-id=<client-id>`: Client ID for multi-tenant installations
- `--force`: Override existing installation

## Configuration

Vector DB configuration is stored in:

```
/opt/agency_stack/clients/${CLIENT_ID}/vector_db/config/
```

Environment variables:

| Variable | Description | Default |
|----------|-------------|---------|
| `VECTOR_DB_TYPE` | Database backend (chroma, qdrant, weaviate) | `chroma` |
| `VECTOR_DB_PORT` | Port for API access | Depends on backend |
| `VECTOR_DB_DIMENSION` | Default embedding dimension | `1536` |
| `VECTOR_DB_SIMILARITY` | Similarity metric (cosine, dot, euclidean) | `cosine` |
| `VECTOR_DB_PERSISTENT` | Enable persistent storage | `true` |
| `VECTOR_DB_MEMORY_LIMIT` | Memory limit for the container | `2g` |

## Usage

### Management Commands

```bash
# Check status
make vector-db-status

# View logs
make vector-db-logs

# Restart service
make vector-db-restart
```

### API Examples

The Vector DB exposes different APIs depending on the backend:

#### Chroma API Example

```python
import requests

# Create a collection
response = requests.post(
    "http://localhost:8000/api/v1/collections",
    json={
        "name": "my_collection",
        "metadata": {"description": "Example collection"}
    }
)

# Add documents/embeddings
response = requests.post(
    "http://localhost:8000/api/v1/collections/my_collection/add",
    json={
        "documents": ["This is a document", "This is another document"],
        "metadatas": [{"source": "doc1"}, {"source": "doc2"}],
        "ids": ["id1", "id2"]
    }
)

# Query
response = requests.post(
    "http://localhost:8000/api/v1/collections/my_collection/query",
    json={
        "query_texts": ["similar document"],
        "n_results": 2
    }
)
```

## Security

The Vector Database implements the following security measures:

- API key authentication for all requests
- Container resource limits to prevent resource exhaustion
- Access logging for all operations
- Client data isolation in multi-tenant deployments
- Optional TLS encryption via Traefik

## Monitoring

All Vector DB operations are logged to:

```
/var/log/agency_stack/components/vector_db.log
```

Metrics are exposed on the `/metrics` endpoint for Prometheus integration.

## Troubleshooting

### Common Issues

1. **Out of memory errors**:
   - Increase the `VECTOR_DB_MEMORY_LIMIT` setting
   - Consider switching to a more memory-efficient backend

2. **Slow query performance**:
   - Verify you're using SSD storage
   - Optimize index parameters in configuration
   - Consider sharding large collections

3. **Connection failures**:
   - Check if the container is running with `docker ps`
   - Verify network connectivity between services

### Logs

For detailed logs:

```bash
tail -f /var/log/agency_stack/components/vector_db.log
```

## Integration with Other Components

The Vector Database integrates with:

1. **LangChain**: For document embeddings and retrievals
2. **Ollama**: For generating embeddings from content
3. **AI Dashboard**: For monitoring and configuration
4. **Agent Orchestrator**: For agent knowledge bases

## Advanced Customization

For advanced configurations, edit:

```
/opt/agency_stack/clients/${CLIENT_ID}/vector_db/config/settings.json
```

## Backend Comparison

| Feature | Chroma | Qdrant | Weaviate |
|---------|--------|--------|----------|
| **Ease of Use** | ★★★★★ | ★★★★☆ | ★★★☆☆ |
| **Performance** | ★★★☆☆ | ★★★★★ | ★★★★☆ |
| **Memory Usage** | ★★★★☆ | ★★★☆☆ | ★★★★★ |
| **Feature Set** | ★★★☆☆ | ★★★★☆ | ★★★★★ |
| **Scalability** | ★★★☆☆ | ★★★★★ | ★★★★★ |

Choose your backend based on your specific requirements for performance, scalability, and features.
