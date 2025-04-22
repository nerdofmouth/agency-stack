# AgencyStack Quick Reference

## Non-Negotiables & Critical Conventions

### Directory Structure
| Purpose             | Path                                                      |
|---------------------|----------------------------------------------------------|
| Install scripts     | `/scripts/components/`                                    |
| Utility scripts     | `/scripts/utils/`                                        |
| Mock/test code      | `/scripts/mock/`                                         |
| Component docs      | `/docs/pages/components/`                                |
| Logs                | `/var/log/agency_stack/components/<component>.log`       |
| Install output      | `/opt/agency_stack/clients/${CLIENT_ID}/<component>/`    |

- **Never write to `/usr`, `$HOME`, or system paths unless explicitly instructed.**

### Makefile Targets (Per Component)
- `make <component>`           # Install
- `make <component>-status`    # Check status
- `make <component>-logs`      # View logs
- `make <component>-restart`   # Restart
- `make <component>-test`      # (Optional) Smoke/API test

> **Use dashes (`-`) in all target names.**

### Install Script Conventions
- Each `install_<component>.sh` script must:
  - Be hardened, idempotent, multi-tenant-aware
  - Log to `/var/log/agency_stack/components/<component>.log`
  - Use `scripts/utils/common.sh` for safety/logging
  - Use `docker`, `docker-compose`, or `systemctl` if necessary
  - Accept optional flags:
    - `--enable-cloud`
    - `--enable-openai`
    - `--use-github`

### Component Registry Requirements
Each entry in `component_registry.json` must include:
```json
{
  "name": "example",
  "category": "infrastructure",
  "description": "Example service",
  "flags": {
    "installed": true,
    "makefile": true,
    "docs": true,
    "hardened": true,
    "monitoring": false,
    "multi_tenant": true,
    "sso": false
  }
}
```

### Documentation Requirements
- Each component must have `/docs/pages/components/<component>.md` with:
  - Purpose
  - Paths
  - Logs
  - Ports
  - Restart methods
  - Security details
- Inclusion in `/docs/pages/components.md`

### SSO & Identity Management (Keycloak Policy)
- All components with `sso: true` **must** integrate with **Keycloak** as the primary identity provider unless explicitly excluded in writing.
- Requirements:
  - Keycloak-based login via OIDC or SAML
  - Tenant-isolated realms if `multi_tenant = true`
  - Role-based access controls mapped via Keycloak groups
  - Unified session management where applicable
- Installation scripts must:
  - Check for Keycloak availability and realm readiness
  - Fail loudly if Keycloak is missing or misconfigured
  - Offer `--enable-keycloak` as an install flag
- `component_registry.json` entries must include:
  - `sso_configured: true` only after actual live integration is tested
- Keycloak is a **system-wide dependency for SSO** and is validated as part of `make alpha-check` and future `make beta-check` workflows.

### Repository Integrity Policy
- ALL install behavior must be defined in the repo (scripts, Makefile, registry, docs)
- NEVER patch anything directly on the VM without source-tracking
- ALL changes must be made to the local repository first, then deployed via proper channels (git pull, install scripts, Makefile targets)

---

## How to Include This Quick Reference in Future Prompts

1. **Direct Reference**: Instruct the AI or team to consult `/docs/quick-ref.md` for AgencyStack non-negotiables and conventions.
   - Example: `@quick-ref.md` or `@[docs/quick-ref.md]`
2. **Prompt Example**: 
   > "When updating install scripts, follow all requirements in @[docs/quick-ref.md]."
3. **AI Context**: If using AI assistants, paste or reference the file path in your prompt to ensure the quick-ref is loaded as context.

---

**Keep this file up to date as policies evolve. All contributors must treat these items as non-negotiable.**
