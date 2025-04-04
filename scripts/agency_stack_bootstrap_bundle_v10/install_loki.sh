#!/bin/bash
# install_loki.sh - Install Loki log aggregation for AgencyStack
# https://stack.nerdofmouth.com

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Check if config.env exists
if [ ! -f "/opt/agency_stack/config.env" ]; then
  echo -e "${RED}Error: config.env file not found${NC}"
  exit 1
fi

# Load configuration
source /opt/agency_stack/config.env

# Set variables
LOKI_DATA_DIR="/opt/agency_stack/data/loki"
LOKI_CONFIG_DIR="/opt/agency_stack/config/loki"
PROMTAIL_CONFIG_DIR="/opt/agency_stack/config/promtail"

# Create directories
echo -e "${BLUE}Creating directories for Loki...${NC}"
mkdir -p ${LOKI_DATA_DIR}
mkdir -p ${LOKI_CONFIG_DIR}
mkdir -p ${PROMTAIL_CONFIG_DIR}

# Create Loki configuration
echo -e "${BLUE}Creating Loki configuration...${NC}"
cat > ${LOKI_CONFIG_DIR}/loki-config.yaml << EOL
auth_enabled: false

server:
  http_listen_port: 3100
  grpc_listen_port: 9096

common:
  path_prefix: /loki
  storage:
    filesystem:
      chunks_directory: /loki/chunks
      rules_directory: /loki/rules
  replication_factor: 1
  ring:
    instance_addr: 127.0.0.1
    kvstore:
      store: inmemory

schema_config:
  configs:
    - from: 2020-10-24
      store: boltdb-shipper
      object_store: filesystem
      schema: v11
      index:
        prefix: index_
        period: 24h

ruler:
  alertmanager_url: http://localhost:9093

limits_config:
  enforce_metric_name: false
  reject_old_samples: true
  reject_old_samples_max_age: 168h
  retention_period: 90d

table_manager:
  retention_deletes_enabled: true
  retention_period: 90d

compactor:
  working_directory: /loki/compactor
  shared_store: filesystem
  compaction_interval: 10m
  retention_enabled: true
  retention_delete_delay: 2h
  retention_delete_worker_count: 150
EOL

# Create Promtail configuration
echo -e "${BLUE}Creating Promtail configuration...${NC}"
cat > ${PROMTAIL_CONFIG_DIR}/promtail-config.yaml << EOL
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://loki:3100/loki/api/v1/push

scrape_configs:
  - job_name: system
    static_configs:
      - targets:
          - localhost
        labels:
          job: varlogs
          __path__: /var/log/*log

  - job_name: agency_stack
    static_configs:
      - targets:
          - localhost
        labels:
          job: agency_stack
          __path__: /var/log/agency_stack/*log

  - job_name: docker
    docker_sd_configs:
      - host: unix:///var/run/docker.sock
        refresh_interval: 5s
    relabel_configs:
      - source_labels: ['__meta_docker_container_name']
        regex: '/(.*)'
        target_label: 'container'
EOL

# Create docker-compose file
echo -e "${BLUE}Creating docker-compose file for Loki...${NC}"
cat > ${LOKI_CONFIG_DIR}/docker-compose.yml << EOL
version: '3'

services:
  loki:
    image: grafana/loki:2.7.0
    container_name: agency_stack_loki
    ports:
      - "3100:3100"
    volumes:
      - ${LOKI_CONFIG_DIR}/loki-config.yaml:/etc/loki/local-config.yaml
      - ${LOKI_DATA_DIR}:/loki
    command: -config.file=/etc/loki/local-config.yaml
    restart: unless-stopped
    networks:
      - loki
      - traefik-public
    labels:
      - traefik.enable=true
      - traefik.http.routers.loki.rule=Host(\`loki.${PRIMARY_DOMAIN}\`)
      - traefik.http.routers.loki.entrypoints=websecure
      - traefik.http.routers.loki.tls=true
      - traefik.http.routers.loki.tls.certresolver=letsencrypt
      - traefik.http.services.loki.loadbalancer.server.port=3100

  promtail:
    image: grafana/promtail:2.7.0
    container_name: agency_stack_promtail
    volumes:
      - ${PROMTAIL_CONFIG_DIR}/promtail-config.yaml:/etc/promtail/config.yml
      - /var/log:/var/log
      - /var/lib/docker/containers:/var/lib/docker/containers
      - /var/run/docker.sock:/var/run/docker.sock
    command: -config.file=/etc/promtail/config.yml
    restart: unless-stopped
    networks:
      - loki
    depends_on:
      - loki

networks:
  loki:
    driver: bridge
  traefik-public:
    external: true
EOL

# Start containers
echo -e "${BLUE}Starting Loki and Promtail containers...${NC}"
cd ${LOKI_CONFIG_DIR}
docker-compose up -d

# Check if containers are running
if docker ps | grep -q "agency_stack_loki" && docker ps | grep -q "agency_stack_promtail"; then
  echo -e "${GREEN}✅ Loki and Promtail containers started successfully${NC}"
  echo -e "${GREEN}✅ Loki is accessible at: https://loki.${PRIMARY_DOMAIN}${NC}"
  echo -e "Logs are being collected from: /var/log/agency_stack/ and Docker containers"
else
  echo -e "${RED}❌ Failed to start Loki and Promtail containers${NC}"
  echo -e "Please check the logs: docker logs agency_stack_loki"
  exit 1
fi

# Add to installed components
echo "Loki Log Aggregation" >> /opt/agency_stack/installed_components.txt

# Set up config.env variables
if ! grep -q "LOKI_URL" /opt/agency_stack/config.env; then
  echo -e "\n# Loki Configuration" >> /opt/agency_stack/config.env
  echo "LOKI_URL=https://loki.${PRIMARY_DOMAIN}" >> /opt/agency_stack/config.env
  echo "LOKI_INTERNAL_URL=http://loki:3100" >> /opt/agency_stack/config.env
fi

echo -e "${GREEN}✅ Loki installation complete!${NC}"
