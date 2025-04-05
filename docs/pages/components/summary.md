---
layout: default
title: Component Integration Status - AgencyStack Documentation
---

# AgencyStack Component Integration Status

This document provides a comprehensive overview of all components in the AgencyStack ecosystem and their integration status. It is automatically generated from the authoritative `component_registry.json` file.

Last updated: April 05, 2025

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

## Business Applications

| Component | Version | Installed | Hardened | Makefile | SSO | Dashboard | Logs | Docs | Auditable | Traefik TLS | Multi-tenant |
|-----------|---------|:---------:|:--------:|:--------:|:---:|:---------:|:----:|:----:|:---------:|:-----------:|:------------:|
| **Cal.com** | 2.9.4 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Documenso** | 1.3.0 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **ERPNext** | 14.0.0 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **KillBill** | 0.24.0 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |


## Email & Communication

| Component | Version | Installed | Hardened | Makefile | SSO | Dashboard | Logs | Docs | Auditable | Traefik TLS | Multi-tenant |
|-----------|---------|:---------:|:--------:|:--------:|:---:|:---------:|:----:|:----:|:---------:|:-----------:|:------------:|
| **Listmonk** | v2.5.1 | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Mailu** | 2.0.0 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Mattermost** | 7.10.0 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **VoIP** | 1.0.0 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |


## Content Management

| Component | Version | Installed | Hardened | Makefile | SSO | Dashboard | Logs | Docs | Auditable | Traefik TLS | Multi-tenant |
|-----------|---------|:---------:|:--------:|:--------:|:---:|:---------:|:----:|:----:|:---------:|:-----------:|:------------:|
| **Builder.io** | 2.0.0 | ✅ | ❌ | ✅ | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| **Focalboard** | 7.8.0 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Ghost** | 5.59.0 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **PeerTube** | 5.1.0 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Seafile** | 10.0.1 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **WordPress** | 6.4.2 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |


## Core Infrastructure

| Component | Version | Installed | Hardened | Makefile | SSO | Dashboard | Logs | Docs | Auditable | Traefik TLS | Multi-tenant |
|-----------|---------|:---------:|:--------:|:--------:|:---:|:---------:|:----:|:----:|:---------:|:-----------:|:------------:|
| **DroneCI** | 2.16.0 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| **Portainer** | 2.17.1 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| **Traefik** | 2.9.8 | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |


## Monitoring & Observability

| Component | Version | Installed | Hardened | Makefile | SSO | Dashboard | Logs | Docs | Auditable | Traefik TLS | Multi-tenant |
|-----------|---------|:---------:|:--------:|:--------:|:---:|:---------:|:----:|:----:|:---------:|:-----------:|:------------:|
| **Grafana** | 10.1.0 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Loki** | 2.9.0 | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Prometheus** | 2.44.0 | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |


## Security & Identity

| Component | Version | Installed | Hardened | Makefile | SSO | Dashboard | Logs | Docs | Auditable | Traefik TLS | Multi-tenant |
|-----------|---------|:---------:|:--------:|:--------:|:---:|:---------:|:----:|:----:|:---------:|:-----------:|:------------:|
| **CrowdSec** | 1.5.0 | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| **Keycloak** | 22.0.1 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Vault** | 1.14.0 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |


## Integration Completion Status

### Overall Status

- **Total Components**: 23
- **Fully Integrated Components**: 15 (65%)
- **Partially Integrated Components**: 8 (34%)
- **Components Needing Attention**: 2 (8%)

### Integration Areas Needing Attention

1. **Builder.io**: Needs hardened, sso, multi_tenant
1. **CrowdSec**: Needs sso, multi_tenant

## How to Update this Document

This document is automatically generated from the `component_registry.json` file. To update component status:

1. Edit the `/config/registry/component_registry.json` file
2. Run the component registry update utility
3. Commit the changes to the repository

Please do not edit this document directly as changes will be overwritten.
