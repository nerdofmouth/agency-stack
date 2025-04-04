# Installation Guide

This guide provides instructions for deploying the FOSS server stack on a fresh Linux server.

## Prerequisites

- A server with a clean installation of Ubuntu/Debian
- Root or sudo access
- A domain name pointing to your server's IP address
- Open ports (80 and 443 for web traffic)

## Preparation

1. **Update DNS Records**
   
   Before installation, ensure your domain and any subdomains you want to use for services are pointing to your server's public IP address.

2. **Server Access**
   
   Connect to your server via SSH:
   ```
   ssh username@your-server-ip
   ```

3. **Get the Scripts**
   
   Clone the repository:
   ```
   git clone https://github.com/your-username/foss-server-stack.git
   cd foss-server-stack
   ```

## Installation Options

### Option 1: Full Stack Installation

To install all components:

```bash
cd scripts/agency_stack_bootstrap_bundle_v10
bash install_all.sh
```

This will sequentially install all components in the stack.

### Option 2: Selective Installation

If you only want specific components, you can run the individual installation scripts:

```bash
cd scripts/agency_stack_bootstrap_bundle_v10
# Install prerequisites and core components
bash install_prerequisites.sh
bash install_docker.sh
bash install_docker_compose.sh
bash install_traefik_ssl.sh

# Then install only the services you need, for example:
bash install_portainer.sh
bash install_wordpress_module.sh
bash install_listmonk.sh
```

## Post-Installation

After installation:

1. Access Portainer at `https://your-server-ip:9443` to manage containers
2. Configure each service according to their specific documentation
3. Set up regular backups for your data

## Troubleshooting

If you encounter issues:

1. Check the Docker container logs:
   ```
   docker logs container-name
   ```

2. Ensure all required ports are open:
   ```
   ufw status
   ```

3. Verify Docker services are running:
   ```
   docker ps
   ```

4. Check system resources:
   ```
   htop
   ```
