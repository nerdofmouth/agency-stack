# Grafana

## Overview
Visualization and analytics

## Installation

### Prerequisites
- List of prerequisites

### Installation Process
The installation is handled by the `install_grafana.sh` script, which can be executed using:

```bash
make grafana
```

## Configuration

### Default Configuration
- Configuration details

### Customization
- How to customize

Configuration files can be found at `/opt/agency_stack/clients/${CLIENT_ID}/grafana/config/`.

## Usage

### Accessing Grafana

Access the Grafana dashboard through your browser:

```bash
# Open Grafana interface
open https://grafana.yourdomain.com

# Login using:
# - Keycloak SSO (if enabled with --enable-keycloak)
# - Default admin credentials (username: admin, password: located in /opt/agency_stack/clients/${CLIENT_ID}/grafana/.admin_password)
```

### Configuring Data Sources

Connect Grafana to your monitoring data:

```bash
# Add a data source
# Configuration → Data Sources → Add data source
# Select source type (Prometheus, Loki, InfluxDB, etc.)
# Configure connection details
# Save & Test to verify connection

# Common AgencyStack data sources
# Prometheus: http://prometheus:9090
# Loki: http://loki:3100
# InfluxDB: http://influxdb:8086
```

### Creating Dashboards

Build monitoring dashboards for your infrastructure:

```bash
# Create a new dashboard
# + (Create) → Dashboard → Add new panel
# Select data source and query
# Configure visualization options
# Save dashboard with descriptive name

# Import a dashboard
# + (Create) → Import
# Upload JSON or enter dashboard ID
# Configure data source variables
# Save dashboard
```

### Setting Up Alerts

Configure monitoring alerts:

```bash
# Create an alert rule
# Alerting → Alert rules → New alert rule
# Define conditions and evaluation interval
# Set notification channels

# Configure notification channels
# Alerting → Notification channels → New channel
# Select type (Email, Slack, Webhook, etc.)
# Configure delivery settings
```

### Using Annotations

Mark important events on your dashboards:

```bash
# Add a manual annotation
# Click on dashboard graph → Add annotation
# Enter description and tags

# Configure annotation queries
# Dashboard settings → Annotations → New
# Set up query to automatically pull events
```

### Multi-tenant Monitoring

For environments with multiple clients:

```bash
# Use Grafana Organizations
# Admin → Organizations → New Organization
# Switch between organizations using dropdown

# Set up folder permissions
# Dashboard → Folder → Permissions
# Assign view/edit permissions to teams
```

### API Integration

Automate Grafana operations:

```bash
# Generate API key
# Configuration → API keys → New API key

# Example API usage (curl)
curl -X GET "https://grafana.yourdomain.com/api/dashboards/home" \
  -H "Authorization: Bearer YOUR_API_KEY"
```

## Ports & Endpoints

| Service | Port | Protocol | Description |
|---------|------|----------|-------------|
| Web UI  | XXXX | HTTP/S   | Main web interface |

## Logs & Monitoring

### Log Files
- `/var/log/agency_stack/components/grafana.log`

### Monitoring
- Metrics and monitoring information

## Troubleshooting

### Common Issues
- List of common issues and their solutions

## Makefile Targets

| Target | Description |
|--------|-------------|
| `make grafana` | Install grafana |
| `make grafana-status` | Check status of grafana |
| `make grafana-logs` | View grafana logs |
| `make grafana-restart` | Restart grafana services |
