# ⚠️ BOOTSTRAP BUNDLE DEPRECATED ⚠️

## NOTICE: THIS DIRECTORY IS DEPRECATED

The scripts in this directory are **no longer maintained** and will be removed in a future release of AgencyStack.

## Migration to Standard Components

All functionality from this bootstrap bundle has been migrated to the standardized component system:

```
/scripts/components/
```

## Benefits of Using Components

The new component system provides several advantages:

- **Standardized installation**: All components follow consistent installation patterns
- **Makefile integration**: Every component has dedicated targets for management
- **Comprehensive logging**: Better visibility into installation and runtime behavior
- **Multi-tenant support**: Improved multi-client capabilities
- **Documentation**: Each component has detailed documentation
- **Security hardening**: Enhanced security measures throughout
- **Improved error handling**: Better resilience and validation

## How to Use the New Component System

Instead of directly using scripts from this directory, use the Makefile targets:

```bash
# Install a component
make <component-name>

# Check component status
make <component-name>-status

# View component logs
make <component-name>-logs

# Restart a component
make <component-name>-restart
```

## Migration Map

| Old Script | New Component |
|------------|---------------|
| install_backup.sh | make backup-strategy |
| install_signing_timestamps.sh | make signing-timestamps |
| install_docker.sh | make docker |
| install_docker_compose.sh | make docker-compose |
| install_fail2ban.sh | make fail2ban |
| install_security.sh | make security |
| install_loki.sh | make loki |

## Documentation

For detailed documentation on each component, see:

```
/docs/pages/components/<component-name>.md
```

## Questions or Issues?

If you have any questions or issues migrating from the bootstrap bundle to the component system, please refer to the AgencyStack documentation or contact support.

---

**Last Updated:** 2025-04-07  
**Migration Complete:** Yes
