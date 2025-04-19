#!/bin/bash
# Utility: stub_missing_components.sh
# Scans for referenced install scripts and creates stubs for any missing ones.
COMPONENTS_DIR="$(dirname "$0")/../components"
STUB_SRC="$COMPONENTS_DIR/install_stub.sh"

# List of expected install scripts from install.sh menu mapping (update as needed)
EXPECTED=(
  install_prerequisites.sh install_docker.sh install_docker_compose.sh install_traefik_ssl.sh install_portainer.sh \
  install_erpnext.sh install_peertube.sh install_wordpress_module.sh install_focalboard.sh install_listmonk.sh \
  install_calcom.sh install_n8n.sh install_openintegrationhub.sh install_taskwarrior_calcure.sh install_posthog.sh \
  install_killbill.sh install_voip.sh install_seafile.sh install_documenso.sh install_webpush.sh install_netdata.sh \
  install_fail2ban.sh install_security.sh install_droneci.sh install_keycloak.sh install_tailscale.sh \
  install_signing_timestamps.sh install_backup_strategy.sh install_markdown_lexical.sh install_launchpad-dashboard.sh \
  install_builderio.sh install_loki.sh install_grafana.sh install_wordpress.sh
)

for script in "${EXPECTED[@]}"; do
  TARGET="$COMPONENTS_DIR/$script"
  if [ ! -f "$TARGET" ]; then
    echo "[STUB] Creating missing installer: $TARGET"
    cp "$STUB_SRC" "$TARGET"
    chmod +x "$TARGET"
  fi
done

echo "[INFO] All missing component installers have been stubbed."
