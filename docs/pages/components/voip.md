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
- **Keycloak SSO**: Optional single sign-on integration for secure authentication

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

# Installation with Keycloak SSO integration
make install-voip DOMAIN=voip.yourdomain.com ADMIN_EMAIL=admin@yourdomain.com ENABLE_KEYCLOAK=true

# With client ID for multi-tenancy
make install-voip DOMAIN=voip.client1.com ADMIN_EMAIL=admin@client1.com CLIENT_ID=client1

# With additional options
make install-voip DOMAIN=voip.yourdomain.com ADMIN_EMAIL=admin@yourdomain.com WITH_DEPS=true FORCE=true VERBOSE=true
```

### Installation Options

The installation script (`install_voip.sh`) supports the following options:

- `--domain <domain>`: Domain name for VoIP services
- `--admin-email <email>`: Admin email for alerts and notifications
- `--client-id <id>`: Client ID for multi-tenant setup
- `--with-deps`: Install dependencies
- `--force`: Force installation even if already installed
- `--verbose`: Show detailed output during installation
- `--help`: Show help message and exit
- `--enable-keycloak`: Enable Keycloak SSO integration
- `--enforce-https`: Enforce HTTPS redirects
- `--fusionpbx-version`: Version of FusionPBX to install
- `--freeswitch-version`: Version of FreeSWITCH to install

## Keycloak SSO Integration

The VoIP component can be integrated with Keycloak for single sign-on authentication. This provides:

- Unified authentication across all AgencyStack components
- Role-based access control for VoIP administration
- Enhanced security with multi-factor authentication options
- Centralized user management

### Enabling SSO Integration

To enable SSO integration during installation:

```bash
scripts/components/install_voip.sh \
  --domain yourdomain.com \
  --admin-email admin@yourdomain.com \
  --enable-keycloak
```

Or using the Makefile:

```bash
make voip DOMAIN=yourdomain.com ADMIN_EMAIL=admin@yourdomain.com ENABLE_KEYCLOAK=true
```

### SSO Configuration

When SSO is enabled, the following configurations are applied:

1. A client is registered in Keycloak with appropriate redirect URIs
2. SSO integration files are created in the VoIP directory
3. The component registry is updated with `sso_configured: true`
4. FusionPBX is configured to use Keycloak for authentication

### Verifying SSO Integration

To verify that SSO integration is correctly configured:

1. Check the component registry for SSO status:
   ```bash
   make voip-status
   ```

2. Verify the SSO configuration files exist:
   ```bash
   ls -la /opt/agency_stack/clients/<CLIENT_ID>/voip/<DOMAIN>/sso/
   ```

3. Access the FusionPBX web interface and verify it redirects to Keycloak login.

### Troubleshooting SSO

If SSO integration is not working as expected:

1. Check the VoIP installation logs:
   ```bash
   cat /var/log/agency_stack/components/voip.log | grep -i keycloak
   ```

2. Verify Keycloak is running and accessible:
   ```bash
   make keycloak-status
   ```

3. Check SSO configuration file permissions:
   ```bash
   ls -la /opt/agency_stack/clients/<CLIENT_ID>/voip/<DOMAIN>/sso/
   ```

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
