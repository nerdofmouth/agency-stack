# Traefik-Keycloak Integration

This component provides a secure integration between Traefik and Keycloak for dashboard authentication.

## Overview

The Traefik-Keycloak integration provides:
- A Traefik reverse proxy for service routing and load balancing
- Keycloak as the identity provider for SSO following the AgencyStack SSO protocol
- Forward authentication to protect the Traefik dashboard

## Installation



## Configuration

The component is configured through the following files:
- `/opt/agency_stack/clients/${CLIENT_ID}/traefik-keycloak/config/traefik/traefik.yml`: Main Traefik configuration
- `/opt/agency_stack/clients/${CLIENT_ID}/traefik-keycloak/config/traefik/dynamic/auth.yml`: Authentication configuration

## Testing and Verification

=== Traefik-Keycloak Integration Verification ===
Checking container status...
❌ Traefik is not running

## Access

- Traefik Dashboard: http://localhost:8081/dashboard/
- Keycloak Admin Console: http://localhost:8082/auth/admin/
  - Default admin credentials: admin/admin

## Logs

Logs are stored in:
- `/var/log/agency_stack/components/traefik-keycloak.log`

## Stopping and Restarting

CONTAINER ID   IMAGE                  COMMAND                  CREATED        STATUS                  PORTS                                          NAMES
dc553cf492fd   agencystack-dev        "/entrypoint.sh zsh"     11 hours ago   Up 11 hours             0.0.0.0:8080->8080/tcp, 0.0.0.0:2222->22/tcp   agencystack-dev
feb240650302   nginx:latest           "/docker-entrypoint.…"   22 hours ago   Up 22 hours             80/tcp                                         localhost-nginx-1
072d3a1a3c3a   wordpress:php8.2-fpm   "docker-entrypoint.s…"   22 hours ago   Up 22 hours (healthy)   9000/tcp                                       localhost-wordpress-1
0fe7f13cbd27   redis:alpine           "docker-entrypoint.s…"   22 hours ago   Up 22 hours             6379/tcp                                       localhost-redis-1
d8c480172fc1   mariadb:10.5           "docker-entrypoint.s…"   22 hours ago   Up 22 hours (healthy)   3306/tcp                                       localhost-mariadb-1
