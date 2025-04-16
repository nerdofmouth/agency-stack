# MiroTalk SFU

## Overview

MiroTalk SFU is a self-hosted, secure WebRTC Selective Forwarding Unit (SFU) video conferencing platform that provides privacy-respecting collaboration capabilities for the AgencyStack infrastructure. It enables real-time video communication without requiring client installation.

### Key Features

- **Group Video Conferencing**: Host meetings with multiple participants
- **Screen Sharing**: Share screens for presentations and collaborative work
- **Chat Functionality**: Text communication alongside video
- **Room System**: Create and join meeting rooms with custom URLs
- **No Account Required**: Join meetings without registration
- **Fully Self-Hosted**: Complete control over your data and privacy
- **SFU Architecture**: Optimized for scalability with multiple participants

## Installation

### Prerequisites

- Docker and Docker Compose
- Traefik (for TLS termination and routing)
- A valid domain name pointed to your server

### Installation Process

The installation is handled by the `install_mirotalk_sfu.sh` script, which can be executed using:

```bash
make mirotalk-sfu DOMAIN=video.example.com ADMIN_EMAIL=admin@example.com
```

Optional parameters:
- `CLIENT_ID=tenant1` - For multi-tenant setups
- `ENABLE_CLOUD=true` - To enable cloud TURN servers
- `ENABLE_METRICS=true` - To enable Prometheus metrics
- `FORCE=true` - To force reinstallation

### Makefile Targets

| Target | Description |
|--------|-------------|
| `make mirotalk-sfu` | Install MiroTalk SFU |
| `make mirotalk-sfu-status` | Check the status of MiroTalk SFU |
| `make mirotalk-sfu-logs` | View logs from MiroTalk SFU |
| `make mirotalk-sfu-restart` | Restart the MiroTalk SFU service |
| `make mirotalk-sfu-update` | Update MiroTalk SFU to a newer version |

## Configuration

### Default Configuration

MiroTalk SFU is configured with the following defaults:

- HTTPS enabled through Traefik
- WebRTC statistics enabled
- Local TURN server enabled by default (unless `--enable-cloud` is specified)
- Prometheus metrics (if `--enable-metrics` is specified)

### Directory Structure

```
/opt/agency_stack/mirotalk_sfu/[DOMAIN]/
├── .env                 # Environment variables
├── config/              # Configuration files
├── data/                # Application data
├── docker-compose.yml   # Docker Compose config
└── logs/                # Application logs
```

### Customization

To customize MiroTalk SFU beyond the default settings, you can modify the `.env` file in the installation directory. The main settings include:

- `MEDIASOUP_ANNOUNCED_IP`: Server's public IP (auto-detected)
- `HTTPS`: TLS encryption (enabled by default)
- `CORS_ALLOW_ORIGIN`: Cross-origin resource sharing (default: *)
- `TURN_ENABLED`: TURN server for NAT traversal
- `RECORDING_ENABLED`: Enable/disable recording feature

## Ports & Endpoints

| Service | Port | Protocol | Description |
|---------|------|----------|-------------|
| Web UI | 3000 | HTTPS | Main web interface |
| Metrics | 3001 | HTTP | Prometheus metrics endpoint (if enabled) |
| WebRTC | Dynamic | UDP/TCP | Media streams |

## Usage

### Accessing MiroTalk SFU

1. Navigate to `https://video.yourdomain.com` (replace with your configured domain)
2. Create a new room or join an existing one
3. Share the room URL with participants

### Creating a Meeting

1. Visit the main page
2. Click "Create Meeting" or directly access a room URL
3. Allow browser permissions for camera and microphone
4. Share the room URL with participants

### Admin Access

Admin functionality can be accessed by visiting:
`https://video.yourdomain.com/admin`

The admin credentials are saved during installation in:
`/opt/agency_stack/secrets/mirotalk_sfu/[DOMAIN].env`

## Security Considerations

### Network Security

- All traffic is routed through Traefik with TLS encryption
- WebRTC media is encrypted by default
- Admin interface is protected by authentication

### Data Privacy

- No user data is stored permanently
- No external services are used by default
- Room data is ephemeral and deleted after meetings end

### Hardening Recommendations

- Use strong admin passwords
- Configure a dedicated TURN server for optimal NAT traversal
- Keep the system updated regularly with `make mirotalk-sfu-update`
- Use `CORS_ALLOW_ORIGIN` to restrict access from specific domains
- Enable Prometheus monitoring for security anomaly detection

## Troubleshooting

### Common Issues

1. **Cannot access video.domain.com**
   - Check that your domain DNS points to the server
   - Verify Traefik is running (`docker ps | grep traefik`)
   - Check TLS certificates are valid

2. **Camera/Microphone not working**
   - Ensure browser permissions are granted
   - Check if the device has working camera/mic
   - Some corporate networks block WebRTC traffic

3. **Poor video quality**
   - Insufficient bandwidth
   - Configure a dedicated TURN server
   - Check server resources (CPU/memory)

### Viewing Logs

```bash
make mirotalk-sfu-logs DOMAIN=video.example.com
```

## Comparison: MiroTalk SFU vs. Jitsi Meet

| Feature | MiroTalk SFU | Jitsi Meet |
|---------|--------------|------------|
| Architecture | Selective Forwarding Unit (SFU) | Selective Forwarding Unit (SFU) |
| Installation Complexity | Low (single container) | Medium (multiple components) |
| Resource Requirements | Lower | Higher |
| UI Customization | Medium | Extensive |
| Authentication | Basic | Advanced (with Prosody) |
| Mobile Support | Web-based | Native apps + web |
| Screen Sharing | Yes | Yes |
| Chat | Yes | Yes |
| Recording | Limited | Advanced |
| Breakout Rooms | No | Yes |
| LDAP/SSO Integration | No | Yes |
| Resource Usage at Scale | Moderate | High |

## Conclusion

MiroTalk SFU provides a lightweight, privacy-focused video conferencing solution within the AgencyStack ecosystem. While not as feature-rich as Jitsi Meet, it offers excellent performance with minimal resource requirements, making it ideal for small to medium-sized teams that prioritize simplicity and privacy.

For larger deployments or more advanced features, consider evaluating Jitsi Meet as an alternative solution.
