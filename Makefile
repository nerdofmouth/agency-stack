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
	@echo "  $(BOLD)make install-mirotalk-sfu$(RESET)     Install MiroTalk SFU - Video Conferencing"

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

erpnext: install-erpnext

erpnext-status:
	@echo "$(MAGENTA)$(BOLD)ℹ️ Checking ERPNext Status...$(RESET)"
	@if [ -z "$(DOMAIN)" ]; then \
		echo "$(RED)Error: Missing required parameter DOMAIN.$(RESET)"; \
		echo "Usage: make erpnext-status DOMAIN=erp.example.com [CLIENT_ID=tenant1]"; \
		exit 1; \
	fi; \
	CLIENT_DIR=""; \
	if [ -n "$(CLIENT_ID)" ]; then \
		CLIENT_DIR="/clients/$(CLIENT_ID)"; \
	fi; \
	if [ -d "/opt/agency_stack$${CLIENT_DIR}/erpnext/$(DOMAIN)" ]; then \
		echo "$(GREEN)✅ ERPNext installation found for $(DOMAIN)$(RESET)"; \
		cd /opt/agency_stack$${CLIENT_DIR}/erpnext/$(DOMAIN) && docker-compose ps; \
	else \
		echo "$(RED)❌ ERPNext installation not found for $(DOMAIN)$(RESET)"; \
	fi

erpnext-logs:
	@echo "$(MAGENTA)$(BOLD)📜 Viewing ERPNext Logs...$(RESET)"
	@if [ -z "$(DOMAIN)" ]; then \
		echo "$(RED)Error: Missing required parameter DOMAIN.$(RESET)"; \
		echo "Usage: make erpnext-logs DOMAIN=erp.example.com [CLIENT_ID=tenant1] [SERVICE=erpnext]"; \
		exit 1; \
	fi; \
	CLIENT_DIR=""; \
	if [ -n "$(CLIENT_ID)" ]; then \
		CLIENT_DIR="/clients/$(CLIENT_ID)"; \
	fi; \
	SERVICE=""; \
	if [ -n "$(SERVICE)" ]; then \
		SERVICE="$(SERVICE)"; \
	else \
		SERVICE="erpnext"; \
	fi; \
	if [ -d "/opt/agency_stack$${CLIENT_DIR}/erpnext/$(DOMAIN)" ]; then \
		cd /opt/agency_stack$${CLIENT_DIR}/erpnext/$(DOMAIN) && \
		docker-compose logs -f --tail=100 $${SERVICE} | tee -a $(LOG_DIR)/components/erpnext.log; \
	else \
		echo "$(RED)❌ ERPNext installation not found for $(DOMAIN)$(RESET)"; \
		echo "$(CYAN)To install: make erpnext DOMAIN=$(DOMAIN) ADMIN_EMAIL=your-email@example.com$(RESET)"; \
		if [ -f "$(LOG_DIR)/components/erpnext.log" ]; then \
			echo "$(YELLOW)Last logs from erpnext.log:$(RESET)"; \
			tail -n 20 $(LOG_DIR)/components/erpnext.log; \
		fi \
	fi

erpnext-restart:
	@echo "$(MAGENTA)$(BOLD)🔄 Restarting ERPNext Services...$(RESET)"
	@if [ -z "$(DOMAIN)" ]; then \
		echo "$(RED)Error: Missing required parameter DOMAIN.$(RESET)"; \
		echo "Usage: make erpnext-restart DOMAIN=erp.example.com [CLIENT_ID=tenant1] [SERVICE=all]"; \
		exit 1; \
	fi; \
	CLIENT_DIR=""; \
	if [ -n "$(CLIENT_ID)" ]; then \
		CLIENT_DIR="/clients/$(CLIENT_ID)"; \
	fi; \
	SERVICE=""; \
	if [ -n "$(SERVICE)" ] && [ "$(SERVICE)" != "all" ]; then \
		SERVICE="$(SERVICE)"; \
		echo "$(CYAN)Restarting $(SERVICE) service...$(RESET)"; \
	fi; \
	if [ -d "/opt/agency_stack$${CLIENT_DIR}/erpnext/$(DOMAIN)" ]; then \
		cd /opt/agency_stack$${CLIENT_DIR}/erpnext/$(DOMAIN) && docker-compose restart $${SERVICE}; \
		echo "$(GREEN)✅ ERPNext services restarted successfully$(RESET)"; \
	else \
		echo "$(RED)❌ ERPNext installation not found for $(DOMAIN)$(RESET)"; \
	fi

erpnext-backup:
	@echo "$(MAGENTA)$(BOLD)💾 Creating ERPNext Backup...$(RESET)"
	@if [ -z "$(DOMAIN)" ]; then \
		echo "$(RED)Error: Missing required parameter DOMAIN.$(RESET)"; \
		echo "Usage: make erpnext-backup DOMAIN=erp.example.com [CLIENT_ID=tenant1]"; \
		exit 1; \
	fi; \
	CLIENT_DIR=""; \
	if [ -n "$(CLIENT_ID)" ]; then \
		CLIENT_DIR="/clients/$(CLIENT_ID)"; \
	fi; \
	if [ -d "/opt/agency_stack$${CLIENT_DIR}/erpnext/$(DOMAIN)" ]; then \
		BACKUP_DIR="$(BACKUP_DIR)/erpnext/$(DOMAIN)"; \
		mkdir -p $${BACKUP_DIR}; \
		TIMESTAMP=$$(date +%Y%m%d_%H%M%S); \
		echo "$(CYAN)Creating database backup...$(RESET)"; \
		cd /opt/agency_stack$${CLIENT_DIR}/erpnext/$(DOMAIN) && \
		SITE_NAME="$$(docker-compose exec -T erpnext bash -c 'echo $$SITE_NAME')"; \
		docker-compose exec -T erpnext bench --site $${SITE_NAME} backup --with-files && \
		docker-compose exec -T erpnext bash -c "cp -r /home/frappe/frappe-bench/sites/$${SITE_NAME}/private/backups/* /home/frappe/frappe-bench/sites/$${SITE_NAME}/private/backups_archive/" && \
		echo "$(CYAN)Copying backup files to $(BACKUP_DIR)...$(RESET)" && \
		docker cp $$(docker-compose ps -q erpnext):/home/frappe/frappe-bench/sites/$${SITE_NAME}/private/backups_archive/ $${BACKUP_DIR}/$${TIMESTAMP}; \
		echo "$(GREEN)✅ ERPNext backup completed successfully$(RESET)"; \
		echo "$(CYAN)Backup saved to: $${BACKUP_DIR}/$${TIMESTAMP}$(RESET)"; \
	else \
		echo "$(RED)❌ ERPNext installation not found for $(DOMAIN)$(RESET)"; \
	fi

erpnext-config:
	@echo "$(MAGENTA)$(BOLD)⚙️ Opening ERPNext Configuration Shell...$(RESET)"
	@if [ -z "$(DOMAIN)" ]; then \
		echo "$(RED)Error: Missing required parameter DOMAIN.$(RESET)"; \
		echo "Usage: make erpnext-config DOMAIN=erp.example.com [CLIENT_ID=tenant1]"; \
		exit 1; \
	fi; \
	CLIENT_DIR=""; \
	if [ -n "$(CLIENT_ID)" ]; then \
		CLIENT_DIR="/clients/$(CLIENT_ID)"; \
	fi; \
	if [ -d "/opt/agency_stack$${CLIENT_DIR}/erpnext/$(DOMAIN)" ]; then \
		cd /opt/agency_stack$${CLIENT_DIR}/erpnext/$(DOMAIN) && \
		SITE_NAME="$$(docker-compose exec -T erpnext bash -c 'echo $$SITE_NAME')"; \
		echo "$(CYAN)Opening ERPNext Bench console for $${SITE_NAME}...$(RESET)"; \
		docker-compose exec erpnext bench --site $${SITE_NAME} console; \
	else \
		echo "$(RED)❌ ERPNext installation not found for $(DOMAIN)$(RESET)"; \
	fi

erpnext-test:
	@echo "$(MAGENTA)$(BOLD)🧪 Testing ERPNext API...$(RESET)"
	@if [ -z "$(DOMAIN)" ]; then \
		echo "$(RED)Error: Missing required parameter DOMAIN.$(RESET)"; \
		echo "Usage: make erpnext-test DOMAIN=erp.example.com [CLIENT_ID=tenant1]"; \
		exit 1; \
	fi; \
	CLIENT_DIR=""; \
	if [ -n "$(CLIENT_ID)" ]; then \
		CLIENT_DIR="/clients/$(CLIENT_ID)"; \
	fi; \
	if [ -d "/opt/agency_stack$${CLIENT_DIR}/erpnext/$(DOMAIN)" ]; then \
		echo "$(CYAN)Testing ERPNext API health...$(RESET)"; \
		curl -s https://$(DOMAIN)/api/method/ping | grep -q "message.*pong" && \
		echo "$(GREEN)✅ ERPNext API is healthy (responded with pong)$(RESET)" || \
		echo "$(RED)❌ ERPNext API health check failed$(RESET)"; \
		\
		echo "$(CYAN)Checking ERPNext site status...$(RESET)"; \
		cd /opt/agency_stack$${CLIENT_DIR}/erpnext/$(DOMAIN) && \
		SITE_NAME="$$(docker-compose exec -T erpnext bash -c 'echo $$SITE_NAME')"; \
		docker-compose exec -T erpnext bench --site $${SITE_NAME} status | tee -a $(LOG_DIR)/components/erpnext.log; \
	else \
		echo "$(RED)❌ ERPNext installation not found for $(DOMAIN)$(RESET)"; \
	fi

erpnext-sso:
	@echo "$(MAGENTA)$(BOLD)🔑 Configuring ERPNext SSO with Keycloak...$(RESET)"
	@if [ -z "$(DOMAIN)" ] || [ -z "$(KEYCLOAK_DOMAIN)" ]; then \
		echo "$(RED)Error: Missing required parameters.$(RESET)"; \
		echo "Usage: make erpnext-sso DOMAIN=erp.example.com KEYCLOAK_DOMAIN=auth.example.com [CLIENT_ID=tenant1]"; \
		exit 1; \
	fi; \
	sudo $(SCRIPTS_DIR)/components/install_erpnext.sh --domain $(DOMAIN) --keycloak-domain $(KEYCLOAK_DOMAIN) --enable-sso $(if $(CLIENT_ID),--client-id $(CLIENT_ID),) $(if $(VERBOSE),--verbose,)

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
	@docker ps -a | grep chatwoot || echo "Chatwoot is not running"

voip-logs:
	@docker logs -f chatwoot-app-$(CLIENT_ID) 2>&1 | tee $(LOG_DIR)/components/chatwoot.log

voip-stop:
	@docker-compose -f $(DOCKER_DIR)/chatwoot/docker-compose.yml down

voip-start:
	@docker-compose -f $(DOCKER_DIR)/chatwoot/docker-compose.yml up -d

voip-restart:
	@docker-compose -f $(DOCKER_DIR)/chatwoot/docker-compose.yml restart

voip-backup:
	@echo "Backing up Chatwoot data..."
	@mkdir -p $(BACKUP_DIR)/chatwoot
	@docker exec chatwoot-postgres-$(CLIENT_ID) pg_dump -U chatwoot chatwoot > $(BACKUP_DIR)/chatwoot/chatwoot_db_$(shell date +%Y%m%d).sql
	@tar -czf $(BACKUP_DIR)/chatwoot/chatwoot_storage_$(shell date +%Y%m%d).tar.gz -C $(CONFIG_DIR)/clients/$(CLIENT_ID)/chatwoot_data/storage .
	@echo "Backup completed: $(BACKUP_DIR)/chatwoot/"

voip-config:
	@echo "Opening Chatwoot environment configuration..."
	@$(EDITOR) $(DOCKER_DIR)/chatwoot/.env

voip-upgrade:
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

# Configure PeerTube Keycloak SSO integration
peertube-sso-configure: validate
	@echo "$(MAGENTA)$(BOLD)🔑 Configuring PeerTube SSO Integration...$(RESET)"
	@sudo $(SCRIPTS_DIR)/components/keycloak/configure_peertube_client.sh --domain $(DOMAIN) $(if $(CLIENT_ID),--client-id $(CLIENT_ID),) $(if $(FORCE),--force,) $(if $(VERBOSE),--verbose,)

# Test PeerTube-Keycloak SSO integration
peertube-sso-test: validate
	@echo "$(MAGENTA)$(BOLD)🧪 Testing PeerTube SSO Integration...$(RESET)"
	@if [ -n "$(CLIENT_ID)" ]; then \
		PEERTUBE_CONTAINER="$(CLIENT_ID)_peertube"; \
	else \
		PEERTUBE_CONTAINER="peertube"; \
	fi; \
	if docker ps --format '{{.Names}}' | grep -q "$$PEERTUBE_CONTAINER"; then \
		echo "$(GREEN)✅ PeerTube is running$(RESET)"; \
		echo "$(CYAN)Testing OAuth configuration...$(RESET)"; \
		OAUTH_CONFIG="/opt/agency_stack/clients/$(or $(CLIENT_ID),default)/peertube_data/config/production.yaml.d/oauth.yaml"; \
		if [ -f "$$OAUTH_CONFIG" ]; then \
			echo "$(GREEN)✅ OAuth configuration exists:$(RESET)"; \
			cat "$$OAUTH_CONFIG"; \
			echo ""; \
			echo "$(CYAN)Testing Keycloak connection...$(RESET)"; \
			OPENID_URL=$$(grep "open_id_configuration_url" "$$OAUTH_CONFIG" | awk -F"'" '{print $$2}'); \
			if [ -n "$$OPENID_URL" ]; then \
				echo "$(CYAN)Checking OpenID configuration at: $$OPENID_URL$(RESET)"; \
				curl -s "$$OPENID_URL" | grep -q "issuer" && echo "$(GREEN)✅ Keycloak OpenID configuration is accessible$(RESET)" || echo "$(RED)❌ Keycloak OpenID configuration is not accessible$(RESET)"; \
			else \
				echo "$(RED)❌ Could not determine OpenID configuration URL$(RESET)"; \
			fi; \
		else \
			echo "$(RED)❌ OAuth configuration not found$(RESET)"; \
			echo "$(CYAN)Run: make peertube-sso-configure DOMAIN=$(DOMAIN)$(RESET)"; \
		fi; \
	else \
		echo "$(RED)❌ PeerTube is not running$(RESET)"; \
		echo "$(CYAN)Start PeerTube with: make peertube-restart$(RESET)"; \
	fi

# Remote Deployment
deploy-remote:
	@echo "$(MAGENTA)$(BOLD)🚀 Deploying to Remote VM...$(RESET)"
	@if [ -z "$(REMOTE_HOST)" ]; then \
		echo "$(RED)Error: Missing required parameter REMOTE_HOST.$(RESET)"; \
		echo "Usage: make deploy-remote REMOTE_HOST=hostname.example.com [COMPONENT=keycloak] [REMOTE_USER=root] [SSH_KEY=/path/to/key] [SSH_PORT=22]"; \
		exit 1; \
	fi; \
	bash $(SCRIPTS_DIR)/utils/deploy_to_remote.sh \
		--remote-host $(REMOTE_HOST) \
		$(if $(REMOTE_USER),--remote-user $(REMOTE_USER),) \
		$(if $(SSH_KEY),--ssh-key $(SSH_KEY),) \
		$(if $(SSH_PORT),--ssh-port $(SSH_PORT),) \
		$(if $(COMPONENT),--component $(COMPONENT),) \
		$(if $(FORCE),--force,) \
		$(if $(VERBOSE),--verbose,)

deploy-keycloak-remote:
	@echo "$(MAGENTA)$(BOLD)🔑 Deploying Keycloak to Remote VM...$(RESET)"
	@if [ -z "$(REMOTE_HOST)" ]; then \
		echo "$(RED)Error: Missing required parameter REMOTE_HOST.$(RESET)"; \
		echo "Usage: make deploy-keycloak-remote REMOTE_HOST=hostname.example.com [REMOTE_USER=root] [SSH_KEY=/path/to/key] [SSH_PORT=22]"; \
		exit 1; \
	fi; \
	bash $(SCRIPTS_DIR)/utils/deploy_to_remote.sh \
		--remote-host $(REMOTE_HOST) \
		$(if $(REMOTE_USER),--remote-user $(REMOTE_USER),) \
		$(if $(SSH_KEY),--ssh-key $(SSH_KEY),) \
		$(if $(SSH_PORT),--ssh-port $(SSH_PORT),) \
		--component keycloak \
		$(if $(FORCE),--force,) \
		$(if $(VERBOSE),--verbose,)

configure-keycloak-remote:
	@echo "$(MAGENTA)$(BOLD)🔧 Configuring Keycloak OAuth on Remote VM...$(RESET)"
	@if [ -z "$(REMOTE_HOST)" ] || [ -z "$(DOMAIN)" ]; then \
		echo "$(RED)Error: Missing required parameters.$(RESET)"; \
		echo "Usage: make configure-keycloak-remote REMOTE_HOST=hostname.example.com DOMAIN=auth.example.com [ENABLE_OAUTH_*=true]"; \
		exit 1; \
	fi; \
	echo "$(CYAN)Deploying Keycloak files to remote...$(RESET)" && \
	make deploy-keycloak-remote REMOTE_HOST=$(REMOTE_HOST) $(if $(REMOTE_USER),REMOTE_USER=$(REMOTE_USER),) $(if $(SSH_KEY),SSH_KEY=$(SSH_KEY),) $(if $(SSH_PORT),SSH_PORT=$(SSH_PORT),) && \
	echo "$(CYAN)Configuring OAuth providers on remote...$(RESET)" && \
	ssh $(if $(SSH_KEY),-i $(SSH_KEY),) $(if $(SSH_PORT),-p $(SSH_PORT),) $(if $(REMOTE_USER),$(REMOTE_USER),root)@$(REMOTE_HOST) \
		"cd /opt/agency_stack && make keycloak-oauth-configure DOMAIN=$(DOMAIN) \
		$(if $(CLIENT_ID),CLIENT_ID=$(CLIENT_ID),) \
		$(if $(ENABLE_OAUTH_GOOGLE),ENABLE_OAUTH_GOOGLE=true,) \
		$(if $(ENABLE_OAUTH_GITHUB),ENABLE_OAUTH_GITHUB=true,) \
		$(if $(ENABLE_OAUTH_APPLE),ENABLE_OAUTH_APPLE=true,) \
		$(if $(ENABLE_OAUTH_LINKEDIN),ENABLE_OAUTH_LINKEDIN=true,) \
		$(if $(ENABLE_OAUTH_MICROSOFT),ENABLE_OAUTH_MICROSOFT=true,) \
		$(if $(VERBOSE),VERBOSE=true,)"

# Cross-VM OAuth Dashboard Sync
sync-oauth-dashboard:
	@echo "$(MAGENTA)$(BOLD)🔄 Synchronizing OAuth Dashboard Data Between VMs...$(RESET)"
	@if [ -z "$(SOURCE_HOST)" ] || [ -z "$(TARGET_HOST)" ]; then \
		echo "Usage: make sync-oauth-dashboard SOURCE_HOST=proto002.alpha.nerdofmouth.com TARGET_HOST=proto001.alpha.nerdofmouth.com [DOMAIN=auth.example.com] [VERBOSE=true]"; \
		exit 1; \
	fi; \
	bash $(SCRIPTS_DIR)/utils/sync_dashboard_oauth.sh \
		--source-host $(SOURCE_HOST) \
		--target-host $(TARGET_HOST) \
		$(if $(DOMAIN),--domain $(DOMAIN),) \
		$(if $(SOURCE_CLIENT_ID),--source-client-id $(SOURCE_CLIENT_ID),) \
		$(if $(TARGET_CLIENT_ID),--target-client-id $(TARGET_CLIENT_ID),) \
		$(if $(FORCE),--force,) \
		$(if $(VERBOSE),--verbose,) \
		$(if $(DRY_RUN),--dry-run,)

# MiroTalk SFU - Video Conferencing
install-mirotalk-sfu: validate
	@echo "$(MAGENTA)$(BOLD)🎥 Installing MiroTalk SFU...$(RESET)"
	@sudo $(SCRIPTS_DIR)/components/install_mirotalk_sfu.sh --domain $(DOMAIN) --admin-email $(ADMIN_EMAIL) $(if $(CLIENT_ID),--client-id $(CLIENT_ID),) $(if $(FORCE),--force,) $(if $(WITH_DEPS),--with-deps,) $(if $(ENABLE_CLOUD),--enable-cloud,) $(if $(ENABLE_METRICS),--enable-metrics,) $(if $(VERBOSE),--verbose,)

mirotalk-sfu: install-mirotalk-sfu

mirotalk-sfu-status:
	@echo "$(MAGENTA)$(BOLD)ℹ️ Checking MiroTalk SFU Status...$(RESET)"
	@if [ -z "$(DOMAIN)" ]; then \
		echo "$(RED)Error: Missing required parameter DOMAIN.$(RESET)"; \
		echo "Usage: make mirotalk-sfu-status DOMAIN=video.example.com [CLIENT_ID=tenant1]"; \
		exit 1; \
	fi; \
	CLIENT_DIR=""; \
	if [ -n "$(CLIENT_ID)" ]; then \
		CLIENT_DIR="/clients/$(CLIENT_ID)"; \
	fi; \
	if [ -d "/opt/agency_stack$${CLIENT_DIR}/mirotalk_sfu/$(DOMAIN)" ]; then \
		echo "$(GREEN)✅ MiroTalk SFU installation found for $(DOMAIN)$(RESET)"; \
		cd /opt/agency_stack$${CLIENT_DIR}/mirotalk_sfu/$(DOMAIN) && docker-compose ps; \
	else \
		echo "$(RED)❌ MiroTalk SFU installation not found for $(DOMAIN)$(RESET)"; \
	fi

mirotalk-sfu-logs:
	@echo "$(MAGENTA)$(BOLD)📜 Viewing MiroTalk SFU Logs...$(RESET)"
	@if [ -z "$(DOMAIN)" ]; then \
		echo "$(RED)Error: Missing required parameter DOMAIN.$(RESET)"; \
		echo "Usage: make mirotalk-sfu-logs DOMAIN=video.example.com [CLIENT_ID=tenant1]"; \
		exit 1; \
	fi; \
	CLIENT_DIR=""; \
	if [ -n "$(CLIENT_ID)" ]; then \
		CLIENT_DIR="/clients/$(CLIENT_ID)"; \
	fi; \
	if [ -d "/opt/agency_stack$${CLIENT_DIR}/mirotalk_sfu/$(DOMAIN)" ]; then \
		cd /opt/agency_stack$${CLIENT_DIR}/mirotalk_sfu/$(DOMAIN) && docker-compose logs -f | tee -a /var/log/agency_stack/components/mirotalk_sfu.log; \
	else \
		echo "$(RED)❌ MiroTalk SFU installation not found for $(DOMAIN)$(RESET)"; \
		echo "$(CYAN)To install: make mirotalk-sfu DOMAIN=$(DOMAIN) ADMIN_EMAIL=your-email@example.com$(RESET)"; \
		if [ -f "/var/log/agency_stack/components/mirotalk_sfu.log" ]; then \
			echo "$(YELLOW)Last logs from mirotalk_sfu.log:$(RESET)"; \
			tail -n 20 /var/log/agency_stack/components/mirotalk_sfu.log; \
		fi \
	fi

mirotalk-sfu-restart:
	@echo "$(MAGENTA)$(BOLD)🔄 Restarting MiroTalk SFU Services...$(RESET)"
	@if [ -z "$(DOMAIN)" ]; then \
		echo "$(RED)Error: Missing required parameter DOMAIN.$(RESET)"; \
		echo "Usage: make mirotalk-sfu-restart DOMAIN=video.example.com [CLIENT_ID=tenant1]"; \
		exit 1; \
	fi; \
	CLIENT_DIR=""; \
	if [ -n "$(CLIENT_ID)" ]; then \
		CLIENT_DIR="/clients/$(CLIENT_ID)"; \
	fi; \
	if [ -d "/opt/agency_stack$${CLIENT_DIR}/mirotalk_sfu/$(DOMAIN)" ]; then \
		cd /opt/agency_stack$${CLIENT_DIR}/mirotalk_sfu/$(DOMAIN) && docker-compose restart; \
		echo "$(GREEN)✅ MiroTalk SFU services restarted successfully$(RESET)"; \
	else \
		echo "$(RED)❌ MiroTalk SFU installation not found for $(DOMAIN)$(RESET)"; \
	fi

mirotalk-sfu-update:
	@echo "$(MAGENTA)$(BOLD)🔄 Updating MiroTalk SFU...$(RESET)"
	@if [ -z "$(DOMAIN)" ]; then \
		echo "$(RED)Error: Missing required parameter DOMAIN.$(RESET)"; \
		echo "Usage: make mirotalk-sfu-update DOMAIN=video.example.com [CLIENT_ID=tenant1] [VERSION=latest]"; \
		exit 1; \
	fi; \
	CLIENT_DIR=""; \
	if [ -n "$(CLIENT_ID)" ]; then \
		CLIENT_DIR="/clients/$(CLIENT_ID)"; \
	fi; \
	VERSION="latest"; \
	if [ -n "$(VERSION)" ]; then \
		VERSION="$(VERSION)"; \
	fi; \
	if [ -d "/opt/agency_stack$${CLIENT_DIR}/mirotalk_sfu/$(DOMAIN)" ]; then \
		cd /opt/agency_stack$${CLIENT_DIR}/mirotalk_sfu/$(DOMAIN) && \
		sed -i "s|image: mirotalk/sfu:.*|image: mirotalk/sfu:$${VERSION}|g" docker-compose.yml && \
		docker-compose pull && \
		docker-compose up -d; \
		echo "$(GREEN)✅ MiroTalk SFU updated to version $${VERSION}$(RESET)"; \
	else \
		echo "$(RED)❌ MiroTalk SFU installation not found for $(DOMAIN)$(RESET)"; \
	fi

# Standardized Mailu Email Server targets
mailu: install-mailu
	@echo "$(MAGENTA)$(BOLD)📧 Installing Mailu Email Server...$(RESET)"

install-mailu:
	@echo "$(MAGENTA)$(BOLD)📧 Installing Mailu Email Server...$(RESET)"
	@if [ -z "$(DOMAIN)" ]; then \
		read -p "$(YELLOW)Enter domain for Mailu (e.g., mail.yourdomain.com):$(RESET) " DOMAIN; \
		read -p "$(YELLOW)Enter email domain (e.g., yourdomain.com):$(RESET) " EMAIL_DOMAIN; \
		read -p "$(YELLOW)Enter admin email (e.g., admin@yourdomain.com):$(RESET) " ADMIN_EMAIL; \
		sudo $(SCRIPTS_DIR)/components/install_mailu.sh --domain $$DOMAIN --email-domain $$EMAIL_DOMAIN --admin-email $$ADMIN_EMAIL $(ARGS); \
	else \
		sudo $(SCRIPTS_DIR)/components/install_mailu.sh --domain $(DOMAIN) $(if $(EMAIL_DOMAIN),--email-domain $(EMAIL_DOMAIN),) \
		$(if $(ADMIN_EMAIL),--admin-email $(ADMIN_EMAIL),) $(if $(ADMIN_PASSWORD),--admin-password $(ADMIN_PASSWORD),) \
		$(if $(CLIENT_ID),--client-id $(CLIENT_ID),) $(if $(FORCE),--force,) $(if $(WITH_DEPS),--with-deps,) $(if $(VERBOSE),--verbose,) $(ARGS); \
	fi

mailu-status:
	@echo "$(MAGENTA)$(BOLD)ℹ️ Checking Mailu Status...$(RESET)"
	@if [ -z "$(DOMAIN)" ]; then \
		echo "$(RED)Error: Missing required parameter DOMAIN.$(RESET)"; \
		echo "Usage: make mailu-status DOMAIN=mail.example.com [CLIENT_ID=tenant1]"; \
		exit 1; \
	fi; \
	if [ -n "$(CLIENT_ID)" ]; then \
		echo "$(CYAN)Checking Mailu status for $(DOMAIN) (client: $(CLIENT_ID))...$(RESET)"; \
		CONTAINER_PREFIX="mailu_$(CLIENT_ID)"; \
	else \
		echo "$(CYAN)Checking Mailu status for $(DOMAIN)...$(RESET)"; \
		CONTAINER_PREFIX="mailu"; \
	fi; \
	if docker ps | grep -q "$${CONTAINER_PREFIX}_admin"; then \
		echo "$(GREEN)✅ Mailu is running for $(DOMAIN)$(RESET)"; \
		docker ps --filter "name=$${CONTAINER_PREFIX}_" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"; \
		echo ""; \
		echo "$(CYAN)Webmail: https://$(DOMAIN)/webmail/$(RESET)"; \
		echo "$(CYAN)Admin: https://$(DOMAIN)/admin/$(RESET)"; \
	else \
		echo "$(RED)❌ Mailu containers for $(DOMAIN) are not running$(RESET)"; \
		echo "To start Mailu, run: make mailu-restart DOMAIN=$(DOMAIN) $(if $(CLIENT_ID),CLIENT_ID=$(CLIENT_ID),)"; \
	fi

mailu-logs:
	@echo "$(MAGENTA)$(BOLD)📜 Viewing Mailu Logs...$(RESET)"
	@if [ -z "$(DOMAIN)" ]; then \
		echo "$(RED)Error: Missing required parameter DOMAIN.$(RESET)"; \
		echo "Usage: make mailu-logs DOMAIN=mail.example.com [CLIENT_ID=tenant1] [CONTAINER=admin|smtp|imap|webmail|redis|postfix]"; \
		exit 1; \
	fi; \
	if [ -n "$(CLIENT_ID)" ]; then \
		CONTAINER_PREFIX="mailu_$(CLIENT_ID)"; \
	else \
		CONTAINER_PREFIX="mailu"; \
	fi; \
	if [ -n "$(CONTAINER)" ]; then \
		echo "$(CYAN)Viewing logs for $${CONTAINER_PREFIX}_$(CONTAINER) container...$(RESET)"; \
		docker logs $${CONTAINER_PREFIX}_$(CONTAINER) $(if $(FOLLOW),--follow,) $(if $(TAIL),--tail $(TAIL),--tail 100); \
	else \
		echo "$(CYAN)Viewing component logs for Mailu ($(DOMAIN))...$(RESET)"; \
		if [ -f "/var/log/agency_stack/components/mailu.log" ]; then \
			cat "/var/log/agency_stack/components/mailu.log" | tail -n 100; \
		elif [ -f "/var/log/agency_stack/components/install_mailu-"* ]; then \
			ls -t /var/log/agency_stack/components/install_mailu-* | head -n 1 | xargs cat | tail -n 100; \
		else \
			echo "$(YELLOW)No Mailu logs found in /var/log/agency_stack/components/$(RESET)"; \
			echo "$(CYAN)Showing logs from all Mailu containers:$(RESET)"; \
			docker logs $${CONTAINER_PREFIX}_admin --tail 50; \
		fi; \
	fi

mailu-restart:
	@echo "$(MAGENTA)$(BOLD)🔄 Restarting Mailu...$(RESET)"
	@if [ -z "$(DOMAIN)" ]; then \
		echo "$(RED)Error: Missing required parameter DOMAIN.$(RESET)"; \
		echo "Usage: make mailu-restart DOMAIN=mail.example.com [CLIENT_ID=tenant1]"; \
		exit 1; \
	fi; \
	if [ -n "$(CLIENT_ID)" ]; then \
		MAILU_DIR="/opt/agency_stack/mailu/clients/$(CLIENT_ID)/$(DOMAIN)"; \
		echo "$(CYAN)Restarting Mailu for $(DOMAIN) (client: $(CLIENT_ID))...$(RESET)"; \
	else \
		MAILU_DIR="/opt/agency_stack/mailu/$(DOMAIN)"; \
		echo "$(CYAN)Restarting Mailu for $(DOMAIN)...$(RESET)"; \
	fi; \
	if [ -d "$$MAILU_DIR" ]; then \
		cd "$$MAILU_DIR" && docker-compose down && docker-compose up -d; \
		echo "$(GREEN)✅ Mailu has been restarted for $(DOMAIN)$(RESET)"; \
	else \
		echo "$(RED)❌ Mailu installation directory not found: $$MAILU_DIR$(RESET)"; \
		echo "Please make sure Mailu is installed for $(DOMAIN)"; \
		exit 1; \
	fi

# Make targets for integration with other components
mailu-listmonk:
	@echo "$(MAGENTA)$(BOLD)🔗 Integrating Mailu with Listmonk...$(RESET)"
	@if [ -z "$(DOMAIN)" ]; then \
		echo "$(RED)Error: Missing required parameter DOMAIN.$(RESET)"; \
		echo "Usage: make mailu-listmonk DOMAIN=mail.example.com [CLIENT_ID=tenant1]"; \
		exit 1; \
	fi; \
	echo "$(CYAN)Configuring Listmonk to use Mailu as SMTP relay...$(RESET)"; \
	sudo $(SCRIPTS_DIR)/integrations/integrate_mailu_listmonk.sh --domain $(DOMAIN) $(if $(CLIENT_ID),--client-id $(CLIENT_ID),)
