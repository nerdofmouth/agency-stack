# Launchbox - Makefile
# FOSS Server Stack for Agencies & Enterprises
# https://nerdofmouth.com/launchbox

# Variables
SHELL := /bin/bash
VERSION := 0.0.1.2025.04.04.0013
SCRIPTS_DIR := scripts
DOCS_DIR := docs
STACK_NAME := Launchbox

# Colors for output
BOLD := $(shell tput bold)
RED := $(shell tput setaf 1)
GREEN := $(shell tput setaf 2)
YELLOW := $(shell tput setaf 3)
BLUE := $(shell tput setaf 4)
MAGENTA := $(shell tput setaf 5)
CYAN := $(shell tput setaf 6)
RESET := $(shell tput sgr0)

.PHONY: help install update client test-env clean backup launchbox-info

# Default target
help:
	@echo "$(MAGENTA)$(BOLD)🚀 Launchbox $(VERSION) - FOSS Server Stack$(RESET)"
	@echo ""
	@bash $(SCRIPTS_DIR)/motto.sh
	@echo ""
	@echo "$(CYAN)Usage:$(RESET)"
	@echo "  $(BOLD)make install$(RESET)          Install Launchbox components"
	@echo "  $(BOLD)make update$(RESET)           Update Launchbox components"
	@echo "  $(BOLD)make client$(RESET)           Create a new client"
	@echo "  $(BOLD)make test-env$(RESET)         Test the environment"
	@echo "  $(BOLD)make backup$(RESET)           Backup all data"
	@echo "  $(BOLD)make clean$(RESET)            Remove all containers and volumes"
	@echo "  $(BOLD)make launchbox-info$(RESET)   Display Launchbox information"
	@echo ""
	@echo "$(GREEN)Visit https://nerdofmouth.com/launchbox for documentation$(RESET)"

# Install Launchbox
install:
	@echo "🔧 Installing Launchbox..."
	@sudo $(SCRIPTS_DIR)/install.sh

# Update Launchbox
update:
	@echo "🔄 Updating Launchbox..."
	@git pull
	@sudo $(SCRIPTS_DIR)/update.sh

# Create a new client
client:
	@echo "🏢 Creating new client..."
	@sudo $(SCRIPTS_DIR)/agency_stack_bootstrap_bundle_v10/bootstrap_client.sh

# Test the environment
test-env:
	@echo "🧪 Testing Launchbox environment..."
	@sudo $(SCRIPTS_DIR)/test_environment.sh

# Backup all data
backup:
	@echo "💾 Backing up Launchbox data..."
	@sudo $(SCRIPTS_DIR)/backup.sh

# Clean all containers and volumes
clean:
	@echo "🧹 Cleaning Launchbox environment..."
	@read -p "This will remove all containers and volumes. Are you sure? [y/N] " confirm; \
	[[ $$confirm == [yY] || $$confirm == [yY][eE][sS] ]] || exit 1
	@sudo docker-compose down -v

# Display Launchbox information
launchbox-info:
	@echo "$(MAGENTA)$(BOLD)📊 Launchbox Information$(RESET)"
	@echo "========================="
	@echo "Version: $(YELLOW)$(VERSION)$(RESET)"
	@echo "Stack Name: $(YELLOW)$(STACK_NAME)$(RESET)"
	@echo "Website: $(GREEN)https://nerdofmouth.com/launchbox$(RESET)"
	@echo ""
	@bash $(SCRIPTS_DIR)/motto.sh
	@echo ""
	@echo "$(CYAN)$(BOLD)Installed Components:$(RESET)"
	@if [ -f "/opt/launchbox/installed_components.txt" ]; then \
		cat /opt/launchbox/installed_components.txt | sort; \
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
