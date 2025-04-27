# Modular Makefile System

## Overview

AgencyStack uses a modular Makefile system to improve maintainability, enforce consistency, and accelerate development. This approach addresses the challenges of large-scale infrastructure automation while adhering to the principles outlined in the [v1.0.3 Charter](../../charter/v1.0.3.md) and [TDD Protocol](../../charter/tdd_protocol.md).

## Structure

1. **Main Makefile**: Defines global variables, includes component modules, and provides top-level targets
2. **Component Modules**: Located in `makefiles/components/` with `.mk` extension
3. **Component Templates**: Standardized module templates for rapid component development

## Component Integration Workflow

### 1. Create Component Module

Create a new file in `makefiles/components/<component-name>.mk` using the template below:

```makefile
# <Component-Name> targets
<component>:
	@echo "$(MAGENTA)$(BOLD)🚀 Installing <Component>...$(RESET)"
	@$(SCRIPTS_DIR)/components/install_<component>.sh --domain $(DOMAIN) --admin-email $(ADMIN_EMAIL) $(if $(CLIENT_ID),--client-id $(CLIENT_ID),) $(if $(FORCE),--force,) $(if $(WITH_DEPS),--with-deps,) || true

<component>-status:
	@echo "$(MAGENTA)$(BOLD)ℹ️ Checking <Component> status...$(RESET)"
	@$(SCRIPTS_DIR)/components/install_<component>.sh --status-only $(if $(CLIENT_ID),--client-id $(CLIENT_ID),) || true

<component>-restart:
	@echo "$(MAGENTA)$(BOLD)🔄 Restarting <Component>...$(RESET)"
	@$(SCRIPTS_DIR)/components/install_<component>.sh --restart-only $(if $(CLIENT_ID),--client-id $(CLIENT_ID),) || true

<component>-logs:
	@echo "$(MAGENTA)$(BOLD)📜 Viewing <Component> logs...$(RESET)"
	@$(SCRIPTS_DIR)/components/install_<component>.sh --logs-only $(if $(CLIENT_ID),--client-id $(CLIENT_ID),) || true

<component>-test:
	@echo "$(MAGENTA)$(BOLD)🧪 Running <Component> TDD protocol tests...$(RESET)"
	@$(SCRIPTS_DIR)/components/install_<component>.sh --test-only $(if $(CLIENT_ID),--client-id $(CLIENT_ID),) || echo "Tests completed with issues, review output for details"

.PHONY: <component> <component>-status <component>-restart <component>-logs <component>-test
```

### 2. Create Installation Script

Create a component installation script in `scripts/components/install_<component>.sh` that supports all the required flags (`--status-only`, `--restart-only`, `--logs-only`, `--test-only`).

### 3. Add Component Registry Entry

Update the component registry in `component_registry.json` to include the new component.

## Benefits

1. **Isolation**: Each component's Makefile targets are isolated, preventing conflicts
2. **Consistency**: Standard template ensures all components have required targets
3. **Speed**: Reuse patterns across components for faster development
4. **Idempotency**: All targets are designed to be safely rerunnable
5. **Container-Friendly**: Works in both host and container environments

## Development Guidelines

1. **One Component Per Day**: Focus on completing a single component correctly with all required targets before moving to the next
2. **TDD First**: Create the test target before implementing the component
3. **Container-Ready**: All scripts detect container environments and adjust paths
4. **Self-Contained**: Include all required dependencies and error handling

## Common Gotchas and Solutions

1. **Exit Codes**: Always add `|| true` to prevent Make from stopping on non-zero exits
2. **Path Handling**: Use container-aware paths with fallbacks
3. **Hard Dependencies**: Document and test component dependencies explicitly

## Examples

See `makefiles/components/traefik-keycloak.mk` for a complete implementation example.
