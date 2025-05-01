# client-wordpress.mk - Generic multi-tenant WordPress deployment
# Following AgencyStack Charter v1.0.3 principles and Repository Integrity Policy

# Default variables
CLIENT_ID ?= default
DOMAIN ?= localhost
ADMIN_EMAIL ?= admin@example.com
WP_PORT ?= 8080
MARIADB_PORT ?= 3306
TRAEFIK_ENABLED ?= false
KEYCLOAK_ENABLED ?= false
TLS_ENABLED ?= false
DID_MODE ?= false
FORCE ?= false

# Directory references
SCRIPTS_DIR = scripts

# Generic multi-tenant WordPress target
client-wordpress:
	@echo "🌐 Installing WordPress for client: $(CLIENT_ID)..."
	@mkdir -p /var/log/agency_stack/components || true
	@$(SCRIPTS_DIR)/components/install_client_wordpress.sh \
		--client-id=$(CLIENT_ID) \
		--domain=$(DOMAIN) \
		--admin-email=$(ADMIN_EMAIL) \
		--wordpress-port=$(WP_PORT) \
		--mariadb-port=$(MARIADB_PORT) \
		$(if $(filter true,$(TRAEFIK_ENABLED)),--enable-traefik,) \
		$(if $(filter true,$(KEYCLOAK_ENABLED)),--enable-keycloak,) \
		$(if $(filter true,$(TLS_ENABLED)),--enable-tls,) \
		$(if $(filter true,$(FORCE)),--force,)
	@echo "✅ WordPress installation for client $(CLIENT_ID) complete"
	@echo "🌐 Access WordPress at: https://$(DOMAIN) (or http://localhost:$(WP_PORT))"

# Docker-in-Docker development target
client-wordpress-did:
	@echo "🐳 Installing WordPress for client $(CLIENT_ID) in Docker-in-Docker environment..."
	@$(SCRIPTS_DIR)/components/install_client_wordpress.sh \
		--client-id=$(CLIENT_ID) \
		--domain=$(DOMAIN) \
		--admin-email=$(ADMIN_EMAIL) \
		--wordpress-port=$(WP_PORT) \
		--mariadb-port=$(MARIADB_PORT) \
		$(if $(filter true,$(TRAEFIK_ENABLED)),--enable-traefik,) \
		$(if $(filter true,$(KEYCLOAK_ENABLED)),--enable-keycloak,) \
		$(if $(filter true,$(TLS_ENABLED)),--enable-tls,) \
		--did-mode \
		$(if $(filter true,$(FORCE)),--force,)
	@echo "✅ WordPress installation for client $(CLIENT_ID) in Docker-in-Docker complete"
	@echo "🌐 Access WordPress at: http://localhost:$(WP_PORT)"

# Status check target
client-wordpress-status:
	@echo "🔍 Checking WordPress status for client $(CLIENT_ID)..."
	@$(SCRIPTS_DIR)/components/install_client_wordpress.sh \
		--client-id=$(CLIENT_ID) \
		--domain=$(DOMAIN) \
		--status-only

# Logs target
client-wordpress-logs:
	@echo "📜 Viewing WordPress logs for client $(CLIENT_ID)..."
	@$(SCRIPTS_DIR)/components/install_client_wordpress.sh \
		--client-id=$(CLIENT_ID) \
		--domain=$(DOMAIN) \
		--logs-only

# Restart target
client-wordpress-restart:
	@echo "♻️  Restarting WordPress services for client $(CLIENT_ID)..."
	@$(SCRIPTS_DIR)/components/install_client_wordpress.sh \
		--client-id=$(CLIENT_ID) \
		--domain=$(DOMAIN) \
		--restart-only

# Removal target
client-wordpress-remove:
	@echo "🗑️  Removing WordPress installation for client $(CLIENT_ID)..."
	@$(SCRIPTS_DIR)/components/install_client_wordpress.sh \
		--client-id=$(CLIENT_ID) \
		--domain=$(DOMAIN) \
		--remove

# Test target
client-wordpress-test:
	@echo "🧪 Testing WordPress installation for client $(CLIENT_ID)..."
	@$(SCRIPTS_DIR)/utils/test_client_wordpress.sh \
		--client-id=$(CLIENT_ID) \
		--domain=$(DOMAIN) \
		--wordpress-port=$(WP_PORT) \
		--mariadb-port=$(MARIADB_PORT)

# Meta-targets for specific clients (examples)
peacefestivalusa-wordpress:
	@$(MAKE) client-wordpress CLIENT_ID=peacefestivalusa DOMAIN=peacefestivalusa.nerdofmouth.com WP_PORT=8082 MARIADB_PORT=33060

peacefestivalusa-wordpress-did:
	@$(MAKE) client-wordpress-did CLIENT_ID=peacefestivalusa DOMAIN=peacefestivalusa.nerdofmouth.com WP_PORT=8082 MARIADB_PORT=33060

peacefestivalusa-wordpress-status:
	@$(MAKE) client-wordpress-status CLIENT_ID=peacefestivalusa DOMAIN=peacefestivalusa.nerdofmouth.com

peacefestivalusa-wordpress-logs:
	@$(MAKE) client-wordpress-logs CLIENT_ID=peacefestivalusa DOMAIN=peacefestivalusa.nerdofmouth.com

peacefestivalusa-wordpress-restart:
	@$(MAKE) client-wordpress-restart CLIENT_ID=peacefestivalusa DOMAIN=peacefestivalusa.nerdofmouth.com

peacefestivalusa-wordpress-test:
	@$(MAKE) client-wordpress-test CLIENT_ID=peacefestivalusa DOMAIN=peacefestivalusa.nerdofmouth.com WP_PORT=8082 MARIADB_PORT=33060

.PHONY: client-wordpress client-wordpress-did client-wordpress-status client-wordpress-logs client-wordpress-restart client-wordpress-remove client-wordpress-test \
        peacefestivalusa-wordpress peacefestivalusa-wordpress-did peacefestivalusa-wordpress-status peacefestivalusa-wordpress-logs peacefestivalusa-wordpress-restart peacefestivalusa-wordpress-test
