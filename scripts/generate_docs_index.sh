#!/bin/bash
# AgencyStack - Documentation Index Generator
# Generates a table of contents and indexes for all documentation

# Colors
BOLD="\033[1m"
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
MAGENTA="\033[35m"
CYAN="\033[36m"
RESET="\033[0m"

# File paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
DOCS_DIR="${BASE_DIR}/docs"
PAGES_DIR="${DOCS_DIR}/pages"
COMPONENTS_DIR="${PAGES_DIR}/components"
SETUP_DIR="${PAGES_DIR}/setup"

# Logging
LOG_FILE="/var/log/agency_stack/docs_index.log"
mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true

# Create directories if they don't exist
mkdir -p "$COMPONENTS_DIR" 2>/dev/null || true
mkdir -p "$SETUP_DIR" 2>/dev/null || true

# Function to generate component documentation index
generate_components_index() {
  echo "Generating components index..."
  
  local output_file="${PAGES_DIR}/components.md"
  
  # Header
  cat > "$output_file" << EOF
# AgencyStack Components

This page provides an overview of all components available in AgencyStack.

## Core Infrastructure

These components provide the foundation for AgencyStack:

| Component | Description | Status |
|-----------|-------------|--------|
EOF

  # Add core infrastructure components
  for component in docker docker_compose traefik_ssl portainer; do
    local title=$(echo "$component" | tr '_' ' ' | sed -r 's/\<./\U&/g')
    local desc=""
    local status="✓"
    
    case "$component" in
      docker) desc="Container engine for running services" ;;
      docker_compose) desc="Multi-container Docker applications" ;;
      traefik_ssl) desc="Edge router with automatic SSL" ;;
      portainer) desc="Visual Docker management" ;;
      *) desc="Core infrastructure component" ;;
    esac
    
    echo "| [$title](components/${component}.md) | $desc | $status |" >> "$output_file"
  done

  # Security section
  cat >> "$output_file" << EOF

## Security

Components for security, monitoring, and access control:

| Component | Description | Status |
|-----------|-------------|--------|
EOF

  # Add security components
  for component in keycloak fail2ban crowdsec security cryptosync; do
    local title=$(echo "$component" | tr '_' ' ' | sed -r 's/\<./\U&/g')
    local desc=""
    local status="✓"
    
    case "$component" in
      keycloak) desc="Single Sign-On and Identity Management" ;;
      fail2ban) desc="Intrusion prevention system" ;;
      crowdsec) desc="Collaborative security platform" ;;
      security) desc="Security infrastructure and hardening" ;;
      cryptosync) desc="Encrypted storage and sync" ;;
      *) desc="Security component" ;;
    esac
    
    echo "| [$title](components/${component}.md) | $desc | $status |" >> "$output_file"
  done

  # Monitoring section
  cat >> "$output_file" << EOF

## Monitoring and Observability

Components for system monitoring, logging, and analytics:

| Component | Description | Status |
|-----------|-------------|--------|
EOF

  # Add monitoring components
  for component in prometheus grafana loki netdata posthog; do
    local title=$(echo "$component" | tr '_' ' ' | sed -r 's/\<./\U&/g')
    local desc=""
    local status="✓"
    
    case "$component" in
      prometheus) desc="Metrics collection and monitoring" ;;
      grafana) desc="Data visualization and dashboards" ;;
      loki) desc="Log aggregation system" ;;
      netdata) desc="Real-time performance monitoring" ;;
      posthog) desc="Product analytics platform" ;;
      *) desc="Monitoring component" ;;
    esac
    
    echo "| [$title](components/${component}.md) | $desc | $status |" >> "$output_file"
  done

  # Content Management section
  cat >> "$output_file" << EOF

## Content Management

Web and media content management systems:

| Component | Description | Status |
|-----------|-------------|--------|
EOF

  # Add CMS components
  for component in wordpress ghost peertube seafile focalboard builderio; do
    local title=$(echo "$component" | tr '_' ' ' | sed -r 's/\<./\U&/g')
    local desc=""
    local status="✓"
    
    case "$component" in
      wordpress) desc="Website and content management system" ;;
      ghost) desc="Modern publishing platform" ;;
      peertube) desc="Self-hosted video platform" ;;
      seafile) desc="File sync and share solution" ;;
      focalboard) desc="Project management system" ;;
      builderio) desc="Visual page builder" ;;
      *) desc="Content management component" ;;
    esac
    
    echo "| [$title](components/${component}.md) | $desc | $status |" >> "$output_file"
  done

  # Database section
  cat >> "$output_file" << EOF

## Databases and Storage

Database systems and storage solutions:

| Component | Description | Status |
|-----------|-------------|--------|
EOF

  # Add database components
  for component in elasticsearch etcd vector_db; do
    local title=$(echo "$component" | tr '_' ' ' | sed -r 's/\<./\U&/g')
    local desc=""
    local status="✓"
    
    case "$component" in
      elasticsearch) desc="Distributed search and analytics engine" ;;
      etcd) desc="Distributed key-value store" ;;
      vector_db) desc="Vector database for AI applications" ;;
      *) desc="Database component" ;;
    esac
    
    echo "| [$title](components/${component}.md) | $desc | $status |" >> "$output_file"
  done

  # Communication section
  cat >> "$output_file" << EOF

## Communication and Email

Email, chat, and communication systems:

| Component | Description | Status |
|-----------|-------------|--------|
EOF

  # Add communication components
  for component in mailu listmonk chatwoot webpush; do
    local title=$(echo "$component" | tr '_' ' ' | sed -r 's/\<./\U&/g')
    local desc=""
    local status="✓"
    
    case "$component" in
      mailu) desc="Complete mail server solution" ;;
      listmonk) desc="Newsletter and mailing list manager" ;;
      chatwoot) desc="Customer engagement suite" ;;
      webpush) desc="Web push notification service" ;;
      *) desc="Communication component" ;;
    esac
    
    echo "| [$title](components/${component}.md) | $desc | $status |" >> "$output_file"
  done

  # Integration section
  cat >> "$output_file" << EOF

## Integration and Workflow

Automation and integration platforms:

| Component | Description | Status |
|-----------|-------------|--------|
EOF

  # Add integration components
  for component in n8n openintegrationhub droneci; do
    local title=$(echo "$component" | tr '_' ' ' | sed -r 's/\<./\U&/g')
    local desc=""
    local status="✓"
    
    case "$component" in
      n8n) desc="Workflow automation platform" ;;
      openintegrationhub) desc="Integration framework" ;;
      droneci) desc="Continuous integration server" ;;
      *) desc="Integration component" ;;
    esac
    
    echo "| [$title](components/${component}.md) | $desc | $status |" >> "$output_file"
  done

  # AI section
  cat >> "$output_file" << EOF

## AI and Automation

Artificial intelligence and automation components:

| Component | Description | Status |
|-----------|-------------|--------|
EOF

  # Add AI components
  for component in ollama langchain ai_dashboard agent_orchestrator resource_watcher; do
    local title=$(echo "$component" | tr '_' ' ' | sed -r 's/\<./\U&/g' | sed 's/Ai/AI/g')
    local desc=""
    local status="✓"
    
    case "$component" in
      ollama) desc="Local LLM serving platform" ;;
      langchain) desc="AI orchestration framework" ;;
      ai_dashboard) desc="AI management dashboard" ;;
      agent_orchestrator) desc="Agent orchestration system" ;;
      resource_watcher) desc="Resource monitoring for AI" ;;
      *) desc="AI component" ;;
    esac
    
    echo "| [$title](components/${component}.md) | $desc | $status |" >> "$output_file"
  done

  # Utilities section
  cat >> "$output_file" << EOF

## Utilities and Special Components

Utility components and special features:

| Component | Description | Status |
|-----------|-------------|--------|
EOF

  # Add utility components
  for component in multi_tenancy taskwarrior_calcure backup_strategy launchpad_dashboard tailscale; do
    local title=$(echo "$component" | tr '_' ' ' | sed -r 's/\<./\U&/g')
    local desc=""
    local status="✓"
    
    case "$component" in
      multi_tenancy) desc="Multi-client environment support" ;;
      taskwarrior_calcure) desc="Task and calendar management" ;;
      backup_strategy) desc="Automated backup system" ;;
      launchpad_dashboard) desc="Quick access dashboard" ;;
      tailscale) desc="Secure network access" ;;
      *) desc="Utility component" ;;
    esac
    
    echo "| [$title](components/${component}.md) | $desc | $status |" >> "$output_file"
  done

  # Footer
  cat >> "$output_file" << EOF

## Alpha Status

For details on the component integration status and alpha readiness:

- [Alpha Readiness Status](components/alpha_ready.md)
- [Component Status Summary](components/summary.md)

## Working with Components

- To install a component: \`make <component>\`
- To check component status: \`make <component>-status\`
- To view component logs: \`make <component>-logs\`
- To restart a component: \`make <component>-restart\`
EOF

  echo -e "${GREEN}✓ Components index generated at $output_file${RESET}"
}

# Function to generate ports documentation
generate_ports_doc() {
  echo "Generating ports documentation..."
  
  local output_file="${PAGES_DIR}/ports.md"
  
  # Header
  cat > "$output_file" << EOF
# AgencyStack Port Reference

This document lists all ports used by AgencyStack components. This is useful for:
- Firewall configuration
- Port conflict resolution
- Debugging connectivity issues

## Core System Ports

| Component | Port | Protocol | Purpose | Access |
|-----------|------|----------|---------|--------|
| Traefik | 80 | HTTP | Web traffic | Public |
| Traefik | 443 | HTTPS | Secure web traffic | Public |
| Traefik | 8080 | HTTP | Dashboard | Private |
| Docker | 2375 | HTTP | Docker API | Private |
| Portainer | 9000 | HTTP | Container management | Private |

## Infrastructure Ports

| Component | Port | Protocol | Purpose | Access |
|-----------|------|----------|---------|--------|
| Prometheus | 9090 | HTTP | Metrics & monitoring | Private |
| Grafana | 3000 | HTTP | Dashboards & visualization | Private |
| Loki | 3100 | HTTP | Log aggregation | Private |
| Keycloak | 8180 | HTTP | Authentication | Private |
| Etcd | 2379 | HTTP | Key-value store | Private |
| Etcd | 2380 | HTTP | Cluster communication | Private |

## Content & Media Ports

| Component | Port | Protocol | Purpose | Access |
|-----------|------|----------|---------|--------|
| WordPress | 8000 | HTTP | CMS | Private |
| Ghost | 2368 | HTTP | Publishing platform | Private |
| PeerTube | 9000 | HTTP | Video platform | Private |
| PeerTube | 1935 | RTMP | Video streaming | Private |
| PeerTube | 9001 | HTTP | Admin interface | Private |
| Seafile | 8082 | HTTP | File storage | Private |
| Focalboard | 8989 | HTTP | Project management | Private |
| Builder.io | 3030 | HTTP | Visual editor | Private |

## Database & Storage Ports

| Component | Port | Protocol | Purpose | Access |
|-----------|------|----------|---------|--------|
| PostgreSQL | 5432 | TCP | Database | Private |
| MySQL | 3306 | TCP | Database | Private |
| Redis | 6379 | TCP | Cache | Private |
| MongoDB | 27017 | TCP | Document DB | Private |
| ElasticSearch | 9200 | HTTP | Search engine | Private |
| ElasticSearch | 9300 | TCP | Cluster communication | Private |
| Vector DB | 6333 | HTTP | Vector database | Private |

## Communication Ports

| Component | Port | Protocol | Purpose | Access |
|-----------|------|----------|---------|--------|
| Mailu | 25 | SMTP | Email sending | Public |
| Mailu | 465 | SMTPS | Secure email sending | Public |
| Mailu | 587 | SMTP | Email submission | Public |
| Mailu | 110 | POP3 | Email retrieval | Public |
| Mailu | 995 | POP3S | Secure email retrieval | Public |
| Mailu | 143 | IMAP | Email access | Public |
| Mailu | 993 | IMAPS | Secure email access | Public |
| Mailu | 8081 | HTTP | Admin interface | Private |
| Listmonk | 9001 | HTTP | Newsletter service | Private |
| ChatWoot | 3002 | HTTP | Chat platform | Private |
| WebPush | 8085 | HTTP | Push notifications | Private |

## Integration & Workflow Ports

| Component | Port | Protocol | Purpose | Access |
|-----------|------|----------|---------|--------|
| n8n | 5678 | HTTP | Workflow automation | Private |
| OpenIntegrationHub | 8080 | HTTP | Integration framework | Private |
| DroneCI | 8090 | HTTP | CI/CD platform | Private |

## AI & Automation Ports

| Component | Port | Protocol | Purpose | Access |
|-----------|------|----------|---------|--------|
| Ollama | 11434 | HTTP | LLM serving | Private |
| LangChain | 8000 | HTTP | AI orchestration | Private |
| AI Dashboard | 8888 | HTTP | AI management | Private |
| Agent Orchestrator | 7007 | HTTP | Agent API | Private |
| Resource Watcher | 7008 | HTTP | Resource monitoring | Private |

## Port Conflict Resolution

If you encounter port conflicts:

1. Use \`make detect-ports\` to identify conflicts
2. Use \`make remap-ports\` to automatically resolve conflicts
3. Or manually edit the component's configuration to use a different port

## Port Management

All AgencyStack components are configured to work with Traefik, meaning you typically access all services through a subdomain on port 443 (HTTPS), regardless of the internal port used by the service.
EOF

  echo -e "${GREEN}✓ Ports documentation generated at $output_file${RESET}"
}

# Function to generate main index
generate_main_index() {
  echo "Generating main documentation index..."
  
  local output_file="${PAGES_DIR}/index.md"
  
  # Create index.md
  cat > "$output_file" << EOF
# AgencyStack Documentation

Welcome to the AgencyStack documentation. AgencyStack is a comprehensive, integrated infrastructure and application stack for agencies, enterprises, and creators who want to own their digital tools.

## Getting Started

- [Installation Guide](installation.md) - How to install AgencyStack
- [Pre-Installation Checklist](/PRE_INSTALLATION_CHECKLIST.md) - Requirements and preparation
- [Environment Configuration](setup/env.md) - Configure your AgencyStack environment
- [First-Time Setup](client-setup.md) - Initial configuration after installation

## Core Areas

### Infrastructure

- [Components](components.md) - All available components
- [Port Reference](ports.md) - Port allocations and management
- [Security](security.md) - Security considerations and hardening
- [Multi-Tenancy](tenancy.md) - Multi-client environment setup

### AI Suite

- [AI Dashboard](ai/dashboard.md) - AI management interface
- [Ollama](components/ollama.md) - Local LLM serving
- [LangChain](ai/langchain.md) - AI orchestration framework
- [Agent Orchestrator](ai/agent_orchestrator.md) - Agent management
- [Resource Watcher](ai/resource_watcher.md) - Resource monitoring
- [Mock Mode](ai/mock_mode.md) - Test without external dependencies
- [Alpha Status](ai/alpha_status.md) - AI suite readiness

### UI & Dashboard

- [Dashboard](dashboard.md) - Main control panel
- [UI Alpha Check](ui/alpha_status.md) - UI readiness
- [Customization](ui/customization.md) - Customize the dashboard
- [Widgets](ui/widgets.md) - Available dashboard widgets

### DevOps & Maintenance

- [DevOps Rules](/docs/dev/hardening.md) - Infrastructure standards
- [Operations](operations.md) - Day-to-day operations
- [Maintenance](maintenance.md) - System maintenance
- [Cron Jobs](cron.md) - Scheduled tasks
- [Backup Strategy](components/backup_strategy.md) - Data backup and recovery
- [Self-Healing](self-healing.md) - Automatic recovery
- [Audit & Cleanup](audit.md) - System auditing

### Integration & Workflow

- [Integrations](integrations.md) - Component integrations
- [DroneCI Guide](droneci-guide.md) - CI/CD setup
- [Builder.io Integration](builderio-integration.md) - Page builder

## Troubleshooting

- [Troubleshooting Guide](troubleshooting.md) - Common issues and solutions
- [Logs](logs.md) - Log locations and analysis
- [Alerts](alerts.md) - Alert system

## Demo & Development

- [Demo Setup](demo-setup.md) - Setting up a demo environment
- [VOIP Client Setup](voip-client-setup.md) - Configure VoIP clients
- [Development Guidelines](dev/hardening.md) - For contributors

## Alpha Status Check

- [Alpha Check](alpha_check.md) - Overall system readiness
- [Component Status Summary](components/summary.md) - Component integration status
EOF

  echo -e "${GREEN}✓ Main index generated at $output_file${RESET}"
}

# Create stub files for any missing required documents
create_stub_files() {
  echo "Creating stub files for missing documents..."
  
  local stubs=(
    "${PAGES_DIR}/alpha_check.md"
    "${COMPONENTS_DIR}/summary.md"
    "${COMPONENTS_DIR}/alpha_ready.md"
    "${PAGES_DIR}/logs.md"
  )
  
  for stub in "${stubs[@]}"; do
    if [ ! -f "$stub" ]; then
      mkdir -p "$(dirname "$stub")" 2>/dev/null || true
      echo "# $(basename "${stub%.md}" | tr '_' ' ' | sed -r 's/\<./\U&/g')" > "$stub"
      echo "" >> "$stub"
      echo "This document is under construction." >> "$stub"
      echo -e "${YELLOW}⚠️ Created stub file: $stub${RESET}"
    fi
  done
}

# Update docs index in the Makefile help
update_makefile_help() {
  echo "Updating Makefile docs-index help entry..."
  
  local makefile="${BASE_DIR}/Makefile"
  
  if grep -q "make docs-index" "$makefile"; then
    echo -e "${GREEN}✓ docs-index already in Makefile help${RESET}"
  else
    echo -e "${YELLOW}⚠️ docs-index not found in Makefile help, please add it manually${RESET}"
  fi
}

# Main function
main() {
  echo -e "${MAGENTA}${BOLD}📚 AgencyStack Documentation Index Generator${RESET}"
  echo -e "${BLUE}Generating documentation indexes and TOC...${RESET}"
  echo ""
  
  # Create stub files
  create_stub_files
  
  # Generate documentation
  generate_components_index
  generate_ports_doc
  generate_main_index
  
  # Update Makefile help
  update_makefile_help
  
  echo ""
  echo -e "${GREEN}${BOLD}✓ Documentation indexes generated successfully!${RESET}"
  echo "$(date): Documentation indexes generated" >> "$LOG_FILE"
  
  return 0
}

# Run main function
main "$@"
exit $?
