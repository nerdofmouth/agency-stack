# Docker & WSL2 Environment Config Notes (Tech Notes)

## Problem: Config File vs Directory Issues in Containerized Environments

### Issue
- **Containers (Traefik, Nginx, etc.) may continuously restart or fail if a config path is mounted as a directory instead of a file.**
- Most common with Docker on WSL2 or similar environments where volume mounts are misconfigured or the expected file does not exist.

### Symptoms
- Traefik: `/etc/traefik/traefik.yml` is a directory (should be a file).
- Nginx: `/etc/nginx/conf.d/default.conf` is a directory (should be a file).
- Containers log errors and enter restart loops.
- Error messages like: `read /etc/traefik/traefik.yml: is a directory` or `pread() "/etc/nginx/conf.d/default.conf" failed (21: Is a directory)`

## Root Cause Analysis
When mounting volumes in Docker, particularly in WSL2 environments, there are several scenarios that can cause the file/directory confusion:

1. **When the target path doesn't exist in the container's filesystem:**
   - Docker creates it with the same type as the source (file or directory)
   - This works correctly if both ends match in type

2. **When the target path exists in the container but is a directory, and the source is a file:**
   - Docker fails with: `Cannot create directory, file exists` or `Are you trying to mount a directory onto a file (or vice-versa)?`
   - The container will not start properly

3. **When the target path exists in the container but is a file, and the source is a directory:**
   - Docker fails with similar errors
   - The container will not start properly

4. **Most problematic: When a container previously had a directory at the mount point:**
   - Even after being removed and recreated, Docker may remember the path as a directory
   - The only solution is to completely remove the container and all its volumes

## Solution: Enforce File-Type Configs and Idempotent Repair Scripts

### 1. Ensure Config Path is Always a File
- **Remove any directory at the config path.**
- **Create a minimal valid config file if missing.**
- **Example Scripts:**
  - `install_traefik.sh` (for Traefik)
  - `fix_nginx_config.sh` (for Nginx)

### 2. Correct Docker Compose Volume Mapping
- Always map the source config as a file, not a directory.
- **Example Mapping:**
  - Traefik: `/opt/agency_stack/clients/${CLIENT_ID}/traefik/traefik.yml:/etc/traefik/traefik.yml:ro`
  - Nginx: `/opt/agency_stack/clients/${CLIENT_ID}/nginx/default.conf:/etc/nginx/conf.d/default.conf:ro`

### 3. Container Reset Procedure
When containers are already affected by this issue, follow this procedure:
- Stop and remove the affected containers: `docker-compose down` or `docker rm -f <container_name>`
- Ensure the host config file exists and is a file (not directory): `ls -la /path/to/config/file.conf`
- If it's a directory, remove it and create a proper file: `rm -rf /path/to/config/file.conf && touch /path/to/config/file.conf`
- Restart with clean containers: `docker-compose up -d`

### 4. Idempotent Repair Flows
- Scripts are safe to run multiple times; they always enforce the correct state.
- Integrate these checks into install, upgrade, and repair flows.
- Always verify file type before starting containers.

## Working with Nested Containers (Docker-in-Docker)

### Installation Patterns for AgencyStack

When working with AgencyStack where components need to be installed inside a container:

1. **Preferred Method: Use Docker Socket Mounting**
   - Mount the host's Docker socket to allow the container to use the host's Docker engine
   - Example: `docker run -v /var/run/docker.sock:/var/run/docker.sock agencystack-dev`
   - This preserves Repository Integrity by using the same installation code for all environments

2. **Alternative: Host-Level Installation with Container Support**
   - Add checks in installation scripts to detect if running inside a container
   - Configure paths and permissions appropriately
   - Document container-specific requirements in component docs

### Critical Nginx Configuration for Docker Compatibility

1. **Problem**: Standard nginx config from typical Ubuntu/Debian installations often includes references to `snippets/fastcgi-php.conf` which doesn't exist in the official nginx Docker image
2. **Solution**: Use Docker-compatible nginx configuration that:
   - Doesn't rely on external snippets
   - Explicitly defines all fastcgi parameters
   - Is created by `fix_nginx_config.sh` or updated `install_wordpress.sh`

### Example Helper Functions

Add this to your shell scripts for config validation:

```bash
# Validate a config file to ensure it's not a directory
validate_config_file() {
  local config_path="$1"
  local template_content="$2"
  
  # Ensure parent directory exists
  mkdir -p "$(dirname "$config_path")"
  
  # Remove if it's a directory (critical for WSL2/Docker compatibility)
  if [ -d "$config_path" ]; then
    echo "WARNING: $config_path is a directory. Removing it."
    rm -rf "$config_path"
  fi
  
  # Create file with content if it doesn't exist
  if [ ! -f "$config_path" ]; then
    echo "Creating $config_path"
    echo "$template_content" > "$config_path"
    chmod 644 "$config_path"
  fi
}
```

## Recommended Helper Function
Add this helper function to your installation scripts:

```bash
validate_config_file() {
  local config_path="$1"
  local default_content="$2"
  
  # Create parent directory if needed
  mkdir -p "$(dirname "$config_path")"
  
  # Remove any existing directory at the config path
  if [ -d "$config_path" ]; then
    echo "WARNING: $config_path is a directory but should be a file. Removing it."
    rm -rf "$config_path"
  fi
  
  # Create file with default content if it doesn't exist
  if [ ! -f "$config_path" ]; then
    echo "Creating default config at $config_path"
    echo "$default_content" > "$config_path"
    chmod 644 "$config_path"
  fi
  
  # Verify it's now a file
  if [ ! -f "$config_path" ]; then
    echo "ERROR: Failed to create $config_path as a file"
    return 1
  fi
  
  return 0
}
```

## Example: Nginx Config Repair
```bash
bash scripts/components/fix_nginx_config.sh
```

## Example: Traefik Config Repair (within install_traefik.sh)
```bash
# Remove directory if present, create file if missing
if [ -d "$TRAEFIK_CONFIG_FILE" ]; then rm -rf "$TRAEFIK_CONFIG_FILE"; fi
mkdir -p "$(dirname "$TRAEFIK_CONFIG_FILE")"
echo -e "entryPoints:\n  web:\n    address: ':80'\n  websecure:\n    address: ':443'" > "$TRAEFIK_CONFIG_FILE"
chmod 644 "$TRAEFIK_CONFIG_FILE"
```

## Repository Integrity Reminder

Always remember to make these fixes in the repository scripts, never directly on the VM. Following the Repository Integrity Policy ensures that:

1. All fixes are tracked in source control
2. Future deployments will automatically include the fix
3. The fix is documented and discoverable by other developers
4. The system remains sovereign, auditable, and repeatable

When encountering this issue, always update the installation scripts to be more robust against file/directory conflicts rather than just manually fixing the running containers.

## Audience
- **Installers:** Use these scripts and mappings to ensure containers start reliably on all environments.
- **AI Agents:** Integrate these checks into automated flows for robust, repeatable, and self-healing deployments.

---

*For more, see component-specific docs or contact the AgencyStack DevOps team.*
