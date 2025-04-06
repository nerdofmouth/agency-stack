---
layout: default
title: Builder.io - AgencyStack Documentation
---

# Builder.io

## Overview

Builder.io provides a visual content management system that integrates with AgencyStack to enable no-code content creation and editing. It allows non-technical users to create and manage web content through a visual interface while maintaining sovereignty and control over your content.

## Features

- **Visual Page Building**: Drag-and-drop content creation
- **Component Library**: Reusable UI components
- **Content API**: Headless CMS capabilities
- **A/B Testing**: Test different content variations
- **Personalization**: Dynamic content based on user attributes
- **Integration with WordPress**: Visual editing for WordPress sites
- **Custom Themes**: Apply consistent branding
- **Responsive Design**: Mobile-friendly content creation
- **Multi-tenant Support**: Client-specific content spaces

## Prerequisites

- Docker and Docker Compose
- Traefik for routing and TLS termination
- MongoDB (installed automatically as a dependency)

## Installation

Install Builder.io using the Makefile:

```bash
make builderio
```

Options:

- `--domain=<domain>`: Domain name for the Builder interface
- `--admin-email=<email>`: Admin user email
- `--admin-password=<password>`: Initial admin password
- `--client-id=<client-id>`: Client ID for multi-tenant installations
- `--with-deps`: Install dependencies
- `--force`: Override existing installation

## Configuration

Builder.io configuration is stored in:

```
/opt/agency_stack/clients/${CLIENT_ID}/builderio/config/
```

Environment variables:

| Variable | Description | Default |
|----------|-------------|---------|
| `BUILDER_PORT` | Port for Builder.io | `3000` |
| `BUILDER_API_KEY` | API key for Builder.io | Auto-generated |
| `BUILDER_PRIVATE_KEY` | Private key for content signing | Auto-generated |
| `BUILDER_ADMIN_EMAIL` | Admin email address | From installation |
| `BUILDER_ADMIN_PASSWORD` | Admin password | From installation |
| `BUILDER_MONGODB_URI` | MongoDB connection URI | Auto-configured |
| `BUILDER_PUBLIC_API_KEY` | Public API key for client-side use | Auto-generated |
| `BUILDER_CONTENT_MODELS` | Predefined content models (JSON) | Basic models |

## Usage

### Management Commands

```bash
# Check status
make builderio-status

# View logs
make builderio-logs

# Restart service
make builderio-restart
```

### Web Interface

The Builder.io admin interface is accessible at:

```
https://builder.yourdomain.com/
```

### Content Creation

1. Log in to the Builder.io admin interface
2. Navigate to Content → Pages
3. Click "New" to create a new page
4. Use the visual editor to build your content
5. Publish when ready

### WordPress Integration

To integrate with WordPress:

1. Install the Builder.io plugin in WordPress
2. Configure the plugin with your API key
3. Enable visual editing for posts or pages
4. Use Builder.io to create and edit content visually

## API Integration

Builder.io provides a Content API for headless usage:

```javascript
// Fetch content from Builder.io
fetch('https://cdn.builder.io/api/v2/content/page?apiKey=YOUR_API_KEY&url=/about-us')
  .then(res => res.json())
  .then(data => {
    // Render content using your framework of choice
    const content = data.results[0];
    // ...
  });
```

## Security

Builder.io is configured with the following security measures:

- API key authentication for all content operations
- Private content signing to prevent tampering
- Content preview restrictions based on user roles
- TLS encryption via Traefik
- MongoDB authentication and encryption
- Regular security updates

## Monitoring

All Builder.io operations are logged to:

```
/var/log/agency_stack/components/builderio.log
```

Metrics are available for Prometheus integration.

## Troubleshooting

### Common Issues

1. **Content not loading**:
   - Check API key configuration
   - Verify the content exists and is published
   - Check for JavaScript errors in browser console

2. **Editor connectivity issues**:
   - Verify MongoDB connection
   - Check network connectivity between services
   - Verify Traefik routing is configured correctly

3. **Image upload failures**:
   - Check storage permissions
   - Verify image size limits
   - Check for disk space issues

### Logs

For detailed logs:

```bash
tail -f /var/log/agency_stack/components/builderio.log
```

## Integration with Other Components

Builder.io integrates with:

1. **WordPress**: For visual page building in WordPress sites
2. **Keycloak**: For SSO authentication (optional)
3. **Traefik**: For routing and TLS termination
4. **Seafile**: For advanced file management (optional)

## Advanced Customization

For advanced configurations, edit:

```
/opt/agency_stack/clients/${CLIENT_ID}/builderio/config/settings.json
```

Custom components can be added to:

```
/opt/agency_stack/clients/${CLIENT_ID}/builderio/custom-components/
```

## Content Backup and Migration

Builder.io content can be backed up and migrated:

```bash
# Backup Builder.io content
make builderio-backup

# Restore from backup
make builderio-restore --backup-file=<path-to-backup>
```

## Multi-tenant Configuration

In multi-tenant environments, Builder.io supports:

1. **Organization Spaces**: Isolated content workspaces per client
2. **Custom Domains**: Client-specific publishing domains
3. **Role Separation**: Different access levels per organization
4. **Branding Customization**: Client-specific visual themes

## Content Delivery Network

By default, AgencyStack configures Builder.io to serve content through:

1. **Local CDN**: Self-hosted content delivery
2. **Traefik Caching**: Built-in caching for improved performance
3. **Browser Caching**: Optimized cache headers

For higher traffic applications, additional CDN configuration is available through the advanced settings.
