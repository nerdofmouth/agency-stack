---
layout: default
title: Public Demo Setup - AgencyStack Documentation
---

# Public Demo Environment Setup

This guide explains how to set up a public demo instance of AgencyStack that automatically rebuilds itself regularly, perfect for showcasing the platform to potential clients or for training purposes.

## Why Create a Demo Environment?

A public demo environment allows you to:

- Showcase AgencyStack features to potential clients
- Provide a training ground for new team members
- Test new configurations in a controlled environment
- Demonstrate the self-healing capabilities of the platform

## Architecture Overview

The demo environment consists of:

1. **Primary Demo Server**: The main server that hosts the demo instance
2. **Buddy Server** (optional): A secondary server that monitors and can restore the demo
3. **Automated Rebuild Process**: Scripts that regularly reset the environment
4. **Public Access Controls**: Limited access settings for public users

![Demo Architecture](../images/demo-architecture.png)

## System Requirements

For the best performance in a demo environment:

- Debian 11+ or Ubuntu 20.04 LTS
- 4GB RAM or more
- 40GB SSD storage
- Dedicated public IP address

## Prerequisites

- Domain name pointed to the server (e.g., demo.stack.nerdofmouth.com)

## Basic Setup

### 1. Initial Server Setup

Start with a fresh server installation:

```bash
# Update system
apt update && apt upgrade -y

# Install basic requirements
apt install -y git make curl wget jq

# Clone repository
git clone https://github.com/nerdofmouth/agency-stack.git /opt/agency_stack
cd /opt/agency_stack

# Make scripts executable
chmod +x scripts/*.sh
```

### 2. Configure Demo Parameters

Create a demo configuration file:

```bash
cat > /opt/agency_stack/.demo-config << EOF
DEMO_DOMAIN=demo.stack.nerdofmouth.com
DEMO_REBUILD_INTERVAL=daily  # Options: hourly, daily, weekly
DEMO_COMPONENTS=40  # Install all components
DEMO_USER=demo
DEMO_PASSWORD=AgencyStack123  # Change this!
DEMO_EMAIL=demo@example.com
EOF
```

### 3. Install AgencyStack

Run the installer with demo parameters:

```bash
cd /opt/agency_stack
make install DEMO_MODE=true
```

## Automated Rebuild Setup

### 1. Create the Rebuild Script

```bash
cat > /opt/demo-scripts/rebuild-demo.sh << EOF
#!/bin/bash
# Demo rebuild script for AgencyStack
# https://stack.nerdofmouth.com

# Load demo configuration
source /opt/agency_stack/.demo-config

# Log setup
LOG_FILE="/var/log/agency-stack-demo/rebuild-\$(date +%Y%m%d-%H%M%S).log"
mkdir -p /var/log/agency-stack-demo
exec > >(tee -a "\$LOG_FILE") 2>&1

echo "===== DEMO REBUILD STARTED: \$(date) ====="

# Backup current configuration
echo "Creating backup before rebuild..."
cd /opt/agency_stack
make backup || true

# Clean current installation
echo "Cleaning current installation..."
cd /opt/agency_stack
make clean || true

# Fresh installation
echo "Performing fresh installation..."
cd /opt/agency_stack
make install DEMO_MODE=true

# Create demo client
echo "Setting up demo client..."
cd /opt/agency_stack
./scripts/agency_stack_bootstrap_bundle_v10/bootstrap_client.sh \$DEMO_DOMAIN

# Create demo user accounts
echo "Creating demo user accounts..."
# Add your commands to create demo users here

# Reset to demo state
echo "Resetting to demo state..."
# Add commands to reset any databases or content to demo state

echo "===== DEMO REBUILD COMPLETED: \$(date) ====="
EOF

chmod +x /opt/demo-scripts/rebuild-demo.sh
```

### 2. Set Up Cron Job

For daily rebuilds at 3 AM:

```bash
echo "0 3 * * * root /opt/demo-scripts/rebuild-demo.sh" > /etc/cron.d/agency-stack-demo
```

### 3. Create Status Page

```bash
mkdir -p /var/www/html

cat > /var/www/html/index.html << EOF
<!DOCTYPE html>
<html>
<head>
  <title>AgencyStack Demo Status</title>
  <meta http-equiv="refresh" content="60">
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; max-width: 800px; margin: 0 auto; padding: 20px; line-height: 1.6; }
    .status { padding: 15px; border-radius: 5px; margin: 20px 0; }
    .good { background: #e6ffee; border-left: 5px solid #00cc66; }
    .warn { background: #fff9e6; border-left: 5px solid #ffcc00; }
    .bad { background: #ffe6e6; border-left: 5px solid #ff3333; }
    h1, h2 { color: #333; }
    a { color: #0066cc; text-decoration: none; }
    a:hover { text-decoration: underline; }
    .button { display: inline-block; background: #0066cc; color: white; padding: 10px 20px; margin: 10px 0; border-radius: 5px; text-decoration: none; }
    .button:hover { background: #004c99; text-decoration: none; }
  </style>
</head>
<body>
  <h1>AgencyStack Demo Environment</h1>
  <p>This is a public demonstration environment for AgencyStack, an open-source agency infrastructure platform.</p>
  
  <div class="status good">
    <h2>Demo Status: Active</h2>
    <p>Last rebuilt: $(date)</p>
    <p>Next scheduled rebuild: 3:00 AM UTC</p>
  </div>
  
  <p><strong>Note:</strong> This demo environment is automatically rebuilt daily. Any changes you make will be lost during the next rebuild cycle.</p>
  
  <h2>Access Information</h2>
  <ul>
    <li><strong>Main URL:</strong> <a href="https://demo.stack.nerdofmouth.com">demo.stack.nerdofmouth.com</a></li>
    <li><strong>Username:</strong> demo</li>
    <li><strong>Password:</strong> AgencyStack123</li>
  </ul>
  
  <h2>Available Services</h2>
  <ul>
    <li><a href="https://portainer.demo.stack.nerdofmouth.com">Portainer</a> - Container Management</li>
    <li><a href="https://wordpress.demo.stack.nerdofmouth.com">WordPress</a> - Content Management</li>
    <li><a href="https://erp.demo.stack.nerdofmouth.com">ERPNext</a> - Enterprise Resource Planning</li>
    <!-- Add more services as appropriate -->
  </ul>
  
  <a href="https://stack.nerdofmouth.com" class="button">Documentation</a>
  <a href="https://github.com/nerdofmouth/agency-stack" class="button">GitHub Repository</a>
</body>
</html>
EOF
```

## Security Considerations

When setting up a public demo, consider these security measures:

### 1. Limit User Permissions

Create restricted demo user accounts with:
- Read-only access where possible
- Limited administrative capabilities
- No access to sensitive areas

### 2. Network Security

Implement these restrictions:
- Configure Fail2ban to prevent brute force attacks
- Restrict outbound internet access from the demo server
- Use a Web Application Firewall (WAF)

### 3. Resource Limits

Set resource limits to prevent abuse:
- Limit container memory and CPU usage
- Set disk quotas
- Implement rate limiting for APIs

### 4. Data Privacy

Protect privacy with:
- Fake/anonymized demo data
- Clear privacy notices
- Regular purging of user-created content

## Monitoring the Demo

Set up basic monitoring to ensure your demo is functioning properly:

```bash
cat > /opt/demo-scripts/check-demo.sh << EOF
#!/bin/bash
# Check if demo environment is running correctly

# Check if main containers are running
if [ $(docker ps --format '{{.Names}}' | grep -c .) -lt 5 ]; then
  echo "ALERT: Demo environment has too few containers running" | mail -s "AgencyStack Demo Alert" admin@example.com
  exit 1
fi

# Check if main website is accessible
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" https://demo.stack.nerdofmouth.com)
if [ "$HTTP_CODE" != "200" ]; then
  echo "ALERT: Demo environment returning HTTP $HTTP_CODE" | mail -s "AgencyStack Demo Alert" admin@example.com
  exit 1
fi

exit 0
EOF

chmod +x /opt/demo-scripts/check-demo.sh

# Add to cron to run every 15 minutes
echo "*/15 * * * * root /opt/demo-scripts/check-demo.sh" > /etc/cron.d/agency-stack-demo-check
```

## Buddy System Integration

For high-availability demo environments, integrate with the buddy system:

```bash
# On the main demo server
cd /opt/agency_stack
make buddy-init

# Configure the buddies.json file
cat > /opt/agency_stack/config/buddies.json << EOF
{
  "name": "demo.stack.nerdofmouth.com",
  "ip": "YOUR_SERVER_IP",
  "buddies": [
    {
      "name": "buddy.stack.nerdofmouth.com",
      "ip": "BUDDY_SERVER_IP",
      "ssh_key": "/opt/agency_stack/config/buddy_keys/buddy.key",
      "recovery_actions": ["restart", "rebuild", "notify"],
      "check_interval_minutes": 5
    }
  ],
  "notification_email": "admin@example.com",
  "drone_ci_enabled": true
}
EOF

# Start the buddy system
make start-buddy-system
```

## Troubleshooting

If your demo environment encounters issues:

1. Check the logs in `/var/log/agency_stack-demo/`
2. Verify container status with `docker ps -a`
3. Run a manual rebuild: `/opt/agency_stack/scripts/rebuild-demo.sh`
4. Check system resources: `sudo make rootofmouth`

For persistent issues, consult the main [Troubleshooting Guide](troubleshooting.html) or contact [support@nerdofmouth.com](mailto:support@nerdofmouth.com).
