#!/bin/bash
# configure_dns.sh - Setup DNS for AgencyStack components
# Part of the AgencyStack Alpha Phase
#
# Source common utilities
source "$(dirname "$0")/common.sh"

# Default values
DNS_PROVIDER="cloudflare"
FORCE=false
DOMAIN=""
PUBLIC_IP=""

# Show help
show_help() {
  echo "Usage: $0 [OPTIONS]"
  echo "Configure DNS for AgencyStack components"
  echo ""
  echo "Options:"
  echo "  --domain DOMAIN       Domain to configure"
  echo "  --public-ip IP        Public IP to point domain to"
  echo "  --provider PROVIDER   DNS provider (default: cloudflare)"
  echo "  --force               Force DNS update even if record exists"
  echo "  --help                Show this help message"
  echo ""
  echo "Example:"
  echo "  $0 --domain wordpress.proto001.alpha.nerdofmouth.com --public-ip 192.64.72.162"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    --domain)
      DOMAIN="$2"
      shift 2
      ;;
    --public-ip)
      PUBLIC_IP="$2"
      shift 2
      ;;
    --provider)
      DNS_PROVIDER="$2"
      shift 2
      ;;
    --force)
      FORCE=true
      shift
      ;;
    --help)
      show_help
      exit 0
      ;;
    *)
      echo "Unknown option: $key"
      show_help
      exit 1
      ;;
  esac
done

# Validate required parameters
if [ -z "$DOMAIN" ]; then
  log_error "Domain is required"
  show_help
  exit 1
fi

if [ -z "$PUBLIC_IP" ]; then
  # Try to detect public IP if not specified
  log_info "Public IP not specified, detecting automatically..."
  PUBLIC_IP=$(curl -s https://ipinfo.io/ip)
  if [ -z "$PUBLIC_IP" ]; then
    log_error "Failed to detect public IP, please specify with --public-ip"
    exit 1
  fi
  log_info "Detected public IP: $PUBLIC_IP"
fi

# Configure DNS based on provider
case $DNS_PROVIDER in
  cloudflare)
    log_info "Configuring DNS for $DOMAIN -> $PUBLIC_IP using Cloudflare"
    
    # Check if the AgencyStack Cloudflare API token is available
    if [ -z "$CLOUDFLARE_API_TOKEN" ]; then
      if [ -f "/opt/agency_stack/secrets/cloudflare/api_token.txt" ]; then
        CLOUDFLARE_API_TOKEN=$(cat "/opt/agency_stack/secrets/cloudflare/api_token.txt")
      else
        log_error "Cloudflare API token not found. Please set CLOUDFLARE_API_TOKEN environment variable or create /opt/agency_stack/secrets/cloudflare/api_token.txt"
        exit 1
      fi
    fi
    
    # Extract the root domain from the full domain
    ROOT_DOMAIN=$(echo "$DOMAIN" | awk -F. '{print $(NF-1)"."$NF}')
    SUBDOMAIN=$(echo "$DOMAIN" | sed "s/\.$ROOT_DOMAIN$//")
    
    log_info "Root domain: $ROOT_DOMAIN, Subdomain: $SUBDOMAIN"
    
    # Get zone ID for the root domain
    ZONE_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$ROOT_DOMAIN" \
      -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
      -H "Content-Type: application/json" | jq -r '.result[0].id')
    
    if [ -z "$ZONE_ID" ] || [ "$ZONE_ID" = "null" ]; then
      log_error "Failed to get zone ID for domain $ROOT_DOMAIN"
      exit 1
    fi
    
    log_info "Found zone ID: $ZONE_ID"
    
    # Check if DNS record already exists
    RECORD_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?type=A&name=$DOMAIN" \
      -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
      -H "Content-Type: application/json" | jq -r '.result[0].id')
    
    if [ -n "$RECORD_ID" ] && [ "$RECORD_ID" != "null" ]; then
      if [ "$FORCE" = true ]; then
        log_info "DNS record already exists for $DOMAIN, updating..."
        
        # Update existing DNS record
        UPDATE_RESPONSE=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$RECORD_ID" \
          -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
          -H "Content-Type: application/json" \
          --data "{\"type\":\"A\",\"name\":\"$DOMAIN\",\"content\":\"$PUBLIC_IP\",\"ttl\":1,\"proxied\":true}")
        
        if echo "$UPDATE_RESPONSE" | jq -e '.success' > /dev/null; then
          log_success "DNS record updated successfully for $DOMAIN -> $PUBLIC_IP"
        else
          log_error "Failed to update DNS record: $(echo "$UPDATE_RESPONSE" | jq -r '.errors[0].message')"
          exit 1
        fi
      else
        log_warning "DNS record already exists for $DOMAIN, use --force to update"
      fi
    else
      log_info "Creating new DNS record for $DOMAIN -> $PUBLIC_IP"
      
      # Create new DNS record
      CREATE_RESPONSE=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records" \
        -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
        -H "Content-Type: application/json" \
        --data "{\"type\":\"A\",\"name\":\"$DOMAIN\",\"content\":\"$PUBLIC_IP\",\"ttl\":1,\"proxied\":true}")
      
      if echo "$CREATE_RESPONSE" | jq -e '.success' > /dev/null; then
        log_success "DNS record created successfully for $DOMAIN -> $PUBLIC_IP"
      else
        log_error "Failed to create DNS record: $(echo "$CREATE_RESPONSE" | jq -r '.errors[0].message')"
        exit 1
      fi
    fi
    ;;
    
  route53)
    log_info "Configuring DNS for $DOMAIN -> $PUBLIC_IP using Route53"
    log_warning "Route53 DNS provider not yet implemented"
    exit 1
    ;;
    
  *)
    log_error "Unsupported DNS provider: $DNS_PROVIDER"
    exit 1
    ;;
esac

log_success "DNS configuration completed for $DOMAIN -> $PUBLIC_IP"
exit 0
