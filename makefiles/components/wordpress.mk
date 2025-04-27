# WordPress component targets
# Manual extraction from main Makefile following modular_makefile.md guidelines

install-wordpress: validate
	@echo "$(MAGENTA)$(BOLD)🌐 Installing WordPress...$(RESET)"
	@FORCE=$(FORCE) sudo $(SCRIPTS_DIR)/components/install_wordpress.sh --domain $(DOMAIN) --admin-email $(ADMIN_EMAIL) $(if $(CLIENT_ID),--client-id $(CLIENT_ID),) $(if $(FORCE),--force,) $(if $(WITH_DEPS),--with-deps,) $(if $(VERBOSE),--verbose,) $(if $(ENABLE_CLOUD),--enable-cloud,) $(if $(ENABLE_OPENAI),--enable-openai,) $(if $(USE_GITHUB),--use-github,) || true

wordpress-status:
	@echo "$(MAGENTA)$(BOLD)ℹ️ Checking WordPress status...$(RESET)"
	@$(SCRIPTS_DIR)/components/check_wordpress.sh --domain $(DOMAIN) $(if $(CLIENT_ID),--client-id $(CLIENT_ID),) || true

wordpress-logs:
	@echo "$(MAGENTA)$(BOLD)📜 Viewing WordPress logs...$(RESET)"
	@tail -n 50 /var/log/agency_stack/components/wordpress.log

wordpress-restart:
	@echo "$(MAGENTA)$(BOLD)🔄 Restarting WordPress...$(RESET)"
	@$(SCRIPTS_DIR)/components/restart_wordpress.sh --domain $(DOMAIN) $(if $(CLIENT_ID),--client-id $(CLIENT_ID),) || true

wordpress-test:
	@echo "$(MAGENTA)$(BOLD)🧪 Testing WordPress installation...$(RESET)"
	@$(SCRIPTS_DIR)/components/test_wordpress.sh --domain $(DOMAIN) $(if $(CLIENT_ID),--client-id $(CLIENT_ID),) || echo "Tests completed with issues, review output for details"

.PHONY: install-wordpress wordpress-status wordpress-logs wordpress-restart wordpress-test
