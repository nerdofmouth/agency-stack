---
layout: default
title: VoIP - AgencyStack Documentation
---

# VoIP Integration

The AgencyStack VoIP integration provides a complete Voice over IP solution using FusionPBX and FreeSWITCH, offering enterprise-grade telephony capabilities for your organization.

## Overview

The VoIP stack combines:
- **FusionPBX**: A full-featured multi-tenant PBX web interface
- **FreeSWITCH**: A scalable open source telephony platform
- **PostgreSQL**: Database for call records and configuration
- **Traefik Integration**: Secure TLS-protected access to web interfaces

## Technical Specifications

| Parameter | Value |
|-----------|-------|
| **Version** | 1.0.0 |
| **Default URL** | https://voip.yourdomain.com |
| **SIP Port (UDP/TCP)** | 5060 |
| **SIP Port (TLS)** | 5061 |
| **RTP Port Range** | 16384-32768 |
| **FusionPBX Web UI** | 8082 (Proxied via Traefik) |
| **FusionPBX Admin UI** | 8445 (Proxied via Traefik) |
| **Container Image** | fusionpbx/fusionpbx:latest, freeswitch/freeswitch:latest |
| **Data Directory** | /opt/agency_stack/clients/{CLIENT_ID}/voip_data |
| **Log File** | /var/log/agency_stack/components/voip.log |

## Installation

### Prerequisites

- Docker and Docker Compose
- Traefik configured with Let's Encrypt
- Public domain with properly configured DNS
- Firewall allowing VoIP traffic (SIP and RTP)
- (Optional) Keycloak for SSO integration

### Installation Commands

```bash
# Basic installation
make install-voip DOMAIN=voip.yourdomain.com ADMIN_EMAIL=admin@yourdomain.com

# With client ID for multi-tenancy
make install-voip DOMAIN=voip.client1.com ADMIN_EMAIL=admin@client1.com CLIENT_ID=client1

# With additional options
make install-voip DOMAIN=voip.yourdomain.com ADMIN_EMAIL=admin@yourdomain.com WITH_DEPS=true FORCE=true VERBOSE=true
```

### Command Line Options

The installation script (`install_voip.sh`) supports the following options:

- `--domain <domain>`: Domain name for VoIP services
- `--admin-email <email>`: Admin email for alerts and notifications
- `--client-id <id>`: Client ID for multi-tenant setup
- `--with-deps`: Install dependencies
- `--force`: Force installation even if already installed
- `--verbose`: Show detailed output during installation
- `--help`: Show help message and exit

## Management

### Makefile Targets

| Target | Description |
|--------|-------------|
| `make install-voip` | Install VoIP stack |
| `make voip-status` | Check VoIP service status |
| `make voip-logs` | View VoIP logs |
| `make voip-restart` | Restart VoIP services |
| `make voip-stop` | Stop VoIP services |
| `make voip-start` | Start VoIP services |

## Features

### Call Center Functionality
- IVR (Interactive Voice Response)
- Automatic Call Distribution
- Call Queues
- Time Conditions
- Ring Groups
- Voicemail

### Administrative Features
- Multi-tenant support
- User management
- Extension management
- Call Detail Records (CDR)
- Custom dialplans
- Conference bridges

### Security Features
- TLS Encryption for SIP
- SRTP for media encryption
- Fail2Ban integration
- IP-based access controls
- Rate limiting

## Multi-Tenancy Support

The VoIP stack supports multi-tenancy through:

- Domain-based separation of tenants
- Role-based access control
- Dedicated FreeSWITCH contexts per tenant
- Isolated data storage at `/opt/agency_stack/clients/{CLIENT_ID}/voip_data`

## Integrations

VoIP integrates with other AgencyStack components:

- **Keycloak**: SSO authentication for admin interface
- **Traefik**: TLS termination and routing
- **Monitoring**: Prometheus metrics for call statistics
- **Dashboard**: Visible in the AgencyStack dashboard

## Network Requirements

The VoIP stack requires specific network configurations:

1. **Firewall Rules**:
   - UDP/TCP port 5060 for SIP
   - TCP port 5061 for SIP over TLS
   - UDP ports 16384-32768 for RTP media

2. **NAT Considerations**:
   - Public IP or proper NAT traversal
   - STUN/TURN server configuration for WebRTC
   - Consider using SIPREC for call recording

## Troubleshooting

### Check Logs
```bash
make voip-logs
# or
tail -f /var/log/agency_stack/components/voip.log
```

### Common Issues

1. **SIP Registration Failures**:
   - Check firewall rules
   - Verify SIP credentials
   - Check network connectivity

2. **Poor Call Quality**:
   - Check bandwidth availability
   - Verify QoS settings
   - Investigate network jitter/latency

3. **Extension Not Ringing**:
   - Check extension registration status
   - Verify call routing rules
   - Check dialplan configuration

## Maintenance

To keep your VoIP system running smoothly:

1. **Regular Backups**:
   - Database backups for call records
   - Configuration files
   - Voicemail messages

2. **Updates**:
   - Regularly update FreeSWITCH and FusionPBX
   - Apply security patches promptly
   - Test updates in staging first

3. **Monitoring**:
   - Keep an eye on call quality metrics
   - Monitor disk space for recordings
   - Set up alerts for service disruptions
