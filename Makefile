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

.PHONY: help install update client test-env clean backup stack-info talknerdy rootofmouth buddy-init buddy-monitor drone-setup generate-buddy-keys start-buddy-system enable-monitoring mailu-setup mailu-test-email logs health-check verify-dns setup-log-rotation monitoring-setup config-snapshot config-rollback config-diff verify-backup setup-cron test-alert integrate-keycloak test-operations motd audit integrate-components dashboard dashboard-refresh dashboard-enable dashboard-update dashboard-open integrate-sso integrate-email integrate-monitoring integrate-data-bridge detect-ports remap-ports scan-ports setup-cronjobs view-alerts log-summary create-client setup-roles security-audit security-fix rotate-secrets setup-log-segmentation verify-certs verify-auth multi-tenancy-status install-wordpress install-erpnext install-posthog install-voip install-mailu install-grafana install-loki install-prometheus install-keycloak install-infrastructure install-security-infrastructure install-multi-tenancy validate validate-report peertube peertube-sso peertube-with-deps peertube-reinstall peertube-status peertube-logs peertube-stop peertube-start peertube-restart demo-core demo-core-clean demo-core-status demo-core-logs

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
	@echo "  $(BOLD)make prerequisites$(RESET)            Install System Prerequisites"
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
	@echo "  $(BOLD)make peertube-upgrade$(RESET)         Upgrade PeerTube to v7.0"

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
		cat /opt/agency_stack/installed_components.txt | sort; \
	else \
		echo "$(RED)No components installed yet$(RESET)"; \
	fi
	@echo ""
	@echo "$(CYAN)$(BOLD)Running Containers:$(RESET)"
	@docker ps --format "table {{.Names}}\t{{.Status}}" 2>/dev/null || echo "$(RED)Docker not running$(RESET)"
	@echo ""
	@echo "$(YELLOW)$(BOLD)Port Allocations:$(RESET)"
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
	@echo "$(MAGENTA)$(BOLD)🔔 Testing alert channels...$(RESET)"
		sudo bash $(SCRIPTS_DIR)/notifications/notify_all.sh "Test Alert" "This is a test alert from AgencyStack on $(shell hostname) at $(shell date)"; \
	else \
		sudo bash $(SCRIPTS_DIR)/test_alert.sh; \
	fi
	@echo "$(GREEN)Test alerts have been sent.$(RESET)"

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
	@echo "$(MAGENTA)$(BOLD)📊 Running AgencyStack Repository Audit...$(RESET)"
		sudo $(SCRIPTS_DIR)/utils/audit_and_cleanup.sh; \
	else \
		sudo bash $(SCRIPTS_DIR)/audit.sh; \
	fi
	@echo "$(GREEN)Audit complete. Check logs for details.$(RESET)"

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
		tail -n 10 /var/log/agency_stack/health.log; \
	else \
		echo "No health logs found"; \
	fi
	@echo ""
	@echo "$(BOLD)Backup Logs:$(RESET)"
		tail -n 10 /var/log/agency_stack/backup.log; \
	else \
		echo "No backup logs found"; \
	fi
	@echo ""
	@echo "$(BOLD)Alert Logs:$(RESET)"
		tail -n 10 /var/log/agency_stack/alerts.log; \
	else \
		echo "No alert logs found"; \
	fi
	@echo ""
	@echo "For more details, run \`make logs\` or view the dashboard"

# Security and multi-tenancy commands
create-client:
	@echo "🏢 Creating new client..."
		echo "$(RED)Error: Missing required parameters.$(RESET)"; \
		echo "Usage: make create-client CLIENT_ID=name CLIENT_NAME=\"Full Name\" CLIENT_DOMAIN=domain.com"; \
		exit 1; \
	fi
	@sudo bash $(SCRIPTS_DIR)/create-client.sh "$(CLIENT_ID)" "$(CLIENT_NAME)" "$(CLIENT_DOMAIN)"

setup-roles:
	@echo "🔑 Setting up Keycloak roles for client..."
		echo "$(RED)Error: Missing required parameter CLIENT_ID.$(RESET)"; \
		echo "Usage: make setup-roles CLIENT_ID=name"; \
		exit 1; \
	fi
	@sudo bash $(SCRIPTS_DIR)/keycloak/setup_roles.sh "$(CLIENT_ID)"

security-audit:
	@echo "🔐 Running security audit..."
		sudo bash $(SCRIPTS_DIR)/security/audit_stack.sh --client-id "$(CLIENT_ID)"; \
	else \
		sudo bash $(SCRIPTS_DIR)/security/audit_stack.sh; \
	fi

security-fix:
	@echo "🔧 Fixing security issues..."
		sudo bash $(SCRIPTS_DIR)/security/audit_stack.sh --fix --client-id "$(CLIENT_ID)"; \
	else \
		sudo bash $(SCRIPTS_DIR)/security/audit_stack.sh --fix; \
	fi

rotate-secrets:
	@echo "🔄 Rotating secrets..."
		sudo bash $(SCRIPTS_DIR)/security/generate_secrets.sh --rotate --client-id "$(CLIENT_ID)" --service "$(SERVICE)"; \
		sudo bash $(SCRIPTS_DIR)/security/generate_secrets.sh --rotate --client-id "$(CLIENT_ID)"; \
	else \
		sudo bash $(SCRIPTS_DIR)/security/generate_secrets.sh --rotate; \
	fi

setup-log-segmentation:
	@echo "📋 Setting up log segmentation..."
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

cryptosync:
	@echo "$(MAGENTA)$(BOLD)🔒 Installing Cryptosync...$(RESET)"
	@sudo $(SCRIPTS_DIR)/components/install_cryptosync.sh $(if $(CLIENT_ID),--client-id $(CLIENT_ID),) \
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
		echo ""; \
		echo "$(MAGENTA)$(BOLD)📋 Last sync operations:$(RESET)"; \
		tail -n 20 $(CONFIG_DIR)/clients/$(CLIENT_ID)/cryptosync/logs/sync.log; \
	fi

# Repository Audit and Cleanup Targets
# ------------------------------------------------------------------------------

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
		cat /var/log/agency_stack/audit/summary_$$(date +%Y%m%d).txt; \
		cat /var/log/agency_stack/audit/usage_summary.txt; \
		cat /var/log/agency_stack/audit/quick_audit_$$(date +%Y%m%d).txt; \
		cat /var/log/agency_stack/audit/audit_report.log; \
	else \
		echo "$(RED)No audit report found. Run 'make audit' first.$(RESET)"; \
		echo "$(YELLOW)Try running the script usage analysis with 'make script-usage'$(RESET)"; \
	fi

cleanup:
	@echo "$(MAGENTA)$(BOLD)🧹 Running AgencyStack Repository Cleanup...$(RESET)"
	@read -p "$(YELLOW)This will clean up unused scripts and resources. Are you sure? (y/N):$(RESET) " confirm; \
		sudo $(CURDIR)/scripts/utils/audit_and_cleanup.sh --clean; \
	else \
		echo "$(YELLOW)Cleanup aborted.$(RESET)"; \
	fi

# Component Registry Management Targets
# ------------------------------------------------------------------------------

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

# Prerequisites Component
prerequisites: validate
	@echo "$(MAGENTA)$(BOLD)🔧 Installing System Prerequisites...$(RESET)"
	@sudo $(SCRIPTS_DIR)/components/install_prerequisites.sh $(if $(DOMAIN),--domain $(DOMAIN),) $(if $(ADMIN_EMAIL),--admin-email $(ADMIN_EMAIL),) $(if $(CLIENT_ID),--client-id $(CLIENT_ID),) $(if $(FORCE),--force,) $(if $(WITH_DEPS),--with-deps,) $(if $(VERBOSE),--verbose,)

prerequisites-status:
	@echo "$(MAGENTA)$(BOLD)ℹ️ Checking System Prerequisites Status...$(RESET)"

prerequisites-logs:
	@echo "$(MAGENTA)$(BOLD)📜 Viewing System Prerequisites Logs...$(RESET)"
	@ls -la /var/log/agency_stack/prerequisites-*.log 2>/dev/null || echo "$(YELLOW)No prerequisite installation logs found$(RESET)"
	@echo ""
	@for log in /var/log/agency_stack/prerequisites-*.log; do \
			echo "$(CYAN)Log file: $$log$(RESET)"; \
			tail -n 20 "$$log"; \
			echo ""; \
		fi; \
	done

prerequisites-restart:
	@echo "$(MAGENTA)$(BOLD)🔄 Reinstalling System Prerequisites...$(RESET)"
	@echo "$(YELLOW)Removing Prerequisites marker file...$(RESET)"
	@sudo rm -f /opt/agency_stack/.prerequisites_ok 
	@sudo $(SCRIPTS_DIR)/components/install_prerequisites.sh $(if $(DOMAIN),--domain $(DOMAIN),) $(if $(ADMIN_EMAIL),--admin-email $(ADMIN_EMAIL),) $(if $(CLIENT_ID),--client-id $(CLIENT_ID),) $(if $(FORCE),--force,) $(if $(WITH_DEPS),--with-deps,) $(if $(VERBOSE),--verbose,)

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
	@docker logs -f listmonk-app-$(CLIENT_ID) 2>&1 | tee $(LOG_DIR)/components/listmonk.log

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
	@tar -czf $(BACKUP_DIR)/listmonk/listmonk_storage_$(shell date +%Y%m%d).tar.gz -C $(CONFIG_DIR)/clients/$(CLIENT_ID)/listmonk_data/storage .
	@echo "Backup completed: $(BACKUP_DIR)/listmonk/"

listmonk-restore:
	@echo "Restoring Listmonk from backup is a manual process."
	@echo "Please refer to the documentation for detailed instructions."

listmonk-config:
	@echo "Opening Listmonk environment configuration..."
	@$(EDITOR) $(DOCKER_DIR)/listmonk/.env

listmonk-upgrade:
	@echo "$(MAGENTA)$(BOLD)🔄 Upgrading Listmonk to v4.1.0...$(RESET)"
	@read -p "$(YELLOW)Enter domain for Listmonk (e.g., mail.yourdomain.com):$(RESET) " DOMAIN; \
	read -p "$(YELLOW)Enter admin email:$(RESET) " ADMIN_EMAIL; \
	read -p "$(YELLOW)Enter client ID (optional):$(RESET) " CLIENT_ID; \
	sudo $(SCRIPTS_DIR)/components/upgrade_listmonk.sh --domain $$DOMAIN --admin-email $$ADMIN_EMAIL $(if $$CLIENT_ID,--client-id $$CLIENT_ID,) $(if $(FORCE),--force,) $(if $(WITH_DEPS),--with-deps,) $(if $(VERBOSE),--verbose,)

# Grafana
install-grafana: validate
	@echo "Installing Grafana monitoring..."
	@sudo $(SCRIPTS_DIR)/components/install_grafana.sh --domain $(DOMAIN) --admin-email $(ADMIN_EMAIL) $(if $(CLIENT_ID),--client-id $(CLIENT_ID),) $(if $(FORCE),--force,) $(if $(WITH_DEPS),--with-deps,) $(if $(VERBOSE),--verbose,)

# Loki
install-loki: validate
	@echo "Installing Loki log aggregation..."
	@sudo $(SCRIPTS_DIR)/components/install_loki.sh --domain logs.$(DOMAIN) $(if $(GRAFANA_DOMAIN),--grafana-domain $(GRAFANA_DOMAIN),--grafana-domain grafana.$(DOMAIN)) $(if $(CLIENT_ID),--client-id $(CLIENT_ID),) $(if $(FORCE),--force,) $(if $(WITH_DEPS),--with-deps,) $(if $(VERBOSE),--verbose,)

loki: validate
	@echo "$(MAGENTA)$(BOLD)📊 Installing Loki - Log Aggregation System...$(RESET)"
	@sudo $(SCRIPTS_DIR)/components/install_loki.sh --domain logs.$(DOMAIN) $(if $(GRAFANA_DOMAIN),--grafana-domain $(GRAFANA_DOMAIN),--grafana-domain grafana.$(DOMAIN)) $(if $(CLIENT_ID),--client-id $(CLIENT_ID),) $(if $(FORCE),--force,) $(if $(WITH_DEPS),--with-deps,) $(if $(VERBOSE),--verbose,)

loki-status:
	@echo "$(MAGENTA)$(BOLD)ℹ️ Checking Loki Status...$(RESET)"
	@if [ -n "$(CLIENT_ID)" ]; then \
		LOKI_CONTAINER="$(CLIENT_ID)_loki"; \
	else \
		SITE_NAME=$$(echo "$(DOMAIN)" | sed 's/\./_/g'); \
		LOKI_CONTAINER="loki_$${SITE_NAME}"; \
	fi; \
	if docker ps --format '{{.Names}}' | grep -q "$$LOKI_CONTAINER"; then \
		echo "$(GREEN)✅ Loki is running$(RESET)"; \
		docker ps --filter "name=$$LOKI_CONTAINER" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"; \
		echo ""; \
		if docker ps --format '{{.Names}}' | grep -q "$(CLIENT_ID)_promtail" || docker ps --format '{{.Names}}' | grep -q "promtail_$${SITE_NAME}"; then \
			echo "$(GREEN)✅ Promtail log collector is running$(RESET)"; \
			docker ps --filter "name=promtail" --format "table {{.Names}}\t{{.Status}}"; \
		else \
			echo "$(YELLOW)⚠️ Promtail log collector is not running$(RESET)"; \
		fi; \
	else \
		echo "$(RED)❌ Loki is not running$(RESET)"; \
		echo "$(CYAN)Install with: make loki DOMAIN=yourdomain.com$(RESET)"; \
	fi; \
	if [ -d "/opt/agency_stack/loki/$(DOMAIN)" ]; then \
		echo ""; \
		echo "$(CYAN)Configuration directory: /opt/agency_stack/loki/$(DOMAIN)$(RESET)"; \
	fi

loki-logs:
	@echo "$(MAGENTA)$(BOLD)📜 Viewing Loki Logs...$(RESET)"
	@if [ -n "$(CLIENT_ID)" ]; then \
		LOKI_CONTAINER="$(CLIENT_ID)_loki"; \
		PROMTAIL_CONTAINER="$(CLIENT_ID)_promtail"; \
	else \
		SITE_NAME=$$(echo "$(DOMAIN)" | sed 's/\./_/g'); \
		LOKI_CONTAINER="loki_$${SITE_NAME}"; \
		PROMTAIL_CONTAINER="promtail_$${SITE_NAME}"; \
	fi; \
	if docker ps --format '{{.Names}}' | grep -q "$$LOKI_CONTAINER"; then \
		echo "$(CYAN)====== Loki Server Logs ======$(RESET)"; \
		docker logs --tail 50 "$$LOKI_CONTAINER"; \
		echo ""; \
		if docker ps --format '{{.Names}}' | grep -q "$$PROMTAIL_CONTAINER"; then \
			echo "$(CYAN)====== Promtail Collector Logs ======$(RESET)"; \
			docker logs --tail 20 "$$PROMTAIL_CONTAINER"; \
		fi; \
	else \
		echo "$(RED)❌ Loki container is not running$(RESET)"; \
		if [ -f "/var/log/agency_stack/components/loki.log" ]; then \
			echo "$(CYAN)Installation logs:$(RESET)"; \
			tail -n 30 /var/log/agency_stack/components/loki.log; \
		fi; \
	fi

loki-restart:
	@echo "$(MAGENTA)$(BOLD)🔄 Restarting Loki...$(RESET)"
	@if [ -n "$(CLIENT_ID)" ]; then \
		LOKI_DIR="/opt/agency_stack/loki/$(DOMAIN)"; \
	else \
		LOKI_DIR="/opt/agency_stack/loki/$(DOMAIN)"; \
	fi; \
	if [ -d "$$LOKI_DIR" ] && [ -f "$$LOKI_DIR/docker-compose.yml" ]; then \
		echo "$(CYAN)Restarting Loki containers...$(RESET)"; \
		cd "$$LOKI_DIR" && docker-compose restart; \
		echo "$(GREEN)✅ Loki has been restarted$(RESET)"; \
		echo "$(CYAN)Check status with: make loki-status$(RESET)"; \
	else \
		echo "$(RED)❌ Loki configuration not found at $$LOKI_DIR$(RESET)"; \
		echo "$(CYAN)Install with: make loki DOMAIN=yourdomain.com$(RESET)"; \
	fi

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

chatwoot-upgrade:
	@echo "$(MAGENTA)$(BOLD)🔄 Upgrading Chatwoot to v4.1.0...$(RESET)"
	@read -p "$(YELLOW)Enter domain for Chatwoot (e.g., chat.yourdomain.com):$(RESET) " DOMAIN; \
	read -p "$(YELLOW)Enter admin email:$(RESET) " ADMIN_EMAIL; \
	read -p "$(YELLOW)Enter client ID (optional):$(RESET) " CLIENT_ID; \
	sudo $(SCRIPTS_DIR)/components/upgrade_chatwoot.sh --domain $$DOMAIN --admin-email $$ADMIN_EMAIL $(if $$CLIENT_ID,--client-id $$CLIENT_ID,) $(if $(FORCE),--force,) $(if $(WITH_DEPS),--with-deps,) $(if $(VERBOSE),--verbose,)

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

peertube-upgrade:
	@echo "$(MAGENTA)$(BOLD)🔄 Upgrading PeerTube to v7.0...$(RESET)"
	@read -p "$(YELLOW)Enter domain for PeerTube (e.g., peertube.yourdomain.com):$(RESET) " DOMAIN; \
	read -p "$(YELLOW)Enter admin email:$(RESET) " ADMIN_EMAIL; \
	read -p "$(YELLOW)Enter client ID (optional):$(RESET) " CLIENT_ID; \
	sudo $(SCRIPTS_DIR)/components/upgrade_peertube.sh --domain $$DOMAIN --admin-email $$ADMIN_EMAIL $(if $$CLIENT_ID,--client-id $$CLIENT_ID,) $(if $(FORCE),--force,) $(if $(WITH_DEPS),--with-deps,) $(if $(VERBOSE),--verbose,)

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

# DevOps Components
# ------------------------------------------------------------------------------

# Drone CI - Continuous Integration and Delivery Platform
droneci:
	@echo "Installing Drone CI..."
	@sudo $(SCRIPTS_DIR)/components/install_droneci.sh --domain $(DRONECI_DOMAIN) $(INSTALL_FLAGS)

droneci-status:
	@docker ps -a | grep drone || echo "Drone CI is not running"

droneci-logs:
	@docker logs -f drone-server-$(CLIENT_ID) 2>&1 | tee $(LOG_DIR)/components/droneci.log

droneci-runner-logs:
	@docker logs -f drone-runner-$(CLIENT_ID) 2>&1 | tee $(LOG_DIR)/components/droneci-runner.log

droneci-stop:
	@docker-compose -f $(DOCKER_DIR)/droneci/docker-compose.yml down

droneci-start:
	@docker-compose -f $(DOCKER_DIR)/droneci/docker-compose.yml up -d

droneci-restart:
	@docker-compose -f $(DOCKER_DIR)/droneci/docker-compose.yml restart

droneci-backup:
	@echo "Backing up Drone CI data..."
	@mkdir -p $(BACKUP_DIR)/droneci
	@$(CONFIG_DIR)/clients/$(CLIENT_ID)/droneci_data/scripts/backup.sh $(BACKUP_DIR)/droneci
	@echo "Backup completed: $(BACKUP_DIR)/droneci/"

droneci-config:
	@echo "Opening Drone CI configuration..."
	@$(EDITOR) $(DOCKER_DIR)/droneci/.env

droneci-upgrade:
	@echo "$(MAGENTA)$(BOLD)🔄 Upgrading DroneCI to v2.25.0...$(RESET)"
	@read -p "$(YELLOW)Enter domain for DroneCI (e.g., drone.yourdomain.com):$(RESET) " DOMAIN; \
	read -p "$(YELLOW)Enter admin email:$(RESET) " ADMIN_EMAIL; \
	read -p "$(YELLOW)Enter client ID (optional):$(RESET) " CLIENT_ID; \
	sudo $(SCRIPTS_DIR)/components/upgrade_droneci.sh --domain $$DOMAIN --admin-email $$ADMIN_EMAIL $(if $$CLIENT_ID,--client-id $$CLIENT_ID,) $(if $(FORCE),--force,) $(if $(WITH_DEPS),--with-deps,) $(if $(VERBOSE),--verbose,)

# Collaboration Components
# ------------------------------------------------------------------------------

# Etebase - Encrypted CalDAV/CardDAV Server
etebase:
	@echo "$(MAGENTA)$(BOLD)🗓️ Installing Etebase...$(RESET)"
	@sudo $(SCRIPTS_DIR)/components/install_etebase.sh $(if $(CLIENT_ID),--client-id $(CLIENT_ID),) \
		$(if $(DOMAIN),--domain $(DOMAIN),) \
		$(if $(PORT),--port $(PORT),) \
		$(if $(ADMIN_USER),--admin-user $(ADMIN_USER),) \
		$(if $(ADMIN_EMAIL),--admin-email $(ADMIN_EMAIL),) \
		$(if $(ADMIN_PASSWORD),--admin-password $(ADMIN_PASSWORD),) \
		$(if $(FORCE),--force,) \
		$(if $(WITH_DEPS),--with-deps,) \
		$(if $(NO_SSL),--no-ssl,) \
		$(if $(DISABLE_MONITORING),--disable-monitoring,)

etebase-status:
	@echo "$(MAGENTA)$(BOLD)ℹ️ Checking Etebase status...$(RESET)"
		$(CONFIG_DIR)/monitoring/scripts/check_etebase-$(CLIENT_ID).sh $(CLIENT_ID); \
	else \
		echo "$(RED)Monitoring script not found. Checking container status...$(RESET)"; \
		docker ps -a | grep etebase-$(CLIENT_ID) || echo "$(RED)Etebase container not found$(RESET)"; \
	fi

etebase-logs:
	@echo "$(MAGENTA)$(BOLD)📋 Viewing Etebase logs...$(RESET)"
	@docker logs -f etebase-$(CLIENT_ID) 2>&1 | tee $(LOG_DIR)/components/etebase.log

etebase-stop:
	@echo "$(MAGENTA)$(BOLD)🛑 Stopping Etebase...$(RESET)"
	@cd $(DOCKER_DIR)/etebase && docker-compose down

etebase-start:
	@echo "$(MAGENTA)$(BOLD)🚀 Starting Etebase...$(RESET)"
	@cd $(DOCKER_DIR)/etebase && docker-compose up -d

etebase-restart:
	@echo "$(MAGENTA)$(BOLD)🔄 Restarting Etebase...$(RESET)"
	@cd $(DOCKER_DIR)/etebase && docker-compose restart

etebase-backup:
	@echo "$(MAGENTA)$(BOLD)💾 Backing up Etebase data...$(RESET)"
	@$(CONFIG_DIR)/clients/$(CLIENT_ID)/etebase/scripts/backup.sh "$(CLIENT_ID)" "$(CONFIG_DIR)/backups/etebase"
	@echo "$(GREEN)Backup completed to: $(CONFIG_DIR)/backups/etebase$(RESET)"

etebase-config:
	@echo "$(MAGENTA)$(BOLD)⚙️ Opening Etebase configuration...$(RESET)"
	@$(EDITOR) $(CONFIG_DIR)/clients/$(CLIENT_ID)/etebase/config/credentials.env

# Database Components

# AI Foundation
.PHONY: ollama ollama-status ollama-logs ollama-stop ollama-start ollama-restart ollama-pull ollama-list ollama-test

ollama:
	@echo "Installing Ollama..."
	@mkdir -p /var/log/agency_stack/components/
	@bash scripts/components/install_ollama.sh $(ARGS)

ollama-status:
	@echo "Checking Ollama status..."
		/opt/agency_stack/monitoring/scripts/check_ollama-$(CLIENT_ID).sh $(CLIENT_ID); \
	else \
		echo "Ollama monitoring script not found. Please install Ollama first."; \
		exit 1; \
	fi

ollama-logs:
	@echo "Displaying Ollama logs..."
		cd /opt/agency_stack/docker/ollama && docker-compose logs --tail=100 -f; \
	else \
		echo "Ollama installation not found. Please install Ollama first."; \
		exit 1; \
	fi

ollama-stop:
	@echo "Stopping Ollama..."
		cd /opt/agency_stack/docker/ollama && docker-compose stop; \
	else \
		echo "Ollama installation not found. Please install Ollama first."; \
		exit 1; \
	fi

ollama-start:
	@echo "Starting Ollama..."
		cd /opt/agency_stack/docker/ollama && docker-compose start; \
	else \
		echo "Ollama installation not found. Please install Ollama first."; \
		exit 1; \
	fi

ollama-restart:
	@echo "Restarting Ollama..."
		cd /opt/agency_stack/docker/ollama && docker-compose restart; \
	else \
		echo "Ollama installation not found. Please install Ollama first."; \
		exit 1; \
	fi

ollama-pull:
	@echo "Pulling Ollama models..."
	@if command -v ollama-pull-models-$(CLIENT_ID) > /dev/null 2>&1; then \
		ollama-pull-models-$(CLIENT_ID); \
	else \
		echo "Ollama helper scripts not found. Please install Ollama first."; \
		exit 1; \
	fi

ollama-list:
	@echo "Listing Ollama models..."
	@if command -v ollama-list-models-$(CLIENT_ID) > /dev/null 2>&1; then \
		ollama-list-models-$(CLIENT_ID); \
	else \
		echo "Ollama helper scripts not found. Please install Ollama first."; \
		exit 1; \
	fi

ollama-test:
	@echo "Testing Ollama API..."
	@if command -v ollama-test-api-$(CLIENT_ID) > /dev/null 2>&1; then \
		ollama-test-api-$(CLIENT_ID) $(MODEL) "$(PROMPT)"; \
	else \
		echo "Ollama helper scripts not found. Please install Ollama first."; \
		exit 1; \
	fi

# LangChain
.PHONY: langchain langchain-status langchain-logs langchain-stop langchain-start langchain-restart langchain-test

langchain:
	@echo "Installing LangChain..."
	@mkdir -p /var/log/agency_stack/components/
	@bash scripts/components/install_langchain.sh $(ARGS)

langchain-status:
	@echo "Checking LangChain status..."
		/opt/agency_stack/monitoring/scripts/check_langchain-$(CLIENT_ID).sh $(CLIENT_ID); \
	else \
		echo "LangChain monitoring script not found. Please install LangChain first."; \
		exit 1; \
	fi

langchain-logs:
	@echo "Displaying LangChain logs..."
		cd /opt/agency_stack/docker/langchain && docker-compose logs --tail=100 -f; \
	else \
		echo "LangChain installation not found. Please install LangChain first."; \
		exit 1; \
	fi

langchain-stop:
	@echo "Stopping LangChain..."
		cd /opt/agency_stack/docker/langchain && docker-compose stop; \
	else \
		echo "LangChain installation not found. Please install LangChain first."; \
		exit 1; \
	fi

langchain-start:
	@echo "Starting LangChain..."
		cd /opt/agency_stack/docker/langchain && docker-compose start; \
	else \
		echo "LangChain installation not found. Please install LangChain first."; \
		exit 1; \
	fi

langchain-restart:
	@echo "Restarting LangChain..."
		cd /opt/agency_stack/docker/langchain && docker-compose restart; \
	else \
		echo "LangChain installation not found. Please install LangChain first."; \
		exit 1; \
	fi

langchain-test:
	@echo "Testing LangChain API..."
		PORT=$$(grep PORT /opt/agency_stack/docker/langchain/.env | cut -d= -f2); \
		curl -X POST http://localhost:$${PORT}/prompt \
			-H "Content-Type: application/json" \
			-d '{"template":"Tell me about {topic} in one sentence.","inputs":{"topic":"LangChain"}}'; \
	else \
		echo "LangChain installation not found. Please install LangChain first."; \
		exit 1; \
	fi

## AI Dashboard Targets
ai-dashboard:
	@echo "Installing AI Dashboard..."
	@./scripts/components/install_ai_dashboard.sh --client-id=$(CLIENT_ID) --domain=$(DOMAIN) $(AI_DASHBOARD_FLAGS)

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

# VM testing and deployment targets
.PHONY: vm-test vm-test-rich vm-test-component-% vm-test-component vm-test-report vm-deploy vm-shell

# Deploy local codebase to remote VM
vm-deploy:
		echo "$(RED)Error: REMOTE_VM_SSH environment variable not set$(RESET)"; \
		echo "$(YELLOW)Set it with: export REMOTE_VM_SSH=user@vm-hostname$(RESET)"; \
		exit 1; \
	fi
	@echo "$(MAGENTA)$(BOLD)🚀 Deploying AgencyStack to ${REMOTE_VM_SSH}...$(RESET)"
	@echo "$(CYAN)Creating necessary directories...$(RESET)"
	@ssh -o ConnectTimeout=10 -o BatchMode=no ${REMOTE_VM_SSH} "\
		mkdir -p /opt/agency_stack && \
		chown -R root:root /opt/agency_stack && \
		chmod -R 755 /opt/agency_stack"
	@echo "$(CYAN)Transferring files (this may take a moment)...$(RESET)"
	@tar czf - --exclude='.git' --exclude='node_modules' --exclude='*.tar.gz' . | \
		ssh -o ConnectTimeout=10 -o BatchMode=no ${REMOTE_VM_SSH} "\
		cd /opt/agency_stack && \
		tar xzf - && \
		chown -R root:root . && \
		chmod -R 755 ."
	@echo "$(GREEN)$(BOLD)✅ Deployment complete!$(RESET)"

# Open a shell on the remote VM
vm-shell:
		echo "$(RED)Error: REMOTE_VM_SSH environment variable not set$(RESET)"; \
		echo "$(YELLOW)Set it with: export REMOTE_VM_SSH=user@vm-hostname$(RESET)"; \
		exit 1; \
	fi
	@echo "$(MAGENTA)$(BOLD)🔌 Connecting to ${REMOTE_VM_SSH}...$(RESET)"
	@ssh -t -o ConnectTimeout=10 -o BatchMode=no ${REMOTE_VM_SSH} "cd /opt/agency_stack && export TERM=xterm-256color && bash"

# Run basic SSH connection test to VM
vm-test: 
		echo "$(RED)Error: REMOTE_VM_SSH environment variable not set$(RESET)"; \
		echo "$(YELLOW)Set it with: export REMOTE_VM_SSH=user@vm-hostname$(RESET)"; \
		exit 1; \
	fi
	@echo "$(MAGENTA)$(BOLD)🧪 Testing AgencyStack on remote VM: ${REMOTE_VM_SSH}$(RESET)"
	@echo "$(CYAN)Testing SSH connection...$(RESET)"
	@ssh -o ConnectTimeout=10 -o BatchMode=no ${REMOTE_VM_SSH} "echo Connected to \$$(hostname) successfully" || { \
		echo "$(RED)Failed to connect to remote VM$(RESET)"; \
		exit 1; \
	}
	@echo "$(GREEN)$(BOLD)✅ Remote VM connection successful!$(RESET)"
	@echo ""
	@echo "$(CYAN)Available remote testing commands:$(RESET)"
	@echo "  $(YELLOW)make vm-deploy$(RESET)             - Deploy current codebase to VM"
	@echo "  $(YELLOW)make vm-shell$(RESET)              - Open shell on the VM"
	@echo "  $(YELLOW)make vm-test-rich$(RESET)          - Run full test suite on VM"
	@echo "  $(YELLOW)make vm-test-component-NAME$(RESET) - Test specific component"
	@echo "  $(YELLOW)make vm-test-report$(RESET)        - Generate markdown test report"
	@echo ""
	@echo "$(CYAN)See docs/LOCAL_DEVELOPMENT.md for complete workflow$(RESET)"

# Run comprehensive tests on the VM
vm-test-rich: vm-deploy
	@echo "$(MAGENTA)$(BOLD)🧪 Running rich VM test for AgencyStack$(RESET)"
	@TERM=xterm-256color $(SCRIPTS_DIR)/utils/vm_test_report.sh --verbose all

# Component-specific VM testing (pattern-based target)
vm-test-component-%: vm-deploy
	@echo "$(MAGENTA)$(BOLD)🧪 Running rich VM test for component: $(CYAN)$*$(RESET)"
	@TERM=xterm-256color $(SCRIPTS_DIR)/utils/vm_test_report.sh --verbose $*

# Test specific component on remote VM with environment variable
vm-test-component:
		echo "$(RED)Error: REMOTE_VM_SSH environment variable not set$(RESET)"; \
		echo "$(YELLOW)Set it with: export REMOTE_VM_SSH=user@vm-hostname$(RESET)"; \
		exit 1; \
	fi
		echo "$(RED)Error: COMPONENT environment variable not set$(RESET)"; \
		echo "$(YELLOW)Set it with: export COMPONENT=component_name$(RESET)"; \
		exit 1; \
	fi
	@echo "$(MAGENTA)$(BOLD)🧪 Testing $(CYAN)$${COMPONENT}$(MAGENTA) on remote VM$(RESET)"
	@TERM=xterm-256color $(SCRIPTS_DIR)/utils/vm_test_report.sh --verbose "$${COMPONENT}"

# Generate markdown report for VM testing
vm-test-report:
		echo "$(RED)Error: REMOTE_VM_SSH environment variable not set$(RESET)"; \
		echo "$(YELLOW)Set it with: export REMOTE_VM_SSH=user@vm-hostname$(RESET)"; \
		exit 1; \
	fi
	@echo "$(MAGENTA)$(BOLD)📊 Generating test report for $(CYAN)$${COMPONENT:-all}$(MAGENTA) on remote VM$(RESET)"
	@TERM=xterm-256color $(SCRIPTS_DIR)/utils/vm_test_report.sh --markdown --verbose "$${COMPONENT:-all}"
	@echo "$(GREEN)Report generated: $(PWD)/vm_test_report.md$(RESET)"

# Display local/remote testing workflow
show-dev-workflow:
	@echo "$(MAGENTA)$(BOLD)🔍 AgencyStack Local/Remote Development Workflow$(RESET)"
	else \
		echo "$(RED)LOCAL_DEVELOPMENT.md file not found$(RESET)"; \
		echo "$(YELLOW)Run 'make alpha-fix --add-dev-docs' to create it$(RESET)"; \
	fi

# Alpha deployment validation
alpha-check:
	@echo "$(MAGENTA)$(BOLD)🧪 Running AgencyStack Alpha validation...$(RESET)"
	@echo "$(CYAN)Verifying all components against DevOps standards...$(RESET)"
	@$(SCRIPTS_DIR)/utils/validate_components.sh --report --verbose || true
	@echo ""
	@echo "$(CYAN)Summary from component validation:$(RESET)"
	@if [ -f "$(PWD)/component_validation_report.md" ]; then \
		cat $(PWD)/component_validation_report.md | grep -E "^✅|^❌|^⚠️" || echo "$(YELLOW)No status markers found in report$(RESET)"; \
	else \
		echo "$(YELLOW)No validation report generated$(RESET)"; \
	fi
	@echo ""
	
	@echo "$(CYAN)Checking for required directories and markers...$(RESET)"
	@mkdir -p $(CONFIG_DIR) $(LOG_DIR) 2>/dev/null || true
	@mkdir -p /opt/agency_stack/clients/${CLIENT_ID:-default} 2>/dev/null || true
	@touch $(CONFIG_DIR)/.installed_ok 2>/dev/null || true
	
	@echo "$(CYAN)Checking for port conflicts...$(RESET)"
	@if [ -f "$(SCRIPTS_DIR)/utils/port_conflict_detector.sh" ]; then \
		$(SCRIPTS_DIR)/utils/port_conflict_detector.sh --quiet || echo "$(YELLOW)⚠️ Port conflicts detected. Run 'make detect-ports' for details.$(RESET)"; \
	else \
		echo "$(YELLOW)⚠️ Port conflict detector not found. Skipping check.$(RESET)"; \
	fi
	
	@echo "$(CYAN)Running quick audit...$(RESET)"
	@if [ -f "$(SCRIPTS_DIR)/utils/quick_audit.sh" ]; then \
		$(SCRIPTS_DIR)/utils/quick_audit.sh || echo "$(YELLOW)⚠️ Quick audit detected issues. Check component logs.$(RESET)"; \
	else \
		echo "$(YELLOW)⚠️ Quick audit script not found. Skipping check.$(RESET)"; \
	fi
	
	@echo ""
	@echo "$(GREEN)$(BOLD)✅ Alpha validation complete!$(RESET)"
	@echo "$(CYAN)Review $(PWD)/component_validation_report.md for full details$(RESET)"
	@echo "$(CYAN)Run 'make alpha-fix' to attempt repairs for common issues$(RESET)"

# Attempt to automatically fix common issues
alpha-fix:
	@echo "$(MAGENTA)$(BOLD)🔧 Attempting to fix common issues...$(RESET)"
	@$(SCRIPTS_DIR)/utils/validate_components.sh --fix --report
	@echo "$(GREEN)Fixes attempted. Please run 'make alpha-check' again to verify.$(RESET)"

# Apply generated makefile targets
alpha-apply-targets:
	@echo "$(MAGENTA)$(BOLD)🔧 Applying generated Makefile targets...$(RESET)"
		echo "Found generated targets file. Merging..."; \
		cat $(PWD)/makefile_targets.generated >> $(PWD)/Makefile; \
		echo "$(GREEN)Applied all generated targets to Makefile$(RESET)"; \
	else \
		echo "$(YELLOW)No generated targets file found$(RESET)"; \
		echo "Run 'make alpha-fix' to generate targets first"; \
	fi

.PHONY: alpha-check alpha-fix alpha-apply-targets

# Tailscale mesh networking component
tailscale: validate
	@echo "Installing Tailscale mesh networking..."
	@sudo $(SCRIPTS_DIR)/components/install_tailscale.sh --domain $(DOMAIN) --admin-email $(ADMIN_EMAIL) $(if $(CLIENT_ID),--client-id $(CLIENT_ID),) $(if $(FORCE),--force,) $(if $(WITH_DEPS),--with-deps,) $(if $(VERBOSE),--verbose,)

tailscale-status:
	@echo "Checking Tailscale status..."
	@if systemctl is-active tailscaled > /dev/null 2>&1; then \
		echo "$(GREEN)✓ Tailscale daemon is running$(RESET)"; \
		echo ""; \
		echo "Network status:"; \
		tailscale status || true; \
		echo ""; \
		echo "IP addresses:"; \
		tailscale ip || true; \
	else \
		echo "$(RED)✗ Tailscale daemon is not running$(RESET)"; \
	fi

tailscale-logs:
	@echo "Viewing Tailscale logs..."
	@if [ -f "$(LOG_DIR)/components/tailscale.log" ]; then \
		echo "$(CYAN)Recent Tailscale actions:$(RESET)"; \
		sudo grep "Tailscale" /var/log/syslog | tail -n 20; \
		echo ""; \
		echo "$(CYAN)For installation logs, use:$(RESET)"; \
		echo "cat /var/log/agency_stack/components/tailscale.log"; \
	else \
		echo "$(YELLOW)Tailscale logs not found.$(RESET)"; \
		journalctl -u tailscaled -n 50; \
	fi

tailscale-restart:
	@echo "Restarting Tailscale..."
	@sudo systemctl restart tailscaled
	@sleep 2
	@systemctl is-active tailscaled > /dev/null 2>&1 && echo "$(GREEN)✓ Tailscale restarted successfully$(RESET)" || echo "$(RED)✗ Failed to restart Tailscale$(RESET)"

# builderio component targets
builderio:
	@echo "🔧 Installing builderio..."
	@$(SCRIPTS_DIR)/components/install_builderio.sh --domain $(DOMAIN) --admin-email $(ADMIN_EMAIL) $(if $(VERBOSE),--verbose,)

builderio-status:
	@echo "🔍 Checking builderio status..."
		$(SCRIPTS_DIR)/components/status_builderio.sh; \
	else \
		echo "Status script not found. Checking service..."; \
		systemctl status builderio 2>/dev/null || docker ps -a | grep builderio || echo "builderio status check not implemented"; \
	fi

builderio-logs:
	@echo "📜 Viewing builderio logs..."
		tail -n 50 "/var/log/agency_stack/components/builderio.log"; \
	else \
		echo "Log file not found. Trying alternative sources..."; \
		journalctl -u builderio 2>/dev/null || docker logs builderio-$(CLIENT_ID) 2>/dev/null || echo "No logs found for builderio"; \
	fi

builderio-restart:
	@echo "🔄 Restarting builderio..."
		$(SCRIPTS_DIR)/components/restart_builderio.sh; \
	else \
		echo "Restart script not found. Trying standard methods..."; \
		systemctl restart builderio 2>/dev/null || \
		docker restart builderio-$(CLIENT_ID) 2>/dev/null || \
		echo "builderio restart not implemented"; \
	fi

# calcom component targets
calcom:
	@echo "🔧 Installing calcom..."
	@$(SCRIPTS_DIR)/components/install_calcom.sh --domain $(DOMAIN) --admin-email $(ADMIN_EMAIL) $(if $(VERBOSE),--verbose,)

calcom-status:
	@echo "🔍 Checking calcom status..."
		$(SCRIPTS_DIR)/components/status_calcom.sh; \
	else \
		echo "Status script not found. Checking service..."; \
		systemctl status calcom 2>/dev/null || docker ps -a | grep calcom || echo "calcom status check not implemented"; \
	fi

calcom-logs:
	@echo "📜 Viewing calcom logs..."
		tail -n 50 "/var/log/agency_stack/components/calcom.log"; \
	else \
		echo "Log file not found. Trying alternative sources..."; \
		journalctl -u calcom 2>/dev/null || docker logs calcom-$(CLIENT_ID) 2>/dev/null || echo "No logs found for calcom"; \
	fi

calcom-restart:
	@echo "🔄 Restarting calcom..."
		$(SCRIPTS_DIR)/components/restart_calcom.sh; \
	else \
		echo "Restart script not found. Trying standard methods..."; \
		systemctl restart calcom 2>/dev/null || \
		docker restart calcom-$(CLIENT_ID) 2>/dev/null || \
		echo "calcom restart not implemented"; \
	fi

# Auto-generated target for portainer
portainer-logs:
	@echo "TODO: Implement portainer-logs"
	@exit 1

# Auto-generated target for portainer
portainer-restart:
	@echo "TODO: Implement portainer-restart"
	@exit 1

# Auto-generated target for seafile
seafile:
	@echo "TODO: Implement seafile"
	@exit 1

# Auto-generated target for seafile
seafile-status:
	@echo "TODO: Implement seafile-status"
	@exit 1

# Auto-generated target for seafile
seafile-logs:
	@echo "TODO: Implement seafile-logs"
	@exit 1

# Auto-generated target for seafile
seafile-restart:
	@echo "TODO: Implement seafile-restart"
	@exit 1

# Auto-generated target for traefik
traefik:
	@echo "TODO: Implement traefik"
	@exit 1

# Auto-generated target for traefik
traefik-status:
	@echo "TODO: Implement traefik-status"
	@exit 1

# Auto-generated target for traefik
traefik-logs:
	@echo "TODO: Implement traefik-logs"
	@exit 1

# Auto-generated target for traefik
traefik-restart:
	@echo "TODO: Implement traefik-restart"
	@exit 1

# Auto-generated target for vault
vault:
	@echo "TODO: Implement vault"
	@exit 1

# Auto-generated target for vault
vault-status:
	@echo "TODO: Implement vault-status"
	@exit 1

# Auto-generated target for vault
vault-logs:
	@echo "TODO: Implement vault-logs"
	@exit 1

# Auto-generated target for vault
vault-restart:
	@echo "TODO: Implement vault-restart"
	@exit 1

# Auto-generated target for wordpress
wordpress:
	@echo "TODO: Implement wordpress"
	@exit 1

# Auto-generated target for wordpress
wordpress-status:
	@echo "TODO: Implement wordpress-status"
	@exit 1

# Auto-generated target for wordpress
wordpress-logs:
	@echo "TODO: Implement wordpress-logs"
	@exit 1

# Auto-generated target for wordpress
wordpress-restart:
	@echo "TODO: Implement wordpress-restart"
	@exit 1


	@exit 1

	@exit 1

	@exit 1

	@exit 1

# Auto-generated target for Parsing
Parsing:
	@echo "TODO: Implement Parsing"
	@exit 1

# Auto-generated target for Parsing
Parsing-status:
	@echo "TODO: Implement Parsing-status"
	@exit 1

# Auto-generated target for Parsing
Parsing-logs:
	@echo "TODO: Implement Parsing-logs"
	@exit 1

# Auto-generated target for Parsing
Parsing-restart:
	@echo "TODO: Implement Parsing-restart"
	@exit 1

# Auto-generated target for component
component:
	@echo "TODO: Implement component"
	@exit 1

# Auto-generated target for component
component-logs:
	@echo "TODO: Implement component-logs"
	@exit 1

# Auto-generated target for component
component-restart:
	@echo "TODO: Implement component-restart"
	@exit 1

	@exit 1

	@exit 1

	@exit 1

	@exit 1

# Auto-generated target for /home/revelationx/CascadeProjects/foss-server-stack/config/registry/component_registry.json
/home/revelationx/CascadeProjects/foss-server-stack/config/registry/component-registry.json:
	@echo "TODO: Implement /home/revelationx/CascadeProjects/foss-server-stack/config/registry/component-registry.json"
	@exit 1

# Auto-generated target for /home/revelationx/CascadeProjects/foss-server-stack/config/registry/component_registry.json
/home/revelationx/CascadeProjects/foss-server-stack/config/registry/component-registry.json-status:
	@echo "TODO: Implement /home/revelationx/CascadeProjects/foss-server-stack/config/registry/component-registry.json-status"
	@exit 1

# Auto-generated target for /home/revelationx/CascadeProjects/foss-server-stack/config/registry/component_registry.json
/home/revelationx/CascadeProjects/foss-server-stack/config/registry/component-registry.json-logs:
	@echo "TODO: Implement /home/revelationx/CascadeProjects/foss-server-stack/config/registry/component-registry.json-logs"
	@exit 1

# Auto-generated target for /home/revelationx/CascadeProjects/foss-server-stack/config/registry/component_registry.json
/home/revelationx/CascadeProjects/foss-server-stack/config/registry/component-registry.json-restart:
	@echo "TODO: Implement /home/revelationx/CascadeProjects/foss-server-stack/config/registry/component-registry.json-restart"
	@exit 1

# Auto-generated target for crowdsec
crowdsec: validate
	@echo "$(MAGENTA)$(BOLD)🔒 Installing CrowdSec security automation...$(RESET)"
	@sudo $(SCRIPTS_DIR)/components/install_crowdsec.sh --domain $(DOMAIN) --admin-email $(ADMIN_EMAIL) $(if $(CLIENT_ID),--client-id $(CLIENT_ID),) $(if $(FORCE),--force,) $(if $(WITH_DEPS),--with-deps,) $(if $(VERBOSE),--verbose,)

crowdsec-status:
	@echo "$(MAGENTA)$(BOLD)ℹ️ Checking CrowdSec Status...$(RESET)"
	@if [ -f "/opt/agency_stack/clients/$(CLIENT_ID)/crowdsec/.installed" ]; then \
		echo "$(GREEN)✅ CrowdSec is installed$(RESET)"; \
		if docker ps | grep -q "crowdsec_$(CLIENT_ID)"; then \
			echo "$(GREEN)✅ CrowdSec container is running$(RESET)"; \
		else \
			echo "$(RED)❌ CrowdSec container is not running$(RESET)"; \
		fi; \
		if docker ps | grep -q "crowdsec-traefik-bouncer_$(CLIENT_ID)"; then \
			echo "$(GREEN)✅ CrowdSec Traefik bouncer is running$(RESET)"; \
		else \
			echo "$(RED)❌ CrowdSec Traefik bouncer is not running$(RESET)"; \
		fi; \
		if docker ps | grep -q "crowdsec-dashboard_$(CLIENT_ID)"; then \
			echo "$(GREEN)✅ CrowdSec dashboard is running$(RESET)"; \
		else \
			echo "$(RED)❌ CrowdSec dashboard is not running$(RESET)"; \
		fi; \
	else \
		echo "$(RED)❌ CrowdSec is not installed$(RESET)"; \
		echo "$(CYAN)Install with: make crowdsec$(RESET)"; \
	fi

crowdsec-logs:
	@echo "$(MAGENTA)$(BOLD)📜 Viewing CrowdSec Logs...$(RESET)"
	@if [ -f "/var/log/agency_stack/components/crowdsec.log" ]; then \
		echo "$(CYAN)Recent CrowdSec installation logs:$(RESET)"; \
		sudo tail -n 30 /var/log/agency_stack/components/crowdsec.log; \
		echo ""; \
		echo "$(CYAN)For container logs, use:$(RESET)"; \
		echo "docker logs crowdsec_$(CLIENT_ID)"; \
		echo "docker logs crowdsec-traefik-bouncer_$(CLIENT_ID)"; \
	else \
		echo "$(YELLOW)CrowdSec logs not found.$(RESET)"; \
		docker logs crowdsec_$(CLIENT_ID) 2>/dev/null || echo "$(RED)CrowdSec container logs not available.$(RESET)"; \
	fi

crowdsec-restart:
	@echo "$(MAGENTA)$(BOLD)🔄 Restarting CrowdSec...$(RESET)"
	@if [ -f "/opt/agency_stack/clients/$(CLIENT_ID)/crowdsec/.installed" ]; then \
		cd /opt/agency_stack/clients/$(CLIENT_ID)/crowdsec && sudo docker-compose restart; \
		echo "$(GREEN)✅ CrowdSec has been restarted$(RESET)"; \
		echo "$(CYAN)Check status with: make crowdsec-status$(RESET)"; \
	else \
		echo "$(RED)❌ CrowdSec is not installed$(RESET)"; \
		echo "$(CYAN)Install with: make crowdsec$(RESET)"; \
	fi

# Auto-generated target for cryptosync
cryptosync-restart:
	@echo "TODO: Implement cryptosync-restart"
	@exit 1

# Auto-generated target for documenso
documenso-status:
	@echo "TODO: Implement documenso-status"
	@exit 1

# Auto-generated target for documenso
documenso-logs:
	@echo "TODO: Implement documenso-logs"
	@exit 1

# Auto-generated target for documenso
documenso-restart:
	@echo "$(MAGENTA)$(BOLD)🔄 Restarting Documenso...$(RESET)"
	@cd $(DOCKER_DIR)/documenso && docker-compose restart

documenso-upgrade:
	@echo "$(MAGENTA)$(BOLD)🔄 Upgrading Documenso to v1.4.2...$(RESET)"
	@read -p "$(YELLOW)Enter domain for Documenso (e.g., sign.yourdomain.com):$(RESET) " DOMAIN; \
	read -p "$(YELLOW)Enter admin email:$(RESET) " ADMIN_EMAIL; \
	read -p "$(YELLOW)Enter client ID (optional):$(RESET) " CLIENT_ID; \
	sudo $(SCRIPTS_DIR)/components/upgrade_documenso.sh --domain $$DOMAIN --admin-email $$ADMIN_EMAIL $(if $$CLIENT_ID,--client-id $$CLIENT_ID,) $(if $(FORCE),--force,) $(if $(WITH_DEPS),--with-deps,) $(if $(VERBOSE),--verbose,)

# erpnext
erpnext:
	@echo "TODO: Implement erpnext"
	@exit 1

# Auto-generated target for erpnext
erpnext-status:
	@echo "TODO: Implement erpnext-status"
	@exit 1

# Auto-generated target for erpnext
erpnext-logs:
	@echo "TODO: Implement erpnext-logs"
	@exit 1

# Auto-generated target for erpnext
erpnext-restart:
	@echo "TODO: Implement erpnext-restart"
	@exit 1

# Auto-generated target for focalboard
focalboard:
	@echo "TODO: Implement focalboard"
	@exit 1

# Auto-generated target for focalboard
focalboard-status:
	@echo "TODO: Implement focalboard-status"
	@exit 1

# Auto-generated target for focalboard
focalboard-logs:
	@echo "TODO: Implement focalboard-logs"
	@exit 1

# Auto-generated target for focalboard
focalboard-restart:
	@echo "TODO: Implement focalboard-restart"
	@exit 1

# Auto-generated target for ghost
ghost:
	@echo "TODO: Implement ghost"
	@exit 1

# Auto-generated target for ghost
ghost-status:
	@echo "TODO: Implement ghost-status"
	@exit 1

# Auto-generated target for ghost
ghost-logs:
	@echo "TODO: Implement ghost-logs"
	@exit 1

# Auto-generated target for ghost
ghost-restart:
	@echo "TODO: Implement ghost-restart"
	@exit 1

# Auto-generated target for gitea
gitea:
	@echo "TODO: Implement gitea"
	@exit 1

# Auto-generated target for gitea
gitea-status:
	@echo "TODO: Implement gitea-status"
	@exit 1

# Auto-generated target for gitea
gitea-logs:
	@echo "TODO: Implement gitea-logs"
	@exit 1

# Auto-generated target for gitea
gitea-restart:
	@echo "TODO: Implement gitea-restart"
	@exit 1

# Auto-generated target for grafana
grafana:
	@echo "TODO: Implement grafana"
	@exit 1

# Auto-generated target for grafana
grafana-status:
	@echo "TODO: Implement grafana-status"
	@exit 1

# Auto-generated target for grafana
grafana-logs:
	@echo "TODO: Implement grafana-logs"
	@exit 1

# Auto-generated target for grafana
grafana-restart:
	@echo "TODO: Implement grafana-restart"
	@exit 1

# Auto-generated target for keycloak
keycloak:
	@echo "TODO: Implement keycloak"
	@exit 1

# Auto-generated target for keycloak
keycloak-status:
	@echo "TODO: Implement keycloak-status"
	@exit 1

# Auto-generated target for keycloak
keycloak-logs:
	@echo "TODO: Implement keycloak-logs"
	@exit 1

# Auto-generated target for keycloak
keycloak-restart:
	@echo "TODO: Implement keycloak-restart"
	@exit 1

# Auto-generated target for killbill
killbill-status:
	@echo "TODO: Implement killbill-status"
	@exit 1

# Auto-generated target for killbill
killbill-logs:
	@echo "TODO: Implement killbill-logs"
	@exit 1

# Auto-generated target for killbill
killbill-restart:
	@echo "TODO: Implement killbill-restart"
	@exit 1

	@exit 1

# Auto-generated target for mailu
mailu:
	@echo "TODO: Implement mailu"
	@exit 1

# Auto-generated target for mailu
mailu-status:
	@echo "TODO: Implement mailu-status"
	@exit 1

# Auto-generated target for mailu
mailu-logs:
	@echo "TODO: Implement mailu-logs"
	@exit 1

# Auto-generated target for mailu
mailu-restart:
	@echo "TODO: Implement mailu-restart"
	@exit 1

# Auto-generated target for mattermost
mattermost:
	@echo "TODO: Implement mattermost"
	@exit 1

# Auto-generated target for mattermost
mattermost-status:
	@echo "TODO: Implement mattermost-status"
	@exit 1

# Auto-generated target for mattermost
mattermost-logs:
	@echo "TODO: Implement mattermost-logs"
	@exit 1

# Auto-generated target for mattermost
mattermost-restart:
	@echo "TODO: Implement mattermost-restart"
	@exit 1

# Auto-generated target for portainer
portainer:
	@echo "TODO: Implement portainer"
	@exit 1

# Auto-generated target for portainer
portainer-status:
	@echo "TODO: Implement portainer-status"
	@exit 1

vm-fault-inject:
	@echo "Injecting fault into VM for recovery testing..."
	@scripts/utils/fault_inject.sh $(FAULT_TYPE)

vm-snapshot:
	@echo "Preparing VM for snapshot..."
	@sudo scripts/release/prepare_vm_snapshot.sh

# Target to run smoke tests for high-risk components
smoke-test:
	@echo "Running smoke tests for high-risk components..."
	@scripts/smoke/smoke_test_high_risk.sh || { \
		echo "Note: Some components failed validation. Full details in /var/log/agency_stack/smoke_test.log"; \
		echo "To test ALL components including Mailu and Tailscale, use: make smoke-test-all"; \
		echo "To test a specific component: make smoke-test COMPONENT=<component>"; \
	}

# Target to run ALL smoke tests including optional components
smoke-test-all:
	@echo "Running ALL smoke tests including optional components..."
	@scripts/smoke/smoke_test_high_risk.sh --test-all || { \
		echo "Some components failed validation. See /var/log/agency_stack/smoke_test.log for details."; \
	}

# Backup Strategy
backup-strategy: validate
	@echo "$(MAGENTA)$(BOLD)💾 Installing Backup Strategy (Restic)...$(RESET)"
	@sudo $(SCRIPTS_DIR)/components/install_backup_strategy.sh --domain $(DOMAIN) --admin-email $(ADMIN_EMAIL) $(if $(CLIENT_ID),--client-id $(CLIENT_ID),) $(if $(FORCE),--force,) $(if $(WITH_DEPS),--with-deps,) $(if $(VERBOSE),--verbose,) $(if $(TEST_MODE),--test-mode,)

backup-strategy-status:
	@echo "$(MAGENTA)$(BOLD)ℹ️ Checking Backup Strategy Status...$(RESET)"
	@if [ -f "/opt/agency_stack/backup_strategy/.installed_ok" ]; then \
		echo "$(GREEN)✅ Backup Strategy is installed$(RESET)"; \
		if [ -f "/etc/cron.d/agency-stack-backup-$(CLIENT_ID)" ]; then \
			echo "$(GREEN)✅ Backup cron job is configured$(RESET)"; \
		else \
			echo "$(RED)❌ Backup cron job is not configured$(RESET)"; \
		fi; \
	else \
		echo "$(RED)❌ Backup Strategy is not installed$(RESET)"; \
	fi
	@echo "$(CYAN)Logs can be viewed with: make backup-strategy-logs$(RESET)"

backup-strategy-logs:
	@echo "$(MAGENTA)$(BOLD)📜 Viewing Backup Strategy Logs...$(RESET)"
	@if [ -d "/opt/agency_stack/clients/$(CLIENT_ID)/backup_strategy/logs" ]; then \
		ls -lat /opt/agency_stack/clients/$(CLIENT_ID)/backup_strategy/logs/ | head -n 5; \
		echo ""; \
		if [ -n "$$(ls -A /opt/agency_stack/clients/$(CLIENT_ID)/backup_strategy/logs/ 2>/dev/null)" ]; then \
			echo "$(CYAN)Latest log:$(RESET)"; \
			cat "$$(ls -t /opt/agency_stack/clients/$(CLIENT_ID)/backup_strategy/logs/* | head -n 1)"; \
		else \
			echo "$(YELLOW)No backup logs found yet.$(RESET)"; \
		fi \
	else \
		cat /var/log/agency_stack/components/backup_strategy.log | tail -n 20; \
	fi

backup-strategy-restart:
	@echo "$(MAGENTA)$(BOLD)🔄 Running Backup Strategy...$(RESET)"
	@if [ -f "/opt/agency_stack/clients/$(CLIENT_ID)/backup_strategy/scripts/backup.sh" ]; then \
		sudo /opt/agency_stack/clients/$(CLIENT_ID)/backup_strategy/scripts/backup.sh; \
	else \
		echo "$(RED)Backup script not found. Is Backup Strategy installed?$(RESET)"; \
		echo "$(CYAN)Install with: make backup-strategy$(RESET)"; \
	fi

# Signing Timestamps
signing-timestamps: validate
	@echo "$(MAGENTA)$(BOLD)🔏 Installing Signing & Timestamps...$(RESET)"
	@sudo $(SCRIPTS_DIR)/components/install_signing_timestamps.sh --domain $(DOMAIN) --admin-email $(ADMIN_EMAIL) $(if $(CLIENT_ID),--client-id $(CLIENT_ID),) $(if $(FORCE),--force,) $(if $(WITH_DEPS),--with-deps,) $(if $(VERBOSE),--verbose,) $(if $(TEST_MODE),--test-mode,)

signing-timestamps-status:
	@echo "$(MAGENTA)$(BOLD)ℹ️ Checking Signing & Timestamps Status...$(RESET)"
	@if [ -f "/opt/agency_stack/signing_timestamps/.installed_ok" ]; then \
		echo "$(GREEN)✅ Signing & Timestamps is installed$(RESET)"; \
		if [ -f "/opt/agency_stack/clients/$(CLIENT_ID)/signing_timestamps/server-public-key.asc" ]; then \
			echo "$(GREEN)✅ Server signing key is configured$(RESET)"; \
			echo "$(CYAN)Key fingerprint:$(RESET)"; \
			cat /opt/agency_stack/clients/$(CLIENT_ID)/signing_timestamps/server-key-fingerprint.txt | grep -A 1 "Key fingerprint"; \
		else \
			echo "$(YELLOW)⚠️ Server signing key is not yet generated$(RESET)"; \
			echo "$(CYAN)Run: sudo /opt/agency_stack/clients/$(CLIENT_ID)/signing_timestamps/scripts/generate-server-key.sh$(RESET)"; \
		fi; \
	else \
		echo "$(RED)❌ Signing & Timestamps is not installed$(RESET)"; \
	fi
	@echo "$(CYAN)Logs can be viewed with: make signing-timestamps-logs$(RESET)"

signing-timestamps-logs:
	@echo "$(MAGENTA)$(BOLD)📜 Viewing Signing & Timestamps Logs...$(RESET)"
	@if [ -d "/opt/agency_stack/clients/$(CLIENT_ID)/signing_timestamps/logs" ]; then \
		ls -lat /opt/agency_stack/clients/$(CLIENT_ID)/signing_timestamps/logs/ | head -n 5; \
		echo ""; \
		if [ -n "$$(ls -A /opt/agency_stack/clients/$(CLIENT_ID)/signing_timestamps/logs/ 2>/dev/null)" ]; then \
			echo "$(CYAN)Latest log:$(RESET)"; \
			cat "$$(ls -t /opt/agency_stack/clients/$(CLIENT_ID)/signing_timestamps/logs/* | head -n 1)"; \
		else \
			echo "$(YELLOW)No signing logs found yet.$(RESET)"; \
		fi \
	else \
		cat /var/log/agency_stack/components/signing_timestamps.log | tail -n 20; \
	fi

signing-timestamps-restart:
	@echo "$(MAGENTA)$(BOLD)🔄 Regenerating Signing Keys...$(RESET)"
	@if [ -f "/opt/agency_stack/clients/$(CLIENT_ID)/signing_timestamps/scripts/generate-server-key.sh" ]; then \
		sudo /opt/agency_stack/clients/$(CLIENT_ID)/signing_timestamps/scripts/generate-server-key.sh; \
	else \
		echo "$(RED)Scripts not found. Is Signing & Timestamps installed?$(RESET)"; \
		echo "$(CYAN)Install with: make signing-timestamps$(RESET)"; \
	fi

# Docker
docker: validate
	@echo "$(MAGENTA)$(BOLD)🐳 Installing Docker Container Runtime...$(RESET)"
	@sudo $(SCRIPTS_DIR)/components/install_docker.sh --domain $(DOMAIN) --admin-email $(ADMIN_EMAIL) $(if $(CLIENT_ID),--client-id $(CLIENT_ID),) $(if $(FORCE),--force,) $(if $(WITH_DEPS),--with-deps,) $(if $(VERBOSE),--verbose,) $(if $(TEST_MODE),--test-mode,)

docker-status:
	@echo "$(MAGENTA)$(BOLD)ℹ️ Checking Docker Status...$(RESET)"
	@if command -v docker &> /dev/null; then \
		echo "$(GREEN)✅ Docker is installed$(RESET)"; \
		echo "$(CYAN)Version: $(shell docker --version)$(RESET)"; \
		echo "$(CYAN)Running containers: $(shell docker ps --format '{{.Names}}' | wc -l)$(RESET)"; \
		if docker network inspect agency_stack_network &> /dev/null; then \
			echo "$(GREEN)✅ AgencyStack Docker network is configured$(RESET)"; \
		else \
			echo "$(RED)❌ AgencyStack Docker network is missing$(RESET)"; \
			echo "$(CYAN)Create with: docker network create agency_stack_network$(RESET)"; \
		fi; \
	else \
		echo "$(RED)❌ Docker is not installed$(RESET)"; \
		echo "$(CYAN)Install with: make docker$(RESET)"; \
	fi

docker-logs:
	@echo "$(MAGENTA)$(BOLD)📜 Viewing Docker Logs...$(RESET)"
	@if [ -f "/var/log/agency_stack/components/docker.log" ]; then \
		cat /var/log/agency_stack/components/docker.log | tail -n 30; \
	else \
		echo "$(YELLOW)Docker installation logs not found.$(RESET)"; \
		if command -v docker &> /dev/null; then \
			echo "$(CYAN)Docker system logs:$(RESET)"; \
			journalctl -u docker --no-pager | tail -n 20; \
		fi; \
	fi

docker-restart:
	@echo "$(MAGENTA)$(BOLD)🔄 Restarting Docker Service...$(RESET)"
	@if systemctl is-active docker &> /dev/null; then \
		sudo systemctl restart docker; \
		echo "$(GREEN)✅ Docker service restarted$(RESET)"; \
	else \
		echo "$(RED)❌ Docker service is not running$(RESET)"; \
		sudo systemctl start docker; \
		echo "$(GREEN)✅ Docker service started$(RESET)"; \
	fi

# Docker Compose
docker-compose: validate
	@echo "$(MAGENTA)$(BOLD)🐙 Installing Docker Compose...$(RESET)"
	@sudo $(SCRIPTS_DIR)/components/install_docker_compose.sh --domain $(DOMAIN) --admin-email $(ADMIN_EMAIL) $(if $(CLIENT_ID),--client-id $(CLIENT_ID),) $(if $(FORCE),--force,) $(if $(WITH_DEPS),--with-deps,) $(if $(VERBOSE),--verbose,) $(if $(TEST_MODE),--test-mode,)

docker-compose-status:
	@echo "$(MAGENTA)$(BOLD)ℹ️ Checking Docker Compose Status...$(RESET)"
	@if command -v docker-compose &> /dev/null; then \
		echo "$(GREEN)✅ Docker Compose is installed$(RESET)"; \
		echo "$(CYAN)Version: $(shell docker-compose --version)$(RESET)"; \
		if [ -f "/opt/agency_stack/docker_compose/version.txt" ]; then \
			echo "$(CYAN)Installed version: $(shell cat /opt/agency_stack/docker_compose/version.txt)$(RESET)"; \
		fi; \
	else \
		echo "$(RED)❌ Docker Compose is not installed$(RESET)"; \
		echo "$(CYAN)Install with: make docker-compose$(RESET)"; \
	fi

docker-compose-logs:
	@echo "$(MAGENTA)$(BOLD)📜 Viewing Docker Compose Logs...$(RESET)"
	@if [ -f "/var/log/agency_stack/components/docker_compose.log" ]; then \
		cat /var/log/agency_stack/components/docker_compose.log | tail -n 30; \
	else \
		echo "$(YELLOW)Docker Compose installation logs not found.$(RESET)"; \
	fi

docker-compose-restart:
	@echo "$(MAGENTA)$(BOLD)🧪 Testing Docker Compose...$(RESET)"
	@if [ -f "/opt/agency_stack/clients/$(CLIENT_ID)/docker_compose/test-docker-compose.sh" ]; then \
		sudo /opt/agency_stack/clients/$(CLIENT_ID)/docker_compose/test-docker-compose.sh; \
	else \
		echo "$(RED)❌ Test script not found. Is Docker Compose installed?$(RESET)"; \
		echo "$(CYAN)Install with: make docker-compose$(RESET)"; \
	fi

# Fail2ban
fail2ban: validate
	@echo "$(MAGENTA)$(BOLD)🔒 Installing Fail2ban Intrusion Prevention...$(RESET)"
	@sudo $(SCRIPTS_DIR)/components/install_fail2ban.sh --domain $(DOMAIN) --admin-email $(ADMIN_EMAIL) $(if $(CLIENT_ID),--client-id $(CLIENT_ID),) $(if $(FORCE),--force,) $(if $(WITH_DEPS),--with-deps,) $(if $(VERBOSE),--verbose,) $(if $(TEST_MODE),--test-mode,)

fail2ban-status:
	@echo "$(MAGENTA)$(BOLD)ℹ️ Checking Fail2ban Status...$(RESET)"
	@if command -v fail2ban-server &> /dev/null && systemctl is-active --quiet fail2ban; then \
		echo "$(GREEN)✅ Fail2ban is installed and running$(RESET)"; \
		if [ -f "/opt/agency_stack/clients/$(CLIENT_ID)/fail2ban/fail2ban-status.sh" ]; then \
			sudo /opt/agency_stack/clients/$(CLIENT_ID)/fail2ban/fail2ban-status.sh; \
		else \
			echo "$(CYAN)Active jails:$(RESET)"; \
			sudo fail2ban-client status | grep -v "Status:" | grep ALLOW; \
		fi; \
	else \
		echo "$(RED)❌ Fail2ban is not running$(RESET)"; \
		echo "$(CYAN)Install with: make fail2ban$(RESET)"; \
	fi

fail2ban-logs:
	@echo "$(MAGENTA)$(BOLD)📜 Viewing Fail2ban Logs...$(RESET)"
	@if [ -f "/var/log/fail2ban.log" ]; then \
		echo "$(CYAN)Recent Fail2ban actions:$(RESET)"; \
		sudo grep "Ban\|Unban" /var/log/fail2ban.log | tail -n 20; \
		echo ""; \
		echo "$(CYAN)For installation logs, use:$(RESET)"; \
		echo "cat /var/log/agency_stack/components/fail2ban.log"; \
	else \
		echo "$(YELLOW)Fail2ban logs not found.$(RESET)"; \
		if [ -f "/var/log/agency_stack/components/fail2ban.log" ]; then \
			cat /var/log/agency_stack/components/fail2ban.log | tail -n 20; \
		fi; \
	fi

fail2ban-restart:
	@echo "$(MAGENTA)$(BOLD)🔄 Restarting Fail2ban Service...$(RESET)"
	@if systemctl is-active fail2ban &> /dev/null; then \
		sudo systemctl restart fail2ban; \
		echo "$(GREEN)✅ Fail2ban service restarted$(RESET)"; \
	else \
		echo "$(RED)❌ Fail2ban service is not running$(RESET)"; \
		sudo systemctl start fail2ban; \
		echo "$(GREEN)✅ Fail2ban service started$(RESET)"; \
	fi

# Security
security: validate
	@echo "$(MAGENTA)$(BOLD)🔒 Installing Security Hardening...$(RESET)"
	@sudo $(SCRIPTS_DIR)/components/install_security.sh --domain $(DOMAIN) --admin-email $(ADMIN_EMAIL) $(if $(CLIENT_ID),--client-id $(CLIENT_ID),) $(if $(FORCE),--force,) $(if $(WITH_DEPS),--with-deps,) $(if $(VERBOSE),--verbose,) $(if $(TEST_MODE),--test-mode,)

security-status:
	@echo "$(MAGENTA)$(BOLD)ℹ️ Checking Security Status...$(RESET)"
	@if [ -f "/opt/agency_stack/security/.installed_ok" ]; then \
		echo "$(GREEN)✅ Security hardening is installed$(RESET)"; \
		if command -v ufw &> /dev/null && ufw status | grep -q "Status: active"; then \
			echo "$(GREEN)✅ Firewall (UFW) is active$(RESET)"; \
			echo "$(CYAN)Allowed ports:$(RESET)"; \
			ufw status | grep -v "Status:" | grep ALLOW; \
		else \
			echo "$(RED)❌ Firewall (UFW) is not active$(RESET)"; \
		fi; \
		if [ -f "/etc/ssh/sshd_config.d/00-hardened.conf" ]; then \
			echo "$(GREEN)✅ SSH hardening is applied$(RESET)"; \
		else \
			echo "$(YELLOW)⚠️ SSH hardening is not applied$(RESET)"; \
		fi; \
		if [ -f "/etc/apt/apt.conf.d/50unattended-upgrades" ]; then \
			echo "$(GREEN)✅ Automatic security updates are configured$(RESET)"; \
		else \
			echo "$(YELLOW)⚠️ Automatic security updates are not configured$(RESET)"; \
		fi; \
	else \
		echo "$(RED)❌ Security hardening is not installed$(RESET)"; \
		echo "$(CYAN)Install with: make security$(RESET)"; \
	fi

security-logs:
	@echo "$(MAGENTA)$(BOLD)📜 Viewing Security Logs...$(RESET)"
	@if [ -f "/var/log/agency_stack/components/security.log" ]; then \
		cat /var/log/agency_stack/components/security.log | tail -n 30; \
		echo ""; \
		echo "$(CYAN)For security audit logs, use:$(RESET)"; \
		if [ -d "/opt/agency_stack/clients/$(CLIENT_ID)/security/audit" ]; then \
			echo "$(CYAN)Available audit logs:$(RESET)"; \
			ls -lt /opt/agency_stack/clients/$(CLIENT_ID)/security/audit/ | head -n 5; \
			echo ""; \
			if [ -f "/opt/agency_stack/clients/$(CLIENT_ID)/security/audit/latest-audit.log" ]; then \
				echo "$(CYAN)Latest audit summary:$(RESET)"; \
				head -n 20 /opt/agency_stack/clients/$(CLIENT_ID)/security/audit/latest-audit.log; \
				echo "..."; \
			fi; \
		fi; \
	else \
		echo "$(YELLOW)Security installation logs not found.$(RESET)"; \
	fi

security-restart:
	@echo "$(MAGENTA)$(BOLD)🔄 Running Security Audit...$(RESET)"
	@if [ -f "/opt/agency_stack/clients/$(CLIENT_ID)/security/security-audit.sh" ]; then \
		sudo /opt/agency_stack/clients/$(CLIENT_ID)/security/security-audit.sh; \
		echo "$(GREEN)✅ Security audit completed$(RESET)"; \
		echo "$(CYAN)View the full report at: /opt/agency_stack/clients/$(CLIENT_ID)/security/audit/latest-audit.log$(RESET)"; \
	else \
		echo "$(RED)❌ Security audit script not found. Is Security component installed?$(RESET)"; \
		echo "$(CYAN)Install with: make security$(RESET)"; \
	fi

# Demo Core Installation
# Installs high-value components suitable for client/investor demos
demo-core: validate
	@echo "$(MAGENTA)$(BOLD)🚀 Installing AgencyStack Demo Core Components...$(RESET)"
	@echo "$(CYAN)This will install a set of high-value components for demonstration purposes.$(RESET)"
	@echo ""
	
	@echo "$(YELLOW)📊 Installing Core Infrastructure...$(RESET)"
	@$(MAKE) docker docker-status docker_compose traefik_ssl
	
	@echo "$(YELLOW)🔐 Installing Security Components...$(RESET)"
	@$(MAKE) keycloak keycloak-status fail2ban
	
	@echo "$(YELLOW)📧 Installing Communication Components...$(RESET)"
	@$(MAKE) mailu mailu-status chatwoot chatwoot-status voip voip-status
	
	@echo "$(YELLOW)📊 Installing Monitoring Components...$(RESET)"
	@$(MAKE) prometheus prometheus-status grafana grafana-status posthog posthog-status
	
	@echo "$(YELLOW)📝 Installing Content & CMS Components...$(RESET)"
	@$(MAKE) wordpress wordpress-status peertube peertube-status builderio builderio-status
	
	@echo "$(YELLOW)🧰 Installing DevOps Components...$(RESET)"
	@$(MAKE) gitea gitea-status droneci
	
	@echo "$(YELLOW)📅 Installing Business Components...$(RESET)"
	@$(MAKE) calcom calcom-status erpnext documenso focalboard
	
	@echo "$(YELLOW)🔄 Integrating Components...$(RESET)"
	@$(MAKE) integrate-sso
	@$(MAKE) integrate-monitoring
	@$(MAKE) dashboard-update
	
	@echo "$(YELLOW)🧪 Running Validation Checks...$(RESET)"
	@$(MAKE) alpha-check
	@if [ -f "$(SCRIPTS_DIR)/smoke_test.sh" ]; then \
		$(MAKE) smoke-test; \
	fi
	
	@echo "$(GREEN)$(BOLD)✅ Demo Core Components Installed Successfully!$(RESET)"
	@echo "$(CYAN)Open the AgencyStack dashboard to view your installation:$(RESET)"
	@echo "$(CYAN)$(MAKE) dashboard-open$(RESET)"

# Demo Core Cleanup
# Removes the demo core components for a clean slate
demo-core-clean:
	@echo "$(MAGENTA)$(BOLD)🧹 Cleaning Up AgencyStack Demo Core Components...$(RESET)"
	@echo "$(RED)This will remove all demo core components and their data.$(RESET)"
	@echo ""
	
	@echo "$(YELLOW)Stopping and Removing Business Components...$(RESET)"
	@-$(MAKE) calcom-stop focalboard-stop erpnext-stop documenso-stop 2>/dev/null || true
	
	@echo "$(YELLOW)Stopping and Removing DevOps Components...$(RESET)"
	@-$(MAKE) gitea-stop droneci-stop 2>/dev/null || true
	
	@echo "$(YELLOW)Stopping and Removing Content Components...$(RESET)"
	@-$(MAKE) wordpress-stop peertube-stop builderio-stop 2>/dev/null || true
	
	@echo "$(YELLOW)Stopping and Removing Monitoring Components...$(RESET)"
	@-$(MAKE) prometheus-stop grafana-stop posthog-stop 2>/dev/null || true
	
	@echo "$(YELLOW)Stopping and Removing Communication Components...$(RESET)"
	@-$(MAKE) mailu-stop chatwoot-stop voip-stop 2>/dev/null || true
	
	@echo "$(YELLOW)Stopping and Removing Security Components...$(RESET)"
	@-$(MAKE) keycloak-stop fail2ban-stop 2>/dev/null || true
	
	@echo "$(GREEN)$(BOLD)✅ Demo Core Components Cleaned Up Successfully!$(RESET)"
	@echo "$(CYAN)The system has been returned to a clean state.$(RESET)"

# Demo Core Status
# Checks the status of all demo core components
demo-core-status:
	@echo "$(MAGENTA)$(BOLD)📊 AgencyStack Demo Core Components Status:$(RESET)"
	@echo ""
	
	@echo "$(YELLOW)📊 Core Infrastructure Components:$(RESET)"
	@-$(MAKE) docker-status docker_compose-status traefik-status 2>/dev/null || true
	
	@echo "$(YELLOW)🔐 Security Components:$(RESET)"
	@-$(MAKE) keycloak-status fail2ban-status 2>/dev/null || true
	
	@echo "$(YELLOW)📧 Communication Components:$(RESET)"
	@-$(MAKE) mailu-status chatwoot-status voip-status 2>/dev/null || true
	
	@echo "$(YELLOW)📊 Monitoring Components:$(RESET)"
	@-$(MAKE) prometheus-status grafana-status posthog-status 2>/dev/null || true
	
	@echo "$(YELLOW)📝 Content & CMS Components:$(RESET)"
	@-$(MAKE) wordpress-status peertube-status builderio-status 2>/dev/null || true
	
	@echo "$(YELLOW)🧰 DevOps Components:$(RESET)"
	@-$(MAKE) gitea-status droneci-status 2>/dev/null || true
	
	@echo "$(YELLOW)📅 Business Components:$(RESET)"
	@-$(MAKE) calcom-status erpnext-status documenso-status focalboard-status 2>/dev/null || true
	
	@echo "$(GREEN)$(BOLD)✅ Status Check Complete!$(RESET)"

# Demo Core Logs
# Views logs from all demo core components
demo-core-logs:
	@echo "$(MAGENTA)$(BOLD)📋 AgencyStack Demo Core Components Logs:$(RESET)"
	@echo "$(CYAN)Viewing recent logs from all demo components...$(RESET)"
	@echo ""
	
	@for component in docker traefik keycloak fail2ban mailu chatwoot voip prometheus grafana posthog wordpress peertube builderio gitea droneci calcom erpnext documenso focalboard; do \
		echo "$(YELLOW)📄 $$component logs:$(RESET)"; \
		$(MAKE) $$component-logs 2>/dev/null || echo "$(RED)No logs available for $$component$(RESET)"; \
		echo ""; \
	done
	
	@echo "$(GREEN)$(BOLD)✅ Logs Display Complete!$(RESET)"
	@echo "$(CYAN)For detailed logs, use 'make <component>-logs' for specific components.$(RESET)"

# Bolt DIY
bolt-diy: validate
	@echo "⚡ Installing Bolt DIY..."
	@sudo $(SCRIPTS_DIR)/components/install_bolt_diy.sh --domain $(DOMAIN) --admin-email $(ADMIN_EMAIL) $(if $(CLIENT_ID),--client-id $(CLIENT_ID),) $(if $(FORCE),--force,) $(if $(WITH_DEPS),--with-deps,) $(if $(VERBOSE),--verbose,)

bolt-diy-status:
	@echo "ℹ️ Checking Bolt DIY Status..."
	@if [ -n "$(CLIENT_ID)" ]; then \
		BOLT_CONTAINER="$(CLIENT_ID)_bolt_diy"; \
	else \
		BOLT_CONTAINER="bolt_diy"; \
	fi; \
	if docker ps -f name=$$BOLT_CONTAINER | grep -q $$BOLT_CONTAINER; then \
		echo "$(GREEN)Bolt DIY is running$(RESET)"; \
	else \
		echo "$(RED)Bolt DIY is not running$(RESET)"; \
	fi

bolt-diy-logs:
	@echo "📜 Viewing Bolt DIY Logs..."
	@if [ -f "/var/log/agency_stack/components/bolt_diy.log" ]; then \
		tail -n 50 "/var/log/agency_stack/components/bolt_diy.log"; \
	else \
		echo "$(YELLOW)No Bolt DIY logs found$(RESET)"; \
	fi

bolt-diy-restart:
	@echo "🔄 Restarting Bolt DIY..."
	@if [ -f "$(SCRIPTS_DIR)/components/restart_bolt_diy.sh" ]; then \
		$(SCRIPTS_DIR)/components/restart_bolt_diy.sh; \
	else \
		echo "Restart script not found. Trying standard methods..."; \
		if [ -n "$(CLIENT_ID)" ]; then \
			systemctl restart $(CLIENT_ID)-bolt-diy; \
		else \
			systemctl restart bolt-diy; \
		fi; \
	fi

# Archon
archon: validate
	@echo "🧠 Installing Archon..."
	@sudo $(SCRIPTS_DIR)/components/install_archon.sh --domain $(DOMAIN) --admin-email $(ADMIN_EMAIL) $(if $(CLIENT_ID),--client-id $(CLIENT_ID),) $(if $(FORCE),--force,) $(if $(WITH_DEPS),--with-deps,) $(if $(VERBOSE),--verbose,)

archon-status:
	@echo "ℹ️ Checking Archon Status..."
	@if [ -n "$(CLIENT_ID)" ]; then \
		ARCHON_CONTAINER="$(CLIENT_ID)_archon"; \
	else \
		ARCHON_CONTAINER="archon"; \
	fi; \
	if docker ps -f name=$$ARCHON_CONTAINER | grep -q $$ARCHON_CONTAINER; then \
		echo "$(GREEN)Archon is running$(RESET)"; \
	else \
		echo "$(RED)Archon is not running$(RESET)"; \
	fi

archon-logs:
	@echo "📜 Viewing Archon Logs..."
	@if [ -f "/var/log/agency_stack/components/archon.log" ]; then \
		tail -n 50 "/var/log/agency_stack/components/archon.log"; \
	else \
		echo "$(YELLOW)No Archon logs found$(RESET)"; \
	fi

archon-restart:
	@echo "🔄 Restarting Archon..."
	@if [ -f "$(SCRIPTS_DIR)/components/restart_archon.sh" ]; then \
		$(SCRIPTS_DIR)/components/restart_archon.sh; \
	else \
		echo "Restart script not found. Trying standard methods..."; \
		docker-compose -f "/opt/agency_stack/clients/$(CLIENT_ID)/archon/docker-compose.yml" restart; \
	fi

# Database Components
# ------------------------------------------------------------------------------

pgvector:
	@echo "$(MAGENTA)$(BOLD)🔍 Installing pgvector...$(RESET)"
	@read -p "$(YELLOW)Enter domain:$(RESET) " DOMAIN; \
	read -p "$(YELLOW)Enter admin email:$(RESET) " ADMIN_EMAIL; \
	read -p "$(YELLOW)Enter client ID (optional):$(RESET) " CLIENT_ID; \
	sudo $(SCRIPTS_DIR)/components/install_pgvector.sh --domain $$DOMAIN --admin-email $$ADMIN_EMAIL $(if $$CLIENT_ID,--client-id $$CLIENT_ID,) $(if $(FORCE),--force,) $(if $(WITH_DEPS),--with-deps,) $(if $(VERBOSE),--verbose,)

pgvector-status:
	@echo "$(MAGENTA)$(BOLD)ℹ️ Checking pgvector status...$(RESET)"
	@CLIENT_ID=$${CLIENT_ID:-default}; \
	INSTALL_DIR="/opt/agency_stack/clients/$${CLIENT_ID}/pgvector"; \
	if [ -f "$${INSTALL_DIR}/.installed" ]; then \
		echo "✅ pgvector is installed for client $${CLIENT_ID}"; \
		VERSION=$$(cat "$${INSTALL_DIR}/.version" 2>/dev/null || echo "unknown"); \
		echo "📊 Version: $${VERSION}"; \
		docker exec postgres-$${CLIENT_ID} psql -U postgres -c "SELECT extversion FROM pg_extension WHERE extname='vector'" || echo "⚠️ Extension not installed or error occurred"; \
	else \
		echo "❌ pgvector is not installed for client $${CLIENT_ID}"; \
	fi

pgvector-logs:
	@echo "$(MAGENTA)$(BOLD)📜 Viewing pgvector logs...$(RESET)"
	@CLIENT_ID=$${CLIENT_ID:-default}; \
	sudo cat /var/log/agency_stack/components/pgvector.log || echo "No logs found"

pgvector-restart:
	@echo "$(MAGENTA)$(BOLD)🔄 Restarting pgvector...$(RESET)"
	@CLIENT_ID=$${CLIENT_ID:-default}; \
	echo "⚠️ pgvector is an extension of PostgreSQL. Restarting database..."; \
	docker restart postgres-$${CLIENT_ID} || echo "Failed to restart PostgreSQL for client $${CLIENT_ID}"

pgvector-test:
	@echo "$(MAGENTA)$(BOLD)🧪 Testing pgvector functionality...$(RESET)"
	@CLIENT_ID=$${CLIENT_ID:-default}; \
	INSTALL_DIR="/opt/agency_stack/clients/$${CLIENT_ID}/pgvector"; \
	if [ -d "$${INSTALL_DIR}/samples" ]; then \
		read -p "$(YELLOW)This will install Python dependencies. Continue? [y/N]$(RESET) " CONFIRM; \
		if [[ $$CONFIRM =~ ^[Yy] ]]; then \
			cd "$${INSTALL_DIR}/samples" && ./run_example.sh; \
		else \
			echo "Test cancelled"; \
		fi \
	else \
		echo "❌ Sample code not found. Check installation."; \
	fi

pgvector-test:
	@echo "$(MAGENTA)$(BOLD)🧪 Testing pgvector functionality...$(RESET)"
	@CLIENT_ID=$${CLIENT_ID:-default}; \
	INSTALL_DIR="/opt/agency_stack/clients/$${CLIENT_ID}/pgvector"; \
	if [ -f "$${INSTALL_DIR}/.installed" ]; then \
		echo "🔍 Testing pgvector extension in PostgreSQL..."; \
		docker exec postgres-$${CLIENT_ID} psql -U postgres -d vectordb -c "CREATE TABLE IF NOT EXISTS vector_test_simple (id serial PRIMARY KEY, embedding vector(3)); INSERT INTO vector_test_simple (embedding) VALUES ('[1,2,3]'), ('[4,5,6]'); SELECT * FROM vector_test_simple; SELECT 'Test successful: Vector operations working correctly' AS status;" || { echo "❌ Test failed"; exit 1; }; \
		echo "✅ Test completed successfully"; \
	else \
		echo "❌ pgvector is not installed. Please run 'make pgvector' first."; \
		exit 1; \
	fi

dashboard-direct:
	@echo "$(MAGENTA)$(BOLD)🔗 Opening dashboard via direct access...$(RESET)"
	@SERVER_IP=$$(hostname -I | awk '{print $$1}'); \
	echo "$(CYAN)Dashboard Direct Access URLs:$(RESET)"; \
	echo "$(GREEN)Main:       http://$${SERVER_IP}:3001$(RESET)"; \
	echo "$(GREEN)Fallback:   http://$${SERVER_IP}:8080$(RESET)"; \
	echo "$(GREEN)Guaranteed: http://$${SERVER_IP}:8888$(RESET)"; \
	xdg-open "http://$${SERVER_IP}:8888" 2>/dev/null || echo "$(YELLOW)No browser available. Access manually using the URLs above.$(RESET)"

dashboard-access:
	@echo "$(MAGENTA)$(BOLD)🔧 Installing comprehensive dashboard access...$(RESET)"
	@read -p "$(YELLOW)Enter domain (default: $${DOMAIN:-proto001.alpha.nerdofmouth.com}):$(RESET) " DOMAIN_INPUT; \
	DOMAIN="$${DOMAIN_INPUT:-$${DOMAIN:-proto001.alpha.nerdofmouth.com}}"; \
	read -p "$(YELLOW)Enter client ID (default: default):$(RESET) " CLIENT_ID_INPUT; \
	CLIENT_ID="$${CLIENT_ID_INPUT:-default}"; \
	sudo $(SCRIPTS_DIR)/components/install_dashboard_access.sh --domain "$${DOMAIN}" --client-id "$${CLIENT_ID}" $(if $(FORCE),--force,)

dashboard-check:
	@echo "$(MAGENTA)$(BOLD)🔍 Checking dashboard access methods...$(RESET)"
	@read -p "$(YELLOW)Enter domain (default: $${DOMAIN:-proto001.alpha.nerdofmouth.com}):$(RESET) " DOMAIN_INPUT; \
	DOMAIN="$${DOMAIN_INPUT:-$${DOMAIN:-proto001.alpha.nerdofmouth.com}}"; \
	read -p "$(YELLOW)Enter client ID (default: default):$(RESET) " CLIENT_ID_INPUT; \
	CLIENT_ID="$${CLIENT_ID_INPUT:-default}"; \
	sudo $(SCRIPTS_DIR)/utils/dashboard_dns_helper.sh --domain "$${DOMAIN}" --client-id "$${CLIENT_ID}" $(if $(VERBOSE),--verbose,)

dashboard-fix:
	@echo "$(MAGENTA)$(BOLD)🛠️ Fixing dashboard access issues...$(RESET)"
	@read -p "$(YELLOW)Enter domain (default: $${DOMAIN:-proto001.alpha.nerdofmouth.com}):$(RESET) " DOMAIN_INPUT; \
	DOMAIN="$${DOMAIN_INPUT:-$${DOMAIN:-proto001.alpha.nerdofmouth.com}}"; \
	read -p "$(YELLOW)Enter client ID (default: default):$(RESET) " CLIENT_ID_INPUT; \
	CLIENT_ID="$${CLIENT_ID_INPUT:-default}"; \
	sudo $(SCRIPTS_DIR)/utils/dashboard_dns_helper.sh --domain "$${DOMAIN}" --client-id "$${CLIENT_ID}" --fix $(if $(VERBOSE),--verbose,)

# Fix Traefik ports for standard HTTP/HTTPS access
traefik-fix-ports:
	@echo "$(MAGENTA)$(BOLD)🛠️ Fixing Traefik ports for standard HTTP/HTTPS access...$(RESET)"
	@read -p "$(YELLOW)Enter domain (default: $${DOMAIN:-proto001.alpha.nerdofmouth.com}):$(RESET) " DOMAIN_INPUT; \
	DOMAIN="$${DOMAIN_INPUT:-$${DOMAIN:-proto001.alpha.nerdofmouth.com}}"; \
	read -p "$(YELLOW)Enter client ID (default: default):$(RESET) " CLIENT_ID_INPUT; \
	CLIENT_ID="$${CLIENT_ID_INPUT:-default}"; \
	sudo $(SCRIPTS_DIR)/components/fix_traefik_ports.sh --domain "$${DOMAIN}" --client-id "$${CLIENT_ID}" $(if $(FORCE),--force,) $(if $(VERBOSE),--verbose,)

# Check Traefik port configuration
traefik-check-ports:
	@echo "$(MAGENTA)$(BOLD)🔍 Checking Traefik port configuration...$(RESET)"
	@read -p "$(YELLOW)Enter domain (default: $${DOMAIN:-proto001.alpha.nerdofmouth.com}):$(RESET) " DOMAIN_INPUT; \
	DOMAIN="$${DOMAIN_INPUT:-$${DOMAIN:-proto001.alpha.nerdofmouth.com}}"; \
	read -p "$(YELLOW)Enter client ID (default: default):$(RESET) " CLIENT_ID_INPUT; \
	CLIENT_ID="$${CLIENT_ID_INPUT:-default}"; \
	sudo $(SCRIPTS_DIR)/components/fix_traefik_ports.sh --domain "$${DOMAIN}" --client-id "$${CLIENT_ID}" --check-only $(if $(VERBOSE),--verbose,)

# Auto-generated target for keycloak
keycloak:
	@echo "🔑 Installing Keycloak SSO & Identity provider..."
	@sudo $(SCRIPTS_DIR)/components/install_keycloak.sh --domain $(DOMAIN) --admin-email $(ADMIN_EMAIL) $(if $(CLIENT_ID),--client-id $(CLIENT_ID),) $(if $(FORCE),--force,) $(if $(WITH_DEPS),--with-deps,) $(if $(VERBOSE),--verbose,)

# Auto-generated target for keycloak
keycloak-status:
	@echo "🔍 Checking Keycloak status..."
	@sudo docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "keycloak|postgres"

# Auto-generated target for keycloak
keycloak-logs:
	@echo "📋 Viewing Keycloak logs..."
	@sudo docker logs --tail=100 -f keycloak_$(subst .,_,$(DOMAIN))

# Auto-generated target for keycloak
keycloak-restart:
	@echo "🔄 Restarting Keycloak services..."
	@cd /opt/agency_stack/keycloak/$(DOMAIN) && sudo docker-compose restart

# SSO Integration targets
sso-integrate:
	@echo "🔒 Integrating component with Keycloak SSO..."
	@if [ -z "$(COMPONENT)" ]; then \
		echo "Error: COMPONENT parameter is required. Usage: make sso-integrate COMPONENT=name FRAMEWORK=nodejs COMPONENT_URL=https://example.com"; \
		exit 1; \
	fi
	@if [ -z "$(FRAMEWORK)" ]; then \
		echo "Error: FRAMEWORK parameter is required. Valid options: nodejs, python, docker"; \
		exit 1; \
	fi
	@if [ -z "$(COMPONENT_URL)" ]; then \
		echo "Error: COMPONENT_URL parameter is required."; \
		exit 1; \
	fi
	@sudo $(SCRIPTS_DIR)/components/implement_sso_integration.sh --domain $(DOMAIN) --admin-email $(ADMIN_EMAIL) --client-id $(CLIENT_ID) --component $(COMPONENT) --framework $(FRAMEWORK) --component-url $(COMPONENT_URL) $(if $(FORCE),--force,) $(if $(VERBOSE),--verbose,)

sso-status:
	@echo "🔍 Checking SSO integration status for components..."
	@echo "Components with SSO enabled:"
	@grep -B 5 -A 3 '"sso": true' $(CONFIG_DIR)/registry/component_registry.json | grep '"name":' | awk -F'"' '{print $$4}' | sort | uniq
	@echo ""
	@echo "Components with SSO configured:"
	@grep -B 10 -A 3 '"sso_configured": true' $(CONFIG_DIR)/registry/component_registry.json 2>/dev/null | grep '"name":' | awk -F'"' '{print $$4}' | sort | uniq || echo "None configured yet"

# Add SSO integration for specific components
%-sso:
	@echo "🔒 Integrating $(subst -sso,,$@) with Keycloak SSO..."
	@component=$(subst -sso,,$@); \
	if grep -q "\"name\": \"$$component\"" $(CONFIG_DIR)/registry/component_registry.json && grep -q -A 20 "\"name\": \"$$component\"" $(CONFIG_DIR)/registry/component_registry.json | grep -q "\"sso\": true"; then \
		framework="docker"; \
		if [ "$$component" = "peertube" ] || [ "$$component" = "gitea" ] || [ "$$component" = "n8n" ]; then framework="nodejs"; fi; \
		if [ "$$component" = "django" ] || [ "$$component" = "grafana" ]; then framework="python"; fi; \
		$(MAKE) sso-integrate COMPONENT=$$component FRAMEWORK=$$framework COMPONENT_URL=https://$$component.$(DOMAIN); \
	else \
		echo "Component $$component does not exist or is not SSO-enabled in the registry"; \
		exit 1; \
	fi

# Implement SSO for all components marked with sso: true
sso-integrate-all:
	@echo "🔒 Integrating all SSO-enabled components with Keycloak..."
	@for component in $$(grep -B 5 -A 3 '"sso": true' $(CONFIG_DIR)/registry/component_registry.json | grep '"name":' | awk -F'"' '{print $$4}' | sort | uniq); do \
		echo "Integrating $$component..."; \
		framework="docker"; \
		if [ "$$component" = "peertube" ] || [ "$$component" = "gitea" ] || [ "$$component" = "n8n" ]; then framework="nodejs"; fi; \
		if [ "$$component" = "django" ] || [ "$$component" = "grafana" ]; then framework="python"; fi; \
		$(MAKE) sso-integrate COMPONENT=$$component FRAMEWORK=$$framework COMPONENT_URL=https://$$component.$(DOMAIN) || true; \
		echo ""; \
	done
