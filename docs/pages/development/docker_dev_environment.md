# AgencyStack Docker Development Environment

This document outlines how to set up, use, and maintain a Docker-based development environment for AgencyStack, following the Repository Integrity Policy.

## Prerequisites

- Docker Desktop installed locally
- Git configured for GitHub access
- Local clone of the AgencyStack repository

## Environment Structure

The Docker development environment consists of:

- A Debian-based container with all required dependencies
- SSH access for remote commands
- Docker-in-Docker support via socket mounting
- Git integration for following the Repository Integrity Policy
- Mapped volume for file sharing

## Initial Setup

1. Clone the AgencyStack repository if you haven't already:
   ```bash
   git clone https://github.com/nerdofmouth/agency-stack.git
   cd agency-stack
   ```

2. Run the development container setup script:
   ```bash
   ./run_dev_container.sh
   ```

   This will:
   - Build the Docker image with all dependencies
   - Start a container with proper volume mounts
   - Configure SSH access on port 2222
   - Set up appropriate Docker socket permissions

3. Connect to the container via SSH:
   ```bash
   ssh developer@localhost -p 2222  # Password: agencystack
   ```

## Development Workflow

Following the AgencyStack Repository Integrity Policy, all development should follow this workflow:

1. **Make changes locally** on your host machine
   ```bash
   # Edit files in your preferred IDE
   ```

2. **Commit and push changes** to the remote repository
   ```bash
   git add .
   git commit -m "Description of your changes"
   git push origin main
   ```

3. **Pull changes inside the container** via SSH
   ```bash
   # Inside the container (via SSH)
   cd ~/projects/agency-stack
   git pull origin main
   ```

4. **Test with AgencyStack make commands**
   ```bash
   # Inside the container (via SSH)
   make preflight DOMAIN=localhost.test
   make keycloak DOMAIN=localhost.test ADMIN_EMAIL=admin@localhost.test
   ```

## Component Testing

### Keycloak Testing

To install and test Keycloak with a login screen:

1. Inside the container, pull the latest code:
   ```bash
   cd ~/projects/agency-stack
   git pull origin main
   ```

2. Install Keycloak:
   ```bash
   make keycloak DOMAIN=localhost.test ADMIN_EMAIL=admin@localhost.test WITH_DEPS=true
   ```

3. Check Keycloak status:
   ```bash
   make keycloak-status DOMAIN=localhost.test
   ```

4. Access the Keycloak login screen:
   - If running with Traefik: https://localhost.test/auth/
   - If running standalone: http://localhost:8080/auth/

### Container Management

To completely reset your development environment:

1. Stop and remove the existing container:
   ```bash
   docker stop agencystack-dev
   docker rm agencystack-dev
   ```

2. Optionally remove the image:
   ```bash
   docker rmi agencystack-dev-image
   ```

3. Restart with a fresh environment:
   ```bash
   ./run_dev_container.sh
   ```

## Troubleshooting

### Docker Socket Permissions

If you encounter Docker permission issues inside the container:

```bash
# Inside the container via SSH
sudo chmod 666 /var/run/docker.sock
```

### SSH Connection Issues

If you can't connect via SSH, check:

1. Container is running:
   ```bash
   docker ps | grep agencystack-dev
   ```

2. SSH port is mapped correctly:
   ```bash
   docker port agencystack-dev
   ```

3. SSH service is running inside the container:
   ```bash
   docker exec -it agencystack-dev service ssh status
   ```

## References

- [AgencyStack Documentation](https://stack.nerdofmouth.com)
- [Keycloak Documentation](https://www.keycloak.org/documentation.html)
- [Docker Documentation](https://docs.docker.com/)
