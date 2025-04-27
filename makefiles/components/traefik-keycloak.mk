# Traefik-Keycloak Integration targets
traefik-keycloak:
	@echo "$(MAGENTA)$(BOLD)🚀 Installing Traefik with Keycloak authentication...$(RESET)"
	@$(SCRIPTS_DIR)/components/install_traefik_keycloak.sh --domain $(DOMAIN) --admin-email $(ADMIN_EMAIL) $(if $(CLIENT_ID),--client-id $(CLIENT_ID),) $(if $(TRAEFIK_PORT),--traefik-port $(TRAEFIK_PORT),) $(if $(KEYCLOAK_PORT),--keycloak-port $(KEYCLOAK_PORT),) $(if $(ENABLE_TLS),--enable-tls,) $(if $(FORCE),--force,) || true

traefik-keycloak-status:
	@echo "$(MAGENTA)$(BOLD)ℹ️ Checking Traefik-Keycloak status...$(RESET)"
	@$(SCRIPTS_DIR)/components/install_traefik_keycloak.sh --status-only $(if $(CLIENT_ID),--client-id $(CLIENT_ID),) || true

traefik-keycloak-restart:
	@echo "$(MAGENTA)$(BOLD)🔄 Restarting Traefik-Keycloak...$(RESET)"
	@$(SCRIPTS_DIR)/components/install_traefik_keycloak.sh --restart-only $(if $(CLIENT_ID),--client-id $(CLIENT_ID),) || true

traefik-keycloak-logs:
	@echo "$(MAGENTA)$(BOLD)📜 Viewing Traefik-Keycloak logs...$(RESET)"
	@$(SCRIPTS_DIR)/components/install_traefik_keycloak.sh --logs-only $(if $(CLIENT_ID),--client-id $(CLIENT_ID),) || true

traefik-keycloak-test:
	@echo "$(MAGENTA)$(BOLD)🧪 Running Traefik-Keycloak TDD protocol tests...$(RESET)"
	@$(SCRIPTS_DIR)/components/install_traefik_keycloak.sh --test-only $(if $(CLIENT_ID),--client-id $(CLIENT_ID),) || echo "Tests completed with issues, review output for details"

.PHONY: traefik-keycloak traefik-keycloak-status traefik-keycloak-restart traefik-keycloak-logs traefik-keycloak-test
