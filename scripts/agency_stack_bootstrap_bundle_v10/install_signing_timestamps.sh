#!/bin/bash
# install_signing_timestamps.sh - Decentralized document signing & integrity verification

echo "🧾 Installing Signing & Timestamps (GPG + OpenTimestamps)..."

# Install required packages
apt-get update
apt-get install -y gnupg2 python3-pip python3-dev git haveged rng-tools

# Improve entropy for key generation
systemctl enable haveged
systemctl start haveged
systemctl enable rng-tools
systemctl start rng-tools

# Create directories
mkdir -p /opt/signing
mkdir -p /opt/signing/gnupg
mkdir -p /opt/signing/scripts
mkdir -p /opt/signing/logs
mkdir -p /opt/signing/verified

# Set proper permissions for GPG directory
chmod 700 /opt/signing/gnupg

# Install OpenTimestamps client
pip3 install opentimestamps-client

# Create helper scripts
cat > /opt/signing/scripts/generate-server-key.sh <<EOL
#!/bin/bash
# This script generates a GPG key for the server

# Check if running as root
if [ "\$(id -u)" -ne 0 ]; then
  echo "This script must be run as root" >&2
  exit 1
fi

# Get hostname for the key
HOSTNAME=\$(hostname)
EMAIL="admin@\${HOSTNAME}"
NAME="FOSS Server \${HOSTNAME}"

# Create batch file for unattended key generation
cat > /opt/signing/gnupg/key-gen-template <<EOF
%echo Generating GPG key for \$NAME
Key-Type: RSA
Key-Length: 4096
Subkey-Type: RSA
Subkey-Length: 4096
Name-Real: \$NAME
Name-Email: \$EMAIL
Expire-Date: 0
%no-protection
%commit
%echo Key generation completed
EOF

# Set GNUPGHOME
export GNUPGHOME=/opt/signing/gnupg

# Generate the key
gpg --batch --generate-key /opt/signing/gnupg/key-gen-template

# Get the key ID
KEY_ID=\$(gpg --list-keys --with-colons | grep pub | head -n1 | cut -d':' -f5)

# Export public key
gpg --armor --export \$KEY_ID > /opt/signing/\${HOSTNAME}-public-key.asc

echo "Server GPG key generated successfully."
echo "Key ID: \$KEY_ID"
echo "Public key exported to: /opt/signing/\${HOSTNAME}-public-key.asc"
echo "Please back up the key directory at /opt/signing/gnupg securely!"
EOL

# Create document signing script
cat > /opt/signing/scripts/sign-document.sh <<EOL
#!/bin/bash
# Signs a document with GPG and creates a timestamp

# Check arguments
if [ \$# -lt 1 ]; then
  echo "Usage: \$0 document_path [output_dir]"
  exit 1
fi

DOCUMENT="\$1"
OUTPUT_DIR="\${2:-/opt/signing/verified}"

# Check if file exists
if [ ! -f "\$DOCUMENT" ]; then
  echo "Error: Document '\$DOCUMENT' not found."
  exit 1
fi

# Set GNUPGHOME
export GNUPGHOME=/opt/signing/gnupg

# Get the key ID
KEY_ID=\$(gpg --list-keys --with-colons | grep pub | head -n1 | cut -d':' -f5)

# Create the basename for output files
BASENAME=\$(basename "\$DOCUMENT")
TIMESTAMP=\$(date +%Y%m%d-%H%M%S)
OUTPUT_BASE="\$OUTPUT_DIR/\$BASENAME-\$TIMESTAMP"

# Sign the document
gpg --detach-sign --armor --local-user \$KEY_ID -o "\${OUTPUT_BASE}.sig" "\$DOCUMENT"

# Create SHA256 hash
sha256sum "\$DOCUMENT" > "\${OUTPUT_BASE}.sha256"

# Create a timestamp
ots stamp "\${OUTPUT_BASE}.sha256"

echo "✅ Document signed and timestamped successfully"
echo "📄 Document: \$DOCUMENT"
echo "🔏 Signature: \${OUTPUT_BASE}.sig"
echo "🔐 Hash: \${OUTPUT_BASE}.sha256"
echo "⏱️ Timestamp: \${OUTPUT_BASE}.sha256.ots"
EOL

# Create timestamp verification script
cat > /opt/signing/scripts/verify-document.sh <<EOL
#!/bin/bash
# Verifies a document's signature and timestamp

# Check arguments
if [ \$# -lt 3 ]; then
  echo "Usage: \$0 document_path signature_path timestamp_path"
  exit 1
fi

DOCUMENT="\$1"
SIGNATURE="\$2"
TIMESTAMP="\$3"

# Check if files exist
if [ ! -f "\$DOCUMENT" ]; then
  echo "Error: Document '\$DOCUMENT' not found."
  exit 1
fi

if [ ! -f "\$SIGNATURE" ]; then
  echo "Error: Signature '\$SIGNATURE' not found."
  exit 1
fi

if [ ! -f "\$TIMESTAMP" ]; then
  echo "Error: Timestamp '\$TIMESTAMP' not found."
  exit 1
fi

# Set GNUPGHOME
export GNUPGHOME=/opt/signing/gnupg

# Verify signature
echo "🔍 Verifying signature..."
gpg --verify "\$SIGNATURE" "\$DOCUMENT"
SIG_RESULT=\$?

# Verify timestamp
echo "⏱️ Verifying timestamp..."
ots verify "\$TIMESTAMP"
OTS_RESULT=\$?

# Show results
if [ \$SIG_RESULT -eq 0 ] && [ \$OTS_RESULT -eq 0 ]; then
  echo "✅ Document verification successful!"
  echo "✅ Signature is valid"
  echo "✅ Timestamp is valid"
  exit 0
else
  echo "❌ Document verification failed!"
  [ \$SIG_RESULT -ne 0 ] && echo "❌ Signature is invalid"
  [ \$OTS_RESULT -ne 0 ] && echo "❌ Timestamp is invalid"
  exit 1
fi
EOL

# Create logging piping script
cat > /opt/signing/scripts/timestamped-log.sh <<EOL
#!/bin/bash
# Pipes logs to a timestamped and signed log file

# Ensure we have a log name
if [ \$# -lt 1 ]; then
  echo "Usage: command | \$0 log_name"
  exit 1
fi

LOG_NAME="\$1"
LOG_DIR="/opt/signing/logs"
DATE=\$(date +%Y-%m-%d)
TIMESTAMP=\$(date +%Y%m%d-%H%M%S)
LOG_FILE="\${LOG_DIR}/\${LOG_NAME}-\${DATE}.log"

# Create log directory if it doesn't exist
mkdir -p "\$LOG_DIR"

# Read from stdin and append to log file
while IFS= read -r line; do
  echo "[\$(date +%Y-%m-%d\ %H:%M:%S)] \$line" >> "\$LOG_FILE"
done

# Sign and timestamp the log file
/opt/signing/scripts/sign-document.sh "\$LOG_FILE" "\$LOG_DIR"

echo "Log saved to \$LOG_FILE and signed/timestamped"
EOL

# Make all scripts executable
chmod +x /opt/signing/scripts/*.sh

# Create a systemd service for regular timestamping of important logs
cat > /etc/systemd/system/timestamp-logs.service <<EOL
[Unit]
Description=Timestamp important log files
After=network.target

[Service]
Type=oneshot
ExecStart=/opt/signing/scripts/sign-document.sh /var/log/auth.log /opt/signing/logs
ExecStart=/opt/signing/scripts/sign-document.sh /var/log/syslog /opt/signing/logs
User=root
Group=root

[Install]
WantedBy=multi-user.target
EOL

# Create a timer to run the service daily
cat > /etc/systemd/system/timestamp-logs.timer <<EOL
[Unit]
Description=Run timestamp-logs service daily

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
EOL

# Reload systemd and enable the timer
systemctl daemon-reload
systemctl enable timestamp-logs.timer
systemctl start timestamp-logs.timer

echo "✅ Signing & Timestamps system installed successfully!"
echo "🔐 To generate a server GPG key, run: sudo /opt/signing/scripts/generate-server-key.sh"
echo "📝 To sign and timestamp a document, run: sudo /opt/signing/scripts/sign-document.sh /path/to/document"
echo "✅ To verify a signed document, run: sudo /opt/signing/scripts/verify-document.sh document signature timestamp"
echo "📜 To pipe command output to a timestamped log, run: command | sudo /opt/signing/scripts/timestamped-log.sh log_name"
echo "⏱️ System logs are automatically timestamped daily"
