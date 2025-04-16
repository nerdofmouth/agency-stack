#!/bin/bash
# AgencyStack Utility: SSH Key Setup
# Securely transfers SSH key to remote server for passwordless authentication
# Follows AgencyStack security best practices

set -e

# Configuration
SSH_KEY_PATH="${1:-$HOME/.ssh/id_ed25519_agency.pub}"
REMOTE_HOST="${2:-proto001.nerdofmouth.com}"
REMOTE_USER="${3:-root}"

# Validation
if [ ! -f "$SSH_KEY_PATH" ]; then
    echo "ERROR: SSH key not found at $SSH_KEY_PATH"
    echo "Usage: $0 [ssh_key_path] [remote_host] [remote_user]"
    exit 1
fi

echo "===== AgencyStack SSH Key Setup ====="
echo "Setting up passwordless SSH authentication"
echo "Key: $SSH_KEY_PATH"
echo "Host: $REMOTE_HOST"
echo "User: $REMOTE_USER"
echo "==============================="

# Create a secure temporary file for the SSH command
SSH_COMMAND_FILE=$(mktemp)
chmod 700 "$SSH_COMMAND_FILE"

# Write the SSH commands to add the key
cat > "$SSH_COMMAND_FILE" << EOF
mkdir -p ~/.ssh
chmod 700 ~/.ssh
touch ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
cat >> ~/.ssh/authorized_keys << 'EOK'
$(cat "$SSH_KEY_PATH")
EOK
echo "Key added successfully!"
EOF

# Execute the SSH commands
echo "Transferring SSH key to remote server..."
cat "$SSH_COMMAND_FILE" | ssh "$REMOTE_USER@$REMOTE_HOST" "bash -s"
RESULT=$?

# Clean up
rm -f "$SSH_COMMAND_FILE"

if [ $RESULT -eq 0 ]; then
    echo "✅ SSH key setup complete. You can now SSH without a password."
    echo "Example: ssh $REMOTE_USER@$REMOTE_HOST"
else
    echo "❌ SSH key setup failed with error code $RESULT"
fi

exit $RESULT
