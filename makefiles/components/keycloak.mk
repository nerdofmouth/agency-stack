# Keycloak component targets
# Manual extraction from main Makefile following modular_makefile.md guidelines

# Keycloak Makefile Targets for AgencyStack Alpha
keycloak:
	@echo "🔑 Installing Keycloak..."
	@$(SCRIPTS_DIR)/components/install_keycloak.sh --domain=$(DOMAIN) --admin-email=$(ADMIN_EMAIL) $(if $(CLIENT_ID),--client-id $(CLIENT_ID),) $(if $(FORCE),--force,) $(if $(WITH_DEPS),--with-deps,) $(if $(VERBOSE),--verbose,) $(if $(ENABLE_CLOUD),--enable-cloud,) $(if $(ENABLE_OPENAI),--enable-openai,) $(if $(USE_GITHUB),--use-github,) $(if $(ENABLE_KEYCLOAK),--enable-keycloak,) || true

keycloak-status:
	@echo "🔍 Checking Keycloak status..."
	@$(SCRIPTS_DIR)/components/verify_keycloak.sh --domain=$(DOMAIN) $(if $(CLIENT_ID),--client-id $(CLIENT_ID),) || true

keycloak-logs:
	@echo "📜 Tailing Keycloak logs..."
	@tail -n 50 /var/log/agency_stack/components/keycloak.log || true

keycloak-restart:
	@echo "♻️  Restarting Keycloak Docker container..."
	@docker restart keycloak_$(DOMAIN) || true

keycloak-test:
	@echo "🧪 Testing Keycloak API endpoint..."
	@curl -k https://$(DOMAIN)/admin/ || echo "Keycloak API test failed"

.PHONY: keycloak keycloak-status keycloak-logs keycloak-restart keycloak-test
