---
layout: default
title: Component Integration Status - AgencyStack Documentation
---

# AgencyStack Component Integration Status

This document provides a comprehensive overview of all components in the AgencyStack ecosystem and their integration status. It is automatically generated from the authoritative `component_registry.json` file.

Last updated: April 24, 2025

## Integration Status Legend

Each component is evaluated against the following integration criteria:

| Criteria | Description |
|----------|-------------|
| **Installed** | Installation is complete and tested |
| **Hardened** | System is validated with idempotent operation and proper flags |
| **Makefile** | Component has proper Makefile support |
| **SSO** | Integrated with Keycloak SSO where applicable |
| **Dashboard** | Registered in dashboard and dashboard_data.json |
| **Logs** | Writes component-specific logs to the log system |
| **Docs** | Has proper entries in components.md, ports.md, etc. |
| **Auditable** | Properly handled by audit/tracking system |
| **Traefik TLS** | Has proper reverse proxy config with TLS |
| **Multi-tenant** | Supports client-aware installation or usage patterns |
| **OAuth IDP Configured** | OAuth IDP is configured for the component |

## Ai

| Component | Version | Installed | Hardened | Makefile | SSO | Dashboard | Logs | Docs | Auditable | Traefik TLS | Multi-tenant | OAuth IDP Configured |
|-----------|---------|:---------:|:--------:|:--------:|:---:|:---------:|:----:|:----:|:---------:|:-----------:|:------------:|:-------------------:|
| **Ollama** | 0.1.27 | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ | ❌ |


## Business Applications

| Component | Version | Installed | Hardened | Makefile | SSO | Dashboard | Logs | Docs | Auditable | Traefik TLS | Multi-tenant | OAuth IDP Configured |
|-----------|---------|:---------:|:--------:|:--------:|:---:|:---------:|:----:|:----:|:---------:|:-----------:|:------------:|:-------------------:|
| **Cal.com** | 2.9.4 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| **Chatwoot** | v3.5.0 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| **Documenso** | 1.4.2 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| **ERPNext** | 14.0.0 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| **KillBill** | 0.24.0 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |


## Collaboration

| Component | Version | Installed | Hardened | Makefile | SSO | Dashboard | Logs | Docs | Auditable | Traefik TLS | Multi-tenant | OAuth IDP Configured |
|-----------|---------|:---------:|:--------:|:--------:|:---:|:---------:|:----:|:----:|:---------:|:-----------:|:------------:|:-------------------:|
| **Etebase** | v0.7.0 | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ | ❌ |


## Email & Communication

| Component | Version | Installed | Hardened | Makefile | SSO | Dashboard | Logs | Docs | Auditable | Traefik TLS | Multi-tenant | OAuth IDP Configured |
|-----------|---------|:---------:|:--------:|:--------:|:---:|:---------:|:----:|:----:|:---------:|:-----------:|:------------:|:-------------------:|
| **Listmonk** | 4.1.0 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| **Mailu** | 1.9 | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| **Mattermost** | 7.10.0 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| **VoIP** | 1.0.0 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |


## Content Management

| Component | Version | Installed | Hardened | Makefile | SSO | Dashboard | Logs | Docs | Auditable | Traefik TLS | Multi-tenant | OAuth IDP Configured |
|-----------|---------|:---------:|:--------:|:--------:|:---:|:---------:|:----:|:----:|:---------:|:-----------:|:------------:|:-------------------:|
| **Builder.io** | 2.0.0 | ✅ | ❌ | ✅ | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ |
| **Focalboard** | 7.8.0 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| **Ghost** | 5.59.0 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| **PeerTube** | 7.0.0 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| **Seafile** | 10.0.1 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| **WordPress** | 6.4.2 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |


## Devops

| Component | Version | Installed | Hardened | Makefile | SSO | Dashboard | Logs | Docs | Auditable | Traefik TLS | Multi-tenant | OAuth IDP Configured |
|-----------|---------|:---------:|:--------:|:--------:|:---:|:---------:|:----:|:----:|:---------:|:-----------:|:------------:|:-------------------:|
| **Drone CI** | 2.16.0 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| **Gitea** | 1.20.0 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |


## Core Infrastructure

| Component | Version | Installed | Hardened | Makefile | SSO | Dashboard | Logs | Docs | Auditable | Traefik TLS | Multi-tenant | OAuth IDP Configured |
|-----------|---------|:---------:|:--------:|:--------:|:---:|:---------:|:----:|:----:|:---------:|:-----------:|:------------:|:-------------------:|
| **Docker** | latest | ✅ | ✅ | ✅ | ❌ | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| **Docker Compose** | latest | ✅ | ✅ | ✅ | ❌ | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| **DroneCI** | 2.25.0 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ |
| **pgvector** | 0.5.1 | ❌ | ✅ | ✅ | ❌ | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| **Portainer** | 2.17.1 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ |
| **Pre-Flight Check** | 1.0.0 | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| **System Prerequisites** | 1.0.0 | ✅ | ✅ | ✅ | ❌ | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| **Traefik** | 2.9.8 | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |


## Monitoring & Observability

| Component | Version | Installed | Hardened | Makefile | SSO | Dashboard | Logs | Docs | Auditable | Traefik TLS | Multi-tenant | OAuth IDP Configured |
|-----------|---------|:---------:|:--------:|:--------:|:---:|:---------:|:----:|:----:|:---------:|:-----------:|:------------:|:-------------------:|
| **Grafana** | 10.1.0 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| **Loki** | 2.9.0 | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| **Prometheus** | 2.44.0 | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |


## Security & Identity

| Component | Version | Installed | Hardened | Makefile | SSO | Dashboard | Logs | Docs | Auditable | Traefik TLS | Multi-tenant | OAuth IDP Configured |
|-----------|---------|:---------:|:--------:|:--------:|:---:|:---------:|:----:|:----:|:---------:|:-----------:|:------------:|:-------------------:|
| **CrowdSec** | 1.5.0 | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ |
| **Fail2ban** | latest | ✅ | ✅ | ✅ | ❌ | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| **Keycloak** | 22.0.1 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| **Security Hardening** | 1.0.0 | ✅ | ✅ | ✅ | ❌ | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| **Signing & Timestamps** | 1.0.0 | ✅ | ✅ | ✅ | ❌ | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| **Vault** | 1.14.0 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |


## Security_storage

| Component | Version | Installed | Hardened | Makefile | SSO | Dashboard | Logs | Docs | Auditable | Traefik TLS | Multi-tenant | OAuth IDP Configured |
|-----------|---------|:---------:|:--------:|:--------:|:---:|:---------:|:----:|:----:|:---------:|:-----------:|:------------:|:-------------------:|
| **Backup Strategy** | 1.0.0 | ✅ | ✅ | ✅ | ❌ | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| **Cryptosync** | v1.0.0 | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ | ❌ |


## Integration Completion Status

### Overall Status

- **Total Components**: 38
- **Fully Integrated Components**: 18 (47%)
- **Partially Integrated Components**: 20 (52%)
- **Components Needing Attention**: 12 (31%)

### Integration Areas Needing Attention

1. **Ollama**: Needs sso_ready, traefik
1. **Builder.io**: Needs hardened, sso, multi_tenant
1. **Docker**: Needs sso, dashboard
1. **Docker Compose**: Needs sso, dashboard
1. **pgvector**: Needs installed, sso, dashboard
1. **System Prerequisites**: Needs sso, dashboard
1. **CrowdSec**: Needs sso, multi_tenant
1. **Fail2ban**: Needs sso, dashboard
1. **Security Hardening**: Needs sso, dashboard
1. **Signing & Timestamps**: Needs sso, dashboard
1. **Backup Strategy**: Needs sso, dashboard
1. **Cryptosync**: Needs sso_ready, monitoring, traefik, ports_defined

## How to Update this Document

This document is automatically generated from the `component_registry.json` file. To update component status:

1. Edit the `/config/registry/component_registry.json` file
2. Run the component registry update utility
3. Commit the changes to the repository

Please do not edit this document directly as changes will be overwritten.
