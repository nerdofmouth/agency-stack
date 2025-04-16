# CrowdSec

## Overview
CrowdSec is a modern security automation engine that detects and responds to attacks. It works as a collaborative security solution that leverages a crowd-sourced threat intelligence feed while respecting privacy. Within AgencyStack, CrowdSec acts as a security layer that protects all services by detecting malicious activity and blocking attackers at the reverse proxy level.

## Installation

### Prerequisites
- Docker and Docker Compose must be installed
- Traefik reverse proxy should be configured and running
- System logs must be accessible to the CrowdSec container
- Port 8080 (internal) and 8082 must be available locally

### Installation Process
The installation is handled by the `install_crowdsec.sh` script, which can be executed using:

```bash
make crowdsec
```

This will:
1. Create required directories and configuration files
2. Generate API keys for local and online access
3. Configure CrowdSec to monitor system and service logs
4. Set up the Traefik bouncer for automatic attack mitigation
5. Start CrowdSec, the bouncer, and the dashboard as Docker containers

## Configuration

### Default Configuration
CrowdSec is configured with the following defaults:
- Monitoring of system logs (`/var/log/auth.log`, `/var/log/syslog`) and application logs
- Integration with Traefik via bouncer for automatic IP blocking
- Default remediation of 4 hours ban for malicious IPs
- Secure dashboard access via HTTPS through Traefik
- Pre-installed security collections for Linux, Traefik, Nginx, and Apache2

### Customization
Configuration files are located in `/opt/agency_stack/clients/${CLIENT_ID}/crowdsec/config/`:

- `config.yaml`: Main CrowdSec configuration
- `acquis.yaml`: Log acquisition configuration
- `profiles.yaml`: Remediation profiles
- `local_api_credentials.yaml`: Local API access credentials
- `online_api_credentials.yaml`: Online API access credentials
- `bouncer_traefik.yaml`: Traefik bouncer configuration

## Paths & Directories

| Path | Description |
|------|-------------|
| `/opt/agency_stack/clients/${CLIENT_ID}/crowdsec/` | Main installation directory |
| `/opt/agency_stack/clients/${CLIENT_ID}/crowdsec/config/` | Configuration files |
| `/opt/agency_stack/clients/${CLIENT_ID}/crowdsec/data/` | CrowdSec database and state |
| `/var/log/agency_stack/components/crowdsec.log` | Installation and operation logs |
| `/var/lib/crowdsec/data/` | Data directory inside the container |

## Usage

### Monitoring Security Events

CrowdSec continuously monitors your logs and security events. You can check the current security status through the dashboard or command line:

```bash
# View security service status
make crowdsec-status

# View recent security events via the dashboard
https://crowdsec.${DOMAIN}
```

### Managing Decisions

Security decisions (blocks, captchas, etc.) can be managed through the dashboard or CLI:

```bash
# List active decisions
docker exec -it crowdsec_${CLIENT_ID} cscli decisions list

# Add a manual IP ban
docker exec -it crowdsec_${CLIENT_ID} cscli decisions add --ip 192.0.2.1 --type ban --duration 24h

# Delete a decision
docker exec -it crowdsec_${CLIENT_ID} cscli decisions delete --ip 192.0.2.1
```

### Working with Bouncers

Bouncers are the enforcement components that apply CrowdSec decisions. AgencyStack comes with a Traefik bouncer pre-configured:

```bash
# List registered bouncers
docker exec -it crowdsec_${CLIENT_ID} cscli bouncers list

# Add a new bouncer
docker exec -it crowdsec_${CLIENT_ID} cscli bouncers add myBouncer
```

### Managing Collections and Scenarios

CrowdSec uses scenarios and collections to detect threats:

```bash
# List installed collections
docker exec -it crowdsec_${CLIENT_ID} cscli collections list

# Install a new collection
docker exec -it crowdsec_${CLIENT_ID} cscli collections install crowdsecurity/nginx

# List enabled scenarios
docker exec -it crowdsec_${CLIENT_ID} cscli scenarios list
```

### Viewing Alerts and Metrics

Monitor security alerts and system performance:

```bash
# View recent alerts
docker exec -it crowdsec_${CLIENT_ID} cscli alerts list

# Check metrics
docker exec -it crowdsec_${CLIENT_ID} cscli metrics
```

## Ports & Endpoints

| Service | Port | Protocol | Description |
|---------|------|----------|-------------|
| CrowdSec API | 8080 | HTTP (internal) | Local API for bouncers and dashboard |
| Dashboard | 8082 | HTTP (internal) | Web interface (proxied by Traefik) |
| Dashboard | 443 | HTTPS | External access via `crowdsec.${DOMAIN}` |

## Logs & Monitoring

### Log Files
- `/var/log/agency_stack/components/crowdsec.log`: Installation and operation logs
- Container logs accessible via `docker logs crowdsec_${CLIENT_ID}`
- Container logs accessible via `docker logs crowdsec-traefik-bouncer_${CLIENT_ID}`
- Container logs accessible via `docker logs crowdsec-dashboard_${CLIENT_ID}`

### Monitoring
- Dashboard provides real-time metrics and alerts at `https://crowdsec.${DOMAIN}`
- Health status can be checked with `make crowdsec-status`
- Prometheus metrics exposed at `http://localhost:6060/metrics` (internal)

## Security

### Authentication
- Dashboard is protected with the credentials generated during installation
- API access requires the API key stored in the credentials files
- Traefik bouncer authenticates to CrowdSec using a dedicated API key

### Hardening
- CrowdSec containers run with limited permissions
- API and dashboard ports are only exposed locally (except via Traefik)
- All sensitive files have restricted permissions
- Communication between components is encrypted

## Troubleshooting

### Common Issues
- **Dashboard inaccessible**: Verify Traefik is running and properly configured
- **No alerts appearing**: Check log acquisition in `acquis.yaml` and verify log files exist
- **Bouncer not blocking attacks**: Ensure the Traefik bouncer is running and connected to CrowdSec
- **High CPU usage**: Adjust the number of parser routines in `config.yaml`

### Recovery
If CrowdSec fails, you can restart it with:
```bash
make crowdsec-restart
```

For persistent issues, reinstalling with the force flag may help:
```bash
make crowdsec FORCE=true
```

## Integration with Other Components

CrowdSec automatically protects all services exposed through Traefik. The Traefik bouncer applies all decisions (bans, captchas) at the edge, preventing malicious traffic from reaching your services.

For additional protection of specific services, you can install dedicated bouncers for:
- Nginx
- Apache
- MySQL
- Postgresql

## Makefile Targets

| Target | Description |
|--------|-------------|
| `make crowdsec` | Install CrowdSec |
| `make crowdsec-status` | Check status of CrowdSec and its components |
| `make crowdsec-logs` | View CrowdSec logs |
| `make crowdsec-restart` | Restart CrowdSec services |
