# AgencyStack Development Environment Architecture
## Following Charter v1.0.3 Principles

This document outlines the standardized development environment architecture for AgencyStack components, specifically focusing on the setup for PeaceFestivalUSA WordPress implementation.

## Multi-Layer Environment Architecture

AgencyStack is designed to be deployed in multiple environments, from local development to production. The architecture is specifically crafted to handle the complexities of:

1. **Host System** (Windows/macOS/Linux)
2. **WSL2/VM Layer** (Ubuntu/Debian)
3. **Container Layer** (Docker/Podman)
4. **Application Layer** (WordPress/Keycloak/etc.)

This document explains how components are deployed across these layers following the AgencyStack Charter v1.0.3 principles.

## Environment Detection and Compatibility

The `/scripts/utils/vm_compatibility.sh` module automatically detects the current environment and adapts installations accordingly:

| Environment | Detection Method | Path Adaptations |
|-------------|------------------|------------------|
| VM | hypervisor in /proc/cpuinfo | Standard paths, bridge networking |
| WSL2 | "Microsoft" in /proc/version | Host networking, Docker socket mounting |
| Docker | /.dockerenv file exists | Container paths, volume mapping |

This allows the same installation scripts to work seamlessly across different environments without manual configuration.

## WordPress Installation for PeaceFestivalUSA

### Local Development Flow

For local development using WSL2/Docker Desktop setup:

1. Clone the repository in your WSL2 environment
2. Use Makefile targets to run containerized installations:
   ```bash
   make peacefestival-wordpress
   ```
3. Access the WordPress instance at http://localhost:8082

### VM Deployment Flow

For VM deployments:

1. Clone the repository in your VM
2. Run the same Makefile targets (they will adapt automatically)
3. Access based on your VM's IP address

All installations enforce **strict containerization** as required by the AgencyStack Charter v1.0.3.

## Directory Structure

The component installation follows a structured approach:

```
/root/_repos/agency-stack/               # Repository root (Source of Truth)
├── scripts/
│   ├── components/                      # Component installation scripts
│   │   ├── install_client_wordpress.sh  # WordPress installer
│   │   └── test_peacefestivalusa_wordpress.sh # Tests
│   └── utils/                           # Utility scripts
│       ├── common.sh                    # Common functions
│       └── vm_compatibility.sh          # Environment detection
├── clients/                             # Client-specific configurations
│   └── peacefestivalusa/                # PeaceFestivalUSA client
│       ├── docker-compose.yml           # Docker Compose template
│       └── .env.example                 # Environment variables template
├── makefiles/
│   └── components/
│       └── peacefestivalusa.mk          # Makefile targets
└── docs/
    └── pages/
        └── components/
            └── dev_environment.md       # This documentation
```

The actual installation paths are determined based on the environment:

- VM: `/opt/agency_stack/clients/<client_id>/`
- WSL2: `/opt/agency_stack/clients/<client_id>/`
- Docker: `${HOME}/.agencystack/clients/<client_id>/`

## VM Compatibility Considerations

When deploying to a VM, additional considerations are automatically handled:

1. **Network Mode**: Uses bridge networking instead of host networking
2. **Docker Socket**: Uses the standard Docker socket path
3. **System Requirements**: Checks for sufficient disk space, memory, and Docker installation
4. **Service Management**: Uses systemctl to verify Docker service status

The installation scripts will adapt automatically to the VM environment without requiring manual modifications.

## Testing and Verification

All components include test scripts following the TDD Protocol:

```bash
make peacefestival-wordpress-test
```

This ensures the installation meets the requirements specified in the AgencyStack Charter v1.0.3.

## How Repository and Temporary Files Interact

The repository (/root/_repos/agency-stack/) is the **Source of Truth** for all installations. The temporary files created in /tmp/ should only be used for testing and experimentation. The proper way to create new installations is:

1. Update the repository configuration files
2. Run the installation scripts from the repository
3. Let the scripts deploy from the repository to the appropriate installation paths

This maintains the integrity and auditability requirements of the AgencyStack Charter.

## Diagram of PeaceFestivalUSA WordPress Deployment

```
┌───────────────────────────────────────────────┐
│ PeaceFestivalUSA WordPress Containers         │
│                                               │
│ ┌─────────────────────┐ ┌──────────────────┐  │
│ │                     │ │                  │  │
│ │   WordPress         │ │   MariaDB        │  │
│ │   Container         │ │   Container      │  │
│ │                     │ │                  │  │
│ │ (pfusa_wordpress)   │ │ (pfusa_mariadb)  │  │
│ │                     │ │                  │  │
│ └─────────────────────┘ └──────────────────┘  │
│                                               │
│ Shared Network: pfusa_network                 │
└───────────────────────────────────────────────┘
```

## Accessing Services

WordPress: http://localhost:8082
MariaDB: localhost:33061 (via database tools)

## Testing Procedure

Follow the TDD Protocol for testing:
1. Use `test_peacefestivalusa_wordpress.sh` for automated testing
2. Always run inside the containerized test environment
3. Verify all components are properly isolated and containerized

## Troubleshooting

If containers fail to start:
1. Check Docker logs: `docker logs pfusa_wordpress`
2. Verify network creation: `docker network ls | grep pfusa`
3. Ensure no port conflicts with existing services

Remember: Strict containerization means NEVER installing components directly on any host system, including WSL2.
