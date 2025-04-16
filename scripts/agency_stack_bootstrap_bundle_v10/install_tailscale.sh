#!/bin/bash
# install_tailscale.sh - Mesh VPN built on WireGuard for secure networking

echo "🛰 Installing Tailscale (Mesh VPN)..."

# Add Tailscale's package signing key and repository
curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/focal.gpg | sudo apt-key add -
curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/focal.list | sudo tee /etc/apt/sources.list.d/tailscale.list

# Update package lists
sudo apt-get update

# Install Tailscale
sudo apt-get install -y tailscale

# Enable and start the Tailscale service
sudo systemctl enable --now tailscaled

# Create a setup script for connecting to Tailscale
cat > /usr/local/bin/setup-tailscale.sh <<EOL
#!/bin/bash
# This script helps set up Tailscale with optional configurations

# Check if we're running as root
if [ "\$(id -u)" -ne 0 ]; then
  echo "This script must be run as root" >&2
  exit 1
fi

# Parse command line options
ADVERTISE_ROUTES=""
ADVERTISE_EXIT_NODE=false
HOSTNAME=""

print_usage() {
  echo "Usage: \$0 [options]"
  echo "Options:"
  echo "  --routes ROUTES    Advertise routes (comma-separated CIDR format)"
  echo "  --exit-node        Configure this machine as an exit node"
  echo "  --hostname NAME    Set the hostname on Tailscale network"
  echo "  --help             Display this help message"
}

while [ \$# -gt 0 ]; do
  case "\$1" in
    --routes)
      ADVERTISE_ROUTES="\$2"
      shift 2
      ;;
    --exit-node)
      ADVERTISE_EXIT_NODE=true
      shift
      ;;
    --hostname)
      HOSTNAME="\$2"
      shift 2
      ;;
    --help)
      print_usage
      exit 0
      ;;
    *)
      echo "Unknown option: \$1" >&2
      print_usage
      exit 1
      ;;
  esac
done

# Construct Tailscale options
TAILSCALE_OPTS=""

if [ -n "\$ADVERTISE_ROUTES" ]; then
  TAILSCALE_OPTS="\$TAILSCALE_OPTS --advertise-routes=\$ADVERTISE_ROUTES"
fi

if [ "\$ADVERTISE_EXIT_NODE" = true ]; then
  TAILSCALE_OPTS="\$TAILSCALE_OPTS --advertise-exit-node"
fi

if [ -n "\$HOSTNAME" ]; then
  TAILSCALE_OPTS="\$TAILSCALE_OPTS --hostname=\$HOSTNAME"
fi

# Setup Tailscale authentication
echo "🔑 Starting Tailscale authentication..."
echo "🌐 You will need to authenticate this machine to your Tailscale account."
echo "🔗 A browser window will open for authentication (or use the provided URL)."

# Run tailscale up with the configured options
if [ -n "\$TAILSCALE_OPTS" ]; then
  echo "🛰 Running: tailscale up \$TAILSCALE_OPTS"
  tailscale up \$TAILSCALE_OPTS
else
  echo "🛰 Running: tailscale up"
  tailscale up
fi

# Check if tailscale is running and authenticated
if tailscale status | grep -q "authenticated"; then
  echo "✅ Tailscale setup completed successfully!"
  
  # Configure to start on boot
  systemctl enable tailscaled
  
  # Show the current status
  echo "📊 Current Tailscale status:"
  tailscale status
  
  # Show the tailscale IP address
  TAILSCALE_IP=\$(tailscale ip -4)
  echo "🌐 Tailscale IPv4 address: \$TAILSCALE_IP"
else
  echo "❌ Tailscale setup failed or was not completed."
  echo "🔄 You can try again by running: tailscale up"
fi
EOL

# Make the setup script executable
chmod +x /usr/local/bin/setup-tailscale.sh

# Create a systemd service to start Tailscale at boot
cat > /etc/systemd/system/tailscale-autoconnect.service <<EOL
[Unit]
Description=Ensure Tailscale is connected
After=network-online.target tailscaled.service
Wants=network-online.target tailscaled.service

[Service]
Type=oneshot
ExecStart=/usr/sbin/tailscale up --accept-routes
RemainAfterExit=yes
StandardOutput=journal

[Install]
WantedBy=multi-user.target
EOL

# Reload systemd and enable the service
systemctl daemon-reload
systemctl enable tailscale-autoconnect.service

echo "✅ Tailscale installed successfully!"
echo "🛰 To complete setup, run: sudo setup-tailscale.sh"
echo "🔄 For advanced configuration options, run: sudo setup-tailscale.sh --help"
echo "🌐 After setup, you can access your Tailscale network status at https://login.tailscale.com/"
echo "📝 Documentation: https://tailscale.com/kb/"
