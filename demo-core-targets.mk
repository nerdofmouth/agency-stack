# Demo Core - Core components for agency demo
demo-core: validate
	@echo "$(MAGENTA)$(BOLD)🚀 Installing AgencyStack Demo Core Components...$(RESET)"
	@echo "$(CYAN)This will install essential components for a full demo environment.$(RESET)"
	@echo ""
	
	@echo "$(YELLOW)$(BOLD)🔐 Installing Identity & Proxy Components...$(RESET)"
	@if grep -q "^prerequisites:" $(MAKEFILE_LIST); then \
		make prerequisites || { echo "$(RED)Failed to install prerequisites$(RESET)"; exit 1; }; \
	elif grep -q "^install-prerequisites:" $(MAKEFILE_LIST); then \
		make install-prerequisites || { echo "$(RED)Failed to install prerequisites$(RESET)"; exit 1; }; \
	else \
		echo "$(RED)Target 'prerequisites' not found$(RESET)"; \
	fi
	
	@if grep -q "^docker:" $(MAKEFILE_LIST); then \
		make docker || { echo "$(RED)Failed to install docker$(RESET)"; exit 1; }; \
	elif grep -q "^install-docker:" $(MAKEFILE_LIST); then \
		make install-docker || { echo "$(RED)Failed to install docker$(RESET)"; exit 1; }; \
	else \
		echo "$(RED)Target 'docker' not found$(RESET)"; \
	fi
	
	@if grep -q "^docker-compose:" $(MAKEFILE_LIST); then \
		make docker-compose || { echo "$(RED)Failed to install docker-compose$(RESET)"; exit 1; }; \
	elif grep -q "^install-docker-compose:" $(MAKEFILE_LIST); then \
		make install-docker-compose || { echo "$(RED)Failed to install docker-compose$(RESET)"; exit 1; }; \
	else \
		echo "$(RED)Target 'docker-compose' not found$(RESET)"; \
	fi
	
	@if grep -q "^traefik:" $(MAKEFILE_LIST); then \
		make traefik || { echo "$(RED)Failed to install traefik$(RESET)"; exit 1; }; \
	elif grep -q "^install-traefik:" $(MAKEFILE_LIST); then \
		make install-traefik || { echo "$(RED)Failed to install traefik$(RESET)"; exit 1; }; \
	else \
		echo "$(RED)Target 'traefik' not found$(RESET)"; \
	fi
	
	@if grep -q "^keycloak:" $(MAKEFILE_LIST); then \
		make keycloak || { echo "$(RED)Failed to install keycloak$(RESET)"; exit 1; }; \
	elif grep -q "^install-keycloak:" $(MAKEFILE_LIST); then \
		make install-keycloak || { echo "$(RED)Failed to install keycloak$(RESET)"; exit 1; }; \
	else \
		echo "$(RED)Target 'keycloak' not found$(RESET)"; \
	fi
	
	@echo "$(YELLOW)$(BOLD)🧠 Installing Monitoring & Status Components...$(RESET)"
	@if grep -q "^dashboard:" $(MAKEFILE_LIST); then \
		make dashboard || { echo "$(RED)Failed to install dashboard$(RESET)"; exit 1; }; \
	elif grep -q "^install-dashboard:" $(MAKEFILE_LIST); then \
		make install-dashboard || { echo "$(RED)Failed to install dashboard$(RESET)"; exit 1; }; \
	else \
		echo "$(RED)Target 'dashboard' not found$(RESET)"; \
	fi
	
	@if grep -q "^posthog:" $(MAKEFILE_LIST); then \
		make posthog || { echo "$(RED)Failed to install posthog$(RESET)"; exit 1; }; \
	elif grep -q "^install-posthog:" $(MAKEFILE_LIST); then \
		make install-posthog || { echo "$(RED)Failed to install posthog$(RESET)"; exit 1; }; \
	else \
		echo "$(RED)Target 'posthog' not found$(RESET)"; \
	fi
	
	@if grep -q "^prometheus:" $(MAKEFILE_LIST); then \
		make prometheus || { echo "$(RED)Failed to install prometheus$(RESET)"; exit 1; }; \
	elif grep -q "^install-prometheus:" $(MAKEFILE_LIST); then \
		make install-prometheus || { echo "$(RED)Failed to install prometheus$(RESET)"; exit 1; }; \
	else \
		echo "$(RED)Target 'prometheus' not found$(RESET)"; \
	fi
	
	@if grep -q "^grafana:" $(MAKEFILE_LIST); then \
		make grafana || { echo "$(RED)Failed to install grafana$(RESET)"; exit 1; }; \
	elif grep -q "^install-grafana:" $(MAKEFILE_LIST); then \
		make install-grafana || { echo "$(RED)Failed to install grafana$(RESET)"; exit 1; }; \
	else \
		echo "$(RED)Target 'grafana' not found$(RESET)"; \
	fi
	
	@echo "$(YELLOW)$(BOLD)📡 Installing Communication Layer...$(RESET)"
	@if grep -q "^mailu:" $(MAKEFILE_LIST); then \
		make mailu || { echo "$(RED)Failed to install mailu$(RESET)"; exit 1; }; \
	elif grep -q "^install-mailu:" $(MAKEFILE_LIST); then \
		make install-mailu || { echo "$(RED)Failed to install mailu$(RESET)"; exit 1; }; \
	else \
		echo "$(RED)Target 'mailu' not found$(RESET)"; \
	fi
	
	@if grep -q "^chatwoot:" $(MAKEFILE_LIST); then \
		make chatwoot || { echo "$(RED)Failed to install chatwoot$(RESET)"; exit 1; }; \
	elif grep -q "^install-chatwoot:" $(MAKEFILE_LIST); then \
		make install-chatwoot || { echo "$(RED)Failed to install chatwoot$(RESET)"; exit 1; }; \
	else \
		echo "$(RED)Target 'chatwoot' not found$(RESET)"; \
	fi
	
	@if grep -q "^voip:" $(MAKEFILE_LIST); then \
		make voip || { echo "$(RED)Failed to install voip$(RESET)"; exit 1; }; \
	elif grep -q "^install-voip:" $(MAKEFILE_LIST); then \
		make install-voip || { echo "$(RED)Failed to install voip$(RESET)"; exit 1; }; \
	else \
		echo "$(RED)Target 'voip' not found$(RESET)"; \
	fi
	
	@echo "$(YELLOW)$(BOLD)📝 Installing Content & UI Components...$(RESET)"
	@if grep -q "^wordpress:" $(MAKEFILE_LIST); then \
		make wordpress || { echo "$(RED)Failed to install wordpress$(RESET)"; exit 1; }; \
	elif grep -q "^install-wordpress:" $(MAKEFILE_LIST); then \
		make install-wordpress || { echo "$(RED)Failed to install wordpress$(RESET)"; exit 1; }; \
	else \
		echo "$(RED)Target 'wordpress' not found$(RESET)"; \
	fi
	
	@if grep -q "^peertube:" $(MAKEFILE_LIST); then \
		make peertube || { echo "$(RED)Failed to install peertube$(RESET)"; exit 1; }; \
	elif grep -q "^install-peertube:" $(MAKEFILE_LIST); then \
		make install-peertube || { echo "$(RED)Failed to install peertube$(RESET)"; exit 1; }; \
	else \
		echo "$(RED)Target 'peertube' not found$(RESET)"; \
	fi
	
	@if grep -q "^builderio:" $(MAKEFILE_LIST); then \
		make builderio || { echo "$(RED)Failed to install builderio$(RESET)"; exit 1; }; \
	elif grep -q "^install-builderio:" $(MAKEFILE_LIST); then \
		make install-builderio || { echo "$(RED)Failed to install builderio$(RESET)"; exit 1; }; \
	else \
		echo "$(RED)Target 'builderio' not found$(RESET)"; \
	fi
	
	@echo "$(YELLOW)$(BOLD)💼 Installing Business Logic Components...$(RESET)"
	@if grep -q "^calcom:" $(MAKEFILE_LIST); then \
		make calcom || { echo "$(RED)Failed to install calcom$(RESET)"; exit 1; }; \
	elif grep -q "^install-calcom:" $(MAKEFILE_LIST); then \
		make install-calcom || { echo "$(RED)Failed to install calcom$(RESET)"; exit 1; }; \
	else \
		echo "$(RED)Target 'calcom' not found$(RESET)"; \
	fi
	
	@if grep -q "^documenso:" $(MAKEFILE_LIST); then \
		make documenso || { echo "$(RED)Failed to install documenso$(RESET)"; exit 1; }; \
	elif grep -q "^install-documenso:" $(MAKEFILE_LIST); then \
		make install-documenso || { echo "$(RED)Failed to install documenso$(RESET)"; exit 1; }; \
	else \
		echo "$(RED)Target 'documenso' not found$(RESET)"; \
	fi
	
	@if grep -q "^erpnext:" $(MAKEFILE_LIST); then \
		make erpnext || { echo "$(RED)Failed to install erpnext$(RESET)"; exit 1; }; \
	elif grep -q "^install-erpnext:" $(MAKEFILE_LIST); then \
		make install-erpnext || { echo "$(RED)Failed to install erpnext$(RESET)"; exit 1; }; \
	else \
		echo "$(RED)Target 'erpnext' not found$(RESET)"; \
	fi
	
	@if grep -q "^focalboard:" $(MAKEFILE_LIST); then \
		make focalboard || { echo "$(RED)Failed to install focalboard$(RESET)"; exit 1; }; \
	elif grep -q "^install-focalboard:" $(MAKEFILE_LIST); then \
		make install-focalboard || { echo "$(RED)Failed to install focalboard$(RESET)"; exit 1; }; \
	else \
		echo "$(RED)Target 'focalboard' not found$(RESET)"; \
	fi
	
	@echo "$(YELLOW)$(BOLD)⚙️ Installing DevOps Components...$(RESET)"
	@if grep -q "^gitea:" $(MAKEFILE_LIST); then \
		make gitea || { echo "$(RED)Failed to install gitea$(RESET)"; exit 1; }; \
	elif grep -q "^install-gitea:" $(MAKEFILE_LIST); then \
		make install-gitea || { echo "$(RED)Failed to install gitea$(RESET)"; exit 1; }; \
	else \
		echo "$(RED)Target 'gitea' not found$(RESET)"; \
	fi
	
	@if grep -q "^droneci:" $(MAKEFILE_LIST); then \
		make droneci || { echo "$(RED)Failed to install droneci$(RESET)"; exit 1; }; \
	elif grep -q "^install-droneci:" $(MAKEFILE_LIST); then \
		make install-droneci || { echo "$(RED)Failed to install droneci$(RESET)"; exit 1; }; \
	else \
		echo "$(RED)Target 'droneci' not found$(RESET)"; \
	fi
	
	@echo ""
	@echo "$(GREEN)$(BOLD)✅ AgencyStack Demo Core components installation completed!$(RESET)"
	@echo "$(CYAN)Run 'make demo-core-status' to check the status of all components.$(RESET)"
	@echo "$(CYAN)Run 'make dashboard' to access the dashboard interface.$(RESET)"

# Clean up all demo core components
demo-core-clean:
	@echo "$(MAGENTA)$(BOLD)🧹 Cleaning up AgencyStack Demo Core components...$(RESET)"
	@for component in keycloak traefik dashboard posthog prometheus grafana mailu chatwoot voip wordpress peertube builderio calcom documenso erpnext focalboard gitea droneci; do \
		if grep -q "^$${component}-clean:" $(MAKEFILE_LIST); then \
			echo "$(CYAN)Cleaning $${component}...$(RESET)"; \
			make $${component}-clean; \
		elif grep -q "^$${component}-stop:" $(MAKEFILE_LIST); then \
			echo "$(CYAN)Stopping $${component}...$(RESET)"; \
			make $${component}-stop; \
		else \
			echo "$(YELLOW)No clean/stop target for $${component}, skipping.$(RESET)"; \
		fi; \
	done
	@echo "$(GREEN)$(BOLD)✅ AgencyStack Demo Core components cleanup completed!$(RESET)"

# Check status of all demo core components
demo-core-status:
	@echo "$(MAGENTA)$(BOLD)📊 AgencyStack Demo Core Components Status:$(RESET)"
	@echo "============================================================"
	@for component in keycloak traefik dashboard posthog prometheus grafana mailu chatwoot voip wordpress peertube builderio calcom documenso erpnext focalboard gitea droneci; do \
		echo "$(BOLD)$${component}:$(RESET)"; \
		if grep -q "^$${component}-status:" $(MAKEFILE_LIST); then \
			make $${component}-status || echo "$(RED)Status check failed.$(RESET)"; \
		else \
			echo "$(YELLOW)No status target for $${component}.$(RESET)"; \
		fi; \
		echo "------------------------------------------------------------"; \
	done
	@echo "$(GREEN)$(BOLD)✅ AgencyStack Demo Core status check completed!$(RESET)"

# Display logs for all demo core components
demo-core-logs:
	@echo "$(MAGENTA)$(BOLD)📋 AgencyStack Demo Core Components Logs:$(RESET)"
	@echo "============================================================"
	@for component in keycloak traefik dashboard posthog prometheus grafana mailu chatwoot voip wordpress peertube builderio calcom documenso erpnext focalboard gitea droneci; do \
		if grep -q "^$${component}-logs:" $(MAKEFILE_LIST); then \
			echo "$(CYAN)$(BOLD)$${component} logs:$(RESET)"; \
			make $${component}-logs; \
			echo "------------------------------------------------------------"; \
		else \
			echo "$(YELLOW)No logs target for $${component}, skipping.$(RESET)"; \
		fi; \
	done
	@echo "$(GREEN)$(BOLD)✅ AgencyStack Demo Core logs check completed!$(RESET)"
