# Docker & WSL2 Environment Config Notes (Tech Notes)

## Problem: Config File vs Directory Issues in Containerized Environments

### Issue
- **Containers (Traefik, Nginx, etc.) may continuously restart or fail if a config path is mounted as a directory instead of a file.**
- Most common with Docker on WSL2 or similar environments where volume mounts are misconfigured or the expected file does not exist.

### Symptoms
- Traefik: `/etc/traefik/traefik.yml` is a directory (should be a file).
- Nginx: `/etc/nginx/conf.d/default.conf` is a directory (should be a file).
- Containers log errors and enter restart loops.

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

### 3. Idempotent Repair Flows
- Scripts are safe to run multiple times; they always enforce the correct state.
- Integrate these checks into install, upgrade, and repair flows.

## Example: Nginx Config Repair
```bash
bash scripts/components/fix_nginx_config.sh
```

## Example: Traefik Config Repair (within install_traefik.sh)
```bash
# Remove directory if present, create file if missing
if [ -d "$TRAEFIK_CONFIG_FILE" ]; then rm -rf "$TRAEFIK_CONFIG_FILE"; fi
if [ ! -f "$TRAEFIK_CONFIG_FILE" ]; then ... create minimal config ...; fi
```

## Audience
- **Installers:** Use these scripts and mappings to ensure containers start reliably on all environments.
- **AI Agents:** Integrate these checks into automated flows for robust, repeatable, and self-healing deployments.

---

*For more, see component-specific docs or contact the AgencyStack DevOps team.*
