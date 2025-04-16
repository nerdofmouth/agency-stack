# AgencyStack Multi-Tenancy

AgencyStack provides robust multi-tenancy capabilities, allowing you to host multiple clients on a single infrastructure while maintaining strict isolation between them. This guide explains the multi-tenancy features, setup, and management.

## Multi-Tenancy Architecture

AgencyStack implements multi-tenancy through four key isolation mechanisms:

1. **Network Isolation**: Each client gets dedicated Docker networks for front-end, back-end, and database layers
2. **Data Separation**: Client data is stored in isolated databases and volume mounts
3. **Access Control**: Each client has a dedicated Keycloak realm with unique roles and users
4. **Resource Management**: Logs, backups, and configurations are segmented by client

## Client Management

### Creating a New Client

To create a new client with full isolation:

```bash
make create-client CLIENT_ID=acme CLIENT_NAME="ACME Corporation" CLIENT_DOMAIN=acme.example.com
```

This command creates:
- Client configuration in `/opt/agency_stack/clients/<client_id>/`
- Dedicated Docker networks for the client
- Keycloak realm configuration
- Log and backup directories
- Client-specific secrets

### Client Directory Structure

Each client has the following directory structure:

```
/opt/agency_stack/clients/<client_id>/
├── client.env                      # Client environment variables
├── docker-compose.override.yml     # Client-specific services
├── keycloak/
│   └── realm.json                  # Keycloak realm configuration
├── backup/
│   └── config.sh                   # Client backup configuration
└── traefik.yml                     # Client-specific middlewares
```

### Checking Multi-Tenancy Status

To verify the isolation status of all clients:

```bash
make multi-tenancy-status
```

This generates a report showing:
- Network isolation status
- Backup separation status
- Log segmentation status
- Keycloak realm configuration status

### Setting Up Keycloak Roles

To set up default roles for a client realm:

```bash
make setup-roles CLIENT_ID=acme
```

This creates the standard roles:
- `realm_admin`: Full administrative access
- `editor`: Content editing permissions
- `viewer`: Read-only access

## Client Networks

Each client has four dedicated Docker networks:

| Network | Purpose | Isolation Level |
|---------|---------|----------------|
| `<client_id>_frontend` | External-facing services | Restricted to Traefik and web applications |
| `<client_id>_backend` | Internal API communication | Restricted to application services |
| `<client_id>_database` | Database connections | Highest isolation, no external access |
| `<client_id>_network` | General client communication | For client-specific integrations |

## Client Data Management

### Backup Separation

Client backups are stored in dedicated Restic repositories:

```
client-<client_id>
```

Backup configuration is stored in:
```
/opt/agency_stack/clients/<client_id>/backup/config.sh
```

Backup logs are stored in:
```
/var/log/agency_stack/clients/<client_id>/backup.log
```

### Log Segmentation

Client logs are segmented by client in:
```
/var/log/agency_stack/clients/<client_id>/
```

Each client has the following log files:
- `access.log`: HTTP access logs
- `error.log`: Error logs from all services
- `audit.log`: Security-related events
- `backup.log`: Backup operations

To set up log segmentation for a client:
```bash
make setup-log-segmentation CLIENT_ID=acme
```

## Client Authentication

Each client has a dedicated Keycloak realm which provides:
- Isolated user management
- Client-specific authentication policies
- Separate role and group management
- Custom theme options

## Environment Variables

Client configuration is driven by environment variables in:
```
/opt/agency_stack/clients/<client_id>/client.env
```

Key variables include:
- `CLIENT_ID`: Unique identifier for the client
- `CLIENT_NAME`: Human-readable name for the client
- `CLIENT_DOMAIN`: Primary domain for the client
- `CLIENT_NETWORK`: Network identifier
- `CLIENT_REALM`: Keycloak realm name

## Secrets Management

Client secrets are stored in:
```
/opt/agency_stack/secrets/<client_id>/secrets.env
```

To rotate secrets for a client:
```bash
make rotate-secrets CLIENT_ID=acme
```

## Multi-Tenancy Best Practices

1. **Always Use Dedicated Networks**: Never share networks between clients
2. **Rotate Client Secrets Regularly**: Use `make rotate-secrets` to maintain security
3. **Monitor Client Isolation Status**: Run `make multi-tenancy-status` weekly
4. **Backup Client Configuration**: Include `/opt/agency_stack/clients/` in system backups
5. **Document Client Setup**: Keep records of all client configurations
6. **Use Descriptive Client IDs**: Choose client IDs that are meaningful and short (e.g., company name)
7. **Verify SSO Integration**: Ensure all client services use the client's Keycloak realm

## Troubleshooting

### Network Isolation Issues

If `make multi-tenancy-status` reports network isolation issues:

1. Check Docker networks:
```bash
docker network ls | grep <client_id>
```

2. Recreate missing networks:
```bash
docker network create <client_id>_frontend
docker network create <client_id>_backend
docker network create <client_id>_database
docker network create <client_id>_network
```

### Keycloak Realm Issues

If the client's Keycloak realm is missing:

1. Manually create the realm using the client's realm configuration:
```bash
make setup-roles CLIENT_ID=<client_id>
```

2. Verify the realm was created:
```bash
curl -s -X GET "http://localhost:8080/auth/admin/realms" \
  -H "Authorization: Bearer $TOKEN" | grep <client_id>
```

### Log Segmentation Issues

If client logs are not properly segmented:

1. Run the log segmentation setup:
```bash
make setup-log-segmentation CLIENT_ID=<client_id>
```

2. Verify log directories:
```bash
ls -la /var/log/agency_stack/clients/<client_id>/
```

## Changelog

### Version 1.0.0 (April 2025)
- Initial implementation of multi-tenancy features
- Added client isolation mechanisms
- Created client provisioning tools
- Implemented Keycloak realm management
- Added log segmentation capabilities
