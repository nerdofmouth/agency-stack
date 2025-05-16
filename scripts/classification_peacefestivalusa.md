# AgencyStack Script Classification — Peace Festival USA Focus

_Last updated: 2025-05-15 00:20:56-05:00_

## Legend
- **Essential**: Required for current deployments or core stack operation
- **Redundant**: Overlaps with other scripts; candidate for consolidation/removal
- **Obsolete**: Outdated or deprecated
- **Needs Review**: Unclear purpose or requires deeper inspection

---

## /scripts/components/

| Script Name                               | Size (KB) | Classification | Notes |
|-------------------------------------------|-----------|----------------|-------|
| install_peacefestivalusa.sh               | 3.2       | Essential      | Main Peace Festival USA install script |
| install_peacefestivalusa_wordpress.sh     | 25.4      | Essential      | Installs WordPress for Peace Festival USA |
| install_peacefestivalusa_wordpress_did.sh | 9.1       | Needs Review   | DID = Decentralized ID? Confirm use |
| deploy_peacefestivalusa.sh                | 9.7       | Essential      | Deploys Peace Festival USA stack |
| deploy_peacefestivalusa_full.sh           | 7.9       | Needs Review   | Full stack deploy, clarify overlap |
| deploy_peacefestivalusa_remote.sh         | 14.2      | Needs Review   | Remote deploy, clarify distinction |
| peacefestivalusa_container.sh             | 4.2       | Needs Review   | Container management, clarify usage |
| peacefestivalusa_http_fix.sh              | 11.6      | Needs Review   | HTTP fix, check if still needed |
| peacefestivalusa_test_fix.sh              | 12.7      | Needs Review   | Test fix, clarify current relevance |
| test_peacefestivalusa_wordpress.sh        | 5.6       | Essential      | Tests WordPress deployment for client |
| test_keycloak_idp.sh                      | 23.2      | Essential      | Tests Keycloak IDP integration |
| install_keycloak.sh                       | 50.0      | Essential      | Keycloak is core to SSO |
| install_traefik.sh                        | 30.4      | Essential      | Traefik is core to stack networking |
| install_traefik_keycloak.sh               | 27.8      | Essential      | Traefik/Keycloak integration |
| test_traefik_keycloak.sh                  | 7.8       | Essential      | Tests Traefik/Keycloak |
| test_traefik_keycloak_sso.sh              | 18.3      | Essential      | Tests SSO integration |
| install_wordpress.sh                      | 41.8      | Essential      | Core WordPress installer |

## /scripts/utils/

| Script Name                | Size (KB) | Classification | Notes |
|---------------------------|-----------|----------------|-------|
| audit_and_cleanup.sh       | 24.0      | Essential      | Audits and cleans up stack |
| common.sh                 | 18.9      | Essential      | Core utility sourced by many scripts |
| setup_traefik_keycloak.sh | 4.6       | Essential      | Helper for Traefik/Keycloak |
| test_peacefestivalusa_wordpress.sh | 7.2 | Essential | Utility test for client deployment |
| fix_script_idempotence.sh | 10.8      | Essential      | Ensures idempotency (critical for discipline) |
| validate_components.sh    | 23.1      | Essential      | Component validation |
| validate_system.sh        | 5.9       | Essential      | System-wide validation |
| quick_audit.sh            | 9.3       | Essential      | Fast audit, useful for CI |

---

> **Next Steps:**
> - Review all scripts marked "Needs Review" for purpose, overlap, or obsolescence.
> - For "Essential" scripts, check for missing documentation, idempotency, and auditability issues.
> - Repeat process for remaining scripts in inventory.
