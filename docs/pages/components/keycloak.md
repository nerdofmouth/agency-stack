# Keycloak

## Overview
Single sign-on and identity management

## Installation

### Prerequisites
- List of prerequisites

### Installation Process
The installation is handled by the `install_keycloak.sh` script, which can be executed using:

```bash
make keycloak
```

## Configuration

### Default Configuration
- Configuration details

### Customization
- How to customize

## Ports & Endpoints

| Service | Port | Protocol | Description |
|---------|------|----------|-------------|
| Web UI  | XXXX | HTTP/S   | Main web interface |

## Logs & Monitoring

### Log Files
- `/var/log/agency_stack/components/keycloak.log`

### Monitoring
- Metrics and monitoring information

## Troubleshooting

### Common Issues
- List of common issues and their solutions

## Makefile Targets

| Target | Description |
|--------|-------------|
| `make keycloak` | Install keycloak |
| `make keycloak-status` | Check status of keycloak |
| `make keycloak-logs` | View keycloak logs |
| `make keycloak-restart` | Restart keycloak services |
