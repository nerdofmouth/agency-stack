---
layout: default
title: Cryptosync - Encrypted Storage & Remote Sync - AgencyStack Documentation
---

# Cryptosync

Cryptosync is an AgencyStack integration that combines encrypted local storage with flexible remote sync capabilities using gocryptfs (or CryFS) and rclone.

![Cryptosync Logo](../../assets/images/components/cryptosync-logo.png)

## Overview

Cryptosync provides a secure, client-isolated way to store sensitive data with transparent encryption while offering flexible sync options to various remote cloud providers. It's designed for multi-tenant environments where data security and separation are critical.

* **Version**: 1.0.0
* **Category**: Security & Storage
* **Components**:
  * gocryptfs - Encrypted filesystem
  * rclone - Remote sync tool
  * Helper scripts for mount/unmount/sync operations

## Features

* **Strong Encryption**: Uses gocryptfs (or optional CryFS) for transparent, filename-encrypted FUSE filesystems
* **Multi-Tenant Design**: Complete isolation between client vaults with dedicated configs and credentials
* **Cloud Provider Flexibility**: Support for 40+ cloud storage providers via rclone
* **Simple Management**: Consistent Makefile targets for easy operation
* **Hardened Security**: Password handling, secure permissions, and isolated storage paths
* **Automated Workflows**: Optional auto-mount and auto-sync capabilities

## Architecture

Cryptosync creates an encrypted FUSE filesystem using either gocryptfs (default) or CryFS. Files written to the mounted directory are automatically encrypted before being stored on disk. The encrypted data can then be synchronized to remote storage using rclone.

### Components

1. **gocryptfs/CryFS**: Provides the encrypted filesystem layer
2. **rclone**: Handles synchronization with remote storage providers
3. **Helper scripts**: Mount, unmount, and sync operations

### Data Flow

```
User Files → Mounted Directory → Encryption Layer → Encrypted Storage → rclone → Remote Storage
```

## Installation

### Prerequisites

* Linux system with FUSE support
* sudo privileges for installation
* Internet access (for dependency installation)

### Using the Makefile

The simplest way to install is through the AgencyStack Makefile:

```bash
# Basic installation with default settings
make cryptosync

# Installation with specific client ID and custom mount directory
make cryptosync CLIENT_ID=client1 MOUNT_DIR=/mnt/secure WITH_DEPS=true

# Installation with S3 remote configuration
make cryptosync CLIENT_ID=client1 REMOTE_TYPE=s3 REMOTE_NAME=my-s3-backup \
  REMOTE_OPTIONS="access_key_id=AKIAXXXXXXXX,secret_access_key=YYYYYY,region=us-east-1" \
  INITIAL_SYNC=true
```

### Manual Installation

You can also install manually using the installation script:

```bash
sudo /opt/agency_stack/scripts/components/install_cryptosync.sh \
  --client-id client1 \
  --mount-dir /mnt/secure \
  --remote-name my-s3-backup \
  --config-name default \
  --with-deps \
  --remote-type s3 \
  --remote-path mybucket/backup \
  --remote-options "access_key_id=AKIAXXXXXXXX,secret_access_key=YYYYYY,region=us-east-1" \
  --initial-sync
```

### Configuration Options

| Option | Description | Default |
|--------|-------------|---------|
| `--client-id` | Client ID for multi-tenant setup | `default` |
| `--mount-dir` | Directory where the encrypted volume will be mounted | `/opt/agency_stack/clients/<CLIENT_ID>/vault/decrypted` |
| `--remote-name` | Name for the rclone remote configuration | `default-remote` |
| `--config-name` | Name for the configuration profile | `default` |
| `--with-deps` | Install dependencies (gocryptfs, rclone, etc.) | `false` |
| `--force` | Force installation even if already installed | `false` |
| `--use-cryfs` | Use CryFS instead of gocryptfs | `false` |
| `--initial-sync` | Perform initial sync to remote after setup | `false` |
| `--remote-type` | Rclone remote type (e.g., s3, gdrive, webdav) | |
| `--remote-path` | Path/bucket on the remote | `backup` |
| `--remote-options` | Comma-separated list of remote options (key=value) | |
| `--vault-password` | Password for the encrypted vault (UNSAFE: use only for automation) | |
| `--auto-mount` | Automatically mount the encrypted volume after setup | `false` |

## Usage

### Basic Operations

```bash
# Mount the encrypted filesystem
make cryptosync-mount CLIENT_ID=client1

# View the status
make cryptosync-status CLIENT_ID=client1

# Sync to remote
make cryptosync-sync CLIENT_ID=client1 REMOTE_PATH=mybucket/backup

# Unmount the encrypted filesystem
make cryptosync-unmount CLIENT_ID=client1
```

### Configuration

You can configure Cryptosync and rclone settings:

```bash
# Edit Cryptosync configuration
make cryptosync-config CLIENT_ID=client1 CONFIG_NAME=default

# Configure rclone remotes interactively
make cryptosync-rclone-config CLIENT_ID=client1
```

### Direct Script Access

The installation creates symlinks for direct access to helper scripts:

```bash
# Mount filesystem
cryptosync-mount-client1-default

# Unmount filesystem
cryptosync-unmount-client1-default

# Sync to remote
cryptosync-sync-client1-default mybucket/backup
```

## Multi-Tenant Configuration

Each client gets its own isolated storage and configuration:

```
/opt/agency_stack/clients/<CLIENT_ID>/
├── vault/
│   ├── encrypted/    # Encrypted data
│   └── decrypted/    # Mount point (if default)
├── rclone/
│   └── rclone.conf   # Client-specific rclone config
└── cryptosync/
    ├── config/       # Configuration files
    ├── scripts/      # Helper scripts
    └── summary.json  # Installation summary
```

This ensures complete isolation between different clients' data.

## Supported Remote Services

Cryptosync supports all rclone backends, including:

* **Cloud Storage**: Amazon S3, Google Cloud Storage, Microsoft Azure Blob Storage
* **File Storage**: Google Drive, Dropbox, OneDrive, Box, pCloud
* **Self-Hosted**: SFTP, WebDAV, Nextcloud, ownCloud, SMB/CIFS
* **Specialized**: Backblaze B2, Wasabi, Storj, Mega, Jottacloud

See the [rclone documentation](https://rclone.org/docs/) for a complete list of supported providers and their configuration options.

## Security Considerations

### Encryption Strength

Cryptosync uses strong encryption:

* **gocryptfs**: AES-256-GCM for file contents, EME wide-block encryption for filenames
* **CryFS** (optional): AES-256-GCM for both file contents and directory structure

### Password Management

Best practices for password management:

1. **Interactive Mode**: Always prefer interactive password entry rather than using `--vault-password`
2. **Password Storage**: If automation requires password storage, use secure environment variables or a secret management system
3. **Access Control**: Ensure the mount directory has appropriate permissions (default: 700)

### Remote Security

When configuring remote storage:

1. **Credentials**: Store API keys and secrets securely
2. **Encryption**: Use HTTPS for all remote connections
3. **Access Control**: Apply least-privilege principles to remote storage access

## Monitoring and Logging

Cryptosync logs all activities to:

```
/var/log/agency_stack/components/cryptosync.log
```

The log includes information about:
- Installation steps
- Mount/unmount operations
- Sync operations
- Error conditions

## Troubleshooting

### Common Issues

**Filesystem won't mount**
- Check if FUSE is properly installed
- Verify you have the correct password
- Check filesystem permissions

```bash
# Check FUSE installation
fusermount -V

# Check mount directory permissions
ls -la $(dirname /path/to/mountdir)
```

**Sync failures**
- Verify rclone configuration is correct
- Check network connectivity to remote
- Confirm remote credentials are valid

```bash
# Test rclone configuration
rclone lsd --config /opt/agency_stack/clients/client1/rclone/rclone.conf remote-name:

# Check rclone logs
make cryptosync-sync CLIENT_ID=client1 REMOTE_PATH=path | tee sync-debug.log
```

**Permission denied errors**
- Check that you're running commands with appropriate privileges
- Verify ownership of encryption/mount directories

```bash
# Fix permissions
sudo chown -R $(whoami):$(whoami) /opt/agency_stack/clients/client1/vault
```

## Advanced Usage

### Automation with Cron

You can set up automated backups using cron:

```bash
# Add to crontab
# Daily backup at 2 AM
0 2 * * * /usr/local/bin/cryptosync-mount-client1-default && /usr/local/bin/cryptosync-sync-client1-default mybucket/backup && /usr/local/bin/cryptosync-unmount-client1-default
```

### Multiple Configuration Profiles

You can create multiple configuration profiles for different purposes:

```bash
# Install with specific config name
make cryptosync CLIENT_ID=client1 CONFIG_NAME=photos REMOTE_NAME=photo-backup

# Use the specific config
make cryptosync-mount CLIENT_ID=client1 CONFIG_NAME=photos
```

### Bidirectional Sync

For bidirectional synchronization:

```bash
# Use rclone bisync instead of sync
rclone bisync --config /opt/agency_stack/clients/client1/rclone/rclone.conf \
  /opt/agency_stack/clients/client1/vault/encrypted remote:path
```

## Data Migration

### Moving to a New Server

To migrate Cryptosync data to a new server:

1. **Backup configuration**:
   ```bash
   tar -czf cryptosync-config.tar.gz /opt/agency_stack/clients/client1/cryptosync
   tar -czf cryptosync-rclone.tar.gz /opt/agency_stack/clients/client1/rclone
   ```

2. **Copy encrypted data**:
   ```bash
   tar -czf cryptosync-vault.tar.gz /opt/agency_stack/clients/client1/vault/encrypted
   ```

3. **Restore on new server**:
   ```bash
   mkdir -p /opt/agency_stack/clients/client1
   tar -xzf cryptosync-config.tar.gz -C /opt/agency_stack/clients/client1
   tar -xzf cryptosync-rclone.tar.gz -C /opt/agency_stack/clients/client1
   tar -xzf cryptosync-vault.tar.gz -C /opt/agency_stack/clients/client1
   ```

4. **Install Cryptosync on new server**:
   ```bash
   make cryptosync CLIENT_ID=client1 FORCE=true
   ```

## Uninstallation

To completely remove Cryptosync:

```bash
# Unmount all filesystems first
make cryptosync-unmount CLIENT_ID=client1

# Remove data directories (caution!)
sudo rm -rf /opt/agency_stack/clients/client1/vault
sudo rm -rf /opt/agency_stack/clients/client1/rclone
sudo rm -rf /opt/agency_stack/clients/client1/cryptosync

# Remove symlinks
sudo rm /usr/local/bin/cryptosync-*-client1-*
```

## Further Resources

- [gocryptfs Documentation](https://nuetzlich.net/gocryptfs/documentation/)
- [CryFS Documentation](https://www.cryfs.org/tutorial)
- [rclone Documentation](https://rclone.org/docs/)
- [FUSE Filesystem Guide](https://www.kernel.org/doc/html/latest/filesystems/fuse.html)
