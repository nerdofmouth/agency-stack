---
layout: default
title: AgencyStack Documentation
---

# AgencyStack Documentation

> "Run your agency. Reclaim your agency."

AgencyStack is a sovereign, multi-tenant, hardenable DevOps toolkit designed for agencies and businesses who want to own their technology stack. This alpha release provides a foundation for digital sovereignty with a curated set of open-source tools that work seamlessly together.

## 🚀 Core Principles

1. **Digital Sovereignty**: Own your tools, data, and infrastructure.
2. **Multi-Tenancy**: Manage multiple clients from a single installation.
3. **Security-First**: Hardened by default, with configurable security levels.
4. **Automation**: Idempotent installation, one-command deployment.
5. **Integration**: Components work together seamlessly with shared authentication and monitoring.

## 📚 Documentation Sections

- [Installation Guide](/pages/installation.html) - Get started with AgencyStack
- [Components Overview](/pages/components.html) - Browse available components
- [Environment Setup](/pages/setup/env.html) - Configure your installation
- [Port Assignments](/pages/ports.html) - Network port reference
- [Security Settings](/pages/security.html) - Secure your installation
- [Operation Guide](/pages/operations.html) - Day-to-day management
- [Client Management](/pages/client-setup.html) - Multi-tenancy configuration
- [Troubleshooting](/pages/troubleshooting.html) - Resolve common issues

## 🧩 Component Categories

AgencyStack is organized into functional categories:

### 🏗️ Core Infrastructure
- [Traefik](/pages/components/traefik.html) - Edge router and reverse proxy
- [Docker](/pages/components/docker.html) - Container runtime
- [Portainer](/pages/components/portainer.html) - Container management UI
- [DroneCI](/pages/components/droneci.html) - Continuous Integration server

### 🔒 Security
- [Keycloak](/pages/components/keycloak.html) - Identity and access management
- [Fail2Ban](/pages/components/fail2ban.html) - Intrusion prevention
- [CrowdSec](/pages/components/crowdsec.html) - Collaborative security

### 📊 Monitoring
- [Prometheus](/pages/components/prometheus.html) - Metrics collection
- [Grafana](/pages/components/grafana.html) - Metrics visualization
- [Loki](/pages/components/loki.html) - Log aggregation

### 📧 Communication
- [Mailu](/pages/components/mailu.html) - Complete email server
- [VoIP](/pages/components/voip.html) - Voice-over-IP solution
- [Chatwoot](/pages/components/chatwoot.html) - Customer messaging platform
- [Listmonk](/pages/components/listmonk.html) - Newsletter and mailing list manager

### 🧠 AI Stack
- [Ollama](/pages/components/ollama.html) - Local LLM server
- [LangChain](/pages/components/langchain.html) - AI framework
- [Vector DB](/pages/components/vector_db.html) - Vector storage
- [AI Dashboard](/pages/components/ai_dashboard.html) - AI management UI
- [Agent Orchestrator](/pages/components/agent_orchestrator.html) - AI agent management
- [Resource Watcher](/pages/components/resource_watcher.html) - Resource monitoring for AI

### 📝 Content Management
- [WordPress](/pages/components/wordpress.html) - CMS platform
- [Ghost](/pages/components/ghost.html) - Publishing platform
- [PeerTube](/pages/components/peertube.html) - Video streaming
- [Seafile](/pages/components/seafile.html) - File sync and share
- [Focalboard](/pages/components/focalboard.html) - Project management
- [Builder.io](/pages/components/builderio.html) - Visual content management

### 💼 Business Applications
- [ERPNext](/pages/components/erpnext.html) - Enterprise Resource Planning
- [KillBill](/pages/components/killbill.html) - Billing and invoicing
- [Cal.com](/pages/components/cal.html) - Scheduling platform
- [Documenso](/pages/components/documenso.html) - Document signing

### 🔄 Integration
- [n8n](/pages/components/n8n.html) - Workflow automation
- [OpenIntegrationHub](/pages/components/openintegrationhub.html) - Data integration platform
- [CryptoSync](/pages/components/cryptosync.html) - Secure file synchronization

## 🛠️ Administration Tools

AgencyStack includes several built-in tools to help you manage your installation:

```bash
# Check status of all components
make alpha-check

# Validate environment configuration
make env-check

# Generate documentation index
make docs-index

# View component-specific logs
make <component>-logs

# Check status of specific component
make <component>-status

# Restart a component
make <component>-restart
```

## 🔗 Resources

- [GitHub Repository](https://github.com/nerdofmouth/agency-stack)
- [Bug Tracker](https://github.com/nerdofmouth/agency-stack/issues)
- [Alpha Milestone](/pages/components/alpha_ready.html)
