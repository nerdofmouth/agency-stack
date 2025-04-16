---
layout: default
title: Installation Guide - AgencyStack Documentation
---

# Installation Guide

AgencyStack provides multiple installation methods to fit your needs and technical comfort level.

## Prerequisites

Before installing AgencyStack, make sure you have:

1. **Domain Name Configuration**:
   - Configure DNS records for your domain to point to your server's IP address
   - Set up A records for your main domain and any subdomains you plan to use
   - Allow time for DNS propagation (can take 24-48 hours)
   - Example DNS records:
     ```
     example.com.         IN A     203.0.113.10
     *.example.com.       IN A     203.0.113.10
     ```

2. **Server Requirements**:
   - Debian 11+ or Ubuntu 20.04 LTS or newer
   - Minimum 2GB RAM (4GB+ recommended)
   - Minimum 20GB storage
   - Open ports: 80, 443 (and 22 for SSH)
   - Root access or sudo privileges

3. **Network Requirements**:
   - Stable internet connection
   - Ability to make outbound connections to Docker Hub and GitHub
   - No firewall blocking HTTP/HTTPS traffic
   - Public static IP address (recommended)

4. **Email Requirements**:
   - Access to an SMTP server for sending system emails
   - Can be your existing email provider (Gmail, Office 365, etc.)
   - Or a transactional email service (SendGrid, Mailgun, Amazon SES)
   - The email domain does NOT need to match your primary domain
   - For testing, you can skip email setup or use a service like Mailtrap

5. **Software Dependencies**:
   - The installer will automatically install these for you:
     - Docker and Docker Compose (for containerization)
     - Git, Make, Curl, Wget, JQ (for installation and configuration)
     - OpenSSL, Certbot (for SSL certificates)
     - UFW, Fail2ban (for basic security)
     - Vim, ZSH, Htop, Procps (for system management)
   - Additional dependencies specific to optional components:
     - NodeJS (for JavaScript-based components)
     - Python 3 (for various automation scripts)
     - PostgreSQL client libraries (for database components)
   - No need to install these manually unless you choose the manual installation method

## Quick Installation (Recommended)

The simplest way to install AgencyStack is with our one-line installer.

### Option 1: One-Step Installation (Fully Automated)

Using curl (if available on your system):

```bash
curl -sSL https://stack.nerdofmouth.com/install.sh | sudo bash
```

Using wget (alternative method):

```bash
sudo bash -c "$(wget -qO- https://stack.nerdofmouth.com/install.sh)"
```

This will download the installer, set up the environment, and launch the interactive component selection menu.

### Option 2: Two-Step Installation (More Interactive)

For a more deliberate, sovereign approach:

```bash
# Step 1: Prepare the environment only
curl -sSL https://stack.nerdofmouth.com/install.sh | sudo bash -s -- --prepare-only

# Step 2: Run the interactive installer when you're ready
sudo bash /opt/agency_stack/repo/scripts/install.sh
```

This approach gives you time to review the system between preparation and component installation.

The installation process will:
- Install all required dependencies
- Configure the system appropriately
- Set up the core infrastructure components
- Prepare your system for client deployments

## Manual Installation

For more control over the installation process, you can perform a manual installation:

### Prerequisites

- Debian-based Linux distribution
- Root access to the server
- Git, Make, Curl, Wget, JQ (will be installed if missing)

### Steps

1. **Clone the repository:**

```bash
git clone https://github.com/nerdofmouth/agency-stack.git /opt/agency_stack
cd /opt/agency_stack
```

2. **Make scripts executable (requires root access):**

```bash
sudo chmod +x scripts/*.sh
sudo chmod +x scripts/agency_stack_bootstrap_bundle_v10/*.sh
```

3. **Run the installation:**

```bash
sudo make install
```

4. **Verify the installation:**

```bash
make test-env
```

## Component Selection

During installation, you'll be prompted to select which components to install. Choose from:

1. **Core Infrastructure Only**: Traefik, Portainer, basic monitoring (minimum requirement)
2. **Business Suite**: Core + ERPNext, KillBill, Cal.com, Documenso
3. **Content Suite**: Core + WordPress, PeerTube, Seafile, Builder.io 
4. **Team Suite**: Core + Focalboard, TaskWarrior/Calcure
5. **Marketing Suite**: Core + Listmonk, PostHog, WebPush
6. **Full Stack**: All of the above components
7. **Custom**: Select individual components

## Post-Installation

After installation completes:

1. Access the Portainer dashboard at `https://portainer.yourdomain.com`
2. Set up your first client with:

```bash
make client
```

3. Consider setting up the [self-healing infrastructure](self-healing.html) for production deployments

## Post-Installation Configuration

After completing the basic installation, you may need to configure additional settings:

### Email (SMTP) Configuration

AgencyStack uses SMTP for sending notifications, password resets, and other system emails. During installation, you'll be prompted for SMTP details.

#### Option 1: Using Built-in Mailu Email Server (Recommended)

AgencyStack includes Mailu, a complete email server solution. To use it:

1. During installation, select to install the Mailu component
2. When prompted for SMTP details, use:
   - SMTP Enabled: `true`
   - SMTP Host: `mailu` (internal Docker network name)
   - SMTP Port: `25` (internal network port)
   - SMTP Username: `admin@yourdomain.com` (replace with your domain)
   - SMTP Password: The admin password you set during Mailu installation
   - SMTP From: `noreply@yourdomain.com` (or any address on your domain)

This configuration uses the local Mailu instance, providing a fully integrated solution with:
- Complete control over your email infrastructure
- No dependency on external providers
- Proper SPF, DKIM, and DMARC configuration
- Built-in webmail interface for users

#### Option 2: Using External Email Provider

If you prefer using an external email provider:

| Setting | Description | Example |
|---------|-------------|---------|
| SMTP Enabled | Enable/disable email functionality | `true` or `false` |
| SMTP Host | Your email provider's SMTP server | `smtp.gmail.com` |
| SMTP Port | The port for your SMTP server | `587` (TLS) or `465` (SSL) |
| SMTP Username | Your email address or username | `notifications@yourdomain.com` |
| SMTP Password | Password for your email account | `your-secure-password` |
| SMTP From | The email address emails appear from | `noreply@yourdomain.com` |

**Note for Gmail users**: You may need to create an "App Password" if you have 2-Factor Authentication enabled. Visit [Google Account Security](https://myaccount.google.com/security) → App Passwords.

**Note for Office 365 users**: Make sure SMTP AUTH is enabled for your account and you've allowed "Less secure apps" if required.

You can update these settings later by editing the `/opt/agency_stack/config.env` file and restarting the affected services.

## Troubleshooting

If you encounter issues during installation:

1. Check the logs in `/var/log/agency_stack/`
2. Run the environment test: `make test-env`
3. Ensure all ports are available: 80, 443, 8080, 9000

For additional help, see our [troubleshooting guide](troubleshooting.html) or contact [support@nerdofmouth.com](mailto:support@nerdofmouth.com).
