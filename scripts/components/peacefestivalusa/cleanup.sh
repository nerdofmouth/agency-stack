#!/bin/bash

# PeaceFestivalUSA Clean-Slate Approach
# Following AgencyStack Charter v1.0.3 Principles
# - Repository as Source of Truth
# - Component Consistency
# - Strict Containerization

set -e

# Script parameters
CLIENT_ID="peacefestivalusa"

# Simple logging
log_info() { echo -e "[INFO] $1"; }
log_warning() { echo -e "[WARNING] $1"; }
log_error() { echo -e "[ERROR] $1"; }
log_success() { echo -e "\033[0;32m[SUCCESS]\033[0m $1"; }

log_info "Starting clean-slate approach for ${CLIENT_ID}"

# 1. Stop and remove all containers
log_info "Stopping all related containers..."
docker stop ${CLIENT_ID}_traefik ${CLIENT_ID}_wordpress ${CLIENT_ID}_mariadb 2>/dev/null || true

log_info "Removing all related containers..."
docker rm ${CLIENT_ID}_traefik ${CLIENT_ID}_wordpress ${CLIENT_ID}_mariadb 2>/dev/null || true

# 2. Remove all related networks
log_info "Removing all related networks..."
docker network rm ${CLIENT_ID}_traefik_network 2>/dev/null || true
docker network rm ${CLIENT_ID}_wordpress_network 2>/dev/null || true

# 3. Create networks properly
log_info "Creating fresh networks..."
docker network create ${CLIENT_ID}_traefik_network
docker network create ${CLIENT_ID}_wordpress_network

log_info "Clean-slate preparation complete"
log_success "Networks have been properly reset"
log_info "Now you can run the installation script again"
