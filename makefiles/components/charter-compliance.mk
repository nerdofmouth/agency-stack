# charter-compliance.mk - Targets for ensuring Charter v1.0.3 compliance
# Created following AgencyStack Charter v1.0.3 principles

# Colors for output (already defined in main Makefile)
# BOLD := $(shell tput bold)
# RED := $(shell tput setaf 1)
# GREEN := $(shell tput setaf 2)
# YELLOW := $(shell tput setaf 3)
# BLUE := $(shell tput setaf 4)
# MAGENTA := $(shell tput setaf 5)
# CYAN := $(shell tput setaf 6)
# RESET := $(shell tput sgr0)

# Charter Compliance and Quality Enforcement targets
.PHONY: syntax-repair component-standardize standardize-all tdd-check charter-check component-registry-validate charter-compliance

syntax-repair:
	@echo "$(MAGENTA)$(BOLD)🔧 Repairing syntax issues in component scripts...$(RESET)"
	@docker run --rm -v $(CURDIR):/root/_repos/agency-stack -w /root/_repos/agency-stack ubuntu:20.04 \
		bash -c "cd /root/_repos/agency-stack && ./scripts/utils/syntax_repair.sh --all"

component-standardize:
	@echo "$(CYAN)$(BOLD)🔍 Standardizing component scripts...$(RESET)"
	@if [ -z "$(COMPONENT)" ]; then \
		echo "$(RED)Error: COMPONENT is required. Usage: make component-standardize COMPONENT=component_name$(RESET)"; \
		exit 1; \
	fi
	@docker run --rm -v $(CURDIR):/root/_repos/agency-stack -w /root/_repos/agency-stack ubuntu:20.04 \
		bash -c "cd /root/_repos/agency-stack && ./scripts/utils/component_standardizer.sh $(COMPONENT)"

standardize-all:
	@echo "$(CYAN)$(BOLD)🔍 Standardizing all component scripts...$(RESET)"
	@docker run --rm -v $(CURDIR):/root/_repos/agency-stack -w /root/_repos/agency-stack ubuntu:20.04 \
		bash -c "cd /root/_repos/agency-stack && ./scripts/utils/component_standardizer.sh --all"

tdd-check:
	@echo "$(GREEN)$(BOLD)✅ Checking TDD Protocol compliance...$(RESET)"
	@if [ -f "scripts/utils/environment_audit.sh" ]; then \
		scripts/utils/environment_audit.sh --tdd-check; \
	else \
		echo "$(YELLOW)environment_audit.sh not found, skipping TDD check$(RESET)"; \
	fi

component-registry-validate:
	@echo "$(MAGENTA)$(BOLD)📋 Validating component registry...$(RESET)"
	@if [ -f "scripts/utils/environment_audit.sh" ]; then \
		scripts/utils/environment_audit.sh --validate-registry; \
	else \
		echo "$(YELLOW)environment_audit.sh not found, skipping registry validation$(RESET)"; \
	fi

charter-check:
	@echo "$(YELLOW)$(BOLD)📜 Checking Charter v1.0.3 compliance...$(RESET)"
	@if [ -f "scripts/utils/environment_audit.sh" ]; then \
		scripts/utils/environment_audit.sh --charter-check; \
	else \
		echo "$(YELLOW)environment_audit.sh not found, skipping Charter check$(RESET)"; \
	fi

charter-compliance: syntax-repair standardize-all tdd-check component-registry-validate charter-check
	@echo "$(GREEN)$(BOLD)🚀 Charter compliance checks and fixes completed$(RESET)"

# Add to post-commit check target (will be merged with the main Makefile)
post-commit-check: agent-lint audit alpha-check charter-check
	@echo "$(GREEN)$(BOLD)✓ All post-commit checks passed!$(RESET)"
