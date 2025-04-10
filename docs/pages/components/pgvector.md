---
layout: default
title: pgvector - PostgreSQL Vector Extension - AgencyStack Documentation
---

# pgvector

pgvector is a PostgreSQL extension that adds support for vector similarity search, enabling AI-powered semantic search capabilities within your existing PostgreSQL database.

![PostgreSQL + pgvector](https://pgvector.org/logo.png)

## Overview

pgvector extends PostgreSQL with vector data types and similarity search operations, allowing you to:

* Store embeddings from machine learning models directly in your database
* Perform efficient similarity searches using various distance metrics
* Build AI-powered applications without a separate vector database

* **Version**: 0.5.1 (with PostgreSQL 15)
* **Category**: Database
* **Website**: [https://github.com/pgvector/pgvector](https://github.com/pgvector/pgvector)
* **Documentation**: [https://pgvector.org](https://pgvector.org)

## Architecture

pgvector in AgencyStack is integrated as follows:

1. **PostgreSQL Instance**: Uses the existing PostgreSQL service for the tenant
2. **pgvector Extension**: Installed within PostgreSQL
3. **Vector Database**: Dedicated database for vector operations
4. **Sample Code**: Python examples for embedding generation and search
5. **Multi-tenant**: Each client gets an isolated vector database

## Features

* **Vector Data Types**: Store embeddings as native vector types
* **Similarity Search**: Support for multiple distance metrics (L2, inner product, cosine)
* **Indexing**: HNSW and IVFFlat indexing for high-performance search
* **Integration**: Works with all existing PostgreSQL features (transactions, backups, etc.)
* **Multi-embedding**: Store different types of embeddings in the same database
* **SQL Interface**: Familiar SQL interface for vector operations
* **Performance**: Optimized C implementation for efficient search operations

## Installation

### Prerequisites

* PostgreSQL database installed (v13 or higher)
* Docker environment for containerized PostgreSQL
* Admin access to PostgreSQL

### Standard Installation

```bash
# Install pgvector with default settings
make pgvector
```

### Advanced Installation

```bash
# Install with custom settings
make pgvector FORCE=true WITH_DEPS=true
```

### Installation Options

| Option | Description |
|--------|-------------|
| `--domain` | Domain for the installation (required) |
| `--admin-email` | Admin email for notifications (required) |
| `--client-id` | Client ID for multi-tenant setup (default: default) |
| `--force` | Force installation even if already installed |
| `--enable-cloud` | Allow cloud connections (default: false) |
| `--with-deps` | Install PostgreSQL if not found (default: false) |
| `--verbose` | Enable verbose output |

## Configuration

The pgvector extension is configured within PostgreSQL. Key configuration files:

* **Environment File**: `/opt/agency_stack/clients/{CLIENT_ID}/pgvector/.env`
* **Sample Code**: `/opt/agency_stack/clients/{CLIENT_ID}/pgvector/samples/`

### Connection Details

Vector database connection details:

```
Host: localhost (or postgres-{CLIENT_ID} within Docker network)
Port: 5432
Database: vectordb
User: vectoruser
Password: [generated during installation]
```

Connection string format:
```
postgresql://vectoruser:[password]@localhost:5432/vectordb
```

## Usage

### Python Example

```python
import psycopg2
import numpy as np
from sentence_transformers import SentenceTransformer

# Load model
model = SentenceTransformer('all-MiniLM-L6-v2')

# Connect to database
conn = psycopg2.connect("postgresql://vectoruser:[password]@localhost:5432/vectordb")
cur = conn.cursor()

# Add a document with embedding
text = "AgencyStack provides a comprehensive set of tools for agencies"
embedding = model.encode(text)
cur.execute(
    "INSERT INTO vector_test (content, embedding) VALUES (%s, %s)",
    (text, embedding.tolist())
)
conn.commit()

# Search for similar documents
query = "What tools are available for agencies?"
query_embedding = model.encode(query)
cur.execute(
    "SELECT content, embedding <=> %s AS distance FROM vector_test ORDER BY distance LIMIT 5",
    (query_embedding.tolist(),)
)
results = cur.fetchall()
for content, distance in results:
    print(f"{content} (distance: {distance:.4f})")

# Close connection
cur.close()
conn.close()
```

### Raw SQL Example

```sql
-- Create a table with vector column
CREATE TABLE items (
  id SERIAL PRIMARY KEY,
  embedding vector(384),  -- 384-dimensional vector
  data jsonb
);

-- Insert a vector
INSERT INTO items (embedding, data)
VALUES (
  '[0.1, 0.2, 0.3, ...]'::vector,
  '{"text": "Example item"}'
);

-- Find similar items using cosine distance
SELECT id, data, embedding <=> '[0.15, 0.25, 0.35, ...]'::vector AS distance
FROM items
ORDER BY distance
LIMIT 10;

-- Create an index for faster queries
CREATE INDEX ON items USING hnsw (embedding vector_cosine_ops);
```

## Integration with Other AgencyStack Components

### PeerTube Integration

Use pgvector to power semantic search for video content:

```python
# Example: Index PeerTube video transcripts
from peertube_api import PeerTubeClient
import psycopg2

# Connect to PeerTube and PostgreSQL
pt = PeerTubeClient("https://peertube.domain.com")
conn = psycopg2.connect("postgresql://vectoruser:[password]@localhost:5432/vectordb")
cur = conn.cursor()

# Get videos and their transcripts
videos = pt.get_videos()
for video in videos:
    transcript = pt.get_transcript(video.id)
    embedding = model.encode(transcript)
    
    # Store in pgvector
    cur.execute(
        "INSERT INTO peertube_videos (video_id, title, transcript, embedding) VALUES (%s, %s, %s, %s)",
        (video.id, video.title, transcript, embedding.tolist())
    )

conn.commit()
```

### Archon Integration

Enable semantic routing for the Archon AI agent orchestration:

```python
# Example: Use pgvector for agent memory and routing
import psycopg2
from archon.client import ArchonClient

# Initialize connections
archon = ArchonClient("http://archon.domain.com")
conn = psycopg2.connect("postgresql://vectoruser:[password]@localhost:5432/vectordb")
cur = conn.cursor()

# Store agent context
def store_context(agent_id, context):
    embedding = model.encode(context)
    cur.execute(
        "INSERT INTO agent_contexts (agent_id, context, embedding) VALUES (%s, %s, %s)",
        (agent_id, context, embedding.tolist())
    )
    conn.commit()

# Retrieve similar contexts
def find_similar_contexts(query, limit=5):
    query_embedding = model.encode(query)
    cur.execute(
        "SELECT agent_id, context FROM agent_contexts ORDER BY embedding <=> %s LIMIT %s",
        (query_embedding.tolist(), limit)
    )
    return cur.fetchall()
```

## Management Commands

### Status Check

```bash
# Check pgvector status
make pgvector-status
```

### View Logs

```bash
# View pgvector logs
make pgvector-logs
```

### Restart Service

```bash
# Restart PostgreSQL with pgvector
make pgvector-restart
```

### Run Test

```bash
# Run the test example
make pgvector-test
```

## Security

pgvector inherits PostgreSQL's security model:

* **Access Control**: Role-based authentication and authorization
* **Network Security**: Default to localhost-only connections
* **Data Protection**: Inherits PostgreSQL's encryption capabilities
* **Multi-tenant Isolation**: Each client has separate database users and credentials

### Hardening Recommendations

1. Use strong passwords for database users
2. Update PostgreSQL configuration to limit network access
3. Regularly backup vector data
4. Monitor query performance and adjust indexes as needed

## Troubleshooting

### Common Issues

**Extension Not Found**
```
ERROR: could not load library "vector.so": No such file or directory
```
Solution: Check if the extension is properly installed:
```sql
SELECT * FROM pg_available_extensions WHERE name = 'vector';
```

**Performance Issues**
```
Slow query performance on vector similarity search
```
Solution: Ensure proper indexing:
```sql
CREATE INDEX ON your_table USING hnsw (embedding vector_cosine_ops);
```

**Memory Errors**
```
ERROR: out of memory
```
Solution: Adjust PostgreSQL memory settings:
```
shared_buffers = 1GB
work_mem = 256MB
```

### Viewing Logs

```bash
# View pgvector-specific logs
make pgvector-logs

# View PostgreSQL logs with vector operations
docker logs postgres-{CLIENT_ID} | grep -i vector
```

## Uninstallation

To remove pgvector:

```bash
# Login to PostgreSQL
docker exec -it postgres-{CLIENT_ID} psql -U postgres

# Within psql, remove the extension
DROP DATABASE vectordb;
DROP EXTENSION vector;
```

## References

* [pgvector GitHub Repository](https://github.com/pgvector/pgvector)
* [PostgreSQL Documentation](https://www.postgresql.org/docs/)
* [Vector Search Tutorial](https://supabase.com/blog/pgvector)
* [Embeddings and Vector Databases](https://huggingface.co/learn/nlp-course/en/chapter5/6)
