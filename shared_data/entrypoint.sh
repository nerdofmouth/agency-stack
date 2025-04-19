#!/bin/bash
# entrypoint.sh - Docker container entrypoint script for AgencyStack development
# This script handles proper permission setup and starts SSH server

# Handle Docker permissions
sudo chmod 666 /var/run/docker.sock

# Start SSH server
sudo service ssh start

# Display SSH connection info
echo "=========================================================="
echo "SSH server started! Connect with:"
echo "ssh developer@localhost -p <mapped_port> # Password: agencystack"
echo "=========================================================="
echo "Container is ready for AgencyStack development!"
echo ""
echo "Development workflow:"
echo "1. Make changes to local repo"
echo "2. git commit + git push"
echo "3. In container: git pull"
echo "4. Test with make commands"
echo "=========================================================="

# Keep container running
exec tail -f /dev/null
