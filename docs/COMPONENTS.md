# Stack Components

This document describes each component in the FOSS server stack and explains its purpose and configuration.

## Core Infrastructure

### Docker
- **Description**: Containerization platform that packages applications and their dependencies
- **Usage**: Provides isolated environments for each service
- **Configuration**: Installed via the standard Docker installation script

### Docker Compose
- **Description**: Tool for defining and running multi-container Docker applications
- **Usage**: Manages the configuration and deployment of complex applications
- **Configuration**: Installed alongside Docker

### Traefik
- **Description**: Modern HTTP reverse proxy and load balancer
- **Usage**: Routes traffic to the appropriate services and handles SSL termination
- **Configuration**: Configuration files in the `traefik` directory

### Portainer
- **Description**: Docker management UI
- **Usage**: Web interface for managing Docker containers, images, networks, and volumes
- **Access**: Available at `https://your-server-ip:9443` after installation

## Business Applications

### ERPNext
- **Description**: Open-source ERP system
- **Usage**: Comprehensive business management including accounting, inventory, CRM, and HR
- **Configuration**: Requires initial setup through the web interface

### KillBill
- **Description**: Open-source subscription billing platform
- **Usage**: Handles recurring billing, invoicing, and payment processing
- **Configuration**: Requires API configuration and payment gateway setup

### Cal.com
- **Description**: Open-source scheduling infrastructure
- **Usage**: Appointment scheduling and calendar management
- **Configuration**: Requires user account setup and calendar integration

### Documenso
- **Description**: Open-source DocuSign alternative
- **Usage**: Digital document signing and management
- **Configuration**: Requires initial setup for document templates and user accounts

## Content Management

### WordPress
- **Description**: Content management system
- **Usage**: Website creation and management
- **Configuration**: Requires database setup and theme configuration

### PeerTube
- **Description**: Decentralized video platform
- **Usage**: Video hosting and streaming
- **Configuration**: Requires initial admin account setup

### Seafile
- **Description**: File sync and share platform
- **Usage**: Document storage, sharing, and collaboration
- **Configuration**: Requires initial setup and user management

### Builder.io
- **Description**: Headless CMS and visual content editor
- **Usage**: Enables content managers to visually build and edit web content without coding
- **Configuration**: Requires an account and API key from Builder.io
- **Integration**: Automated provisioning available via `builderio_provision.sh` script
- **Client Setup**: Can be enabled per client by setting `BUILDER_ENABLE=true` in the client's `.env` file

## Team Collaboration

### Focalboard
- **Description**: Project management tool
- **Usage**: Kanban boards and project tracking
- **Configuration**: Can be used standalone or integrated with other systems

### TaskWarrior/Calcure
- **Description**: Task management tools
- **Usage**: Personal and team task organization
- **Configuration**: Minimal setup required for basic usage

## Marketing and Analytics

### Listmonk
- **Description**: Self-hosted newsletter and mailing list manager
- **Usage**: Email marketing campaigns and subscriber management
- **Configuration**: Requires SMTP server configuration

### PostHog
- **Description**: Open-source product analytics
- **Usage**: Track user behavior and product usage
- **Configuration**: Requires integration with web applications

### WebPush
- **Description**: Push notification service
- **Usage**: Engage users with browser notifications
- **Configuration**: Requires integration with web applications

## Integration and Automation

### n8n
- **Description**: Workflow automation tool
- **Usage**: Connect various applications and automate processes
- **Configuration**: Create workflows through the visual editor

### OpenIntegrationHub
- **Description**: Open-source integration framework
- **Usage**: Connect different applications and data sources
- **Configuration**: Requires connector setup for each integration

## System Monitoring and Security

### Netdata
- **Description**: Real-time performance monitoring
- **Usage**: Track system metrics and application health
- **Access**: Available via web interface after installation

### Fail2ban
- **Description**: Intrusion prevention system
- **Usage**: Monitors logs and bans suspicious IP addresses
- **Configuration**: Default configuration targets SSH, can be extended to other services

### VoIP
- **Description**: Voice over IP system
- **Usage**: Internet-based telephony services
- **Configuration**: Requires SIP account setup and network configuration

## New Components

### Keycloak
- **Description**: Identity and access management system
- **Usage**: Provides single sign-on (SSO), realms, user federation, and role-based access
- **Configuration**: Requires admin login and realm/client setup
- **Access**: Available at `https://keycloak.example.com` after installation

### Tailscale
- **Description**: Mesh VPN built on WireGuard
- **Usage**: Secure internal network for admin access, multi-VM trust zones
- **Configuration**: Link with Tailscale auth and enable tailscale up at boot
- **Integration**: Can be used to securely access internal services

### Signing & Timestamps (GPG + OpenTimestamps)
- **Description**: Decentralized document signing & integrity verification
- **Usage**: Ensures verifiability and timeproof of documents & log entries
- **Configuration**: CLI tools, default GPG key per host, logs pipe to timestamped signed chain
- **Security**: Provides cryptographic proof of document existence and integrity

### Backup Strategy (Restic)
- **Description**: Encrypted offsite incremental backup system
- **Usage**: Data durability & disaster recovery
- **Configuration**: Scheduled backup jobs with .env-based repo/credential configs
- **Features**: Efficient deduplication, encryption, and compression

### Markdown + Lexical
- **Description**: Document editing + collaboration
- **Usage**: Internal docs, UX flows, policies, product knowledge bases
- **Configuration**: Git-based markdown editing, optionally integrated into frontend apps
- **Components**: Includes HedgeDoc, Gitea, and Lexical-based editor

### Launchpad Dashboard
- **Description**: Obfuscated or internal homepage
- **Usage**: Aggregates access to all apps/services, fallback monitoring landing
- **Configuration**: Hosted on dashboard.$DOMAIN or internal port
- **Features**: Service status monitoring, unified access, customizable theme
