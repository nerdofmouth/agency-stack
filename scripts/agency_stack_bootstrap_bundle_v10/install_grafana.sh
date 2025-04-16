#!/bin/bash
# install_grafana.sh - Install Grafana for AgencyStack
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
GRAFANA_DATA_DIR="/opt/agency_stack/data/grafana"
GRAFANA_CONFIG_DIR="/opt/agency_stack/config/grafana"
GRAFANA_PROVISIONING_DIR="${GRAFANA_CONFIG_DIR}/provisioning"
GRAFANA_DASHBOARDS_DIR="${GRAFANA_PROVISIONING_DIR}/dashboards"
GRAFANA_DATASOURCES_DIR="${GRAFANA_PROVISIONING_DIR}/datasources"
GRAFANA_DOMAIN="grafana.${PRIMARY_DOMAIN}"
GRAFANA_PORT="3333"

# Create directories
echo -e "${BLUE}Creating directories for Grafana...${NC}"
mkdir -p ${GRAFANA_DATA_DIR}
mkdir -p ${GRAFANA_CONFIG_DIR}
mkdir -p ${GRAFANA_DASHBOARDS_DIR}
mkdir -p ${GRAFANA_DATASOURCES_DIR}
mkdir -p ${GRAFANA_CONFIG_DIR}/dashboards

# Generate secure admin password if not exists
if [ -z "$GRAFANA_ADMIN_PASSWORD" ]; then
  GRAFANA_ADMIN_PASSWORD=$(openssl rand -base64 12)
  echo -e "${BLUE}Generated Grafana admin password: ${GREEN}$GRAFANA_ADMIN_PASSWORD${NC}"
  echo -e "${YELLOW}Please save this password or change it after login${NC}"
fi

# Create Grafana datasource configuration for Loki
echo -e "${BLUE}Creating Loki datasource configuration...${NC}"
cat > ${GRAFANA_DATASOURCES_DIR}/loki.yaml << EOL
apiVersion: 1

datasources:
  - name: Loki
    type: loki
    access: proxy
    url: http://loki:3100
    isDefault: true
    editable: false
EOL

# Create dashboard provisioning configuration
echo -e "${BLUE}Creating dashboard provisioning configuration...${NC}"
cat > ${GRAFANA_DASHBOARDS_DIR}/agency_stack.yaml << EOL
apiVersion: 1

providers:
  - name: 'AgencyStack'
    orgId: 1
    folder: 'AgencyStack'
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /etc/grafana/dashboards
      foldersFromFilesStructure: true
EOL

# Create a simple AgencyStack dashboard
echo -e "${BLUE}Creating AgencyStack dashboard...${NC}"
cat > ${GRAFANA_CONFIG_DIR}/dashboards/agency_stack_logs.json << 'EOL'
{
  "annotations": {
    "list": [
      {
        "builtIn": 1,
        "datasource": {
          "type": "grafana",
          "uid": "-- Grafana --"
        },
        "enable": true,
        "hide": true,
        "iconColor": "rgba(0, 211, 255, 1)",
        "name": "Annotations & Alerts",
        "target": {
          "limit": 100,
          "matchAny": false,
          "tags": [],
          "type": "dashboard"
        },
        "type": "dashboard"
      }
    ]
  },
  "editable": true,
  "fiscalYearStartMonth": 0,
  "graphTooltip": 0,
  "id": 1,
  "links": [],
  "liveNow": false,
  "panels": [
    {
      "datasource": {
        "type": "loki",
        "uid": "P8E80F9AEF21F6940"
      },
      "gridPos": {
        "h": 9,
        "w": 24,
        "x": 0,
        "y": 0
      },
      "id": 2,
      "options": {
        "dedupStrategy": "none",
        "enableLogDetails": true,
        "prettifyLogMessage": false,
        "showCommonLabels": false,
        "showLabels": false,
        "showTime": true,
        "sortOrder": "Descending",
        "wrapLogMessage": false
      },
      "targets": [
        {
          "datasource": {
            "type": "loki",
            "uid": "P8E80F9AEF21F6940"
          },
          "editorMode": "builder",
          "expr": "{job=\"agency_stack\"}",
          "queryType": "range",
          "refId": "A"
        }
      ],
      "title": "AgencyStack Logs",
      "type": "logs"
    },
    {
      "datasource": {
        "type": "loki",
        "uid": "P8E80F9AEF21F6940"
      },
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "thresholds"
          },
          "mappings": [],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "green",
                "value": null
              },
              {
                "color": "red",
                "value": 80
              }
            ]
          }
        },
        "overrides": []
      },
      "gridPos": {
        "h": 8,
        "w": 12,
        "x": 0,
        "y": 9
      },
      "id": 4,
      "options": {
        "colorMode": "value",
        "graphMode": "area",
        "justifyMode": "auto",
        "orientation": "auto",
        "reduceOptions": {
          "calcs": [
            "count"
          ],
          "fields": "",
          "values": false
        },
        "textMode": "auto"
      },
      "pluginVersion": "9.3.2",
      "targets": [
        {
          "datasource": {
            "type": "loki",
            "uid": "P8E80F9AEF21F6940"
          },
          "editorMode": "builder",
          "expr": "{job=\"agency_stack\"} |= `ERROR`",
          "queryType": "range",
          "refId": "A"
        }
      ],
      "title": "Error Count (Last 24h)",
      "type": "stat"
    },
    {
      "datasource": {
        "type": "loki",
        "uid": "P8E80F9AEF21F6940"
      },
      "description": "",
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "thresholds"
          },
          "mappings": [],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "green",
                "value": null
              },
              {
                "color": "yellow",
                "value": 10
              }
            ]
          }
        },
        "overrides": []
      },
      "gridPos": {
        "h": 8,
        "w": 12,
        "x": 12,
        "y": 9
      },
      "id": 6,
      "options": {
        "colorMode": "value",
        "graphMode": "area",
        "justifyMode": "auto",
        "orientation": "auto",
        "reduceOptions": {
          "calcs": [
            "count"
          ],
          "fields": "",
          "values": false
        },
        "textMode": "auto"
      },
      "pluginVersion": "9.3.2",
      "targets": [
        {
          "datasource": {
            "type": "loki",
            "uid": "P8E80F9AEF21F6940"
          },
          "editorMode": "builder",
          "expr": "{job=\"agency_stack\"} |= `WARN`",
          "queryType": "range",
          "refId": "A"
        }
      ],
      "title": "Warning Count (Last 24h)",
      "type": "stat"
    }
  ],
  "refresh": "10s",
  "schemaVersion": 37,
  "style": "dark",
  "tags": [
    "agency-stack"
  ],
  "templating": {
    "list": []
  },
  "time": {
    "from": "now-24h",
    "to": "now"
  },
  "timepicker": {},
  "timezone": "",
  "title": "AgencyStack Overview",
  "uid": "agency-stack-overview",
  "version": 2,
  "weekStart": ""
}
EOL

# Create a system metrics dashboard
echo -e "${BLUE}Creating system metrics dashboard...${NC}"
cat > ${GRAFANA_CONFIG_DIR}/dashboards/system_metrics.json << 'EOL'
{
  "annotations": {
    "list": [
      {
        "builtIn": 1,
        "datasource": {
          "type": "grafana",
          "uid": "-- Grafana --"
        },
        "enable": true,
        "hide": true,
        "iconColor": "rgba(0, 211, 255, 1)",
        "name": "Annotations & Alerts",
        "target": {
          "limit": 100,
          "matchAny": false,
          "tags": [],
          "type": "dashboard"
        },
        "type": "dashboard"
      }
    ]
  },
  "editable": true,
  "fiscalYearStartMonth": 0,
  "graphTooltip": 0,
  "id": 2,
  "links": [],
  "liveNow": false,
  "panels": [
    {
      "datasource": {
        "type": "loki",
        "uid": "P8E80F9AEF21F6940"
      },
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "thresholds"
          },
          "mappings": [],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "green",
                "value": null
              },
              {
                "color": "red",
                "value": 80
              }
            ]
          }
        },
        "overrides": []
      },
      "gridPos": {
        "h": 8,
        "w": 12,
        "x": 0,
        "y": 0
      },
      "id": 4,
      "options": {
        "colorMode": "value",
        "graphMode": "area",
        "justifyMode": "auto",
        "orientation": "auto",
        "reduceOptions": {
          "calcs": [
            "lastNotNull"
          ],
          "fields": "",
          "values": false
        },
        "textMode": "auto"
      },
      "pluginVersion": "9.3.2",
      "targets": [
        {
          "datasource": {
            "type": "loki",
            "uid": "P8E80F9AEF21F6940"
          },
          "editorMode": "builder",
          "expr": "{job=\"system\"} |= `Memory usage` | pattern `<_> Memory usage <status>: <value>% used`",
          "queryType": "range",
          "refId": "A"
        }
      ],
      "title": "Memory Usage (%)",
      "type": "stat"
    },
    {
      "datasource": {
        "type": "loki",
        "uid": "P8E80F9AEF21F6940"
      },
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "thresholds"
          },
          "mappings": [],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "green",
                "value": null
              },
              {
                "color": "red",
                "value": 80
              }
            ]
          }
        },
        "overrides": []
      },
      "gridPos": {
        "h": 8,
        "w": 12,
        "x": 12,
        "y": 0
      },
      "id": 2,
      "options": {
        "colorMode": "value",
        "graphMode": "area",
        "justifyMode": "auto",
        "orientation": "auto",
        "reduceOptions": {
          "calcs": [
            "lastNotNull"
          ],
          "fields": "",
          "values": false
        },
        "textMode": "auto"
      },
      "pluginVersion": "9.3.2",
      "targets": [
        {
          "datasource": {
            "type": "loki",
            "uid": "P8E80F9AEF21F6940"
          },
          "editorMode": "builder",
          "expr": "{job=\"system\"} |= `Disk space` | pattern `<_> Disk space <status>: <value>% used`",
          "queryType": "range",
          "refId": "A"
        }
      ],
      "title": "Disk Usage (%)",
      "type": "stat"
    },
    {
      "datasource": {
        "type": "loki",
        "uid": "P8E80F9AEF21F6940"
      },
      "description": "",
      "gridPos": {
        "h": 8,
        "w": 24,
        "x": 0,
        "y": 8
      },
      "id": 6,
      "options": {
        "dedupStrategy": "none",
        "enableLogDetails": true,
        "prettifyLogMessage": false,
        "showCommonLabels": false,
        "showLabels": false,
        "showTime": true,
        "sortOrder": "Descending",
        "wrapLogMessage": false
      },
      "targets": [
        {
          "datasource": {
            "type": "loki",
            "uid": "P8E80F9AEF21F6940"
          },
          "editorMode": "builder",
          "expr": "{job=\"docker\"} | line_format \"{{ .container }}: {{ .message }}\"",
          "queryType": "range",
          "refId": "A"
        }
      ],
      "title": "Docker Container Logs",
      "type": "logs"
    }
  ],
  "refresh": "5s",
  "schemaVersion": 37,
  "style": "dark",
  "tags": [
    "agency-stack",
    "system"
  ],
  "templating": {
    "list": []
  },
  "time": {
    "from": "now-1h",
    "to": "now"
  },
  "timepicker": {},
  "timezone": "",
  "title": "System Metrics",
  "uid": "system-metrics",
  "version": 1,
  "weekStart": ""
}
EOL

# Create docker-compose file
echo -e "${BLUE}Creating docker-compose file for Grafana...${NC}"
cat > ${GRAFANA_CONFIG_DIR}/docker-compose.yml << EOL
version: '3'

services:
  grafana:
    image: grafana/grafana:9.3.2
    container_name: agency_stack_grafana
    ports:
      - "${GRAFANA_PORT}:3000"
    environment:
      - GF_SECURITY_ADMIN_USER=admin
      - GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_ADMIN_PASSWORD}
      - GF_USERS_ALLOW_SIGN_UP=false
      - GF_SERVER_ROOT_URL=https://${GRAFANA_DOMAIN}
      - GF_INSTALL_PLUGINS=grafana-piechart-panel
    volumes:
      - ${GRAFANA_DATA_DIR}:/var/lib/grafana
      - ${GRAFANA_PROVISIONING_DIR}:/etc/grafana/provisioning
      - ${GRAFANA_CONFIG_DIR}/dashboards:/etc/grafana/dashboards
    restart: unless-stopped
    networks:
      - loki
      - traefik-public
    labels:
      - traefik.enable=true
      - traefik.http.routers.grafana.rule=Host(\`${GRAFANA_DOMAIN}\`)
      - traefik.http.routers.grafana.entrypoints=websecure
      - traefik.http.routers.grafana.tls=true
      - traefik.http.routers.grafana.tls.certresolver=letsencrypt
      - traefik.http.services.grafana.loadbalancer.server.port=3000
      - traefik.http.routers.grafana.middlewares=grafana-auth
      - "traefik.http.middlewares.grafana-auth.basicauth.users=admin:$$apr1$$$(openssl passwd -apr1 ${GRAFANA_ADMIN_PASSWORD} | sed 's/\\$/\\$\\$/g')"

networks:
  loki:
    external: true
  traefik-public:
    external: true
EOL

# Start containers
echo -e "${BLUE}Starting Grafana container...${NC}"
cd ${GRAFANA_CONFIG_DIR}
docker-compose up -d

# Check if container is running
if docker ps | grep -q "agency_stack_grafana"; then
  echo -e "${GREEN}✅ Grafana container started successfully${NC}"
  echo -e "${GREEN}✅ Grafana is accessible at: https://${GRAFANA_DOMAIN}${NC}"
  echo -e "Username: admin"
  echo -e "Password: ${GRAFANA_ADMIN_PASSWORD}"
else
  echo -e "${RED}❌ Failed to start Grafana container${NC}"
  echo -e "Please check the logs: docker logs agency_stack_grafana"
  exit 1
fi

# Add to installed components
echo "Grafana Monitoring" >> /opt/agency_stack/installed_components.txt

# Set up config.env variables
if ! grep -q "GRAFANA_URL" /opt/agency_stack/config.env; then
  echo -e "\n# Grafana Configuration" >> /opt/agency_stack/config.env
  echo "GRAFANA_URL=https://${GRAFANA_DOMAIN}" >> /opt/agency_stack/config.env
  echo "GRAFANA_ADMIN_PASSWORD=${GRAFANA_ADMIN_PASSWORD}" >> /opt/agency_stack/config.env
fi

echo -e "${GREEN}✅ Grafana installation complete!${NC}"
