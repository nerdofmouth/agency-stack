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

.PHONY: help install update client test-env clean backup stack-info talknerdy rootofmouth buddy-init buddy-monitor drone-setup generate-buddy-keys start-buddy-system enable-monitoring mailu-setup mailu-test-email logs health-check verify-dns setup-log-rotation monitoring-setup config-snapshot config-rollback config-diff verify-backup setup-cron test-alert integrate-keycloak test-operations motd audit integrate-components dashboard dashboard-refresh dashboard-enable dashboard-update dashboard-open integrate-sso integrate-email integrate-monitoring integrate-data-bridge detect-ports remap-ports scan-ports setup-cronjobs view-alerts log-summary

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
	@echo "$(GREEN)Visit https://stack.nerdofmouth.com for documentation$(RESET)"

# Install AgencyStack
install:
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
