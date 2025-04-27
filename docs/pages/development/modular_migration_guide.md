# Modular Makefile Migration Guide

## Overview

This document outlines the process of migrating from the monolithic Makefile to the modular approach defined in [`modular_makefile.md`](./modular_makefile.md). This migration follows the principles outlined in the [v1.0.3 Charter](../../charter/v1.0.3.md) §7 "Makefile & Component Registry Standards" and [TDD Protocol](../../charter/tdd_protocol.md) §9 "Docker Development Workflow".

## Migration Status

| Component | Migrated | Tested | Notes |
|-----------|:--------:|:------:|-------|
| traefik-keycloak | ✅ | ✅ | Fully modularized with proper container awareness |
| wordpress | ✅ | ❌ | Needs testing in container environment |
| keycloak | ✅ | ❌ | Needs container-aware path updates |

## Migration Process

For each component, follow these steps:

1. **Extract Component Targets**:
   - Create a new file in `makefiles/components/<component>.mk`
   - Reference the template in [`modular_makefile.md`](./modular_makefile.md)
   - Include `|| true` for each command to prevent Make exit errors

2. **Container-Awareness**:
   - Update scripts to detect container environment
   - Use safe fallback paths (`$HOME/.agencystack` or `/opt/agency_stack`)
   - Include proper error handling and log redirection

3. **Test Component**:
   - Verify each target works inside the container
   - Test error conditions and failure handling
   - Document test results

## Component Template Structure

Each component module should follow this structure:

```makefile
# Component name targets
# Reference to documentation

<component>:
	@echo "$(MAGENTA)$(BOLD)🚀 Installing <Component>...$(RESET)"
	@$(SCRIPTS_DIR)/components/install_<component>.sh [flags] || true

<component>-status:
	@echo "$(MAGENTA)$(BOLD)ℹ️ Checking <Component> status...$(RESET)"
	@$(SCRIPTS_DIR)/components/install_<component>.sh --status-only [flags] || true

<component>-logs:
	@echo "$(MAGENTA)$(BOLD)📜 Viewing <Component> logs...$(RESET)"
	@$(SCRIPTS_DIR)/components/install_<component>.sh --logs-only [flags] || true

<component>-restart:
	@echo "$(MAGENTA)$(BOLD)🔄 Restarting <Component>...$(RESET)"
	@$(SCRIPTS_DIR)/components/install_<component>.sh --restart-only [flags] || true

<component>-test:
	@echo "$(MAGENTA)$(BOLD)🧪 Running <Component> tests...$(RESET)"
	@$(SCRIPTS_DIR)/components/install_<component>.sh --test-only [flags] || true

.PHONY: <component> <component>-status <component>-logs <component>-restart <component>-test
```

## Validation

After migrating a component, verify these conditions:

1. All targets work identically to the original monolithic Makefile
2. The component shows proper behavior in both container and host environments
3. Error handling is robust (no Make exit on component failure)
4. Logs and status information are clear and actionable

## Next Steps for Complete Migration

1. Migrate remaining components in order of priority:
   - Core infrastructure (postgres, nginx, etc.)
   - SSO components (keycloak, auth, etc.)
   - Application components (wordpress, erpnext, etc.)
   - Monitoring and utilities

2. Update main Makefile to remove migrated targets
   - Comment out or delete once verified in modules

3. Enhance component templates with:
   - Standard logging format
   - Consistent error codes
   - Directory structure validation

## References

- [Modular Makefile Documentation](./modular_makefile.md)
- [AgencyStack Charter v1.0.3](../../charter/v1.0.3.md)
- [TDD Protocol](../../charter/tdd_protocol.md)
- [Component Template](../../../scripts/utils/component_template.sh)
