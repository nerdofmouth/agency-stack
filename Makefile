# AgencyStack - Makefile
# FOSS Server Stack for Agencies & Enterprises
# https://stack.nerdofmouth.com

# Variables
SHELL := /bin/bash
VERSION := 0.0.1.2025.04.04.0013
SCRIPTS_DIR := scripts
DOCS_DIR := docs
STACK_NAME := AgencyStack

# Colors for output
BOLD := $(shell tput bold)
RED := $(shell tput setaf 1)
GREEN := $(shell tput setaf 2)
YELLOW := $(shell tput setaf 3)
BLUE := $(shell tput setaf 4)
MAGENTA := $(shell tput setaf 5)
CYAN := $(shell tput setaf 6)
RESET := $(shell tput sgr0)

.PHONY: help install update client test-env clean backup stack-info talknerdy rootofmouth buddy-init buddy-monitor drone-setup generate-buddy-keys start-buddy-system enable-monitoring mailu-setup mailu-test-email logs health-check verify-dns setup-log-rotation monitoring-setup config-snapshot config-rollback config-diff verify-backup setup-cron test-alert integrate-keycloak test-operations motd audit-components integrate-components dashboard dashboard-refresh dashboard-enable dashboard-update dashboard-open integrate-sso integrate-email integrate-monitoring integrate-data-bridge detect-ports remap-ports scan-ports setup-cronjobs view-alerts log-summary create-client setup-roles security-audit security-fix rotate-secrets setup-log-segmentation verify-certs verify-auth multi-tenancy-status install-wordpress install-erpnext install-posthog install-voip install-mailu install-grafana install-loki install-prometheus install-keycloak install-infrastructure install-security-infrastructure install-multi-tenancy peertube peertube-sso peertube-with-deps peertube-reinstall peertube-status peertube-logs peertube-stop peertube-start peertube-restart alpha-check ui-alpha-check ai-alpha-check fail2ban fail2ban-status fail2ban-logs fail2ban-restart security security-status security-logs security-infrastructure security-infrastructure-status security-infrastructure-logs signing-timestamps signing-timestamps-status signing-timestamps-logs signing-timestamps-restart docker docker-status docker-logs docker-restart docker-compose docker-compose-status infrastructure infrastructure-status infrastructure-logs traefik-ssl traefik-ssl-status traefik-ssl-logs traefik-ssl-renew openintegrationhub openintegrationhub-status openintegrationhub-logs openintegrationhub-restart n8n n8n-status n8n-logs n8n-restart posthog posthog-status posthog-logs posthog-restart netdata netdata-status netdata-logs netdata-restart multi-tenancy multi-tenancy-logs taskwarrior-calcure taskwarrior-calcure-status taskwarrior-calcure-logs taskwarrior-calcure-restart backup-strategy backup-strategy-status backup-strategy-logs backup-strategy-run prerequisites prerequisites-status launchpad-dashboard launchpad-dashboard-status launchpad-dashboard-logs launchpad-dashboard-restart webpush webpush-status webpush-logs webpush-restart tailscale tailscale-status tailscale-logs tailscale-restart crowdsec crowdsec-status crowdsec-logs crowdsec-restart crowdsec-dashboard mailu mailu-status mailu-logs mailu-restart mailu-test-email

# Default target
help:
	@echo "$(MAGENTA)$(BOLD)🚀 AgencyStack $(VERSION) - Open Source Agency Platform$(RESET)"
	@echo ""
	@bash $(SCRIPTS_DIR)/agency_branding.sh tagline
	@echo ""
	@echo "$(CYAN)Usage:$(RESET)"
	@echo "  $(BOLD)make install$(RESET)          Install AgencyStack components"
	@echo "  $(BOLD)make update$(RESET)           Update AgencyStack components"
	@echo "  $(BOLD)make client$(RESET)           Create a new client"
	@echo "  $(BOLD)make test-env$(RESET)         Test the environment"
	@echo "  $(BOLD)make backup$(RESET)           Backup all data"
	@echo "  $(BOLD)make clean$(RESET)            Remove all containers and volumes"
	@echo "  $(BOLD)make prep-dirs$(RESET)        Create required directories for AgencyStack"
	@echo "  $(BOLD)make env-check$(RESET)        Validate environment variables"
	@echo "  $(BOLD)make docs-index$(RESET)       Generate documentation index and TOC"
	@echo "  $(BOLD)make stack-info$(RESET)       Display AgencyStack information"
	@echo "  $(BOLD)make talknerdy$(RESET)        Display a random nerdy quote"
	@echo "  $(BOLD)make rootofmouth$(RESET)      Display system performance stats"
	@echo "  $(BOLD)make buddy-init$(RESET)       Initialize buddy system"
	@echo "  $(BOLD)make buddy-monitor$(RESET)    Check health of buddy servers"
	@echo "  $(BOLD)make drone-setup$(RESET)      Setup DroneCI integration"
	@echo "  $(BOLD)make mailu-setup$(RESET)      Configure Mailu email server"
	@echo "  $(BOLD)make mailu-test-email$(RESET) Send a test email via Mailu"
	@echo "  $(BOLD)make logs$(RESET)             View installation and component logs"
	@echo "  $(BOLD)make health-check$(RESET)     Verify all components are working properly"
	@echo "  $(BOLD)make verify-dns$(RESET)       Check DNS configuration"
	@echo "  $(BOLD)make setup-log-rotation$(RESET) Configure log rotation"
	@echo "  $(BOLD)make monitoring-setup$(RESET) Install Loki & Grafana monitoring stack"
	@echo "  $(BOLD)make config-snapshot$(RESET)  Create Git snapshot of current configuration"
	@echo "  $(BOLD)make config-rollback$(RESET)  Restore configuration from a previous snapshot"
	@echo "  $(BOLD)make config-diff$(RESET)      Show differences between configuration snapshots"
	@echo "  $(BOLD)make verify-backup$(RESET)    Verify integrity of Restic backups"
	@echo "  $(BOLD)make setup-cron$(RESET)       Configure automated monitoring tasks"
	@echo "  $(BOLD)make test-alert$(RESET)       Test alert channels"
	@echo "  $(BOLD)make integrate-keycloak$(RESET) Integrate Keycloak with AgencyStack components"
	@echo "  $(BOLD)make test-operations$(RESET)  Test AgencyStack operational features"
	@echo "  $(BOLD)make motd$(RESET)             Generate server message of the day"
	@echo "  $(BOLD)make audit-components$(RESET) Audit AgencyStack components and system"
	@echo "  $(BOLD)make integrate-components$(RESET) Integrate AgencyStack components"
	@echo "  $(BOLD)make dashboard$(RESET)        Open AgencyStack dashboard"
	@echo "  $(BOLD)make dashboard-refresh$(RESET) Refresh AgencyStack dashboard"
	@echo "  $(BOLD)make dashboard-enable$(RESET) Enable AgencyStack dashboard"
	@echo "  $(BOLD)make dashboard-update$(RESET) Update AgencyStack dashboard data"
	@echo "  $(BOLD)make dashboard-open$(RESET)   Open AgencyStack dashboard in browser"
	@echo "  $(BOLD)make integrate-sso$(RESET)    Integrate Single Sign-On for AgencyStack components"
	@echo "  $(BOLD)make integrate-email$(RESET)  Integrate Email systems for AgencyStack components"
	@echo "  $(BOLD)make integrate-monitoring$(RESET) Integrate Monitoring for AgencyStack components"
	@echo "  $(BOLD)make integrate-data-bridge$(RESET) Integrate Data Exchange for AgencyStack components"
	@echo "  $(BOLD)make detect-ports$(RESET)      Detect port conflicts in AgencyStack"
	@echo "  $(BOLD)make remap-ports$(RESET)       Automatically remap conflicting ports"
	@echo "  $(BOLD)make scan-ports$(RESET)        Scan and update port registry without conflict resolution"
	@echo "  $(BOLD)make setup-cronjobs$(RESET)    Setup cron jobs for scheduled tasks"
	@echo "  $(BOLD)make view-alerts$(RESET)       View recent alerts"
	@echo "  $(BOLD)make log-summary$(RESET)       Display summary of logs"
	@echo ""
	@echo "$(BOLD)Multi-Tenancy Commands:$(RESET)"
	@echo "  $(BOLD)make create-client CLIENT_ID=name CLIENT_NAME=\"Full Name\" CLIENT_DOMAIN=domain.com$(RESET)  Create a new client"
	@echo "  $(BOLD)make setup-roles CLIENT_ID=name$(RESET)  Set up Keycloak roles for a client"
	@echo "  $(BOLD)make multi-tenancy-status$(RESET)  Check status of all clients"
	@echo "  $(BOLD)make setup-log-segmentation CLIENT_ID=name$(RESET)  Set up client log segmentation"
	@echo ""
	@echo "$(BOLD)Security Commands:$(RESET)"
	@echo "  $(BOLD)make security-audit$(RESET)   Run security audit on stack"
	@echo "  $(BOLD)make security-fix$(RESET)     Automatically fix security issues"
	@echo "  $(BOLD)make rotate-secrets$(RESET)   Rotate all secrets"
	@echo "  $(BOLD)make verify-certs$(RESET)     Verify TLS certificates"
	@echo "  $(BOLD)make verify-auth$(RESET)      Verify authentication configuration"
	@echo "  $(BOLD)make cryptosync$(RESET)       Install Cryptosync - Encrypted Storage & Remote Sync"
	@echo "  $(BOLD)make cryptosync-mount$(RESET) Mount Cryptosync vault"
	@echo "  $(BOLD)make cryptosync-unmount$(RESET) Unmount Cryptosync vault"
	@echo "  $(BOLD)make cryptosync-sync$(RESET)  Sync Cryptosync data to remote"
	@echo "  $(BOLD)make cryptosync-config$(RESET) Open Cryptosync configuration"
	@echo "  $(BOLD)make cryptosync-rclone-config$(RESET) Configure Rclone remotes"
	@echo "  $(BOLD)make cryptosync-status$(RESET) Check Cryptosync status"
	@echo "  $(BOLD)make cryptosync-logs$(RESET)  View Cryptosync logs"
	@echo ""
	@echo "$(BOLD)Component Installation Commands:$(RESET)"
	@echo "  $(BOLD)make install-wordpress$(RESET)          Install WordPress"
	@echo "  $(BOLD)make install-erpnext$(RESET)           Install ERPNext"
	@echo "  $(BOLD)make install-posthog$(RESET)           Install PostHog"
	@echo "  $(BOLD)make install-voip$(RESET)              Install VoIP system (FusionPBX + FreeSWITCH)"
	@echo "  $(BOLD)make install-mailu$(RESET)             Install Mailu email server"
	@echo "  $(BOLD)make install-grafana$(RESET)           Install Grafana monitoring"
	@echo "  $(BOLD)make install-loki$(RESET)              Install Loki log aggregation"
	@echo "  $(BOLD)make install-prometheus$(RESET)        Install Prometheus monitoring"
	@echo "  $(BOLD)make install-keycloak$(RESET)         Install Keycloak identity provider"
	@echo "  $(BOLD)make install-infrastructure$(RESET)    Install core infrastructure"
	@echo "  $(BOLD)make install-security-infrastructure$(RESET) Install security infrastructure"
	@echo "  $(BOLD)make install-multi-tenancy$(RESET)     Set up multi-tenancy infrastructure"
	@echo "  $(BOLD)make peertube$(RESET)                 Install PeerTube - Self-hosted Video Platform"
	@echo "  $(BOLD)make peertube-sso$(RESET)             Install PeerTube with SSO integration"
	@echo "  $(BOLD)make peertube-with-deps$(RESET)       Install PeerTube with all dependencies"
	@echo "  $(BOLD)make peertube-reinstall$(RESET)       Reinstall PeerTube"
	@echo "  $(BOLD)make peertube-status$(RESET)          Check PeerTube status"
	@echo "  $(BOLD)make peertube-logs$(RESET)            View PeerTube logs"
	@echo "  $(BOLD)make peertube-stop$(RESET)            Stop PeerTube"
	@echo "  $(BOLD)make peertube-start$(RESET)           Start PeerTube"
	@echo "  $(BOLD)make peertube-restart$(RESET)         Restart PeerTube"

# Install AgencyStack
install: validate
	@echo "🔧 Installing AgencyStack..."
	@sudo $(SCRIPTS_DIR)/install.sh

# Update AgencyStack
update:
	@echo "🔄 Updating AgencyStack..."
	@git pull
	@sudo $(SCRIPTS_DIR)/update.sh

# Create a new client
client:
	@echo "🏢 Creating new client..."
	@sudo $(SCRIPTS_DIR)/agency_stack_bootstrap_bundle_v10/bootstrap_client.sh

# Test the environment
test-env:
	@echo "🧪 Testing AgencyStack environment..."
	@sudo $(SCRIPTS_DIR)/test_environment.sh

# Backup all data
backup:
	@echo "💾 Backing up AgencyStack data..."
	@sudo $(SCRIPTS_DIR)/backup.sh

# Clean all containers and volumes
clean:
	@echo "🧹 Cleaning AgencyStack environment..."
	@read -p "This will remove all containers and volumes. Are you sure? [y/N] " confirm; \
	[[ $$confirm == [yY] || $$confirm == [yY][eE][sS] ]] || exit 1
	@sudo docker-compose down -v

# Prepare required directories
prep-dirs:
	@echo "$(MAGENTA)$(BOLD)🏗️ Creating required AgencyStack directories...$(RESET)"
	@sudo mkdir -p /opt/agency_stack/
	@sudo mkdir -p /opt/agency_stack/clients/
	@sudo mkdir -p /opt/agency_stack/secrets/
	@sudo mkdir -p /var/log/agency_stack/components/
	@sudo mkdir -p /var/log/agency_stack/clients/
	@sudo mkdir -p /var/log/agency_stack/integrations/
	@sudo chown -R $(shell whoami):$(shell whoami) /opt/agency_stack/ 2>/dev/null || true
	@sudo chmod -R 750 /opt/agency_stack/ 2>/dev/null || true
	@sudo chown -R $(shell whoami):$(shell whoami) /var/log/agency_stack/ 2>/dev/null || true
	@sudo chmod -R 750 /var/log/agency_stack/ 2>/dev/null || true
	@echo "$(GREEN)✓ All required directories created with proper permissions$(RESET)"

# Check environment variables
env-check:
	@echo "$(MAGENTA)$(BOLD)🔍 Validating Environment Variables...$(RESET)"
	@bash $(SCRIPTS_DIR)/env_check.sh
	@echo ""
	@echo "$(BLUE)If you need to update your environment variables:$(RESET)"
	@echo "1. Edit your .env file: $(BOLD)nano .env$(RESET)"
	@echo "2. Run this check again: $(BOLD)make env-check$(RESET)"
	@echo ""
	@echo "$(BLUE)For documentation on all available environment variables:$(RESET)"
	@echo "$(BOLD)cat docs/pages/setup/env.md$(RESET)"

# Generate documentation index and TOC
docs-index:
	@echo "$(MAGENTA)$(BOLD)📚 Generating Documentation Index...$(RESET)"
	@bash $(SCRIPTS_DIR)/generate_docs_index.sh
	@echo ""
	@echo "$(GREEN)Documentation index generated successfully.$(RESET)"
	@echo "$(BLUE)Main index: $(BOLD)docs/pages/index.md$(RESET)"
	@echo "$(BLUE)Components index: $(BOLD)docs/pages/components.md$(RESET)"
	@echo "$(BLUE)Ports reference: $(BOLD)docs/pages/ports.md$(RESET)"

# Display AgencyStack information
stack-info:
	@echo "$(MAGENTA)$(BOLD)📊 AgencyStack Information$(RESET)"
	@echo "========================="
	@echo "Version: $(YELLOW)$(VERSION)$(RESET)"
	@echo "Stack Name: $(YELLOW)$(STACK_NAME)$(RESET)"
	@echo "Website: $(GREEN)https://stack.nerdofmouth.com$(RESET)"
	@echo ""
	@bash $(SCRIPTS_DIR)/agency_branding.sh tagline
	@echo ""
	@echo "$(CYAN)$(BOLD)Installed Components:$(RESET)"
	@if [ -f "/opt/agency_stack/installed_components.txt" ]; then \
		cat /opt/agency_stack/installed_components.txt | sort; \
	else \
		echo "$(RED)No components installed yet$(RESET)"; \
	fi
	@echo ""
	@echo "$(CYAN)$(BOLD)Running Containers:$(RESET)"
	@docker ps --format "table {{.Names}}\t{{.Status}}" 2>/dev/null || echo "$(RED)Docker not running$(RESET)"
	@echo ""
	@echo "$(YELLOW)$(BOLD)Port Allocations:$(RESET)"
	@if [ -f "$(SCRIPTS_DIR)/port_manager.sh" ]; then \
		bash $(SCRIPTS_DIR)/port_manager.sh list; \
	else \
		echo "$(RED)Port manager not installed$(RESET)"; \
	fi

# Display a random nerdy quote
talknerdy:
	@echo "$(MAGENTA)$(BOLD)💡 Random Nerdy Quote:$(RESET)"
	@bash $(SCRIPTS_DIR)/nerdy_quote.sh

# Display system performance stats
rootofmouth:
	@echo "$(MAGENTA)$(BOLD)📊 System Performance Stats:$(RESET)"
	@bash $(SCRIPTS_DIR)/system_performance.sh

# Initialize buddy system
buddy-init:
	@echo "🤝 Initializing AgencyStack buddy system..."
	@sudo $(SCRIPTS_DIR)/buddy_system.sh init
	@sudo $(SCRIPTS_DIR)/buddy_system.sh generate-keys
	@sudo $(SCRIPTS_DIR)/buddy_system.sh install-cron

# Monitor buddy servers
buddy-monitor:
	@echo "👀 Monitoring buddy servers..."
	@sudo $(SCRIPTS_DIR)/buddy_system.sh monitor

# Setup DroneCI integration
drone-setup:
	@echo "🚀 Setting up DroneCI integration..."
	@sudo $(SCRIPTS_DIR)/buddy_system.sh setup-drone
	@echo "Visit https://drone.$(shell hostname -f) to access your DroneCI instance"

# Generate buddy keys
generate-buddy-keys:
	@echo "🔑 Generating SSH keys for buddy system..."
	@sudo $(SCRIPTS_DIR)/buddy_system.sh generate-keys

# Start buddy system monitoring
start-buddy-system:
	@echo "🚀 Starting buddy system monitoring..."
	@sudo $(SCRIPTS_DIR)/buddy_system.sh install-cron
	@echo "Buddy system scheduled monitoring is now active"

# Enable monitoring
enable-monitoring: drone-setup start-buddy-system
	@echo "🔍 Monitoring systems enabled"
	@echo "Visit https://drone.$(shell hostname -f) to access your DroneCI instance"

# Configure Mailu email server
mailu-setup:
	@echo "📨 Configuring Mailu email server..."
	@sudo $(SCRIPTS_DIR)/mailu_setup.sh

# Send a test email via Mailu
mailu-test-email:
	@echo "$(CYAN)This is a deprecated target. Using the consolidated implementation...$(RESET)"
	@$(MAKE) -f $(MAKEFILE_LIST) mailu-test-email-consolidated

# View installation and component logs
logs:
	@echo "📝 Viewing installation and component logs..."
	@sudo $(SCRIPTS_DIR)/view_logs.sh

# Verify all components are working properly
health-check:
	@echo "🏥 Verifying all components are working properly..."
	@sudo $(SCRIPTS_DIR)/health_check.sh

# Check DNS configuration
verify-dns:
	@echo "📈 Checking DNS configuration..."
	@sudo $(SCRIPTS_DIR)/verify_dns.sh

# Configure log rotation
setup-log-rotation:
	@echo "🔄 Configuring log rotation..."
	@sudo $(SCRIPTS_DIR)/setup_log_rotation.sh

# Install Loki & Grafana monitoring stack
monitoring-setup:
	@echo "📊 Installing Loki & Grafana monitoring stack..."
	@sudo $(SCRIPTS_DIR)/monitoring_setup.sh

# Create Git snapshot of current configuration
config-snapshot:
	@echo "📸 Creating Git snapshot of current configuration..."
	@sudo $(SCRIPTS_DIR)/config_snapshot.sh

# Restore configuration from a previous snapshot
config-rollback:
	@echo "🔄 Restoring configuration from a previous snapshot..."
	@sudo $(SCRIPTS_DIR)/config_rollback.sh

# Show differences between configuration snapshots
config-diff:
	@echo "Running config diff..."
	@sudo bash $(SCRIPTS_DIR)/config_diff.sh

# Verify integrity of Restic backups
verify-backup:
	@echo "📈 Verifying integrity of Restic backups..."
	@sudo $(SCRIPTS_DIR)/verify_backup.sh

# Configure automated monitoring tasks
setup-cron:
	@echo "📅 Configuring automated monitoring tasks..."
	@sudo $(SCRIPTS_DIR)/setup_cron.sh

# Test alert channels
test-alert:
	@echo "$(MAGENTA)$(BOLD)🔔 Testing Alert System...$(RESET)"
	@$(SCRIPTS_DIR)/send_alert.sh --level=test --message="This is a test alert from AgencyStack" --client=$(CLIENT_ID)
	@echo "$(GREEN)Test alert sent successfully.$(RESET)"
	@echo "$(CYAN)Check your configured alert channels to verify receipt.$(RESET)"

# Integrate Keycloak with AgencyStack components
integrate-keycloak:
	@echo "🔐 Integrating Keycloak with AgencyStack components..."
	@sudo bash $(SCRIPTS_DIR)/keycloak_integration.sh

# Test AgencyStack operational features
test-operations:
	@echo "🧪 Testing AgencyStack operational features..."
	@sudo bash $(SCRIPTS_DIR)/test_operations.sh

# Generate server message of the day
motd:
	@echo "📝 Generating server message of the day..."
	@sudo bash $(SCRIPTS_DIR)/motd_generator.sh

# Audit AgencyStack components and system
audit-components:
	@echo "$(MAGENTA)$(BOLD)🔍 Auditing AgencyStack Components...$(RESET)"
	@$(SCRIPTS_DIR)/audit_and_cleanup.sh --dry-run
	@echo "$(CYAN)Audit complete! To view the report: make audit-report$(RESET)"
	@echo "$(YELLOW)To actually perform cleanup of unused files, run: make cleanup$(RESET)"

# Integrate AgencyStack components
integrate-components:
	@echo "🔄 Integrating AgencyStack components..."
	@sudo bash $(SCRIPTS_DIR)/integrate_components.sh

# Integrate Single Sign-On for AgencyStack components
integrate-sso:
	@echo "🔑 Integrating Single Sign-On for AgencyStack components..."
	@sudo bash $(SCRIPTS_DIR)/integrate_components.sh --type=sso

# Integrate Email systems for AgencyStack components
integrate-email:
	@echo "📧 Integrating Email systems for AgencyStack components..."
	@sudo bash $(SCRIPTS_DIR)/integrate_components.sh --type=email

# Integrate Monitoring for AgencyStack components
integrate-monitoring:
	@echo "📊 Integrating Monitoring for AgencyStack components..."
	@sudo bash $(SCRIPTS_DIR)/integrate_components.sh --type=monitoring

# Integrate Data Exchange for AgencyStack components
integrate-data-bridge:
	@echo "🔄 Integrating Data Exchange for AgencyStack components..."
	@sudo bash $(SCRIPTS_DIR)/integrate_components.sh --type=data-bridge

# Open AgencyStack dashboard
dashboard:
	@echo "📊 Opening AgencyStack dashboard..."
	@sudo bash $(SCRIPTS_DIR)/dashboard.sh

# Refresh AgencyStack dashboard
dashboard-refresh:
	@echo "🔄 Refreshing AgencyStack dashboard..."
	@sudo bash $(SCRIPTS_DIR)/dashboard_refresh.sh

# Enable AgencyStack dashboard
dashboard-enable:
	@echo "🔓 Enabling AgencyStack dashboard..."
	@sudo bash $(SCRIPTS_DIR)/dashboard_enable.sh

# Update dashboard data
dashboard-update:
	@echo "🔄 Updating AgencyStack dashboard data..."
	@sudo bash $(SCRIPTS_DIR)/dashboard/update_dashboard_data.sh

# Open dashboard in browser
dashboard-open:
	@echo "🌐 Opening AgencyStack dashboard in browser..."
	@xdg-open http://dashboard.$(shell grep PRIMARY_DOMAIN /opt/agency_stack/config.env 2>/dev/null | cut -d '=' -f2 || echo "localhost")

# Detect port conflicts
detect-ports:
	@echo "🔍 Detecting port conflicts in AgencyStack..."
	@sudo bash $(SCRIPTS_DIR)/utils/port_conflict_detector.sh --dry-run

# Remap conflicting ports
remap-ports:
	@echo "🔄 Remapping conflicting ports in AgencyStack..."
	@sudo bash $(SCRIPTS_DIR)/utils/port_conflict_detector.sh --fix

# Scan and update port registry
scan-ports:
	@echo "📋 Scanning and updating port registry..."
	@sudo bash $(SCRIPTS_DIR)/utils/port_conflict_detector.sh --scan

# Setup cron jobs
setup-cronjobs:
	@echo "⏱️ Setting up scheduled tasks for AgencyStack..."
	@sudo bash $(SCRIPTS_DIR)/setup_cronjobs.sh

# View alerts
view-alerts:
	@echo "📢 Recent alerts from AgencyStack:"
	@echo "--------------------------------"
	@if [ -f /var/log/agency_stack/alerts.log ]; then \
		tail -n 20 /var/log/agency_stack/alerts.log; \
	else \
		echo "No alerts log found"; \
	fi

# Display summary of logs
log-summary:
	@echo "📋 AgencyStack Log Summary"
	@echo "=================================="
	@echo ""
	@echo "$(BOLD)Health Check Logs:$(RESET)"
	@if [ -f /var/log/agency_stack/health.log ]; then \
		tail -n 10 /var/log/agency_stack/health.log; \
	else \
		echo "No health logs found"; \
	fi
	@echo ""
	@echo "$(BOLD)Backup Logs:$(RESET)"
	@if [ -f /var/log/agency_stack/backup.log ]; then \
		tail -n 10 /var/log/agency_stack/backup.log; \
	else \
		echo "No backup logs found"; \
	fi
	@echo ""
	@echo "$(BOLD)Alert Logs:$(RESET)"
	@if [ -f /var/log/agency_stack/alerts.log ]; then \
		tail -n 10 /var/log/agency_stack/alerts.log; \
	else \
		echo "No alert logs found"; \
	fi
	@echo ""
	@echo "For more details, run \`make logs\` or view the dashboard"

# Security and multi-tenancy commands
create-client:
	@echo "🏢 Creating new client..."
	@if [ -z "$(CLIENT_ID)" ] || [ -z "$(CLIENT_NAME)" ] || [ -z "$(CLIENT_DOMAIN)" ]; then \
		echo "$(RED)Error: Missing required parameters.$(RESET)"; \
		echo "Usage: make create-client CLIENT_ID=name CLIENT_NAME=\"Full Name\" CLIENT_DOMAIN=domain.com"; \
		exit 1; \
	fi
	@sudo bash $(SCRIPTS_DIR)/create-client.sh "$(CLIENT_ID)" "$(CLIENT_NAME)" "$(CLIENT_DOMAIN)"

setup-roles:
	@echo "🔑 Setting up Keycloak roles for client..."
	@if [ -z "$(CLIENT_ID)" ]; then \
		echo "$(RED)Error: Missing required parameter CLIENT_ID.$(RESET)"; \
		echo "Usage: make setup-roles CLIENT_ID=name"; \
		exit 1; \
	fi
	@sudo bash $(SCRIPTS_DIR)/keycloak/setup_roles.sh "$(CLIENT_ID)"

security-audit:
	@echo "🔐 Running security audit..."
	@if [ -n "$(CLIENT_ID)" ]; then \
		sudo bash $(SCRIPTS_DIR)/security/audit_stack.sh --client-id "$(CLIENT_ID)"; \
	else \
		sudo bash $(SCRIPTS_DIR)/security/audit_stack.sh; \
	fi

security-fix:
	@echo "🔧 Fixing security issues..."
	@if [ -n "$(CLIENT_ID)" ]; then \
		sudo bash $(SCRIPTS_DIR)/security/audit_stack.sh --fix --client-id "$(CLIENT_ID)"; \
	else \
		sudo bash $(SCRIPTS_DIR)/security/audit_stack.sh --fix; \
	fi

rotate-secrets:
	@echo "🔄 Rotating secrets..."
	@if [ -n "$(CLIENT_ID)" ] && [ -n "$(SERVICE)" ]; then \
		sudo bash $(SCRIPTS_DIR)/security/generate_secrets.sh --rotate --client-id "$(CLIENT_ID)" --service "$(SERVICE)"; \
	elif [ -n "$(CLIENT_ID)" ]; then \
		sudo bash $(SCRIPTS_DIR)/security/generate_secrets.sh --rotate --client-id "$(CLIENT_ID)"; \
	else \
		sudo bash $(SCRIPTS_DIR)/security/generate_secrets.sh --rotate; \
	fi

setup-log-segmentation:
	@echo "📋 Setting up log segmentation..."
	@if [ -n "$(CLIENT_ID)" ]; then \
		sudo bash $(SCRIPTS_DIR)/security/setup_log_segmentation.sh --client-id "$(CLIENT_ID)"; \
	else \
		sudo bash $(SCRIPTS_DIR)/security/setup_log_segmentation.sh; \
	fi

verify-certs:
	@echo "🔒 Verifying TLS certificates..."
	@sudo -E bash $(SCRIPTS_DIR)/security/verify_certificates.sh

verify-auth:
	@echo "👤 Verifying authentication configuration..."
	@sudo -E bash $(SCRIPTS_DIR)/security/verify_authentication.sh

# DEPRECATED: This target has been consolidated with the newer implementation at line ~546
multi-tenancy-status:
	@echo "$(CYAN)This is a deprecated target. Using the consolidated implementation...$(RESET)"
	@$(MAKE) -f $(MAKEFILE_LIST) multi-tenancy-status-consolidated

multi-tenancy-status-consolidated:
	@echo "$(MAGENTA)$(BOLD)📊 Checking Multi-Tenancy Status...$(RESET)"
	@$(SCRIPTS_DIR)/utils/multi_tenancy_check.sh

cryptosync:
	@echo "$(MAGENTA)$(BOLD)🔒 Installing Cryptosync...$(RESET)"
	@$(SCRIPTS_DIR)/components/install_cryptosync.sh $(if $(CLIENT_ID),--client-id $(CLIENT_ID),) \
		$(if $(MOUNT_DIR),--mount-dir $(MOUNT_DIR),) \
		$(if $(REMOTE_NAME),--remote-name $(REMOTE_NAME),) \
		$(if $(CONFIG_NAME),--config-name $(CONFIG_NAME),) \
		$(if $(REMOTE_TYPE),--remote-type $(REMOTE_TYPE),) \
		$(if $(REMOTE_PATH),--remote-path $(REMOTE_PATH),) \
		$(if $(REMOTE_OPTIONS),--remote-options $(REMOTE_OPTIONS),) \
		$(if $(FORCE),--force,) \
		$(if $(WITH_DEPS),--with-deps,) \
		$(if $(USE_CRYFS),--use-cryfs,) \
		$(if $(INITIAL_SYNC),--initial-sync,) \
		$(if $(AUTO_MOUNT),--auto-mount,)

cryptosync-mount:
	@echo "$(MAGENTA)$(BOLD)🔒 Mounting Cryptosync vault...$(RESET)"
	@cryptosync-mount-$(CLIENT_ID)-$(CONFIG_NAME)

cryptosync-unmount:
	@echo "$(MAGENTA)$(BOLD)🔒 Unmounting Cryptosync vault...$(RESET)"
	@cryptosync-unmount-$(CLIENT_ID)-$(CONFIG_NAME)

cryptosync-sync:
	@echo "$(MAGENTA)$(BOLD)🔄 Syncing Cryptosync data to remote...$(RESET)"
	@cryptosync-sync-$(CLIENT_ID)-$(CONFIG_NAME) $(REMOTE_PATH)

cryptosync-config:
	@echo "$(MAGENTA)$(BOLD)⚙️ Opening Cryptosync configuration...$(RESET)"
	@$(EDITOR) $(CONFIG_DIR)/clients/$(CLIENT_ID)/cryptosync/config/cryptosync.$(CONFIG_NAME).conf

cryptosync-rclone-config:
	@echo "$(MAGENTA)$(BOLD)⚙️ Configuring Rclone remotes...$(RESET)"
	@rclone config --config $(CONFIG_DIR)/clients/$(CLIENT_ID)/rclone/rclone.conf

cryptosync-status:
	@echo "$(MAGENTA)$(BOLD)ℹ️ Cryptosync Status:$(RESET)"
	@echo "$(CYAN)Encrypted directory:$(RESET) $(CONFIG_DIR)/clients/$(CLIENT_ID)/vault/encrypted"
	@echo "$(CYAN)Mount point:$(RESET) $(if $(MOUNT_DIR),$(MOUNT_DIR),$(CONFIG_DIR)/clients/$(CLIENT_ID)/vault/decrypted)"
	@echo "$(CYAN)Mounted:$(RESET) $$(mountpoint -q $(if $(MOUNT_DIR),$(MOUNT_DIR),$(CONFIG_DIR)/clients/$(CLIENT_ID)/vault/decrypted) && echo "Yes" || echo "No")"
	@echo "$(CYAN)Configuration:$(RESET) $(CONFIG_DIR)/clients/$(CLIENT_ID)/cryptosync/config/cryptosync.$(CONFIG_NAME).conf"
	@echo "$(CYAN)Rclone config:$(RESET) $(CONFIG_DIR)/clients/$(CLIENT_ID)/rclone/rclone.conf"
	@echo "$(CYAN)Remote:$(RESET) $(REMOTE_NAME)"
	@$(SCRIPTS_DIR)/monitoring/check_cryptosync.sh $(CLIENT_ID) $(CONFIG_NAME)

cryptosync-logs:
	@echo "$(MAGENTA)$(BOLD)📋 Viewing Cryptosync logs...$(RESET)"
	@tail -n 50 $(LOG_DIR)/components/cryptosync.log
	@echo ""
	@echo "$(YELLOW)For more logs: $(RESET)less $(LOG_DIR)/components/cryptosync.log"
	@if [ -f "$(CONFIG_DIR)/clients/$(CLIENT_ID)/cryptosync/logs/sync.log" ]; then \
		echo ""; \
		echo "$(MAGENTA)$(BOLD)📋 Last sync operations:$(RESET)"; \
		tail -n 20 $(CONFIG_DIR)/clients/$(CLIENT_ID)/cryptosync/logs/sync.log; \
	fi

# Repository Audit and Cleanup Targets
# ------------------------------------------------------------------------------

# DEPRECATED: This target has been consolidated with the newer implementation at line ~546
audit:
	@echo "$(CYAN)This target has been replaced by a newer implementation. Redirecting...$(RESET)"
	@$(MAKE) -f $(MAKEFILE_LIST) audit-new

audit-consolidated:
	@echo "$(MAGENTA)$(BOLD)📊 Running AgencyStack Repository Audit...$(RESET)"
	@sudo $(CURDIR)/scripts/utils/audit_and_cleanup.sh

audit-new:
	@echo "$(MAGENTA)$(BOLD)🔍 Running Comprehensive AgencyStack Audit...$(RESET)"
	@sudo $(CURDIR)/scripts/utils/audit_and_cleanup.sh --dry-run
	@echo "$(CYAN)Audit complete! To view the report: make audit-report$(RESET)"
	@echo "$(YELLOW)To actually perform cleanup of unused files, run: make cleanup$(RESET)"

quick-audit:
	@echo "$(MAGENTA)$(BOLD)🔍 Running Quick AgencyStack Repository Audit...$(RESET)"
	@sudo $(CURDIR)/scripts/utils/quick_audit.sh
	@echo "$(GREEN)To view detailed report, check: /var/log/agency_stack/audit/quick_audit_$$(date +%Y%m%d).txt$(RESET)"

script-usage:
	@echo "$(MAGENTA)$(BOLD)📜 Analyzing Script Usage Patterns...$(RESET)"
	@sudo $(CURDIR)/scripts/utils/reliable_track_usage.sh
	@echo "$(GREEN)To view detailed report, check: /var/log/agency_stack/audit/usage_summary.txt$(RESET)"

script-usage-verbose:
	@echo "$(MAGENTA)$(BOLD)📜 Analyzing Script Usage Patterns (Verbose Mode)...$(RESET)"
	@sudo $(CURDIR)/scripts/utils/track_usage.sh --verbose
	@echo "$(GREEN)To view detailed report, check: /var/log/agency_stack/audit/usage_summary.txt$(RESET)"

audit-docs:
	@echo "$(MAGENTA)$(BOLD)📚 Running Documentation Audit...$(RESET)"
	@sudo $(CURDIR)/scripts/utils/quick_audit.sh --include-docs

audit-report:
	@echo "$(MAGENTA)$(BOLD)📋 Displaying AgencyStack Audit Report...$(RESET)"
	@if [ -f /var/log/agency_stack/audit/summary_$$(date +%Y%m%d).txt ]; then \
		cat /var/log/agency_stack/audit/summary_$$(date +%Y%m%d).txt; \
	elif [ -f /var/log/agency_stack/audit/usage_summary.txt ]; then \
		cat /var/log/agency_stack/audit/usage_summary.txt; \
	elif [ -f /var/log/agency_stack/audit/quick_audit_$$(date +%Y%m%d).txt ]; then \
		cat /var/log/agency_stack/audit/quick_audit_$$(date +%Y%m%d).txt; \
	elif [ -f /var/log/agency_stack/audit/audit_report.log ]; then \
		cat /var/log/agency_stack/audit/audit_report.log; \
	else \
		echo "$(RED)No audit report found. Run 'make audit' first.$(RESET)"; \
		echo "$(YELLOW)Try running the script usage analysis with 'make script-usage'$(RESET)"; \
	fi

cleanup:
	@echo "$(MAGENTA)$(BOLD)🧹 Running AgencyStack Repository Cleanup...$(RESET)"
	@read -p "$(YELLOW)This will clean up unused scripts and resources. Are you sure? (y/N):$(RESET) " confirm; \
	if [ "$$confirm" = "y" ] || [ "$$confirm" = "Y" ]; then \
		sudo $(CURDIR)/scripts/utils/audit_and_cleanup.sh --clean; \
	else \
		echo "$(YELLOW)Cleanup aborted.$(RESET)"; \
	fi

# Component Registry Management Targets
# ------------------------------------------------------------------------------

component-registry:
	@echo "$(MAGENTA)$(BOLD)📋 Updating Component Registry...$(RESET)"
	@sudo $(SCRIPTS_DIR)/utils/update_component_registry.sh

component-status:
	@echo "$(MAGENTA)$(BOLD)📊 Checking Component Integration Status...$(RESET)"
	@sudo $(SCRIPTS_DIR)/utils/update_component_registry.sh --summary

component-check:
	@echo "$(MAGENTA)$(BOLD)🔍 Checking Component Registry for Inconsistencies...$(RESET)"
	@sudo $(SCRIPTS_DIR)/utils/update_component_registry.sh --check

component-update:
	@echo "$(MAGENTA)$(BOLD)✏️ Updating Component Status...$(RESET)"
	@read -p "$(YELLOW)Enter component name:$(RESET) " COMPONENT; \
	read -p "$(YELLOW)Enter flag to update (installed/hardened/makefile/sso/etc):$(RESET) " FLAG; \
	read -p "$(YELLOW)Enter new value (true/false):$(RESET) " VALUE; \
	sudo $(SCRIPTS_DIR)/utils/update_component_registry.sh --update-component $$COMPONENT --update-flag $$FLAG --update-value $$VALUE

# System Validation
validate:
	@echo "🔍 Validating system readiness for AgencyStack..."
	@sudo -E bash $(SCRIPTS_DIR)/utils/validate_system.sh $(if $(VERBOSE),--verbose,) $(if $(REPORT),--report,)

validate-report: REPORT := true
validate-report: validate

# WordPress
install-wordpress: validate
	@echo "Installing WordPress..."
	@sudo $(SCRIPTS_DIR)/components/install_wordpress.sh --domain $(DOMAIN) --admin-email $(ADMIN_EMAIL) $(if $(CLIENT_ID),--client-id $(CLIENT_ID),) $(if $(FORCE),--force,) $(if $(WITH_DEPS),--with-deps,) $(if $(VERBOSE),--verbose,)

# ERPNext
install-erpnext: validate
	@echo "Installing ERPNext..."
	@sudo $(SCRIPTS_DIR)/components/install_erpnext.sh --domain $(DOMAIN) --admin-email $(ADMIN_EMAIL) $(if $(CLIENT_ID),--client-id $(CLIENT_ID),) $(if $(FORCE),--force,) $(if $(WITH_DEPS),--with-deps,) $(if $(VERBOSE),--verbose,)

# PostHog
install-posthog: validate
	@echo "Installing PostHog..."
	@sudo $(SCRIPTS_DIR)/components/install_posthog.sh --domain $(DOMAIN) --admin-email $(ADMIN_EMAIL) $(if $(CLIENT_ID),--client-id $(CLIENT_ID),) $(if $(FORCE),--force,) $(if $(WITH_DEPS),--with-deps,) $(if $(VERBOSE),--verbose,)

# VoIP (FusionPBX + FreeSWITCH)
install-voip: validate
	@echo "$(MAGENTA)$(BOLD)☎️ Installing VoIP system (FusionPBX + FreeSWITCH)...$(RESET)"
	@sudo $(SCRIPTS_DIR)/components/install_voip.sh --domain $(DOMAIN) --admin-email $(ADMIN_EMAIL) $(if $(CLIENT_ID),--client-id $(CLIENT_ID),) $(if $(FORCE),--force,) $(if $(WITH_DEPS),--with-deps,) $(if $(VERBOSE),--verbose,)

voip: install-voip

voip-status:
	@echo "$(MAGENTA)$(BOLD)ℹ️ Checking VoIP System Status...$(RESET)"
	@cd /opt/agency_stack/voip/$(if $(CLIENT_ID),clients/$(CLIENT_ID)/,) && docker-compose ps
	@echo "$(CYAN)Logs can be viewed with: make voip-logs$(RESET)"

voip-logs:
	@echo "$(MAGENTA)$(BOLD)📜 Viewing VoIP Logs...$(RESET)"
	@cd /opt/agency_stack/voip/$(if $(CLIENT_ID),clients/$(CLIENT_ID)/,) && docker-compose logs -f

voip-restart:
	@echo "$(MAGENTA)$(BOLD)🔄 Restarting VoIP Services...$(RESET)"
	@cd /opt/agency_stack/voip/$(if $(CLIENT_ID),clients/$(CLIENT_ID)/,) && docker-compose restart

voip-stop:
	@echo "$(MAGENTA)$(BOLD)🛑 Stopping VoIP Services...$(RESET)"
	@cd /opt/agency_stack/voip/$(if $(CLIENT_ID),clients/$(CLIENT_ID)/,) && docker-compose stop

voip-start:
	@echo "$(MAGENTA)$(BOLD)▶️ Starting VoIP Services...$(RESET)"
	@cd /opt/agency_stack/voip/$(if $(CLIENT_ID),clients/$(CLIENT_ID)/,) && docker-compose start

voip-config:
	@echo "$(MAGENTA)$(BOLD)⚙️ Configuring VoIP System...$(RESET)"
	@read -p "$(YELLOW)Enter domain for VoIP (e.g., voip.yourdomain.com):$(RESET) " DOMAIN; \
	read -p "$(YELLOW)Enter admin email:$(RESET) " ADMIN_EMAIL; \
	read -p "$(YELLOW)Enter client ID (optional):$(RESET) " CLIENT_ID; \
	sudo $(SCRIPTS_DIR)/components/install_voip.sh --domain $$DOMAIN --admin-email $$ADMIN_EMAIL $(if [ -n "$$CLIENT_ID" ]; then echo "--client-id $$CLIENT_ID"; fi) --configure-only

# Mailu Email Server
install-mailu: validate
	@echo "Installing Mailu email server..."
	@sudo $(SCRIPTS_DIR)/components/install_mailu.sh --domain mail.$(DOMAIN) --email-domain $(DOMAIN) --admin-email $(ADMIN_EMAIL) $(if $(CLIENT_ID),--client-id $(CLIENT_ID),) $(if $(FORCE),--force,) $(if $(WITH_DEPS),--with-deps,) $(if $(VERBOSE),--verbose,)

# Listmonk - Newsletter & Mailing Lists
listmonk:
	@echo "Installing Listmonk..."
	@sudo $(SCRIPTS_DIR)/components/install_listmonk.sh --domain $(LISTMONK_DOMAIN) $(INSTALL_FLAGS)

listmonk-status:
	@docker ps -a | grep listmonk || echo "Listmonk is not running"

listmonk-logs:
	@docker logs -f listmonk-$(CLIENT_ID) 2>&1 | tee $(LOG_DIR)/components/listmonk.log

listmonk-stop:
	@docker-compose -f $(DOCKER_DIR)/listmonk/docker-compose.yml down

listmonk-start:
	@docker-compose -f $(DOCKER_DIR)/listmonk/docker-compose.yml up -d

listmonk-restart:
	@docker-compose -f $(DOCKER_DIR)/listmonk/docker-compose.yml restart

listmonk-backup:
	@echo "Backing up Listmonk data..."
	@mkdir -p $(BACKUP_DIR)/listmonk
	@docker exec listmonk-postgres-$(CLIENT_ID) pg_dump -U listmonk listmonk > $(BACKUP_DIR)/listmonk/listmonk_db_$(shell date +%Y%m%d).sql
	@tar -czf $(BACKUP_DIR)/listmonk/listmonk_uploads_$(shell date +%Y%m%d).tar.gz -C $(CONFIG_DIR)/clients/$(CLIENT_ID)/listmonk_data/uploads .
	@echo "Backup completed: $(BACKUP_DIR)/listmonk/"

listmonk-restore:
	@echo "Restoring Listmonk from backup is a manual process."
	@echo "Please refer to the documentation for detailed instructions."

listmonk-config:
	@echo "Opening Listmonk configuration..."
	@$(EDITOR) $(CONFIG_DIR)/clients/$(CLIENT_ID)/listmonk_data/config/config.toml

# Grafana
install-grafana: validate
	@echo "Installing Grafana monitoring..."
	@sudo $(SCRIPTS_DIR)/components/install_grafana.sh --domain $(DOMAIN) --admin-email $(ADMIN_EMAIL) $(if $(CLIENT_ID),--client-id $(CLIENT_ID),) $(if $(FORCE),--force,) $(if $(WITH_DEPS),--with-deps,) $(if $(VERBOSE),--verbose,)

# Loki
install-loki: validate
	@echo "Installing Loki log aggregation..."
	@sudo $(SCRIPTS_DIR)/components/install_loki.sh --domain logs.$(DOMAIN) $(if $(GRAFANA_DOMAIN),--grafana-domain $(GRAFANA_DOMAIN),--grafana-domain grafana.$(DOMAIN)) $(if $(CLIENT_ID),--client-id $(CLIENT_ID),) $(if $(FORCE),--force,) $(if $(WITH_DEPS),--with-deps,) $(if $(VERBOSE),--verbose,)

# Prometheus
install-prometheus: validate
	@echo "$(MAGENTA)$(BOLD)📊 Installing Prometheus Monitoring...$(RESET)"
	@sudo $(SCRIPTS_DIR)/components/install_prometheus.sh --domain metrics.$(DOMAIN) $(if $(GRAFANA_DOMAIN),--grafana-domain $(GRAFANA_DOMAIN),--grafana-domain grafana.$(DOMAIN)) $(if $(CLIENT_ID),--client-id $(CLIENT_ID),) $(if $(FORCE),--force,) $(if $(WITH_DEPS),--with-deps,) $(if $(VERBOSE),--verbose,)

prometheus: install-prometheus

prometheus-status:
	@echo "$(MAGENTA)$(BOLD)ℹ️ Checking Prometheus Status...$(RESET)"
	@cd /opt/agency_stack/prometheus/$(if $(CLIENT_ID),clients/$(CLIENT_ID)/,) && docker-compose ps
	@echo "$(CYAN)Logs can be viewed with: make prometheus-logs$(RESET)"

prometheus-logs:
	@echo "$(MAGENTA)$(BOLD)📜 Viewing Prometheus Logs...$(RESET)"
	@cd /opt/agency_stack/prometheus/$(if $(CLIENT_ID),clients/$(CLIENT_ID)/,) && docker-compose logs -f

prometheus-restart:
	@echo "$(MAGENTA)$(BOLD)🔄 Restarting Prometheus Services...$(RESET)"
	@cd /opt/agency_stack/prometheus/$(if $(CLIENT_ID),clients/$(CLIENT_ID)/,) && docker-compose restart

prometheus-stop:
	@echo "$(MAGENTA)$(BOLD)🛑 Stopping Prometheus Services...$(RESET)"
	@cd /opt/agency_stack/prometheus/$(if $(CLIENT_ID),clients/$(CLIENT_ID)/,) && docker-compose stop

prometheus-start:
	@echo "$(MAGENTA)$(BOLD)▶️ Starting Prometheus Services...$(RESET)"
	@cd /opt/agency_stack/prometheus/$(if $(CLIENT_ID),clients/$(CLIENT_ID)/,) && docker-compose start

prometheus-reload:
	@echo "$(MAGENTA)$(BOLD)🔄 Reloading Prometheus Configuration...$(RESET)"
	@curl -X POST http://localhost:9090/-/reload || echo "$(RED)Failed to reload Prometheus. Is it running?$(RESET)"

prometheus-alerts:
	@echo "$(MAGENTA)$(BOLD)🔔 Viewing Prometheus Alerts...$(RESET)"
	@curl -s http://localhost:9090/api/v1/alerts | jq || echo "$(RED)Failed to fetch alerts. Is Prometheus running?$(RESET)"

prometheus-config:
	@echo "$(MAGENTA)$(BOLD)⚙️ Configuring Prometheus...$(RESET)"
	@read -p "$(YELLOW)Enter domain for Prometheus (e.g., metrics.yourdomain.com):$(RESET) " DOMAIN; \
	read -p "$(YELLOW)Enter Grafana domain (e.g., grafana.yourdomain.com):$(RESET) " GRAFANA_DOMAIN; \
	read -p "$(YELLOW)Enter client ID (optional):$(RESET) " CLIENT_ID; \
	sudo $(SCRIPTS_DIR)/components/install_prometheus.sh --domain $$DOMAIN --grafana-domain $$GRAFANA_DOMAIN $(if [ -n "$$CLIENT_ID" ]; then echo "--client-id $$CLIENT_ID"; fi) --configure-only

# Keycloak
install-keycloak: validate
	@echo "Installing Keycloak identity provider..."
	@sudo $(SCRIPTS_DIR)/components/install_keycloak.sh --domain $(DOMAIN) --admin-email $(ADMIN_EMAIL) $(if $(CLIENT_ID),--client-id $(CLIENT_ID),) $(if $(FORCE),--force,) $(if $(WITH_DEPS),--with-deps,) $(if $(VERBOSE),--verbose,)

# Core Infrastructure
install-infrastructure:
	@echo "Installing core infrastructure..."
	@sudo $(SCRIPTS_DIR)/core/install_infrastructure.sh $(if $(VERBOSE),--verbose,)

# Security Infrastructure
install-security-infrastructure:
	@echo "Installing security infrastructure..."
	@sudo $(SCRIPTS_DIR)/core/install_security_infrastructure.sh --domain $(DOMAIN) --email $(ADMIN_EMAIL) $(if $(VERBOSE),--verbose,)

# Multi-tenancy Infrastructure
install-multi-tenancy:
	@echo "Setting up multi-tenancy infrastructure..."
	@sudo $(SCRIPTS_DIR)/multi-tenancy/install_multi_tenancy.sh $(if $(VERBOSE),--verbose,)

# Business Applications
business: erp cal killbill documenso chatwoot
	@echo "Business Applications installed"

# ERPNext - Enterprise Resource Planning
erp:
	@echo "Installing ERPNext..."
	@sudo $(SCRIPTS_DIR)/components/install_erpnext.sh --domain $(ERP_DOMAIN) $(INSTALL_FLAGS)

# Cal.com - Scheduling
cal:
	@echo "Installing Cal.com..."
	@sudo $(SCRIPTS_DIR)/components/install_cal.sh --domain $(CAL_DOMAIN) $(INSTALL_FLAGS)

# Documenso - Document signing
documenso:
	@echo "Installing Documenso..."
	@sudo $(SCRIPTS_DIR)/components/install_documenso.sh --domain $(DOCUMENSO_DOMAIN) $(INSTALL_FLAGS)

# KillBill - Billing
killbill:
	@echo "Installing KillBill..."
	@sudo $(SCRIPTS_DIR)/components/install_killbill.sh --domain $(KILLBILL_DOMAIN) $(INSTALL_FLAGS)

# Chatwoot - Customer Service Platform
chatwoot:
	@echo "Installing Chatwoot..."
	@sudo $(SCRIPTS_DIR)/components/install_chatwoot.sh --domain $(CHATWOOT_DOMAIN) $(INSTALL_FLAGS)

chatwoot-status:
	@docker ps -a | grep chatwoot || echo "Chatwoot is not running"

chatwoot-logs:
	@docker logs -f chatwoot-app-$(CLIENT_ID) 2>&1 | tee $(LOG_DIR)/components/chatwoot.log

chatwoot-stop:
	@docker-compose -f $(DOCKER_DIR)/chatwoot/docker-compose.yml down

chatwoot-start:
	@docker-compose -f $(DOCKER_DIR)/chatwoot/docker-compose.yml up -d

chatwoot-restart:
	@docker-compose -f $(DOCKER_DIR)/chatwoot/docker-compose.yml restart

chatwoot-backup:
	@echo "Backing up Chatwoot data..."
	@mkdir -p $(BACKUP_DIR)/chatwoot
	@docker exec chatwoot-postgres-$(CLIENT_ID) pg_dump -U chatwoot chatwoot > $(BACKUP_DIR)/chatwoot/chatwoot_db_$(shell date +%Y%m%d).sql
	@tar -czf $(BACKUP_DIR)/chatwoot/chatwoot_storage_$(shell date +%Y%m%d).tar.gz -C $(CONFIG_DIR)/clients/$(CLIENT_ID)/chatwoot_data/storage .
	@echo "Backup completed: $(BACKUP_DIR)/chatwoot/"

chatwoot-config:
	@echo "Opening Chatwoot environment configuration..."
	@$(EDITOR) $(DOCKER_DIR)/chatwoot/.env

# Content & Media
peertube:
	@echo "$(MAGENTA)$(BOLD)🎞️ Installing PeerTube - Self-hosted Video Platform...$(RESET)"
	@read -p "$(YELLOW)Enter domain for PeerTube (e.g., peertube.yourdomain.com):$(RESET) " DOMAIN; \
	sudo $(SCRIPTS_DIR)/components/install_peertube.sh --domain $$DOMAIN

peertube-sso:
	@echo "$(MAGENTA)$(BOLD)🔐 Installing PeerTube with SSO integration...$(RESET)"
	@read -p "$(YELLOW)Enter domain for PeerTube (e.g., peertube.yourdomain.com):$(RESET) " DOMAIN; \
	read -p "$(YELLOW)Enter SSO client ID for PeerTube:$(RESET) " CLIENT_ID; \
	sudo $(SCRIPTS_DIR)/components/install_peertube.sh --domain $$DOMAIN --client-id $$CLIENT_ID

peertube-with-deps:
	@echo "$(MAGENTA)$(BOLD)🎞️ Installing PeerTube with all dependencies...$(RESET)"
	@read -p "$(YELLOW)Enter domain for PeerTube (e.g., peertube.yourdomain.com):$(RESET) " DOMAIN; \
	sudo $(SCRIPTS_DIR)/components/install_peertube.sh --domain $$DOMAIN --with-deps

peertube-reinstall:
	@echo "$(MAGENTA)$(BOLD)🔄 Reinstalling PeerTube...$(RESET)"
	@read -p "$(YELLOW)Enter domain for PeerTube (e.g., peertube.yourdomain.com):$(RESET) " DOMAIN; \
	sudo $(SCRIPTS_DIR)/components/install_peertube.sh --domain $$DOMAIN --force

peertube-status:
	@echo "$(MAGENTA)$(BOLD)ℹ️ Checking PeerTube status...$(RESET)"
	@cd $(DOCKER_DIR)/peertube && docker-compose ps
	@echo "$(CYAN)Logs can be viewed with: make peertube-logs$(RESET)"

peertube-logs:
	@echo "$(MAGENTA)$(BOLD)📜 Viewing PeerTube logs...$(RESET)"
	@cd $(DOCKER_DIR)/peertube && docker-compose logs -f

peertube-stop:
	@echo "$(MAGENTA)$(BOLD)🛑 Stopping PeerTube...$(RESET)"
	@cd $(DOCKER_DIR)/peertube && docker-compose stop

peertube-start:
	@echo "$(MAGENTA)$(BOLD)▶️ Starting PeerTube...$(RESET)"
	@cd $(DOCKER_DIR)/peertube && docker-compose start

peertube-restart:
	@echo "$(MAGENTA)$(BOLD)🔄 Restarting PeerTube...$(RESET)"
	@cd $(DOCKER_DIR)/peertube && docker-compose restart

## AI Suite Test Harness
ai-suite-test:
	@echo "$(MAGENTA)$(BOLD)🧪 Starting AI Suite Test Harness (Mock Mode)...$(RESET)"
	@echo "$(YELLOW)This will spin up a sandbox environment with mock AI components.$(RESET)"
	
	@# Create test client if it doesn't exist
	@if [ ! -d "/opt/agency_stack/clients/test" ]; then \
		mkdir -p /opt/agency_stack/clients/test; \
		echo "$(GREEN)Created test client directory.$(RESET)"; \
	fi
	
	@# Create test directories for each component
	@mkdir -p /opt/agency_stack/clients/test/ai/logs
	@mkdir -p /opt/agency_stack/clients/test/ai/data
	@mkdir -p /opt/agency_stack/clients/test/ai/config
	
	@# Start mock Agent Orchestrator
	@echo "$(CYAN)Starting Mock Agent Orchestrator...$(RESET)"
	@docker run -d --rm \
		--name agent-orchestrator-mock \
		-p 5210:5210 \
		-e CLIENT_ID=test \
		-e MOCK_MODE=true \
		-e LOG_LEVEL=info \
		-v /opt/agency_stack/clients/test/ai/logs:/logs \
		-v /opt/agency_stack/clients/test/ai/data:/data \
		$(SCRIPTS_DIR)/components/agent_orchestrator_mock.sh || echo "$(RED)Failed to start mock Agent Orchestrator. Using fallback mock server.$(RESET)" && \
		$(SCRIPTS_DIR)/mock/start_mock_server.sh agent-orchestrator 5210
	
	@# Start mock LangChain
	@echo "$(CYAN)Starting Mock LangChain...$(RESET)"
	@docker run -d --rm \
		--name langchain-mock \
		-p 5111:5111 \
		-e CLIENT_ID=test \
		-e MOCK_MODE=true \
		-e LOG_LEVEL=info \
		-v /opt/agency_stack/clients/test/ai/logs:/logs \
		-v /opt/agency_stack/clients/test/ai/data:/data \
		$(SCRIPTS_DIR)/components/langchain_mock.sh || echo "$(RED)Failed to start mock LangChain. Using fallback mock server.$(RESET)" && \
		$(SCRIPTS_DIR)/mock/start_mock_server.sh langchain 5111
	
	@# Start mock Resource Watcher
	@echo "$(CYAN)Starting Mock Resource Watcher...$(RESET)"
	@docker run -d --rm \
		--name resource-watcher-mock \
		-p 5220:5220 \
		-e CLIENT_ID=test \
		-e MOCK_MODE=true \
		-e LOG_LEVEL=info \
		-v /opt/agency_stack/clients/test/ai/logs:/logs \
		-v /opt/agency_stack/clients/test/ai/data:/data \
		$(SCRIPTS_DIR)/components/resource_watcher_mock.sh || echo "$(RED)Failed to start mock Resource Watcher. Using fallback mock server.$(RESET)" && \
		$(SCRIPTS_DIR)/mock/start_mock_server.sh resource-watcher 5220
	
	@# Start Agent Tools UI with mock mode enabled
	@echo "$(CYAN)Starting Agent Tools UI in Mock Mode...$(RESET)"
	@cd $(ROOT_DIR)/apps/agent_tools && \
		NEXT_PUBLIC_MOCK_MODE=true \
		NEXT_PUBLIC_CLIENT_ID=test \
		npm run dev &
	
	@echo "$(GREEN)$(BOLD)✅ AI Suite Test Harness is running!$(RESET)"
	@echo "$(YELLOW)Mock Mode is ENABLED. All operations are simulated.$(RESET)"
	@echo ""
	@echo "$(CYAN)Access points:$(RESET)"
	@echo "  Agent Tools UI:      http://localhost:5120/?client_id=test&mock=true"
	@echo "  Agent Orchestrator:  http://localhost:5210"
	@echo "  LangChain:           http://localhost:5111"
	@echo "  Resource Watcher:    http://localhost:5220"
	@echo ""
	@echo "$(CYAN)To stop the test harness: make ai-suite-reset$(RESET)"
	@echo "$(CYAN)For more information: See /docs/pages/ai/mock_mode.md$(RESET)"

ai-suite-reset:
	@echo "$(MAGENTA)$(BOLD)🧹 Resetting AI Suite test environment...$(RESET)"
	
	@# Stop mock containers
	@echo "$(CYAN)Stopping mock containers...$(RESET)"
	@docker stop agent-orchestrator-mock langchain-mock resource-watcher-mock 2>/dev/null || true
	
	@# Kill any running Next.js dev server for Agent Tools
	@echo "$(CYAN)Stopping Agent Tools UI...$(RESET)"
	@pkill -f "next.*5120" 2>/dev/null || true
	
	@# Clear test client directory
	@echo "$(CYAN)Clearing test client data...$(RESET)"
	@if [ -d "/opt/agency_stack/clients/test" ]; then \
		rm -rf /opt/agency_stack/clients/test; \
		echo "$(GREEN)Removed test client directory.$(RESET)"; \
	fi
	
	@# Create placeholder for next test
	@mkdir -p /opt/agency_stack/clients/test
	
	@echo "$(GREEN)$(BOLD)✅ AI Suite Test Harness has been reset!$(RESET)"
	@echo "$(CYAN)To start the test harness again: make ai-suite-test$(RESET)"

## AI Dashboard Targets
ai-dashboard:
	@echo "Installing AI Dashboard..."
	@sudo $(SCRIPTS_DIR)/components/install_ai_dashboard.sh --client-id=$(CLIENT_ID) --domain=$(DOMAIN) $(AI_DASHBOARD_FLAGS)

ai-dashboard-status:
	@echo "Checking AI Dashboard status..."
	@docker ps -f "name=ai-dashboard-$(CLIENT_ID)" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

ai-dashboard-logs:
	@echo "Viewing AI Dashboard logs..."
	@docker logs ai-dashboard-$(CLIENT_ID) -f --tail=100

ai-dashboard-restart:
	@echo "Restarting AI Dashboard..."
	@docker restart ai-dashboard-$(CLIENT_ID)

ai-dashboard-test:
	@echo "Opening AI Dashboard in browser..."
	@xdg-open https://ai.$(DOMAIN) || open https://ai.$(DOMAIN) || echo "Could not open browser, please visit https://ai.$(DOMAIN) manually"

## Agent Orchestrator Targets
agent-orchestrator:
	@echo "Installing Agent Orchestrator..."
	@./scripts/components/install_agent_orchestrator.sh --client-id=$(CLIENT_ID) --domain=$(DOMAIN) $(AGENT_ORCHESTRATOR_FLAGS)

agent-orchestrator-status:
	@echo "Checking Agent Orchestrator status..."
	@docker ps -f "name=agent-orchestrator-$(CLIENT_ID)" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

agent-orchestrator-logs:
	@echo "Viewing Agent Orchestrator logs..."
	@docker logs agent-orchestrator-$(CLIENT_ID) -f --tail=100

agent-orchestrator-restart:
	@echo "Restarting Agent Orchestrator..."
	@docker restart agent-orchestrator-$(CLIENT_ID)

agent-orchestrator-test:
	@echo "Testing Agent Orchestrator API..."
	@curl -s http://localhost:5210/health || echo "Could not connect to Agent Orchestrator. Is it running?"
	@echo ""
	@echo "To open in browser, visit: https://agent.$(DOMAIN)"

## AI Agent Tools Targets
ai-agent-tools:
	@echo "$(MAGENTA)$(BOLD)🤖 Installing AI Agent Tools Panel...$(RESET)"
	@if [ ! -d "$(ROOT_DIR)/apps/agent_tools" ]; then \
		echo "$(RED)Agent Tools directory not found!$(RESET)"; \
		exit 1; \
	fi
	@cd $(ROOT_DIR)/apps/agent_tools && npm install && npm run build
	@echo "$(GREEN)AI Agent Tools Panel installed successfully!$(RESET)"
	@echo "$(CYAN)To start the Agent Tools Panel, run: make ai-agent-tools-start$(RESET)"

ai-agent-tools-start:
	@echo "$(MAGENTA)$(BOLD)🚀 Starting AI Agent Tools Panel...$(RESET)"
	@if [ ! -d "$(ROOT_DIR)/apps/agent_tools" ]; then \
		echo "$(RED)Agent Tools directory not found!$(RESET)"; \
		exit 1; \
	fi
	@cd $(ROOT_DIR)/apps/agent_tools && \
		NEXT_PUBLIC_MOCK_MODE=true \
		NEXT_PUBLIC_CLIENT_ID=$(CLIENT_ID) \
		npm run dev &

ai-agent-tools-status:
	@echo "$(MAGENTA)$(BOLD)ℹ️ Checking AI Agent Tools Panel Status...$(RESET)"
	@if [ ! -d "$(ROOT_DIR)/apps/agent_tools" ]; then \
		echo "$(RED)Agent Tools Panel is not installed.$(RESET)"; \
	else \
		echo "$(GREEN)Agent Tools Panel is installed.$(RESET)"; \
		echo "$(CYAN)Configuration:$(RESET)"; \
		echo "  - Directory: $(ROOT_DIR)/apps/agent_tools"; \
		echo "  - Port: 5120"; \
		echo "  - Status: $(shell if pgrep -f "next.*5120" > /dev/null; then echo "$(GREEN)Running$(RESET)"; else echo "$(RED)Not Running$(RESET)"; fi)"; \
		echo "$(YELLOW)To start the Agent Tools Panel, run: make ai-agent-tools-start$(RESET)"; \
	fi

## Resource Watcher Targets
resource-watcher:
	@echo "$(MAGENTA)$(BOLD)📊 Installing Resource Watcher - AI Resource Monitoring Agent...$(RESET)"
	@$(SCRIPTS_DIR)/components/install_resource_watcher.sh --client-id=$(CLIENT_ID) --domain=$(DOMAIN) $(if $(WITH_DEPS),--with-deps,) $(if $(FORCE),--force,) $(if $(ENABLE_MONITORING),--enable-monitoring,) $(if $(VERBOSE),--verbose,)
	@echo "$(GREEN)Resource Watcher installed successfully!$(RESET)"
	@echo "$(CYAN)To check status: make resource-watcher-status$(RESET)"

resource-watcher-status:
	@echo "$(MAGENTA)$(BOLD)ℹ️ Checking Resource Watcher Status...$(RESET)"
	@if [ -d "/opt/agency_stack/resource_watcher" ]; then \
		echo "$(GREEN)✓ Resource Watcher is installed$(RESET)"; \
		if docker ps | grep -q "resource-watcher"; then \
			echo "$(GREEN)✓ Resource Watcher is running$(RESET)"; \
		else \
			echo "$(RED)✗ Resource Watcher is installed but not running$(RESET)"; \
		fi \
	else \
		echo "$(RED)✗ Resource Watcher is not installed$(RESET)"; \
	fi
	@curl -s http://localhost:5220/health || echo "Could not connect to Resource Watcher. Is it running?"
	@echo ""

resource-watcher-logs:
	@echo "$(MAGENTA)$(BOLD)📋 Viewing Resource Watcher logs...$(RESET)"
	@if [ -d "/opt/agency_stack/resource_watcher" ]; then \
		docker logs -n 50 resource-watcher; \
	else \
		echo "$(RED)Resource Watcher is not installed$(RESET)"; \
	fi

resource-watcher-metrics:
	@echo "$(MAGENTA)$(BOLD)📊 Viewing current system metrics...$(RESET)"
	@PORT=$$(docker port resource-watcher-$(CLIENT_ID) 5211/tcp | sed 's/0.0.0.0://'); \
	curl -s "http://localhost:$${PORT}/metrics" | jq

resource-watcher-summary:
	@echo "$(MAGENTA)$(BOLD)📈 Viewing resource usage summary...$(RESET)"
	@PORT=$$(docker port resource-watcher-$(CLIENT_ID) 5211/tcp | sed 's/0.0.0.0://'); \
	curl -s "http://localhost:$${PORT}/summary?include_insights=true" | jq

resource-watcher-alerts:
	@echo "$(MAGENTA)$(BOLD)⚠️ Viewing recent alerts...$(RESET)"
	@PORT=$$(docker port resource-watcher-$(CLIENT_ID) 5211/tcp | sed 's/0.0.0.0://'); \
	curl -s "http://localhost:$${PORT}/alerts?limit=10" | jq

## Install AI Suite Targets
install-ai-suite:
	@echo "$(MAGENTA)$(BOLD)🧠 Installing Complete AI Suite...$(RESET)"
	@echo "$(YELLOW)This will install Ollama, LangChain, AI Dashboard, Agent Orchestrator, Resource Watcher, and Agent Tools.$(RESET)"
	@read -p "$(BOLD)Continue? [y/N] $(RESET)" confirm; \
	[[ $$confirm == [yY] || $$confirm == [yY][eE][sS] ]] || exit 1
	@$(MAKE) ollama
	@$(MAKE) langchain
	@$(MAKE) ai-dashboard
	@$(MAKE) agent-orchestrator
	@$(MAKE) resource-watcher
	@$(MAKE) ai-agent-tools
	@echo "$(GREEN)$(BOLD)✅ AI Suite installation complete!$(RESET)"
	@echo "$(CYAN)Run 'make ai-alpha-check' to verify the installation.$(RESET)"

## AI Alpha Check Targets
alpha-check:
	@echo "$(MAGENTA)$(BOLD)🔍 Running AgencyStack Alpha Check...$(RESET)"
	@bash $(SCRIPTS_DIR)/alpha_check.sh
	@echo ""
	@echo "$(BLUE)Check log file for detailed results:$(RESET)"
	@echo "$(BOLD)cat /var/log/agency_stack/alpha_check.log$(RESET)"

ui-alpha-check:
	@echo "$(MAGENTA)$(BOLD)🖥️ Running AgencyStack UI Alpha Check...$(RESET)"
	@echo "$(BLUE)Checking UI components and dashboard functionality...$(RESET)"
	@echo ""
	
	@echo "$(CYAN)Checking dashboard and UI components...$(RESET)"
	@if docker ps | grep -q "agency-dashboard"; then \
		echo "$(GREEN)✓ Dashboard container is running$(RESET)"; \
	else \
		echo "$(RED)❌ Dashboard container is not running$(RESET)"; \
	fi
	
	@echo "$(CYAN)Checking Traefik routes...$(RESET)"
	@if [ -f "/opt/agency_stack/traefik/rules/dashboard.yml" ]; then \
		echo "$(GREEN)✓ Dashboard routing is configured$(RESET)"; \
	else \
		echo "$(RED)❌ Dashboard routing is not configured$(RESET)"; \
	fi
	
	@echo "$(CYAN)Checking UI data sources...$(RESET)"
	@if [ -f "/opt/agency_stack/dashboard/data/dashboard_data.json" ]; then \
		echo "$(GREEN)✓ Dashboard data source exists$(RESET)"; \
	else \
		echo "$(RED)❌ Dashboard data source is missing$(RESET)"; \
	fi
	
	@echo "$(CYAN)Checking UI auth integration...$(RESET)"
	@if grep -q "auth_config" "/opt/agency_stack/dashboard/config/config.json" 2>/dev/null; then \
		echo "$(GREEN)✓ UI authentication is configured$(RESET)"; \
	else \
		echo "$(YELLOW)⚠️ UI authentication may not be configured$(RESET)"; \
	fi
	
	@echo ""
	@echo "$(BLUE)To open the dashboard:$(RESET)"
	@echo "$(BOLD)make dashboard-open$(RESET)"

ai-alpha-check:
	@echo "$(CYAN)This is a deprecated implementation. Using the consolidated version...$(RESET)"
	@$(MAKE) -f $(MAKEFILE_LIST) ai-alpha-check-consolidated

ai-alpha-check-consolidated:
	@echo "$(MAGENTA)$(BOLD)🔍 Running AI Alpha Readiness Check...$(RESET)"
	@echo "$(CYAN)Checking installed components...$(RESET)"
	@echo "-------------------------------------------"
	
	@echo "1. Checking Ollama..."
	@if [ -d "/opt/agency_stack/ollama" ]; then \
		echo "$(GREEN)✓ Ollama is installed$(RESET)"; \
	else \
		echo "$(RED)❌ Ollama is not installed$(RESET)"; \
	fi
	
	@echo "2. Checking LangChain..."
	@if [ -d "/opt/agency_stack/langchain" ]; then \
		echo "$(GREEN)✓ LangChain is installed$(RESET)"; \
	else \
		echo "$(RED)❌ LangChain is not installed$(RESET)"; \
	fi
	
	@echo "3. Checking AI Dashboard..."
	@if [ -d "/opt/agency_stack/ai_dashboard" ]; then \
		echo "$(GREEN)✓ AI Dashboard is installed$(RESET)"; \
	else \
		echo "$(RED)❌ AI Dashboard is not installed$(RESET)"; \
	fi
	
	@echo "4. Checking Agent Orchestrator..."
	@if [ -d "/opt/agency_stack/agent_orchestrator" ]; then \
		echo "$(GREEN)✓ Agent Orchestrator is installed$(RESET)"; \
	else \
		echo "$(RED)❌ Agent Orchestrator is not installed$(RESET)"; \
	fi
	
	@echo "5. Checking Resource Watcher..."
	@if [ -d "/opt/agency_stack/resource_watcher" ]; then \
		echo "$(GREEN)✓ Resource Watcher is installed$(RESET)"; \
	else \
		echo "$(RED)❌ Resource Watcher is not installed$(RESET)"; \
	fi
	
	@echo "6. Checking Agent Tools..."
	@if [ -d "/opt/agency_stack/agent_tools" ]; then \
		echo "$(GREEN)✓ Agent Tools are installed$(RESET)"; \
	else \
		echo "$(RED)❌ Agent Tools are not installed$(RESET)"; \
	fi
	
	@echo ""
	@echo "$(BLUE)To open the AI Dashboard:$(RESET)"
	@echo "$(BOLD)make ai-dashboard-test$(RESET)"

# Install all components in the correct order
install-all: prep-dirs env-check
	@echo "$(MAGENTA)$(BOLD)🚀 Installing Complete AgencyStack...$(RESET)"
	@echo "$(YELLOW)This will install all components in the proper order. This may take some time.$(RESET)"
	@read -p "$(BOLD)Continue? [y/N] $(RESET)" confirm; \
	[[ $$confirm == [yY] || $$confirm == [yY][eE][sS] ]] || exit 1
	
	@echo "$(CYAN)Step 1/7: Installing core infrastructure...$(RESET)"
	@$(MAKE) -f $(MAKEFILE_LIST) infrastructure
	@$(MAKE) -f $(MAKEFILE_LIST) traefik-ssl
	
	@echo "$(CYAN)Step 2/7: Installing security components...$(RESET)"
	@$(MAKE) -f $(MAKEFILE_LIST) security-infrastructure
	@$(MAKE) -f $(MAKEFILE_LIST) keycloak
	
	@echo "$(CYAN)Step 3/7: Installing monitoring stack...$(RESET)"
	@$(MAKE) -f $(MAKEFILE_LIST) prometheus
	@$(MAKE) -f $(MAKEFILE_LIST) grafana
	@$(MAKE) -f $(MAKEFILE_LIST) loki
	
	@echo "$(CYAN)Step 4/7: Installing core services...$(RESET)"
	@$(MAKE) -f $(MAKEFILE_LIST) mailu
	@$(MAKE) -f $(MAKEFILE_LIST) peertube
	@$(MAKE) -f $(MAKEFILE_LIST) wordpress
	
	@echo "$(CYAN)Step 5/7: Installing integration tools...$(RESET)"
	@$(MAKE) -f $(MAKEFILE_LIST) n8n
	@$(MAKE) -f $(MAKEFILE_LIST) openintegrationhub
	
	@echo "$(CYAN)Step 6/7: Installing AI components...$(RESET)"
	@$(MAKE) -f $(MAKEFILE_LIST) install-ai-suite
	
	@echo "$(CYAN)Step 7/7: Finalizing installation...$(RESET)"
	@$(MAKE) -f $(MAKEFILE_LIST) dashboard-update
	@$(MAKE) -f $(MAKEFILE_LIST) integrate-sso
	@$(MAKE) -f $(MAKEFILE_LIST) integrate-monitoring
	@$(MAKE) -f $(MAKEFILE_LIST) setup-log-rotation
	@$(MAKE) -f $(MAKEFILE_LIST) setup-cron
	
	@echo "$(GREEN)$(BOLD)✅ AgencyStack installation complete!$(RESET)"
	@echo "$(BLUE)Run 'make alpha-check' to verify all components are working correctly.$(RESET)"
	@echo "$(BLUE)Run 'make dashboard' to open the AgencyStack dashboard.$(RESET)"

# Docker Infrastructure Targets
docker: prep-dirs env-check
	@echo "$(MAGENTA)$(BOLD)🐳 Installing Docker...$(RESET)"
	@sudo $(SCRIPTS_DIR)/components/install_docker.sh $(if $(FORCE),--force,) \
		$(if $(CLIENT_ID),--client-id $(CLIENT_ID),) \
		$(if $(DOMAIN),--domain $(DOMAIN),)
	@. $(SCRIPTS_DIR)/utils/common.sh && log "INFO" "Docker installation completed via Makefile"
	@echo "$(GREEN)Docker installation complete$(RESET)"

docker-status:
	@echo "$(MAGENTA)$(BOLD)🔍 Checking Docker Status...$(RESET)"
	@if command -v docker &>/dev/null; then \
		echo "$(GREEN)✓ Docker installed: $(shell docker --version)$(RESET)"; \
		echo "$(CYAN)Runtime info:$(RESET)"; \
		docker info | grep -E "Server Version|OS/Arch|Containers|Images|Storage Driver|Logging Driver|Cgroup Driver|Swarm|Live Restore Enabled"; \
		echo ""; \
		echo "$(CYAN)Running containers:$(RESET)"; \
		docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"; \
	else \
		echo "$(RED)✗ Docker is not installed$(RESET)"; \
		echo "Run 'make docker' to install"; \
	fi

docker-logs:
	@echo "$(MAGENTA)$(BOLD)📋 Viewing Docker logs...$(RESET)"
	@if [ -f /var/log/agency_stack/components/docker.log ]; then \
		tail -n 50 /var/log/agency_stack/components/docker.log; \
	else \
		echo "$(YELLOW)Docker log file not found. Showing system logs instead:$(RESET)"; \
		journalctl -u docker -n 50; \
	fi
	@echo ""
	@echo "$(YELLOW)For more logs: $(RESET)journalctl -u docker"

docker-restart:
	@echo "$(MAGENTA)$(BOLD)🔄 Restarting Docker...$(RESET)"
	@echo "$(YELLOW)This will restart the Docker daemon and may temporarily disrupt running containers.$(RESET)"
	@. $(SCRIPTS_DIR)/utils/common.sh && confirm "Continue with restart?" || exit 0
	@sudo systemctl restart docker
	@echo "$(GREEN)Docker daemon restarted$(RESET)"
	@echo "$(CYAN)Status: $(RESET)$(shell systemctl is-active docker)"

# Docker Compose Targets
docker_compose: prep-dirs env-check
	@echo "$(MAGENTA)$(BOLD)🐙 Installing Docker Compose...$(RESET)"
	@sudo $(SCRIPTS_DIR)/components/install_docker_compose.sh $(if $(FORCE),--force,) \
		$(if $(CLIENT_ID),--client-id $(CLIENT_ID),) \
		$(if $(DOMAIN),--domain $(DOMAIN),) \
		$(if $(COMPOSE_VERSION),--compose-version $(COMPOSE_VERSION),)
	@. $(SCRIPTS_DIR)/utils/common.sh && log "INFO" "Docker Compose installation completed via Makefile"
	@echo "$(GREEN)Docker Compose installation complete$(RESET)"

docker_compose-status:
	@echo "$(MAGENTA)$(BOLD)🔍 Checking Docker Compose Status...$(RESET)"
	@if docker compose version &>/dev/null; then \
		echo "$(GREEN)✓ Docker Compose plugin installed: $(shell docker compose version --short)$(RESET)"; \
		echo ""; \
		echo "$(CYAN)Available Docker Compose configurations:$(RESET)"; \
		find /opt/agency_stack -name "docker-compose.yml" 2>/dev/null | sort || echo "No configurations found"; \
	elif command -v docker-compose &>/dev/null; then \
		echo "$(GREEN)✓ Docker Compose standalone installed: $(shell docker-compose --version | cut -d ' ' -f 3 | tr -d ',')$(RESET)"; \
		echo "$(YELLOW)Note: Using standalone version, not the Docker CLI plugin$(RESET)"; \
		echo ""; \
		echo "$(CYAN)Available Docker Compose configurations:$(RESET)"; \
		find /opt/agency_stack -name "docker-compose.yml" 2>/dev/null | sort || echo "No configurations found"; \
	else \
		echo "$(RED)✗ Docker Compose is not installed$(RESET)"; \
		echo "Run 'make docker_compose' to install"; \
	fi

docker_compose-logs:
	@echo "$(MAGENTA)$(BOLD)📋 Viewing Docker Compose logs...$(RESET)"
	@if [ -f /var/log/agency_stack/components/docker_compose.log ]; then \
		tail -n 50 /var/log/agency_stack/components/docker_compose.log; \
	else \
		echo "$(YELLOW)Docker Compose log file not found.$(RESET)"; \
	fi
	@echo ""
	@echo "$(YELLOW)For more logs: $(RESET)less /var/log/agency_stack/components/docker_compose.log"

docker_compose-restart:
	@echo "$(MAGENTA)$(BOLD)🔄 Restarting Docker Compose services...$(RESET)"
	@echo "$(YELLOW)This will restart all Docker Compose services in AgencyStack.$(RESET)"
	@. $(SCRIPTS_DIR)/utils/common.sh && confirm "Continue with restart?" || exit 0
	@echo "$(CYAN)Restarting services...$(RESET)"
	@for dir in $$(find /opt/agency_stack -name "docker-compose.yml" 2>/dev/null); do \
		echo "Restarting compose services in $$(dirname $$dir)"; \
		(cd $$(dirname $$dir) && docker compose restart); \
	done
	@echo "$(GREEN)Docker Compose services restarted$(RESET)"

# Setup utility targets
setup-dirs: prep-dirs
	@echo "$(MAGENTA)$(BOLD)🔧 Setting up component directories and placeholders...$(RESET)"
	@$(SCRIPTS_DIR)/utils/setup_component_directories.sh $(if $(CLIENT_ID),--client-id $(CLIENT_ID),) $(if $(VERBOSE),--verbose,)
	@echo "$(GREEN)Component directories and placeholders created$(RESET)"
	@echo "$(BLUE)This helps with alpha-check validation before components are installed$(RESET)"

setup-dirs-force: prep-dirs
	@echo "$(MAGENTA)$(BOLD)🔧 Forcibly setting up component directories and placeholders...$(RESET)"
	@$(SCRIPTS_DIR)/utils/setup_component_directories.sh $(if $(CLIENT_ID),--client-id $(CLIENT_ID),) --force $(if $(VERBOSE),--verbose,)
	@echo "$(GREEN)Component directories and placeholders forcibly recreated$(RESET)"
	@echo "$(BLUE)This helps with alpha-check validation before components are installed$(RESET)"
