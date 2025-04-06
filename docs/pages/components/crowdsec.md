# CrowdSec

## Overview

CrowdSec is a collaborative security engine that detects and blocks malicious activity using crowd-sourced threat intelligence. It works alongside Fail2Ban to provide enhanced security for AgencyStack by analyzing logs, detecting attacks, and sharing threat intelligence.

## Installation

```bash
# Standard installation
make crowdsec

# With custom options
make crowdsec CLIENT_ID=myagency DOMAIN=example.com DASHBOARD=true
```

## Configuration

The CrowdSec component stores its configuration in:
- `/opt/agency_stack/clients/${CLIENT_ID}/crowdsec/`

Key files:
- `config.yaml`: Main configuration file
- `acquis.yaml`: Log acquisition configuration
- `profiles.yaml`: Alert profiles configuration
- `collections/`: Directory containing security rule collections

### Configuration Options

| Option | Description | Default |
|--------|-------------|---------|
| `--client-id` | Client identifier | `default` |
| `--domain` | Domain for rule configuration | `localhost` |
| `--force` | Force reinstallation | `false` |
| `--no-dashboard` | Disable web dashboard | `false` |
| `--dashboard-port` | Dashboard port | `3000` |
| `--metrics-enabled` | Enable Prometheus metrics | `true` |
| `--metrics-port` | Port for metrics endpoint | `6060` |
| `--collections` | Comma-separated list of collections to install | `crowdsecurity/linux,crowdsecurity/http-cve` |

## Ports

| Port | Service | Notes |
|------|---------|-------|
| 3000 | CrowdSec Dashboard | Optional, web interface |
| 6060 | CrowdSec Metrics | Prometheus-compatible metrics endpoint |
| 8080 | LAPI | Local API for CrowdSec bouncers |

## Restart and Maintenance

```bash
# Check status
make crowdsec-status

# View logs
make crowdsec-logs

# Restart the service
make crowdsec-restart
```

## Security

The CrowdSec component enhances security by:

- Detecting complex attack patterns
- Sharing threat intelligence across the community
- Providing real-time security metrics
- Supporting multiple "bouncers" (enforcement points)
- Isolating security rules per client in multi-tenant setups

## Troubleshooting

Common issues:

1. **Missing Detections**
   - Check if appropriate collections are installed
   - Verify log sources are correctly configured
   - Update to latest security rules

2. **Dashboard Access Issues**
   - Verify dashboard is enabled and running
   - Check firewall rules for dashboard port
   - Review credentials configuration

3. **Performance Impact**
   - Adjust log parsing frequency
   - Limit number of active collections
   - Tune detection thresholds for your environment
