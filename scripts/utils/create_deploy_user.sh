#!/bin/bash

# Prompt for remote host (IP address or hostname only)
read -p "Enter remote host (IP address or hostname only): " REMOTE_HOST

# Prompt for local user
read -p "Enter local username: " LOCAL_USER

# Prompt for root password
read -s -p "Enter root password for $REMOTE_HOST: " ROOT_PASSWORD
echo

# Set username for the deploy account
DEPLOY_USER="deploy"

# Generate a strong password for the deploy account
DEPLOY_PASSWORD=$(openssl rand -base64 16)

# Check if the deploy user exists
ssh root@"$REMOTE_HOST" "id -u \"$DEPLOY_USER\"" <<< "$ROOT_PASSWORD"
if [ $? -eq 0 ]; then
  echo "Deploy user already exists on $REMOTE_HOST"
else
  # Create the deploy account
  ssh root@"$REMOTE_HOST" "sudo adduser \"$DEPLOY_USER\"" <<< "$ROOT_PASSWORD"
  if [ $? -ne 0 ]; then
    echo "Error: Failed to create deploy account on $REMOTE_HOST"
    exit 1
  fi

  # Set the password for the deploy account
  ssh root@"$REMOTE_HOST" "echo \"$DEPLOY_USER:$DEPLOY_PASSWORD\" | sudo chpasswd" <<< "$ROOT_PASSWORD"
  if [ $? -ne 0 ]; then
    echo "Error: Failed to set password for deploy account on $REMOTE_HOST"
    exit 1
  fi

  # Create SSH directory for the deploy account
  ssh root@"$REMOTE_HOST" "sudo mkdir -p /home/\"$DEPLOY_USER\"/.ssh" <<< "$ROOT_PASSWORD"
  if [ $? -ne 0 ]; then
    echo "Error: Failed to create .ssh directory on $REMOTE_HOST"
    exit 1
  fi
  ssh root@"$REMOTE_HOST" "sudo chown \"$DEPLOY_USER:$DEPLOY_USER\" /home/\"$DEPLOY_USER\"/.ssh" <<< "$ROOT_PASSWORD"
  if [ $? -ne 0 ]; then
    echo "Error: Failed to chown .ssh directory on $REMOTE_HOST"
    exit 1
  fi
  ssh root@"$REMOTE_HOST" "sudo chmod 700 /home/\"$DEPLOY_USER\"/.ssh" <<< "$ROOT_PASSWORD"
  if [ $? -ne 0 ]; then
    echo "Error: Failed to chmod .ssh directory on $REMOTE_HOST"
    exit 1
  fi

  # Generate SSH key pair for the deploy account
  ssh root@"$REMOTE_HOST" "sudo su - \"$DEPLOY_USER\" -c \"ssh-keygen -t rsa -b 2048 -N '' -f /home/$DEPLOY_USER/.ssh/id_rsa\"" <<< "$ROOT_PASSWORD"
  if [ $? -ne 0 ]; then
    echo "Error: Failed to generate SSH key pair on $REMOTE_HOST"
    exit 1
  fi
fi

# Copy the local user's public key to the remote deploy account
ssh root@"$REMOTE_HOST" "sudo su - \"$DEPLOY_USER\" -c \"mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys\"" <<< "$ROOT_PASSWORD"
ssh "$LOCAL_USER@$REMOTE_HOST" "cat ~/.ssh/id_rsa.pub" | ssh root@"$REMOTE_HOST" "sudo su - \"$DEPLOY_USER\" -c \"cat >> ~/.ssh/authorized_keys\""
if [ $? -ne 0 ]; then
  echo "Error: Failed to copy SSH key to $REMOTE_HOST"
  exit 1
fi

# Print the deploy account password
echo "Deploy account password: $DEPLOY_PASSWORD"
echo "Please save this password in a safe place."

echo "Deploy account created and passwordless SSH configured on $REMOTE_HOST."
