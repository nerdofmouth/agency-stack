---
layout: default
title: PeerTube - AgencyStack Documentation
---

# PeerTube

PeerTube is a decentralized, self-hosted video streaming platform that's integrated into the AgencyStack Content & Media suite.

## Overview

PeerTube enables your organization to host videos on your own infrastructure, providing complete control over your content and user data. It's a powerful alternative to centralized video platforms like YouTube or Vimeo.

**Key Features:**
- Self-hosted video streaming
- Live streaming support via RTMP
- WebTorrent integration for efficient bandwidth use
- Federation capabilities with ActivityPub
- Advanced user management
- Multi-language support
- Customizable interface

## Technical Specifications

| Parameter | Value |
|-----------|-------|
| **Version** | 5.1.0 |
| **Default URL** | https://peertube.yourdomain.com |
| **Web Port** | 9000 |
| **RTMP Port** | 1935 |
| **Admin Port** | 9001 |
| **Container Image** | chocobozzz/peertube:production-bookworm |
| **Data Directory** | /opt/agency_stack/clients/{CLIENT_ID}/peertube_data |
| **Log File** | /var/log/agency_stack/components/peertube.log |

## Installation

### Prerequisites

- Docker and Docker Compose
- Traefik configured with Let's Encrypt
- Domain name properly configured in DNS
- (Optional) Keycloak for SSO integration

### Installation Commands

**Basic Installation:**
```bash
make peertube
```

**With SSO Integration:**
```bash
make peertube-sso
```

**With Dependencies:**
```bash
make peertube-with-deps
```

**Force Reinstallation:**
```bash
make peertube-reinstall
```

### Command Line Options

The installation script (`install_peertube.sh`) supports the following options:

- `--domain <domain>`: Domain name for PeerTube (e.g., peertube.yourdomain.com)
- `--client-id <id>`: Client ID for multi-tenant setup and SSO integration
- `--with-deps`: Install dependencies (PostgreSQL, Redis, ffmpeg, etc.)
- `--force`: Force installation even if already installed
- `--help`: Show help message and exit

## Management

### Makefile Targets

| Target | Description |
|--------|-------------|
| `make peertube` | Install PeerTube |
| `make peertube-sso` | Install PeerTube with SSO integration |
| `make peertube-with-deps` | Install PeerTube with all dependencies |
| `make peertube-reinstall` | Reinstall PeerTube |
| `make peertube-status` | Check PeerTube status |
| `make peertube-logs` | View PeerTube logs |
| `make peertube-stop` | Stop PeerTube |
| `make peertube-start` | Start PeerTube |
| `make peertube-restart` | Restart PeerTube |

## Multi-Tenancy Support

PeerTube in AgencyStack supports multi-tenancy through the `--client-id` parameter. Each client gets:

- Isolated data storage at `/opt/agency_stack/clients/{CLIENT_ID}/peertube_data`
- Custom subdomains (e.g., peertube.client1.com, peertube.client2.com)
- Separate SSO configurations
- Isolated Docker containers with unique names

## Integration with AgencyStack

PeerTube integrates with other AgencyStack components:

- **Keycloak**: SSO authentication
- **Traefik**: TLS termination and routing
- **Monitoring**: Prometheus metrics
- **Mail**: SMTP configuration for notifications
- **Dashboard**: Visible in the AgencyStack dashboard under Content & Media

## Security Features

The AgencyStack PeerTube implementation includes several security enhancements:

- HTTP Strict Transport Security (HSTS)
- XSS Protection
- Content Type Sniffing Protection
- Frame Denial (anti-clickjacking)
- Secure TLS configuration
- Container isolation
- Database credential security

## Broadcasting Scenarios for nerdofmouth.com

### 1. Live Streaming Setup

**Requirements:**
- OBS Studio or similar broadcasting software
- RTMP credentials (from PeerTube admin panel)

**Configuration:**
```
Streaming Service: Custom
Server: rtmp://peertube.nerdofmouth.com/live
Stream Key: [your-stream-key]
```

**Best Practices:**
- Use 720p or 1080p resolution
- Bitrate between 2500-6000 kbps
- Keyframe interval: 2 seconds
- Audio codec: AAC at 128kbps
- Video codec: H.264 (x264)

### 2. Scheduled Broadcasts

1. Create a scheduled video in PeerTube admin
2. Configure OBS to auto-start at scheduled time
3. Use `--scheduled-time` parameter when starting stream

### 3. Multi-stream Setup

```bash
# Primary stream
rtmp://peertube.nerdofmouth.com/live/primary

# Backup stream (failover)
rtmp://peertube.nerdofmouth.com/live/backup
```

### 4. Recording and Archiving

- All streams automatically archived
- Find recordings in `/opt/agency_stack/clients/{CLIENT_ID}/peertube/recordings`
- Auto-published based on admin settings

### 5. Monitoring Stream Health

```bash
# Check stream status
make peertube-status

# View recent logs
make peertube-logs | grep -i rtmp

# Check bandwidth usage
vnstat -i eth0 -l
```

## Troubleshooting

**Check Logs:**
```bash
make peertube-logs
# or
tail -f /var/log/agency_stack/components/peertube.log
```

**Common Issues:**

1. **PeerTube doesn't start:** 
   - Check ports are not in use
   - Ensure Docker is running
   - Verify disk space availability

2. **Cannot upload videos:**
   - Check disk space
   - Verify user permissions
   - Ensure FFmpeg is installed correctly

3. **SSO not working:**
   - Verify Keycloak integration
   - Check client ID configuration
   - Inspect browser console for CORS errors

## Maintenance

To keep your PeerTube instance healthy:

1. **Regular Updates:**
   ```bash
   make peertube-reinstall
   ```

2. **Backup Data:**
   - Regularly backup the `/opt/agency_stack/clients/{CLIENT_ID}/peertube_data` directory
   - Backup PostgreSQL database

3. **Clean Old Videos:**
   - Use PeerTube admin UI to manage storage
   - Set retention policies as needed

## Additional Resources

- [Official PeerTube Documentation](https://docs.joinpeertube.org/)
- [AgencyStack Community Forum](https://community.agencystack.com/c/components/peertube)
- [Video Tutorial: PeerTube Administration](https://videos.agencystack.com/w/peertube-admin)
