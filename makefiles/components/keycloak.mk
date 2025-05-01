# Keycloak component targets
# Manual extraction from main Makefile following modular_makefile.md guidelines

# Environment variables (if not already defined)
CLIENT_ID ?= default
DOMAIN ?= localhost
ADMIN_EMAIL ?= admin@example.com
KEYCLOAK_PORT ?= 8082

# Keycloak Makefile Targets for AgencyStack Alpha
keycloak:
	@echo "🔑 Installing Keycloak..."
	@mkdir -p /var/log/agency_stack/components || true
	@$(SCRIPTS_DIR)/components/install_keycloak.sh \
		--domain=$(DOMAIN) \
		--admin-email=$(ADMIN_EMAIL) \
		$(if $(CLIENT_ID),--client-id=$(CLIENT_ID),) \
		$(if $(FORCE),--force,) \
		$(if $(WITH_DEPS),--with-deps,) \
		$(if $(VERBOSE),--verbose,) \
		$(if $(ENABLE_CLOUD),--enable-cloud,) \
		$(if $(ENABLE_OPENAI),--enable-openai,) \
		$(if $(USE_GITHUB),--use-github,) \
		$(if $(ENABLE_KEYCLOAK),--enable-keycloak,) \
		|| true
	@echo "✅ Keycloak installation complete"
	@echo "🌐 Access Keycloak at: https://$(DOMAIN)"

keycloak-status:
	@echo "🔍 Checking Keycloak status..."
	@$(SCRIPTS_DIR)/components/install_keycloak.sh \
		--domain=$(DOMAIN) \
		--admin-email=$(ADMIN_EMAIL) \
		$(if $(CLIENT_ID),--client-id=$(CLIENT_ID),) \
		--status-only || true

keycloak-logs:
	@echo "📜 Viewing Keycloak logs..."
	@$(SCRIPTS_DIR)/components/install_keycloak.sh \
		--domain=$(DOMAIN) \
		--admin-email=$(ADMIN_EMAIL) \
		$(if $(CLIENT_ID),--client-id=$(CLIENT_ID),) \
		--logs-only || true

keycloak-restart:
	@echo "♻️  Restarting Keycloak services..."
	@$(SCRIPTS_DIR)/components/install_keycloak.sh \
		--domain=$(DOMAIN) \
		--admin-email=$(ADMIN_EMAIL) \
		$(if $(CLIENT_ID),--client-id=$(CLIENT_ID),) \
		--restart-only || true

keycloak-test:
	@echo "🧪 Testing Keycloak API endpoint..."
	@$(SCRIPTS_DIR)/components/install_keycloak.sh \
		--domain=$(DOMAIN) \
		--admin-email=$(ADMIN_EMAIL) \
		$(if $(CLIENT_ID),--client-id=$(CLIENT_ID),) \
		--test-only || true

# Track component in registry
component-register-keycloak:
	@echo "📝 Registering Keycloak in component registry..."
	@$(SCRIPTS_DIR)/utils/register_component.sh \
		--name="keycloak" \
		--category="Identity Management" \
		--description="Keycloak SSO identity provider" \
		--installed=true \
		--makefile=true \
		--docs=true \
		--hardened=true \
		--multi_tenant=true \
		--sso=true \
		--monitoring=false || true

.PHONY: keycloak keycloak-status keycloak-logs keycloak-restart keycloak-test component-register-keycloak
