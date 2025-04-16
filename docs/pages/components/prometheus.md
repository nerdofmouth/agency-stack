---
layout: default
title: Prometheus - AgencyStack Documentation
---

# Prometheus Monitoring

The AgencyStack Prometheus integration provides a comprehensive monitoring and alerting solution for your entire infrastructure.

## Overview

The Prometheus stack includes:
- **Prometheus Server**: For metrics collection and storage
- **Alertmanager**: For handling and routing alerts
- **Node Exporter**: For system-level metrics
- **Pushgateway** (optional): For batch job metrics
- **Grafana Integration**: For visualization and dashboards
- **Traefik Integration**: For secure TLS access

## Technical Specifications

| Parameter | Value |
|-----------|-------|
| **Version** | 2.44.0 |
| **Default URL** | https://metrics.yourdomain.com |
| **Prometheus Port** | 9090 |
| **Alertmanager Port** | 9093 |
| **Node Exporter Port** | 9100 |
| **Pushgateway Port** | 9091 |
| **Container Images** | prom/prometheus:v2.44.0, prom/alertmanager:v0.25.0, prom/node-exporter:v1.5.0 |
| **Data Directory** | /opt/agency_stack/clients/{CLIENT_ID}/prometheus_data |
| **Log File** | /var/log/agency_stack/components/prometheus.log |

## Installation

### Prerequisites

- Docker and Docker Compose
- Traefik configured with Let's Encrypt
- Domain with properly configured DNS
- Grafana (optional, for visualization)

### Installation Commands

```bash
# Basic installation
make install-prometheus DOMAIN=yourdomain.com

# With Grafana domain specified
make install-prometheus DOMAIN=yourdomain.com GRAFANA_DOMAIN=grafana.yourdomain.com

# With client ID for multi-tenancy
make install-prometheus DOMAIN=client1.com CLIENT_ID=client1

# With additional options
make install-prometheus DOMAIN=yourdomain.com WITH_DEPS=true FORCE=true VERBOSE=true
```

### Command Line Options

The installation script (`install_prometheus.sh`) supports the following options:

- `--domain <domain>`: Base domain for Prometheus services
- `--grafana-domain <domain>`: Domain for Grafana integration
- `--client-id <id>`: Client ID for multi-tenant setup
- `--with-deps`: Install dependencies
- `--force`: Force installation even if already installed
- `--verbose`: Show detailed output during installation
- `--with-pushgateway`: Include Pushgateway for batch job metrics
- `--with-node-exporter`: Include Node Exporter for system metrics (enabled by default)
- `--with-alertmanager`: Include Alertmanager for alerts (enabled by default)
- `--admin-email <email>`: Admin email for alert notifications
- `--help`: Show help message and exit

## Management

### Makefile Targets

| Target | Description |
|--------|-------------|
| `make prometheus` | Install Prometheus stack |
| `make prometheus-status` | Check Prometheus service status |
| `make prometheus-logs` | View Prometheus logs |
| `make prometheus-restart` | Restart Prometheus services |
| `make prometheus-stop` | Stop Prometheus services |
| `make prometheus-start` | Start Prometheus services |
| `make prometheus-reload` | Reload Prometheus configuration |
| `make prometheus-alerts` | View current alert status |

## Features

### Metrics Collection
- Automatic service discovery for AgencyStack components
- Pre-configured rules for common failure scenarios
- High availability mode for critical environments
- Long-term storage with configurable retention

### Alert Management
- Email notifications
- Integration with common notification channels (Slack, PagerDuty, etc.)
- Alert grouping and deduplication
- Silencing and inhibition rules

### Security Features
- TLS encryption for all communications
- Basic authentication for access control
- Role-based access control via Traefik
- HTTPS redirection enforced

## Multi-Tenancy Support

Prometheus supports multi-tenancy through:

- Client-specific metric prefixing
- Isolated data storage at `/opt/agency_stack/clients/{CLIENT_ID}/prometheus_data`
- Separate alerting rules per client
- Role-based dashboard access in Grafana

## Grafana Integration

Prometheus automatically integrates with Grafana:

- Auto-provisioned as a data source in Grafana
- Pre-configured dashboards for all AgencyStack components
- Custom alerting rules synchronized
- Unified query interface

## ExporterHub Integration

AgencyStack components expose metrics via built-in exporters:

| Component | Metrics Path | Port |
|-----------|-------------|------|
| Traefik | /metrics | 8080 |
| Node Exporter | /metrics | 9100 |
| Cadvisor | /metrics | 8081 |
| PostgreSQL | /metrics | 9187 |
| Redis | /metrics | 9121 |
| NGINX | /metrics | 9113 |

## Troubleshooting

### Check Logs
```bash
make prometheus-logs
# or
tail -f /var/log/agency_stack/components/prometheus.log
```

### Common Issues

1. **Target Scraping Failures**:
   - Check network connectivity
   - Verify target is up and running
   - Check firewall rules

2. **Alert Notification Issues**:
   - Verify SMTP configuration
   - Check alert routing configuration
   - Review alert rules for correctness

3. **Storage Issues**:
   - Check disk space availability
   - Review retention policies
   - Consider using remote storage

## Advanced Configuration

### Remote Write/Read

Prometheus can be configured for long-term storage using remote write endpoints:

```yaml
remote_write:
  - url: "https://remote-storage-endpoint/api/v1/write"
    basic_auth:
      username: "username"
      password: "password"
```

### High Availability

For critical environments, Prometheus can be set up in a high-availability mode:

```bash
make install-prometheus DOMAIN=yourdomain.com HA=true
```

### Custom Alerting Rules

Custom alerting rules can be added to:

```
/opt/agency_stack/clients/{CLIENT_ID}/prometheus_data/rules/custom_rules.yml
```

## Maintenance

To keep your monitoring system running smoothly:

1. **Regular Backups**:
   - Database backups for long-term metrics
   - Configuration files
   - Alert rules

2. **Updates**:
   - Regularly update Prometheus and related components
   - Test updates in staging first
   - Keep alert rules current

3. **Capacity Planning**:
   - Monitor storage usage growth
   - Adjust retention policies as needed
   - Scale vertically or horizontally as required
