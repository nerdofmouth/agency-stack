#!/bin/bash
# test_wordpress_access.sh - Test access to WordPress without modifying hosts files
# Part of the AgencyStack Alpha Phase

# VM IP address
VM_IP="192.64.72.162"
DOMAIN="wordpress.proto001.alpha.nerdofmouth.com"

# Use curl with Host header to access WordPress
echo "Testing access to WordPress at https://$DOMAIN (VM IP: $VM_IP)..."
curl -k -H "Host: $DOMAIN" "https://$VM_IP"

echo ""
echo "================================================================"
echo "To access WordPress in your browser without modifying hosts:"
echo ""
echo "1. Use a browser extension like 'ModHeader' to add a custom header:"
echo "   Host: $DOMAIN"
echo ""
echo "2. Then access: https://$VM_IP"
echo ""
echo "Or, temporarily add this to your hosts file:"
echo "$VM_IP $DOMAIN"
echo "================================================================"
