# Builderio

## Overview
Visual content management

## Installation

### Prerequisites
- List of prerequisites

### Installation Process
The installation is handled by the `install_builderio.sh` script, which can be executed using:

```bash
make builderio
```

## Configuration

### Default Configuration
- Configuration details

### Customization
- How to customize

Find configuration in `/opt/agency_stack/clients/${CLIENT_ID}/builderio/config/`.

## Usage

### Accessing the Builder.io Interface

Once installed, access Builder.io through your browser at the configured domain:

```
https://builder.yourdomain.com
```

### Creating and Editing Content

1. **Creating New Content Models**:
   ```bash
   # Log in to Builder.io interface
   # Navigate to Models → New Model
   # Define fields and content structure
   ```

2. **Visual Editing**:
   ```bash
   # Select a page or component
   # Use the drag-and-drop interface
   # Save changes when complete
   ```

3. **Publishing Content**:
   ```bash
   # Review content in preview mode
   # Click "Publish" to make changes live
   # Optionally schedule future publishing
   ```

### API Integration

Integrate Builder.io content with your applications:

```javascript
// In your application
import { builder } from '@builder.io/react'

// Initialize with your API key
builder.init('YOUR_API_KEY')

// Fetch content
builder.get('page', {
  url: window.location.pathname
}).promise().then(content => {
  // Use content in your application
})
```

### Headless CMS Usage

Builder.io functions as a headless CMS with JSON API:

```bash
# Fetch content via API
curl -X GET "https://builder.yourdomain.com/api/v1/content/page?url=/home" \
  -H "Authorization: Bearer YOUR_API_KEY"
```

### Multi-tenant Content Management

For multi-tenant setups, use different API keys for different clients:

```bash
# Generate new API key for a tenant
make builderio-create-key CLIENT_ID=tenant1
```

## Ports & Endpoints

| Service | Port | Protocol | Description |
|---------|------|----------|-------------|
| Web UI  | XXXX | HTTP/S   | Main web interface |

## Logs & Monitoring

### Log Files
- `/var/log/agency_stack/components/builderio.log`

### Monitoring
- Metrics and monitoring information

## Troubleshooting

### Common Issues
- List of common issues and their solutions

## Makefile Targets

| Target | Description |
|--------|-------------|
| `make builderio` | Install builderio |
| `make builderio-status` | Check status of builderio |
| `make builderio-logs` | View builderio logs |
| `make builderio-restart` | Restart builderio services |
