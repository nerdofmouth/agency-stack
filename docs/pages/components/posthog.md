---
title: PostHog
description: Self-hosted Product Analytics Platform
audience: developers, system administrators
capabilities: analytics, user tracking, event collection, funnels
---

# PostHog

PostHog is an open-source product analytics platform that helps you track user behavior, optimize conversion rates, and improve user experience.

## Overview

PostHog enables teams to understand user behavior through event tracking, session recording, feature flags, and more. This component is integrated with AgencyStack to provide analytics capabilities across the platform.

## Installation

PostHog is installed as part of the demo-core components in AgencyStack. You can install it individually using:

```bash
make posthog
```

### Prerequisites

- Docker and Docker Compose
- Traefik (for routing)
- Minimum 4GB RAM
- 2 CPU cores recommended

## Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `POSTHOG_DOMAIN` | Domain for PostHog access | `posthog.${DOMAIN}` |
| `POSTHOG_SECRET` | Secret key for PostHog | Auto-generated |
| `POSTHOG_PORT` | Internal port | `8000` |

### Paths

| Purpose | Path |
|---------|------|
| Installation | `/opt/agency_stack/clients/${CLIENT_ID}/posthog/` |
| Configuration | `/opt/agency_stack/clients/${CLIENT_ID}/posthog/.env` |
| Logs | `/var/log/agency_stack/components/posthog.log` |

## Usage

Access PostHog at `https://posthog.${DOMAIN}` after installation.

### Default Credentials

On first access, you'll be prompted to create an admin account.

## Features

- Event tracking
- User identification
- Session recording
- Feature flags
- A/B testing
- Funnel analysis
- Retention analysis
- Dashboards

## API & Integration

PostHog provides SDKs for various platforms:

- JavaScript
- Python
- Ruby
- PHP
- Go
- Android
- iOS

### Integration Example

```javascript
// JavaScript integration
posthog.init('<your-project-api-key>', {
  api_host: 'https://posthog.yourdomain.com'
})

// Track an event
posthog.capture('button_clicked', {
  button_id: 'signup',
  page: 'homepage'
})
```

## Management

### Status

Check PostHog status with:

```bash
make posthog-status
```

### Logs

View PostHog logs with:

```bash
make posthog-logs
```

### Restart

Restart PostHog with:

```bash
make posthog-restart
```

## Troubleshooting

### Common Issues

1. **Connection Issues**
   - Verify Traefik routes are properly configured
   - Check Docker network connectivity

2. **High Memory Usage**
   - Adjust resource limits in Docker Compose file
   - Consider scaling horizontally for production use

3. **Database Connection Errors**
   - Check PostgreSQL container status
   - Verify database connection settings

### Logs

Critical errors are logged to `/var/log/agency_stack/components/posthog.log`

## Security Considerations

- PostHog contains sensitive user data - ensure proper access controls
- Enable SSO integration with Keycloak for centralized authentication
- Regularly update to the latest version for security patches

## Backup and Recovery

PostHog data is stored in PostgreSQL. Include the database in your backup strategy:

```bash
# Example backup command
docker exec posthog_db pg_dump -U posthog -d posthog > posthog_backup.sql
```

## Integration with AgencyStack

PostHog integrates with other AgencyStack components for enhanced functionality:

- **Keycloak**: SSO authentication
- **Dashboard**: Analytics overview
- **Traefik**: Secure routing

## References

- [PostHog Documentation](https://posthog.com/docs)
- [PostHog GitHub Repository](https://github.com/PostHog/posthog)
- [PostHog API Reference](https://posthog.com/docs/api)
