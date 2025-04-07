# Signing & Timestamps

## Overview
The Signing & Timestamps component provides a secure document signing and integrity verification system for AgencyStack. It combines GPG cryptographic signatures with blockchain-based timestamps to ensure document authenticity, integrity, and non-repudiation.

## Features
- GPG-based document signing with 4096-bit RSA keys
- OpenTimestamps integration for blockchain proof-of-existence
- Detached signatures for integrity verification
- Secure key management
- Document verification workflow
- Audit logs for all signing operations

## Installation

```bash
# Standard installation
make signing-timestamps DOMAIN=example.com ADMIN_EMAIL=admin@example.com

# Multi-tenant installation
make signing-timestamps DOMAIN=example.com ADMIN_EMAIL=admin@example.com CLIENT_ID=client1

# Install with dependencies (automatically generates server keys)
make signing-timestamps DOMAIN=example.com ADMIN_EMAIL=admin@example.com WITH_DEPS=true
```

## Paths and Locations

| Path | Description |
|------|-------------|
| `/opt/agency_stack/clients/<client_id>/signing_timestamps` | Main installation directory |
| `/opt/agency_stack/clients/<client_id>/signing_timestamps/gnupg` | GPG key storage (highly sensitive) |
| `/opt/agency_stack/clients/<client_id>/signing_timestamps/scripts` | Signing and verification scripts |
| `/opt/agency_stack/clients/<client_id>/signing_timestamps/logs` | Signing operation logs |
| `/opt/agency_stack/clients/<client_id>/signing_timestamps/signed` | Contains signed documents |
| `/opt/agency_stack/clients/<client_id>/signing_timestamps/verified` | Contains verification reports |
| `/var/log/agency_stack/components/signing_timestamps.log` | Component installation log |

## Configuration

The component is configured during installation. After installation, you need to generate a signing key if it wasn't automatically created:

```bash
sudo /opt/agency_stack/clients/CLIENT_ID/signing_timestamps/scripts/generate-server-key.sh
```

This will:
1. Create a 4096-bit RSA GPG key
2. Export the public key to the installation directory
3. Save the key fingerprint for verification

## Logs

Logs are stored in two locations:

1. Installation logs: `/var/log/agency_stack/components/signing_timestamps.log`
2. Signing operation logs: `/opt/agency_stack/clients/<client_id>/signing_timestamps/logs/signing.log`

To view logs:

```bash
# View installation logs
cat /var/log/agency_stack/components/signing_timestamps.log

# View signing operation logs through Makefile
make signing-timestamps-logs CLIENT_ID=client1
```

## Ports
This component does not use any network ports directly. It is a command-line utility for document signing and verification.

## Management

The following Makefile targets are available:

```bash
# Install the component
make signing-timestamps

# Check status
make signing-timestamps-status

# View logs
make signing-timestamps-logs

# Regenerate signing keys
make signing-timestamps-restart
```

## Usage

### Signing Documents

To sign a document:

```bash
sudo /opt/agency_stack/clients/CLIENT_ID/signing_timestamps/scripts/sign-document.sh /path/to/document.pdf "Description of document"
```

This will:
1. Create a detached GPG signature
2. Generate a SHA256 hash of the document
3. Create a blockchain timestamp using OpenTimestamps
4. Create a verification package with all necessary information

### Verifying Documents

To verify a document:

```bash
sudo /opt/agency_stack/clients/CLIENT_ID/signing_timestamps/scripts/verify-document.sh /path/to/document.pdf /path/to/document.pdf.asc /path/to/document.pdf.ots
```

This will:
1. Verify the GPG signature
2. Verify the blockchain timestamp
3. Generate a verification report

## Security Considerations

- The GPG keys are stored in `/opt/agency_stack/clients/<client_id>/signing_timestamps/gnupg` with restricted permissions (700)
- Only root can access the signing and verification scripts by default
- All signing operations are logged for audit purposes
- The public key should be shared with parties that need to verify documents
- Consider regular backups of the GPG keys, as loss would prevent verification of previously signed documents

## Integration with Other Components

The Signing & Timestamps component can integrate with several other AgencyStack components:

- **Keycloak**: For identity-based document signing
- **Seafile/Document Storage**: For signing stored documents
- **Backup Strategy**: For secure backup of signing keys
- **Vault**: For enhanced key security

## Troubleshooting

Common issues and solutions:

| Issue | Solution |
|-------|----------|
| Missing GPG keys | Run `make signing-timestamps-restart` to regenerate keys |
| Signature verification fails | Ensure you have the correct public key imported |
| OpenTimestamps verification pending | Timestamps may need time to confirm on the blockchain |
| Permission errors | Ensure scripts are run with sudo privileges |
| Low entropy warning during key generation | Ensure haveged and rng-tools services are running |
