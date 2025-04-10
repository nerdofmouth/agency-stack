# Crowdsec

## Overview
Security automation

## Installation

### Prerequisites
- List of prerequisites

### Installation Process
The installation is handled by the `install_crowdsec.sh` script, which can be executed using:

```bash
make crowdsec
```

## Configuration

### Default Configuration
- Configuration details

### Customization
- How to customize

Configuration files are located in `/opt/agency_stack/clients/${CLIENT_ID}/crowdsec/config/`.

## Usage

### Monitoring Security Events

CrowdSec continuously monitors your logs and security events. You can check the current security status:

```bash
# View recent security events
make crowdsec-status

# Check detailed metrics
make crowdsec-metrics
```

### Managing Decisions

Security decisions (blocks, captchas, etc.) can be managed:

```bash
# List active decisions
sudo cscli decisions list

# Add a manual IP ban
sudo cscli decisions add --ip 192.0.2.1 --type ban --duration 24h

# Delete a decision
sudo cscli decisions delete --ip 192.0.2.1
```

### Working with Bouncers

Bouncers are the enforcement components that apply CrowdSec decisions:

```bash
# List registered bouncers
sudo cscli bouncers list

# Add a new bouncer
sudo cscli bouncers add myBouncer --key <API_KEY>
```

### Managing Collections and Scenarios

CrowdSec uses scenarios and collections to detect threats:

```bash
# List installed collections
sudo cscli collections list

# Install a new collection
sudo cscli collections install crowdsecurity/nginx

# List enabled scenarios
sudo cscli scenarios list
```

### Viewing Alerts and Metrics

Monitor security alerts and system performance:

```bash
# View recent alerts
sudo cscli alerts list

# Check metrics
sudo cscli metrics
```

### Using the Local API

Interact with CrowdSec via its local API:

```bash
# Get server status
curl -H "X-Api-Key: <LAPI_KEY>" http://localhost:8080/v1/info

# Check if an IP is banned
curl -H "X-Api-Key: <LAPI_KEY>" http://localhost:8080/v1/decisions?ip=192.0.2.1
```

### Integrating with AgencyStack Components

CrowdSec protects other AgencyStack components:

```bash
# Enable protection for a specific component
make crowdsec-protect COMPONENT=traefik

# View protection status for all components
make crowdsec-protection-status
```

## Ports & Endpoints

| Service | Port | Protocol | Description |
|---------|------|----------|-------------|
| Web UI  | XXXX | HTTP/S   | Main web interface |

## Logs & Monitoring

### Log Files
- `/var/log/agency_stack/components/crowdsec.log`

### Monitoring
- Metrics and monitoring information

## Troubleshooting

### Common Issues
- List of common issues and their solutions

## Makefile Targets

| Target | Description |
|--------|-------------|
| `make crowdsec` | Install crowdsec |
| `make crowdsec-status` | Check status of crowdsec |
| `make crowdsec-logs` | View crowdsec logs |
| `make crowdsec-restart` | Restart crowdsec services |
