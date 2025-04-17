# AgencyStack Keycloak Container Quickstart

This guide provides step-by-step instructions for setting up a fresh AgencyStack development container with Keycloak serving a login screen.

## Complete Container Rebuild

To completely rebuild your AgencyStack development environment and set up Keycloak from scratch:

### Step 1: Destroy Existing Container and Images

```bash
# Stop and remove the container
docker stop agencystack-dev || true
docker rm agencystack-dev || true

# Remove the image to force a complete rebuild
docker rmi agencystack-dev-image || true
```

### Step 2: Commit and Push Any Local Changes

Following the Repository Integrity Policy, ensure all your local changes are committed and pushed:

```bash
# Stage all changes
git add .

# Commit changes
git commit -m "Updated AgencyStack development environment setup"

# Push to remote repository
git push origin main
```

### Step 3: Start Fresh Container

```bash
# Run the container setup script
./run_dev_container.sh
```

### Step 4: SSH Into the Container

```bash
# Connect via SSH (password: agencystack)
ssh developer@localhost -p 2222
```

### Step 5: Run Keycloak Setup

Inside the container via SSH:

```bash
# Run the Keycloak setup script
bash /home/developer/shared_data/setup_keycloak_dev.sh
```

This will:
- Clone a fresh copy of the AgencyStack repository
- Set up the necessary directory structure
- Install and configure Keycloak
- Create a status page with access information

### Step 6: Access Keycloak Login Screen

- If using Traefik (default): Open `https://localhost.test/auth/` in your browser
- If using standalone mode: Open `http://localhost:8080/auth/` in your browser

## Container Management Commands

Use these commands to manage your container:

```bash
# Start container (if stopped)
docker start agencystack-dev

# Stop container
docker stop agencystack-dev

# View container logs
docker logs agencystack-dev

# Remove container completely
docker rm agencystack-dev

# Get a shell inside the container
docker exec -it agencystack-dev /bin/bash
```

## SSH Access

```bash
# Connect via SSH (password: agencystack)
ssh developer@localhost -p 2222

# Copy files to container
scp -P 2222 localfile.txt developer@localhost:/home/developer/

# Copy files from container
scp -P 2222 developer@localhost:/home/developer/somefile.txt ./
```

## Updating the Container After Repository Changes

After making changes to your local repository and pushing them:

```bash
# SSH into the container
ssh developer@localhost -p 2222

# Navigate to the repository
cd ~/projects/agency-stack

# Pull the latest changes
git pull origin main

# Run any necessary commands to test your changes
make keycloak-status DOMAIN=localhost.test
```

## Testing Keycloak Login

Keycloak provides an admin interface where you can:
- Create and manage users
- Configure client applications
- Set up identity providers
- Manage authentication flows

Default admin credentials:
- Username: `admin`
- Password: `admin`

## Following AgencyStack Repository Integrity Policy

Remember to always follow the AgencyStack Repository Integrity Policy:
1. Never modify files directly in the container
2. Always make changes to your local repository first
3. Commit and push to the remote repository
4. Pull changes in the container for testing
5. Document any issues found during testing in your local repo

This approach ensures that the repository remains the single source of truth and provides a clear audit trail for all changes.
