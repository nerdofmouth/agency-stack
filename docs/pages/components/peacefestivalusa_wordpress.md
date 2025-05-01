# PeaceFestivalUSA WordPress Implementation

This document outlines the implementation of the PeaceFestivalUSA WordPress client following AgencyStack Charter v1.0.3 principles, particularly focusing on repository integrity, strict containerization, and proper documentation.

## Overview

The PeaceFestivalUSA WordPress implementation provides a containerized WordPress environment for the Peace Festival USA website, migrated from GoDaddy to the AgencyStack platform. This implementation follows all Charter v1.0.3 principles, ensuring proper isolation, reproducibility, and security.

## Directory Structure

```
/opt/agency_stack/clients/peacefestivalusa/
├── wordpress/          # WordPress core files and plugins
├── wordpress-custom/   # Custom themes and plugins
├── db_data/            # MariaDB database files
├── backups/            # Database backups
└── logs/               # WordPress logs
```

## Components

This implementation consists of three containerized components:

1. **WordPress Container**: Running WordPress 6.4 with PHP 8.2 and Apache
2. **MariaDB Container**: Running MariaDB 10.11 for the WordPress database
3. **Adminer Container**: Optional web-based database management tool

## Installation

The installation is managed through the AgencyStack repository-first approach, with containerization ensuring complete isolation. To install:

```bash
make peacefestival-wordpress [DOMAIN=your-domain.com] [FORCE=true]
```

Configuration is managed through environment variables defined in `.env`, following the example provided in `.env.example`.

## Environment Variables

| Variable | Description | Default Value |
|----------|-------------|---------------|
| CLIENT_ID | Client identifier | peacefestivalusa |
| DOMAIN | Domain name for WordPress | peacefestivalusa.nerdofmouth.com |
| DATA_DIR | Data directory | /opt/agency_stack/clients/peacefestivalusa |
| LOGS_DIR | Logs directory | /var/log/agency_stack/clients/peacefestivalusa |
| WORDPRESS_DB_NAME | Database name | wordpress |
| WORDPRESS_DB_USER | Database user | wordpress |
| WORDPRESS_DB_PASSWORD | Database password | (required) |
| MYSQL_ROOT_PASSWORD | MariaDB root password | (required) |

## Management Commands

All management is done through Makefile targets, maintaining the repository-first approach:

```bash
# Check status
make peacefestival-status

# View logs
make peacefestival-logs

# Create database backup
make peacefestival-backup

# Restore from backup
make peacefestival-restore BACKUP_FILE=path/to/backup.sql
```

## Security Considerations

This implementation follows the AgencyStack Charter's security principles:

1. **Strict Containerization**: All components run in isolated containers
2. **Password Management**: Sensitive credentials are stored in environment variables, not in the repository
3. **TLS**: HTTPS is enforced through Traefik integration with Let's Encrypt
4. **File Permissions**: Proper file permissions are enforced in volumes

## Migration Notes

When migrating from GoDaddy, the following should be considered:

1. Export the complete WordPress database
2. Export the wp-content directory (themes, plugins, uploads)
3. Update URLs and paths in the database using WP-CLI or a database tool
4. Test all functionality after migration

## Networking

The implementation uses two Docker networks:

1. **peacefestival_network**: Internal network for component communication
2. **traefik_network**: External network connecting to the Traefik reverse proxy

## Troubleshooting

If issues arise during installation or operation:

1. Check container status: `docker ps -a | grep peacefestivalusa`
2. View container logs: `docker logs peacefestivalusa_wordpress`
3. Verify Traefik routing: `docker logs traefik | grep peacefestivalusa`
4. Check WordPress logs: `ls -la /opt/agency_stack/clients/peacefestivalusa/wordpress-custom/logs`

## Fallback Strategy

If Docker deployment fails, a fallback to systemd/nginx installation is available through:

```bash
make peacefestival-wordpress-fallback
```

This fallback maintains the same directory structure and environment variables but uses host-based services instead of containers.

---

**Author:** AgencyStack Team  
**Last Updated:** May 1, 2025
