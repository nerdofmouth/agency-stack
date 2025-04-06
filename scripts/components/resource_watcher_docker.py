# Docker configuration for Resource Watcher

# Create Dockerfile
def create_dockerfile(app_dir):
    dockerfile = f"""
FROM python:3.10-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \\
    curl \\
    procps \\
    net-tools \\
    iproute2 \\
    && apt-get clean \\
    && rm -rf /var/lib/apt/lists/*

# Copy application code
COPY . /app/

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Use non-root user for security
RUN useradd -m appuser
USER appuser

# Expose the application port
EXPOSE 5211

# Run the application
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "5211"]
"""
    
    with open(f"{app_dir}/Dockerfile", "w") as f:
        f.write(dockerfile)

# Create docker-compose.yml
def create_docker_compose(app_dir, client_id, port, log_dir, data_dir, add_traefik=False, domain=None):
    # Basic configuration
    docker_compose = f"""version: '3.8'

services:
  resource-watcher:
    build: .
    container_name: resource-watcher-{client_id}
    restart: unless-stopped
    volumes:
      - {data_dir}:/app/data
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /etc:/host/etc:ro
    environment:
      - CLIENT_ID={client_id}
      - PORT=5211
      - METRICS_PATH=/app/data/metrics
      - ALERTS_PATH=/app/data/alerts
      - HOST_PROC=/host/proc
      - HOST_SYS=/host/sys
      - HOST_ETC=/host/etc
"""

    # Add environment variables for LLM integration
    docker_compose += """      - LLM_ENABLED=${LLM_ENABLED:-false}
      - USE_OLLAMA=${USE_OLLAMA:-false}
      - OLLAMA_API_URL=${OLLAMA_API_URL:-http://ollama:11434}
      - LANGCHAIN_API_URL=${LANGCHAIN_API_URL:-http://langchain:7860}
      - PROMETHEUS_ENABLED=${PROMETHEUS_ENABLED:-false}
      - PROMETHEUS_URL=${PROMETHEUS_URL:-http://prometheus:9090}
      - DOCKER_ENABLED=true
      - COLLECTION_INTERVAL=${COLLECTION_INTERVAL:-60}
      - RETENTION_PERIOD=${RETENTION_PERIOD:-1440}
      - CPU_THRESHOLD=${CPU_THRESHOLD:-80}
      - MEMORY_THRESHOLD=${MEMORY_THRESHOLD:-80}
      - DISK_THRESHOLD=${DISK_THRESHOLD:-90}
"""

    # Add port mapping
    docker_compose += f"""    ports:
      - {port}:5211
"""

    # Add Traefik configuration if requested
    if add_traefik and domain:
        docker_compose += f"""    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.resource-watcher.rule=Host(`resource-watcher.{domain}`)"
      - "traefik.http.routers.resource-watcher.entrypoints=websecure"
      - "traefik.http.routers.resource-watcher.tls=true"
      - "traefik.http.services.resource-watcher.loadbalancer.server.port=5211"
"""

    # Add networks
    docker_compose += """    networks:
      - agency_stack

networks:
  agency_stack:
    external: true
"""

    with open(f"{app_dir}/docker-compose.yml", "w") as f:
        f.write(docker_compose)

# Create Docker .env file
def create_docker_env(app_dir, ollama_url=None, langchain_url=None, prometheus_url=None, 
                     llm_enabled=False, use_ollama=False, prometheus_enabled=False,
                     collection_interval=60, retention_period=1440, 
                     cpu_threshold=80, memory_threshold=80, disk_threshold=90):
    
    env_content = f"""# Resource Watcher Configuration
LLM_ENABLED={'true' if llm_enabled else 'false'}
USE_OLLAMA={'true' if use_ollama else 'false'}
OLLAMA_API_URL={ollama_url or 'http://ollama:11434'}
LANGCHAIN_API_URL={langchain_url or 'http://langchain:7860'}
PROMETHEUS_ENABLED={'true' if prometheus_enabled else 'false'}
PROMETHEUS_URL={prometheus_url or 'http://prometheus:9090'}
DOCKER_ENABLED=true
COLLECTION_INTERVAL={collection_interval}
RETENTION_PERIOD={retention_period}
CPU_THRESHOLD={cpu_threshold}
MEMORY_THRESHOLD={memory_threshold}
DISK_THRESHOLD={disk_threshold}
"""
    
    with open(f"{app_dir}/.env", "w") as f:
        f.write(env_content)
