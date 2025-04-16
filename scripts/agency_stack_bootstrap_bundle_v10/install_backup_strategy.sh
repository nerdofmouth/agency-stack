#!/bin/bash
# install_backup_strategy.sh - Encrypted offsite incremental backup system using Restic

echo "📦 Installing Backup Strategy (Restic)..."

# Install Restic backup tool
apt-get update
apt-get install -y restic

# Create directories for backup
mkdir -p /opt/backup
mkdir -p /opt/backup/scripts
mkdir -p /opt/backup/logs
mkdir -p /opt/backup/keys
mkdir -p /opt/backup/env

# Create environment file template
cat > /opt/backup/env/restic.env.example <<EOL
# Restic backend configuration
# Uncomment and configure one of the following backends

# Local backend
#RESTIC_REPOSITORY=/path/to/backup/repository

# SFTP backend
#RESTIC_REPOSITORY=sftp:user@host:/path/to/backup/repository

# S3 backend (AWS, MinIO, etc.)
#RESTIC_REPOSITORY=s3:s3.amazonaws.com/bucket_name/path
#AWS_ACCESS_KEY_ID=your_access_key
#AWS_SECRET_ACCESS_KEY=your_secret_key

# B2 backend (Backblaze)
#RESTIC_REPOSITORY=b2:bucket_name:path
#B2_ACCOUNT_ID=your_account_id
#B2_ACCOUNT_KEY=your_account_key

# Rest Server backend
#RESTIC_REPOSITORY=rest:http://host:8000/

# Encryption password for repository
RESTIC_PASSWORD=your_secure_password

# Additional parameters
BACKUP_EXCLUDES="--exclude-file=/opt/backup/exclude.txt"
BACKUP_KEEP_PARAMS="--keep-daily 7 --keep-weekly 4 --keep-monthly 6"
EOL

# Create exclude file template
cat > /opt/backup/exclude.txt <<EOL
# Exclude temporary files
**/tmp/**
**/temp/**
**/.cache/**
**/Cache/**

# Exclude logs
**/logs/**
**/log/**
**/*.log

# Exclude package manager directories
**/node_modules/**
**/.npm/**
**/.yarn/**
**/vendor/**
**/__pycache__/**

# Exclude Docker volumes (you might want to back these up separately)
# /var/lib/docker/volumes/**

# Exclude system directories
/proc/**
/sys/**
/dev/**
/run/**
/var/run/**
/tmp/**
/var/tmp/**
EOL

# Create backup script
cat > /opt/backup/scripts/run-backup.sh <<EOL
#!/bin/bash
# Run a full Restic backup with configuration from environment file

# Check arguments
if [ \$# -lt 2 ]; then
  echo "Usage: \$0 env_file backup_path [backup_tag]"
  echo "Example: \$0 /opt/backup/env/production.env /var/www/html website"
  exit 1
fi

ENV_FILE="\$1"
BACKUP_PATH="\$2"
BACKUP_TAG="\${3:-backup}"

# Check if environment file exists
if [ ! -f "\$ENV_FILE" ]; then
  echo "Error: Environment file '\$ENV_FILE' not found."
  exit 1
fi

# Check if backup path exists
if [ ! -d "\$BACKUP_PATH" ]; then
  echo "Error: Backup path '\$BACKUP_PATH' not found."
  exit 1
fi

# Load environment variables
source "\$ENV_FILE"

# Check if repository is configured
if [ -z "\$RESTIC_REPOSITORY" ]; then
  echo "Error: RESTIC_REPOSITORY not configured in \$ENV_FILE"
  exit 1
fi

# Check if password is configured
if [ -z "\$RESTIC_PASSWORD" ]; then
  echo "Error: RESTIC_PASSWORD not configured in \$ENV_FILE"
  exit 1
fi

# Timestamp for logging
TIMESTAMP=\$(date +%Y-%m-%d_%H-%M-%S)
LOG_FILE="/opt/backup/logs/backup_\${BACKUP_TAG}_\${TIMESTAMP}.log"

# Initialize the repository if needed
if ! restic snapshots &>/dev/null; then
  echo "Initializing repository at \$RESTIC_REPOSITORY..."
  restic init
fi

# Run backup
echo "Starting backup of \$BACKUP_PATH with tag '\$BACKUP_TAG'..."
restic backup \
  \$BACKUP_PATH \
  --tag \$BACKUP_TAG \
  \$BACKUP_EXCLUDES \
  --one-file-system \
  --json | tee -a "\$LOG_FILE"

BACKUP_EXIT_CODE=\${PIPESTATUS[0]}

# Check if backup was successful
if [ \$BACKUP_EXIT_CODE -eq 0 ]; then
  echo "Backup completed successfully."
  
  # Run forget policy
  echo "Applying retention policy..."
  restic forget \
    --tag \$BACKUP_TAG \
    \$BACKUP_KEEP_PARAMS \
    --prune | tee -a "\$LOG_FILE"
  
  # Create backup stats
  echo "Backup statistics:" | tee -a "\$LOG_FILE"
  restic stats latest | tee -a "\$LOG_FILE"
  
  echo "✅ Backup process completed successfully"
else
  echo "❌ Backup failed with exit code \$BACKUP_EXIT_CODE"
  exit \$BACKUP_EXIT_CODE
fi
EOL

# Create integrity check script
cat > /opt/backup/scripts/check-backups.sh <<EOL
#!/bin/bash
# Check repository integrity and backup snapshots

# Check arguments
if [ \$# -lt 1 ]; then
  echo "Usage: \$0 env_file"
  exit 1
fi

ENV_FILE="\$1"

# Check if environment file exists
if [ ! -f "\$ENV_FILE" ]; then
  echo "Error: Environment file '\$ENV_FILE' not found."
  exit 1
fi

# Load environment variables
source "\$ENV_FILE"

# Timestamp for logging
TIMESTAMP=\$(date +%Y-%m-%d_%H-%M-%S)
LOG_FILE="/opt/backup/logs/check_\${TIMESTAMP}.log"

# Check repository
echo "Checking repository integrity..." | tee -a "\$LOG_FILE"
restic check | tee -a "\$LOG_FILE"

CHECK_EXIT_CODE=\${PIPESTATUS[0]}

if [ \$CHECK_EXIT_CODE -eq 0 ]; then
  echo "✅ Repository check completed successfully" | tee -a "\$LOG_FILE"
  
  # List snapshots
  echo "Listing snapshots:" | tee -a "\$LOG_FILE"
  restic snapshots | tee -a "\$LOG_FILE"
else
  echo "❌ Repository check failed with exit code \$CHECK_EXIT_CODE" | tee -a "\$LOG_FILE"
  exit \$CHECK_EXIT_CODE
fi
EOL

# Create restore script
cat > /opt/backup/scripts/restore-backup.sh <<EOL
#!/bin/bash
# Restore files from a Restic backup

# Check arguments
if [ \$# -lt 3 ]; then
  echo "Usage: \$0 env_file snapshot_id restore_path [include_pattern]"
  echo "Example: \$0 /opt/backup/env/production.env latest /tmp/restore"
  echo "Example with pattern: \$0 /opt/backup/env/production.env latest /tmp/restore 'path/to/restore/*'"
  exit 1
fi

ENV_FILE="\$1"
SNAPSHOT_ID="\$2"
RESTORE_PATH="\$3"
INCLUDE_PATTERN="\${4:-}"

# Check if environment file exists
if [ ! -f "\$ENV_FILE" ]; then
  echo "Error: Environment file '\$ENV_FILE' not found."
  exit 1
fi

# Load environment variables
source "\$ENV_FILE"

# Create restore path if it doesn't exist
mkdir -p "\$RESTORE_PATH"

# Timestamp for logging
TIMESTAMP=\$(date +%Y-%m-%d_%H-%M-%S)
LOG_FILE="/opt/backup/logs/restore_\${TIMESTAMP}.log"

# Run restore
echo "Starting restore from snapshot \$SNAPSHOT_ID to \$RESTORE_PATH..." | tee -a "\$LOG_FILE"

if [ -n "\$INCLUDE_PATTERN" ]; then
  echo "Including only files matching: \$INCLUDE_PATTERN" | tee -a "\$LOG_FILE"
  restic restore \$SNAPSHOT_ID --target "\$RESTORE_PATH" --include "\$INCLUDE_PATTERN" | tee -a "\$LOG_FILE"
else
  restic restore \$SNAPSHOT_ID --target "\$RESTORE_PATH" | tee -a "\$LOG_FILE"
fi

RESTORE_EXIT_CODE=\${PIPESTATUS[0]}

if [ \$RESTORE_EXIT_CODE -eq 0 ]; then
  echo "✅ Restore completed successfully to \$RESTORE_PATH" | tee -a "\$LOG_FILE"
else
  echo "❌ Restore failed with exit code \$RESTORE_EXIT_CODE" | tee -a "\$LOG_FILE"
  exit \$RESTORE_EXIT_CODE
fi
EOL

# Make scripts executable
chmod +x /opt/backup/scripts/*.sh

# Create systemd service for scheduled backups
cat > /etc/systemd/system/restic-backup.service <<EOL
[Unit]
Description=Restic Backup Service
After=network.target

[Service]
Type=oneshot
ExecStart=/opt/backup/scripts/run-backup.sh /opt/backup/env/restic.env /path/to/backup_directory backup_tag
User=root
Group=root
EOL

# Create systemd timer for daily backups
cat > /etc/systemd/system/restic-backup.timer <<EOL
[Unit]
Description=Run Restic Backup daily

[Timer]
OnCalendar=*-*-* 2:00:00
Persistent=true

[Install]
WantedBy=timers.target
EOL

echo "✅ Backup Strategy (Restic) installed successfully!"
echo "📝 Configuration:"
echo "  1. Copy and edit the environment template: cp /opt/backup/env/restic.env.example /opt/backup/env/restic.env"
echo "  2. Edit the backup service: nano /etc/systemd/system/restic-backup.service"
echo "  3. Customize exclude patterns: nano /opt/backup/exclude.txt"
echo "📦 Usage:"
echo "  - Run manual backup: /opt/backup/scripts/run-backup.sh /opt/backup/env/restic.env /path/to/backup backup_tag"
echo "  - Check backups: /opt/backup/scripts/check-backups.sh /opt/backup/env/restic.env"
echo "  - Restore files: /opt/backup/scripts/restore-backup.sh /opt/backup/env/restic.env latest /path/to/restore"
echo "⏱️ To enable scheduled backups:"
echo "  systemctl daemon-reload"
echo "  systemctl enable restic-backup.timer"
echo "  systemctl start restic-backup.timer"
