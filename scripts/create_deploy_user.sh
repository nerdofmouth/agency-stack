#!/bin/bash
# Script to create a deploy user for AgencyStack installations
# For use in testing and development environments

set -e

# Configuration
DEPLOY_USER="deploy"
DEPLOY_GROUP="deploy"
SUDO_ACCESS=true
SSH_DIR="/home/${DEPLOY_USER}/.ssh"

echo "Creating deploy user for AgencyStack installation..."

# Create user and group if they don't exist
if ! getent group ${DEPLOY_GROUP} > /dev/null; then
  echo "Creating group: ${DEPLOY_GROUP}"
  groupadd ${DEPLOY_GROUP}
fi

if ! id -u ${DEPLOY_USER} > /dev/null 2>&1; then
  echo "Creating user: ${DEPLOY_USER}"
  useradd -m -g ${DEPLOY_GROUP} -s /bin/bash ${DEPLOY_USER}
fi

# Set up sudo access if requested
if [[ "$SUDO_ACCESS" == "true" ]]; then
  echo "Granting sudo access to ${DEPLOY_USER}"
  echo "${DEPLOY_USER} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${DEPLOY_USER}
  chmod 0440 /etc/sudoers.d/${DEPLOY_USER}
fi

# Set up SSH directory
if [[ ! -d ${SSH_DIR} ]]; then
  echo "Creating SSH directory"
  mkdir -p ${SSH_DIR}
  chmod 700 ${SSH_DIR}
  chown ${DEPLOY_USER}:${DEPLOY_GROUP} ${SSH_DIR}
fi

# Copy authorized keys from root if available
if [[ -f /root/.ssh/authorized_keys ]]; then
  echo "Copying SSH authorized keys from root"
  cp /root/.ssh/authorized_keys ${SSH_DIR}/
  chmod 600 ${SSH_DIR}/authorized_keys
  chown ${DEPLOY_USER}:${DEPLOY_GROUP} ${SSH_DIR}/authorized_keys
fi

# Set password (optional - disabled by default for security)
# echo "${DEPLOY_USER}:strongpassword" | chpasswd

echo "Deploy user created successfully!"
echo "Username: ${DEPLOY_USER}"
echo "SSH access: enabled"
echo "Sudo access: ${SUDO_ACCESS}"

# Print next steps
echo ""
echo "Next steps:"
echo "1. Connect to the server using: ssh ${DEPLOY_USER}@<server_ip>"
echo "2. Run the AgencyStack installer as this user"
