#!/bin/bash
# run_dev_container.sh - Script to build and run AgencyStack development container
# Respects Repository Integrity Policy by isolating development in a container

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONTAINER_NAME="agencystack-dev"
IMAGE_NAME="agencystack-dev-image"
SSH_PORT=2222  # Port for SSH access to container

# Build the Docker image if needed
if ! docker image inspect "$IMAGE_NAME" &>/dev/null; then
  echo "🔨 Building $IMAGE_NAME from Dockerfile.dev..."
  docker build -t "$IMAGE_NAME" -f "$SCRIPT_DIR/Dockerfile.dev" "$SCRIPT_DIR"
fi

# Check if container already exists
if docker container inspect "$CONTAINER_NAME" &>/dev/null; then
  echo "🔄 Container $CONTAINER_NAME already exists. Starting and attaching..."
  docker start "$CONTAINER_NAME"
  
  # Display SSH connection info
  echo ""
  echo "📡 SSH Access Available:"
  echo "   ssh developer@localhost -p $SSH_PORT # Password: agencystack"
  echo ""
  echo "🔄 To attach to container shell directly:"
  echo "   docker exec -it $CONTAINER_NAME /bin/bash"
  echo ""
else
  echo "🚀 Creating and starting new $CONTAINER_NAME container..."
  
  # Run container with Docker socket mounted to enable Docker-in-Docker
  # This follows the AgencyStack pattern of allowing the container to use the host's Docker daemon
  docker run -d --name "$CONTAINER_NAME" \
    -p $SSH_PORT:22 \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v "$SCRIPT_DIR/shared_data:/home/developer/shared_data" \
    -e "DEBIAN_FRONTEND=noninteractive" \
    -e "GIT_TERMINAL_PROMPT=0" \
    -e "APT_LISTCHANGES_FRONTEND=none" \
    -e "APT_LISTBUGS_FRONTEND=none" \
    "$IMAGE_NAME"
    
  echo ""
  echo "📡 SSH Access Available:"
  echo "   ssh developer@localhost -p $SSH_PORT # Password: agencystack"
  echo ""
  echo "🔄 To attach to container shell directly:"
  echo "   docker exec -it $CONTAINER_NAME /bin/bash"
  echo ""
fi

# Display workflow reminder
echo "🔄 AgencyStack Development Workflow (following Repository Integrity Policy):"
echo "   1. Make changes to local repository"
echo "   2. git commit + git push"
echo "   3. In container (via SSH): cd ~/projects/agency-stack && git pull"
echo "   4. Test with make commands"
echo ""
