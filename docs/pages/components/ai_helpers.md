# AgencyStack Utility Scripts Reference (AI & System Docs)

This document is auto-generated to assist AgencyStack contributors and AI agents in understanding the available utility scripts in `scripts/utils/`. Each entry includes the filename and a brief description (where available). Use this as a quick reference for automating, debugging, or extending the stack.

---

## Shell Utility Scripts

- **audit_and_cleanup.sh**: Audit and clean up installation state or artifacts.
- **cleanup_install_state.sh**: Remove residual install state for idempotence.
- **common.sh**: Common functions and variables shared by multiple scripts.
- **component_sso_helper.sh**: Helpers for SSO integration and registry updates.
- **component_validator.sh**: Validate component configuration and health.
- **configure_dns.sh**: DNS configuration helpers.
- **create_base_docker_dev.sh**: Bootstrap a base Docker dev environment.
- **create_deploy_user.sh**: Create a deployment user securely.
- **dashboard_dns_helper.sh**: DNS helpers for dashboard setup.
- **dependency_checker.sh**: Check for required dependencies.
- **deploy_to_remote.sh**: Deploy components/scripts to a remote host.
- **directory_helpers.sh**: Directory management helpers.
- **dns_checker.sh**: DNS status and verification.
- **docker_vm_entrypoint.sh**: Entrypoint logic for Docker VM containers.
- **fault_inject.sh**: Inject faults for resilience testing.
- **fix_installed_markers.sh**: Repair or reset install state markers.
- **fix_remote_paths.sh**: Correct remote path issues for deployment.
- **fix_script_idempotence.sh**: Ensure scripts are idempotent.
- **generate_docs_from_logs.sh**: Generate documentation from logs.
- **generate_makefile_targets.sh**: Auto-generate Makefile targets.
- **keycloak_integration.sh**: Keycloak SSO integration helpers.
- **killbill_validation.sh**: Validate KillBill install and configuration.
- **lint_shell.sh**: Lint shell scripts using shellcheck.
- **log_helpers.sh**: Logging helpers for scripts.
- **permission_check.sh**: Check and fix file or directory permissions.
- **port_conflict_detector.sh**: Detect and report port conflicts.
- **quick_audit.sh**: Quick audit of system or install state.
- **registry_parser.sh**: Parse and query the component registry.
- **reliable_track_usage.sh**: Track usage metrics reliably.
- **setup_ssh_key.sh**: Setup SSH key for a user.
- **setup_ssh_keys.sh**: Batch setup of SSH keys.
- **setup_ssh_proto002.sh**: SSH setup for prototype 002.
- **sso_status.sh**: Check SSO status across components.
- **stub_missing_components.sh**: Create stubs for missing components.
- **sync_dashboard_oauth.sh**: Sync dashboard OAuth settings.
- **test_wordpress_access.sh**: Test access to WordPress instance.
- **tls_sso_registry_check.sh**: Check TLS/SSO registry compliance.
- **tls_verify.sh**: Verify TLS configuration and certs.
- **track_usage.sh**: Track system/component usage.
- **update_component_registry.sh**: Update the component registry JSON.
- **update_keycloak_registry.sh**: Update Keycloak registry integration.
- **update_prometheus_killbill.sh**: Update Prometheus for KillBill metrics.
- **update_traefik_certs.sh**: Update Traefik SSL certificates.
- **validate_components.sh**: Validate all installed components.
- **validate_system.sh**: Validate overall system health.
- **verify_tls.sh**: Verify TLS endpoint or certs.
- **version_manager.sh**: Manage component or stack versions.
- **vm_test_report.sh**: Generate VM test reports.

## Python Utility Scripts

- **check_registry_vs_scripts.py**: Audit and report discrepancies between install scripts and registry.
- **generate_docs_from_registry.py**: Auto-generate documentation from the component registry.

---

**How to use:**
- Source relevant helpers in your install scripts for safety, logging, and idempotence.
- Use the Python scripts to automate documentation and audit tasks.
- Refer to this doc before writing new scripts to avoid duplication and leverage existing utilities.

*This document is maintained for both human contributors and AI agents to ensure best practices and maximize reusability across AgencyStack.*
