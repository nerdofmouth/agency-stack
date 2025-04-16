# Script Interactions

This document explains how the various scripts in the FOSS Server Stack interact with each other and how to use them from the command line.

## Script Flow Diagram

```
┌─────────────────┐      
│                 │      
│   install.sh    │◄────┐  Interactive server installation
│    (menu)       │     │  sudo bash scripts/install.sh
│                 │     │
└────────┬────────┘     │
         │              │
         │ calls        │ Option 3
         ▼              │
┌─────────────────┐     │
│                 │     │
│ install_all.sh  │─────┘  Full stack installation
│  or individual  │        bash scripts/agency_stack_bootstrap_bundle_v10/install_all.sh
│ install scripts │
│                 │
└────────┬────────┘
         │
         │ After server setup,
         │ use bootstrap_client.sh
         ▼
┌─────────────────┐
│                 │
│bootstrap_client.│        Client provisioning
│      sh         │────►   bash scripts/agency_stack_bootstrap_bundle_v10/bootstrap_client.sh client.domain.com
│                 │
└────────┬────────┘
         │
         │ If BUILDER_ENABLE=true
         │ in client's .env
         ▼
┌─────────────────┐
│                 │
│  builderio_     │        Builder.io integration
│  provision.sh   │────►   BUILDER_API_KEY="..." bash scripts/builderio_provision.sh client_name domain.com
│                 │
└─────────────────┘
```

## Command Line Usage

### 1. Server Installation

#### Interactive Installation

This provides a menu-driven interface for selecting which components to install:

```bash
sudo bash scripts/install.sh
```

#### Full Stack Installation

Installs all components in the recommended order:

```bash
cd scripts/agency_stack_bootstrap_bundle_v10
bash install_all.sh
```

#### Selective Component Installation

Install only specific components:

```bash
cd scripts/agency_stack_bootstrap_bundle_v10
bash install_prerequisites.sh
bash install_docker.sh
bash install_docker_compose.sh
bash install_traefik_ssl.sh
# Add other components as needed
```

### 2. Client Setup

After the server is set up, you can create client configurations:

```bash
cd scripts/agency_stack_bootstrap_bundle_v10
bash bootstrap_client.sh client.domain.com
```

This will:
1. Create a client directory structure
2. Generate environment files and Docker Compose configuration
3. Optionally integrate with Builder.io if enabled

To start the client services:

```bash
cd clients/client.domain.com
docker compose up -d
```

### 3. Builder.io Integration

#### Automatic Integration Through Client Setup

1. Edit the client's .env file to enable Builder.io:
   ```bash
   nano clients/client.domain.com/.env
   # Set BUILDER_ENABLE=true
   ```

2. Run the bootstrap script again:
   ```bash
   bash bootstrap_client.sh client.domain.com
   ```

#### Manual Builder.io Integration

You can also run the Builder.io provisioning script directly:

```bash
export BUILDER_API_KEY="your_builder_api_key_here"
bash scripts/builderio_provision.sh client_name domain.com
```

## Notes on Script Paths and Dependencies

- `install.sh` expects the component installation scripts to be in `scripts/agency_stack_bootstrap_bundle_v10/`
- `bootstrap_client.sh` automatically resolves the path to `builderio_provision.sh` using relative paths from its own location
- All scripts should be run from within the repository root or with proper path references

## Troubleshooting Script Interactions

If you encounter "file not found" errors:

1. Make sure you're running the scripts from the correct directory
2. Check that the script files exist in the expected locations
3. Verify the permissions on the script files (`chmod +x` if needed)
4. Check the paths in the scripts to ensure they're using the correct relative paths

For Builder.io integration issues:

1. Ensure your `BUILDER_API_KEY` is correctly set in the environment
2. Replace `YOUR_ORG_ID` in the script with your actual organization ID
3. Check the API response for any error messages
