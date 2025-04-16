# Documenso

## Overview
Document signing platform

## Installation

### Prerequisites
- List of prerequisites

### Installation Process
The installation is handled by the `install_documenso.sh` script, which can be executed using:

```bash
make documenso
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
- `/var/log/agency_stack/components/documenso.log`

### Monitoring
- Metrics and monitoring information

## Troubleshooting

### Common Issues
- List of common issues and their solutions

## Usage

### Creating a Document for Signing

To create a new document for digital signatures:

```bash
# Access Documenso web interface
open https://sign.yourdomain.com

# Login with Keycloak SSO or local account
# From Dashboard, click "New Document"
# Upload PDF file and add recipients
```

### Setting Up Signature Fields

Configure signature placements in your document:

```bash
# After uploading, click "Edit" on your document
# Drag signature fields onto the document
# Assign fields to specific recipients
# Set signing order (if sequential signing is required)
```

### Sending Documents for Signature

Send documents to recipients for digital signatures:

```bash
# Review document and signature fields
# Click "Send" to initiate the signing process
# Recipients will receive email notifications
```

### Managing Document Status

Track and manage your document workflows:

```bash
# View all documents in the Dashboard
# Check status: Draft, Pending, Completed, Declined
# Send reminders for pending signatures
```

### Document Templates

Create reusable templates for common documents:

```bash
# Go to Templates → New Template
# Upload base document and configure fields
# Save template for future use
# Create new documents from templates
```

### API Integration

Integrate Documenso with other applications using the API:

```bash
# Generate API key
# Settings → API Keys → Create New Key

# Example API usage (JavaScript)
const response = await fetch('https://sign.yourdomain.com/api/documents', {
  method: 'POST',
  headers: {
    'Authorization': 'Bearer YOUR_API_KEY',
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({
    title: 'Contract Agreement',
    recipients: [
      { email: 'recipient@example.com', name: 'John Doe' }
    ]
  })
});
```

### Multi-tenant Setup

For organizations with multiple tenants:

```bash
# Each client gets their own isolated document space
# Administrators can switch between tenants
# Documents and templates are not shared between tenants
```

## Upgrading to v1.4.2

### Prerequisites
- Backup your database and document storage
- Ensure you have at least 1GB free disk space

### Upgrade Process
```bash
# Standard upgrade
make documenso-upgrade

# Force upgrade (if needed)
make documenso-upgrade FORCE=true
```

### Key Features in v1.4.2
- Enhanced Keycloak SSO integration
- Improved multi-tenant support
- Better document template management
- Performance optimizations for large documents

### Post-Upgrade Checks
1. Verify all documents are accessible:
```bash
make documenso-status
```
2. Check migration logs:
```bash
make documenso-logs | grep -i migration
```

### Rollback Procedure
If issues occur:
```bash
# Stop service
make documenso-stop

# Restore from backup
cp -r /opt/agency_stack/clients/{CLIENT_ID}/documenso_backup_*/* /opt/agency_stack/clients/{CLIENT_ID}/documenso/

# Restart previous version
make documenso-start
```

## Makefile Targets

| Target | Description |
|--------|-------------|
| `make documenso` | Install documenso |
| `make documenso-status` | Check status of documenso |
| `make documenso-logs` | View documenso logs |
| `make documenso-restart` | Restart documenso services |
| `make documenso-upgrade` | Upgrade documenso |
