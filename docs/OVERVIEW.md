# FOSS Server Stack Overview

This project provides a comprehensive set of scripts for deploying a complete FOSS server infrastructure using Docker containers. The stack includes a wide range of applications for business operations, communication, project management, and system monitoring.

## Components

The stack includes the following components:

| Component | Description | Use Case |
|-----------|-------------|----------|
| Docker | Container platform | Base infrastructure |
| Docker Compose | Multi-container orchestration | Container management |
| Traefik | Reverse proxy with SSL | Web traffic and security |
| Portainer | Docker management UI | Container management |
| ERPNext | Enterprise Resource Planning | Business management |
| PeerTube | Video streaming platform | Content sharing |
| WordPress | Content Management System | Website management |
| Focalboard | Project management | Team collaboration |
| Listmonk | Newsletter service | Email marketing |
| Cal.com | Scheduling system | Appointment booking |
| n8n | Workflow automation | Process automation |
| OpenIntegrationHub | Data integration platform | System integration |
| TaskWarrior/Calcure | Task management | Personal productivity |
| PostHog | Product analytics | User behavior tracking |
| KillBill | Billing system | Subscription management |
| VoIP | Voice over IP | Communication |
| Seafile | File sync and share | Document management |
| Documenso | Document signing | Contract management |
| WebPush | Push notifications | User engagement |
| Netdata | Real-time monitoring | System monitoring |
| Fail2ban | Intrusion prevention | Security |

## Architecture

This stack uses Docker containers for each component, orchestrated initially through individual scripts and connected through a shared network. Traefik serves as the reverse proxy and handles SSL termination for secure web access to all services.

## Security Features

- SSL encryption via Traefik
- Fail2ban for intrusion prevention
- Network isolation through Docker
- Additional security hardening script

## System Requirements

- Linux-based OS (Ubuntu/Debian recommended)
- Minimum 8GB RAM (16GB+ recommended)
- 50GB+ storage
- Public IP address with DNS records for web services
