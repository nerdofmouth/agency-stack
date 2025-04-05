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

.PHONY: help install update client test-env clean backup stack-info talknerdy rootofmouth buddy-init buddy-monitor drone-setup generate-buddy-keys start-buddy-system enable-monitoring mailu-setup mailu-test-email logs health-check verify-dns setup-log-rotation monitoring-setup config-snapshot config-rollback config-diff verify-backup setup-cron test-alert integrate-keycloak test-operations motd audit integrate-components dashboard dashboard-refresh dashboard-enable dashboard-update dashboard-open integrate-sso integrate-email integrate-monitoring integrate-data-bridge detect-ports remap-ports scan-ports setup-cronjobs view-alerts log-summary create-client setup-roles security-audit security-fix rotate-secrets setup-log-segmentation verify-certs verify-auth multi-tenancy-status install-wordpress install-erpnext install-posthog install-voip install-mailu install-grafana install-loki install-prometheus install-keycloak install-infrastructure install-security-infrastructure install-multi-tenancy validate validate-report peertube peertube-sso peertube-with-deps peertube-reinstall peertube-status peertube-logs peertube-stop peertube-start peertube-restart

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
	@echo "  $(BOLD)make audit$(RESET)            Audit running components and system status"
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
	@echo "📨 Sending test email via Mailu..."
	@sudo $(SCRIPTS_DIR)/mailu_test_email.sh

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
	@echo "Testing alert channels..."
	@sudo bash $(SCRIPTS_DIR)/test_alert.sh

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
audit:
	@echo "🔍 Auditing AgencyStack components..."
	@sudo bash $(SCRIPTS_DIR)/audit.sh

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

# Send test alert
test-alert:
	@echo "🔔 Sending test alert..."
	@sudo bash $(SCRIPTS_DIR)/notifications/notify_all.sh "Test Alert" "This is a test alert from AgencyStack on $(hostname) at $(date)"

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

multi-tenancy-status:
	@echo "🏢 Checking multi-tenancy status..."
	@sudo -E bash $(SCRIPTS_DIR)/security/check_multi_tenancy.sh

# Repository Audit and Cleanup Targets
# ------------------------------------------------------------------------------

audit:
	@echo "$(MAGENTA)$(BOLD)📊 Running AgencyStack Repository Audit...$(RESET)"
	@sudo $(CURDIR)/scripts/utils/audit_and_cleanup.sh

quick-audit:
	@echo "$(MAGENTA)$(BOLD)🔍 Running Quick AgencyStack Repository Audit...$(RESET)"
	@sudo $(CURDIR)/scripts/utils/audit_and_cleanup.sh --quick

reliable-audit:
	@echo "$(MAGENTA)$(BOLD)🔍 Running Reliable AgencyStack Repository Audit...$(RESET)"
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
	@curl -s http://localhost:9090/api/v1/alerts | jq . || echo "$(RED)Failed to fetch alerts. Is Prometheus running?$(RESET)"

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

# Content & Media Suite Components
# ------------------------------------------------------------------------------

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
