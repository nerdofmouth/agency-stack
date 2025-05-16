# Peace Festival USA WordPress component targets
# Following modular_makefile.md guidelines and AgencyStack Charter

# Environment variables (if not already defined)
DOMAIN ?= peacefestivalusa.nerdofmouth.com
ADMIN_EMAIL ?= admin@peacefestivalusa.com
CLIENT_ID := peacefestivalusa
WP_PORT ?= 8082
DID_MODE ?= false

# Peace Festival USA WordPress (Client-specific) targets
peacefestivalusa-wordpress:
	@echo "🌐 Installing WordPress for Peace Festival USA..."
	@$(SCRIPTS_DIR)/components/install_peacefestivalusa_wordpress.sh \
		--domain=$(DOMAIN) \
		--admin-email=$(ADMIN_EMAIL) \
		$(if $(FORCE),--force,) \
		|| true
	@echo "✅ WordPress installation for Peace Festival USA complete"
	@echo "🌐 Access WordPress at: https://$(DOMAIN) (or http://localhost:$(WP_PORT) in docker-in-docker mode)"

# Docker-in-Docker specific target for peacefestivalusa-wordpress
peacefestivalusa-wordpress-did:
	@echo "🐳 Installing WordPress for Peace Festival USA in Docker-in-Docker environment..."
	@$(SCRIPTS_DIR)/components/install_peacefestivalusa_wordpress.sh \
		--domain=$(DOMAIN) \
		--admin-email=$(ADMIN_EMAIL) \
		--wordpress-port=$(WP_PORT) \
		--did-mode=true \
		$(if $(FORCE),--force,) \
		|| true
	@echo "✅ WordPress installation for Peace Festival USA in Docker-in-Docker complete"
	@echo "🌐 Access WordPress at: http://localhost:$(WP_PORT)"

peacefestivalusa-wordpress-status:
	@echo "🔍 Checking Peace Festival USA WordPress status..."
	@docker ps | grep peacefestivalusa_wordpress || echo "❌ WordPress for Peace Festival USA is not running"
	@docker ps | grep peacefestivalusa_mariadb || echo "❌ MariaDB for Peace Festival USA is not running"

peacefestivalusa-wordpress-logs:
	@echo "📜 Viewing Peace Festival USA WordPress logs..."
	@docker logs peacefestivalusa_wordpress --tail 100

peacefestivalusa-wordpress-restart:
	@echo "♻️  Restarting Peace Festival USA WordPress services..."
	@docker restart peacefestivalusa_wordpress peacefestivalusa_mariadb

peacefestivalusa-wordpress-test:
	@echo "🧪 Testing Peace Festival USA WordPress API endpoint..."
	@$(SCRIPTS_DIR)/utils/test_peacefestivalusa_wordpress.sh || true

# Track component in registry
component-register-peacefestivalusa-wordpress:
	@echo "📝 Registering Peace Festival USA WordPress in component registry..."
	@$(SCRIPTS_DIR)/utils/register_component.sh \
		--name="wordpress_peacefestivalusa" \
		--category="Content Management" \
		--description="WordPress for Peace Festival USA ($(DOMAIN))" \
		--installed=true \
		--makefile=true \
		--docs=true \
		--hardened=true \
		--multi_tenant=true \
		--client_id=$(CLIENT_ID) \
		|| true

.PHONY: peacefestivalusa-wordpress peacefestivalusa-wordpress-did peacefestivalusa-wordpress-status peacefestivalusa-wordpress-logs peacefestivalusa-wordpress-restart peacefestivalusa-wordpress-test component-register-peacefestivalusa-wordpress
