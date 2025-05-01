# peacefestivalusa.mk - Makefile targets for PeaceFestivalUSA client
# Generated following AgencyStack Charter v1.0.3

# Colors for output
CYAN := $(shell tput setaf 6 2>/dev/null || echo '')
GREEN := $(shell tput setaf 2 2>/dev/null || echo '')
YELLOW := $(shell tput setaf 3 2>/dev/null || echo '')
MAGENTA := $(shell tput setaf 5 2>/dev/null || echo '')
BOLD := $(shell tput bold 2>/dev/null || echo '')
RESET := $(shell tput sgr0 2>/dev/null || echo '')

# Directories
SCRIPTS_DIR := $(REPO_ROOT)/scripts
COMPONENTS_DIR := $(SCRIPTS_DIR)/components
CLIENT_DIR := /opt/agency_stack/clients/peacefestivalusa
LOG_DIR := /var/log/agency_stack/clients/peacefestivalusa

# PeaceFestivalUSA WordPress installation target
peacefestival-wordpress:
	@echo "$(CYAN)$(BOLD)🚀 Installing PeaceFestivalUSA WordPress...$(RESET)"
	@$(COMPONENTS_DIR)/install_client_wordpress.sh --client-id peacefestivalusa $(if $(DOMAIN),--domain $(DOMAIN),--domain peacefestivalusa.nerdofmouth.com) --admin-email admin@nerdofmouth.com --enable-traefik --container-name-prefix dev_pfusa_ $(if $(FORCE),--force,) $(if $(ENABLE_KEYCLOAK),--enable-keycloak,) $(if $(ENABLE_TLS),--enable-tls,) $(if $(WP_PORT),--wp-port $(WP_PORT),) $(if $(DB_PORT),--db-port $(DB_PORT),)

# Status check target
peacefestival-status:
	@echo "$(CYAN)$(BOLD)ℹ️ Checking PeaceFestivalUSA WordPress status...$(RESET)"
	@$(COMPONENTS_DIR)/install_client_wordpress.sh --client-id peacefestivalusa --status-only $(if $(DOMAIN),--domain $(DOMAIN),)

# Logs viewing target
peacefestival-logs:
	@echo "$(MAGENTA)$(BOLD)📋 Viewing PeaceFestivalUSA WordPress logs...$(RESET)"
	@$(COMPONENTS_DIR)/install_client_wordpress.sh --client-id peacefestivalusa --logs-only $(if $(DOMAIN),--domain $(DOMAIN),)

# Database backup target
peacefestival-backup:
	@echo "$(GREEN)$(BOLD)💾 Backing up PeaceFestivalUSA WordPress database...$(RESET)"
	@docker exec dev_pfusa_db_1 /bin/bash -c "mkdir -p /backups && \
		mysqldump -u root -p\$${MYSQL_ROOT_PASSWORD} --databases \$${MYSQL_DATABASE} > /backups/wordpress_$(shell date +%Y%m%d%H%M%S).sql" && \
	echo "$(GREEN)Backup created in $(CLIENT_DIR)/backups$(RESET)"

# Restore database target
peacefestival-restore:
	@echo "$(YELLOW)$(BOLD)♻️ Restoring PeaceFestivalUSA WordPress database...$(RESET)"
	@if [ -z "$(BACKUP_FILE)" ]; then \
		echo "$(RED)Error: Missing required parameter BACKUP_FILE.$(RESET)"; \
		echo "Usage: make peacefestival-restore BACKUP_FILE=path/to/backup.sql"; \
		exit 1; \
	fi; \
	docker cp $(BACKUP_FILE) dev_pfusa_db_1:/tmp/restore.sql && \
	docker exec dev_pfusa_db_1 /bin/bash -c "mysql -u root -p\$${MYSQL_ROOT_PASSWORD} < /tmp/restore.sql" && \
	echo "$(GREEN)Database restored from $(BACKUP_FILE)$(RESET)"

# Add to phony targets
.PHONY: peacefestival-wordpress peacefestival-status peacefestival-logs peacefestival-backup peacefestival-restore
