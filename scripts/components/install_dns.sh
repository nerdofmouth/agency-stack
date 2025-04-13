#!/bin/bash
# install_dns.sh - Setup DNS for AgencyStack components
# Part of the AgencyStack Alpha Phase
#
# Source common utilities
source "$(dirname "$0")/../utils/common.sh"

# Default values
DNS_PROVIDER=""
DOMAIN=""
PUBLIC_IP=""
IP_DETECTION="auto"
CLIENT_ID="default"
DNS_CONFIG_DIR="/opt/agency_stack/dns"
SECRETS_DIR="/opt/agency_stack/secrets/dns"
FORCE=false

# Show help
show_help() {
  echo "Usage: $0 [OPTIONS]"
  echo "Configure DNS for AgencyStack components"
  echo ""
  echo "Options:"
  echo "  --domain DOMAIN       Domain to configure"
  echo "  --public-ip IP        Public IP to point domain to (default: auto-detect)"
  echo "  --provider PROVIDER   DNS provider (cloudflare or route53)"
  echo "  --client-id ID        Client ID (default: default)"
  echo "  --ip-detection MODE   IP detection mode (auto, interface, manual)"
  echo "  --force               Force DNS update even if record exists"
  echo "  --help                Show this help message"
  echo ""
  echo "Example:"
  echo "  $0 --domain wordpress.proto001.alpha.nerdofmouth.com --provider cloudflare"
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
      IP_DETECTION="manual"
      shift 2
      ;;
    --provider)
      DNS_PROVIDER="$2"
      shift 2
      ;;
    --client-id)
      CLIENT_ID="$2"
      shift 2
      ;;
    --ip-detection)
      IP_DETECTION="$2"
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

if [ -z "$DNS_PROVIDER" ]; then
  log_error "DNS provider is required"
  show_help
  exit 1
fi

# Create directories
mkdir -p "$DNS_CONFIG_DIR"
mkdir -p "$SECRETS_DIR"

# Determine public IP
if [ "$IP_DETECTION" = "auto" ]; then
  log_info "Auto-detecting public IP..."
  PUBLIC_IP=$(curl -s https://ipinfo.io/ip)
  if [ -z "$PUBLIC_IP" ]; then
    log_error "Failed to auto-detect public IP"
    exit 1
  fi
  log_success "Detected public IP: $PUBLIC_IP"
elif [ "$IP_DETECTION" = "interface" ]; then
  log_info "Detecting IP from network interfaces..."
  PUBLIC_IP=$(ip addr show | grep -E 'inet.*global' | head -1 | awk '{print $2}' | cut -d'/' -f1)
  if [ -z "$PUBLIC_IP" ]; then
    log_error "Failed to detect IP from network interfaces"
    exit 1
  fi
  log_success "Detected IP from interface: $PUBLIC_IP"
elif [ "$IP_DETECTION" = "manual" ] && [ -z "$PUBLIC_IP" ]; then
  log_error "Public IP is required when using manual IP detection"
  exit 1
fi

# Configure DNS based on provider
if [ "$DNS_PROVIDER" = "cloudflare" ]; then
  log_info "Configuring DNS using Cloudflare provider"
  
  # Check if Cloudflare credentials file exists
  CF_CREDENTIALS_FILE="$SECRETS_DIR/cloudflare.env"
  
  if [ ! -f "$CF_CREDENTIALS_FILE" ]; then
    log_warning "Cloudflare credentials not found at $CF_CREDENTIALS_FILE"
    log_info "Creating Cloudflare credentials file..."
    
    echo "Please enter your Cloudflare API token:"
    read -s CF_API_TOKEN
    
    if [ -z "$CF_API_TOKEN" ]; then
      log_error "Cloudflare API token is required"
      exit 1
    fi
    
    echo "export CLOUDFLARE_API_TOKEN=$CF_API_TOKEN" > "$CF_CREDENTIALS_FILE"
    chmod 600 "$CF_CREDENTIALS_FILE"
    log_success "Cloudflare credentials saved to $CF_CREDENTIALS_FILE"
  fi
  
  # Source Cloudflare credentials
  source "$CF_CREDENTIALS_FILE"
  
  if [ -z "$CLOUDFLARE_API_TOKEN" ]; then
    log_error "CLOUDFLARE_API_TOKEN not found in credentials file"
    exit 1
  fi
  
  log_info "Using Cloudflare API to configure DNS for $DOMAIN -> $PUBLIC_IP"
  
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
    log_info "Please ensure the domain is properly set up in Cloudflare"
    exit 1
  fi
  
  log_success "Found Cloudflare zone ID: $ZONE_ID"
  
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
        ERROR_MSG=$(echo "$UPDATE_RESPONSE" | jq -r '.errors[0].message')
        log_error "Failed to update DNS record: $ERROR_MSG"
        exit 1
      fi
    else
      log_warning "DNS record already exists for $DOMAIN, use --force to update"
      exit 0
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
      ERROR_MSG=$(echo "$CREATE_RESPONSE" | jq -r '.errors[0].message')
      log_error "Failed to create DNS record: $ERROR_MSG"
      exit 1
    fi
  fi
  
  # Save DNS configuration
  DNS_CONFIG_FILE="$DNS_CONFIG_DIR/$DOMAIN.json"
  cat > "$DNS_CONFIG_FILE" <<EOL
{
  "domain": "$DOMAIN",
  "root_domain": "$ROOT_DOMAIN",
  "subdomain": "$SUBDOMAIN",
  "ip": "$PUBLIC_IP",
  "provider": "$DNS_PROVIDER",
  "zone_id": "$ZONE_ID",
  "record_id": "$(echo "$CREATE_RESPONSE" | jq -r '.result.id')",
  "client_id": "$CLIENT_ID",
  "last_updated": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOL
  
  log_success "DNS configuration saved to $DNS_CONFIG_FILE"
  
elif [ "$DNS_PROVIDER" = "route53" ]; then
  log_warning "Route53 provider not yet implemented"
  exit 1
else
  log_error "Unsupported DNS provider: $DNS_PROVIDER"
  exit 1
fi

log_success "DNS setup completed for $DOMAIN -> $PUBLIC_IP"
echo ""
echo "================================================================"
echo "Domain:    $DOMAIN"
echo "IP:        $PUBLIC_IP"
echo "Provider:  $DNS_PROVIDER"
echo "Status:    Configured"
echo ""
echo "The DNS changes may take up to 5-10 minutes to propagate globally."
echo "You can verify the configuration using: dig $DOMAIN"
echo "================================================================"

exit 0
