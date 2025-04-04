#!/bin/bash

# Initialize port management
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
echo "🔌 Initializing port management system..."
source "$SCRIPT_DIR/../../scripts/port_manager.sh"
echo "✅ Port management system initialized."

bash install_prerequisites.sh
bash install_docker.sh
bash install_docker_compose.sh
bash install_traefik_ssl.sh
bash install_portainer.sh
bash install_erpnext.sh
bash install_peertube.sh
bash install_wordpress_module.sh
bash install_focalboard.sh
bash install_listmonk.sh
bash install_calcom.sh
bash install_n8n.sh
bash install_openintegrationhub.sh
bash install_taskwarrior_calcure.sh
bash install_posthog.sh
bash install_killbill.sh
bash install_voip.sh
bash install_seafile.sh
bash install_documenso.sh
bash install_webpush.sh
bash install_netdata.sh
bash install_fail2ban.sh
bash install_security.sh

# Newly added components
bash install_keycloak.sh
bash install_tailscale.sh
bash install_signing_timestamps.sh
bash install_backup_strategy.sh
bash install_markdown_lexical.sh
bash install_launchpad_dashboard.sh

echo "✅ FOSS Server Stack installation completed!"
echo "🚀 Access your services through the Launchpad Dashboard"
echo ""
echo "📊 Port allocation summary:"
"$SCRIPT_DIR/../../scripts/port_manager.sh" list
