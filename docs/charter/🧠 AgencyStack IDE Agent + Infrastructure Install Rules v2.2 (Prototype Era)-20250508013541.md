# 🧠 AgencyStack IDE Agent + Infrastructure Install Rules v2.2 (Prototype Era)

* * *

# 🔬 Purpose

This document defines the updated, complete development and install environment rules for **AgencyStack** (aka [**Upstack.agency**](http://Upstack.agency)).

**Main objective:**

> Build, install, and test a secure, multi-tenant WordPress installation integrated with Traefik and Keycloak, repeatably and rapidly, across VMs.

* * *

# 🔍 Scope

Applies to:

*   WordPress (multi-tenant, containerized)
*   Traefik (TLS routing and proxying)
*   Keycloak (SSO identity management)
*   Associated utils, Makefile targets, component registry, docs.
*   MCP server integrations for AI workflows.
*   Modular Makefile-driven installations.

Partial scaffolding for future phases (ERPNext, Seafile, Mailu) may be included.

* * *

# 🔒 Core Principles

| Area | Rule |
| ---| --- |
| Repository | **Single source of truth.** Never modify remote VMs directly. Only local repo -> push -> deploy. |
| Idempotency | All scripts, installs, Makefile targets must be re-runnable safely without breaking anything. |
| Auditability | All actions must log to `/var/log/agency_stack/components/<component>.log`. Docs must exist. |
| Multi-Tenancy | Default to segregated per-client containers and data paths. |
| TLS Everywhere | Traefik must enforce HTTPS by default. |
| SSO Support | Components must accept `--enable-keycloak` flag and integrate SSO cleanly if enabled. |
| Host-to-Container Rule | ❌ **Never treat containers as sources of truth.** Host repository is authoritative. |
| Dev Container Discipline | Customizations must be defined in [`Dockerfile.dev`](http://Dockerfile.dev) and repo-tracked. |
| AI Agent MCP Servers | `context7`, `puppeteer`, and `taskmaster-ai` MCP services must be recognized and usable in the development environment. |
| Windsurf + Ubuntu VM | Development occurs on Ubuntu VMs under Windsurf terminal access with Windows host OS (important for Docker and containerization behaviors). |

* * *

# 🚧 Mandatory Directory Structure

| Purpose | Path |
| ---| --- |
| Install scripts | `/scripts/components/` |
| Utility scripts | `/scripts/utils/` |
| Mock/test scripts | `/scripts/mock/` |
| Component docs | `/docs/pages/components/` |
| Logs | `/var/log/agency_stack/components/<component>.log` |
| Install output | `/opt/agency_stack/clients/${CLIENT_ID}/<component>/` |
| In Container | `$HOME/.agencystack/clients/${CLIENT_ID}/<component>/` |

* * *

# 🔧 Install Script Conventions

Each install script must:

*   Be named `install_<component>.sh`
*   Source [`common.sh`](http://common.sh) at the top
*   Log actions clearly
*   Accept flags:

```diff
--enable-cloud
--enable-openai
--enable-keycloak
--use-github
```

*   Handle both standalone and SSO scenarios
*   Exit cleanly with `|| true` where appropriate to prevent Make pipeline failures
*   Respect container vs host path differences

* * *

# 🔄 Modular Makefile Standards

| Area | Rule |
| ---| --- |
| Structure | All component-specific logic must be in `/makefiles/components/<component>.mk` |
| Inclusion | The main Makefile must dynamically load modules with `-include makefiles/components/*.mk` |
| Targets | Each component must define: `make <component>`, `-status`, `-logs`, `-restart`, `-test` |
| Error Handling | Non-critical failures must use \` |

* * *

# 🎓 Component Registry (component\_registry.json) Rules

| Area | Rule |
| ---| --- |
| Flags | `installed`, `makefile`, `docs`, `hardened`, `multi_tenant`, `sso`, `sso_configured` after live test |
| Structure | Must reflect modular structure and container readiness |

* * *

# 🕹️ TDD Protocol Compliance

Every component must:

*   Include `/verify.sh`, `/test.sh`, `/integration_test.sh`
*   Follow [AgencyStack TDD Protocol v1.0](https://chatgpt.com/c/tdd_protocol.md)
*   Achieve:
    *   100% Critical Paths
    *   90% Core Functionality
    *   80% Edge Cases

* * *

# 🔐 SSO & Keycloak Integration (WordPress)

Sample `.env` for container SSO:

```ini
WORDPRESS_ENABLE_KEYCLOAK=true
KEYCLOAK_REALM=agency_realm
KEYCLOAK_CLIENT_ID=wordpress-client
KEYCLOAK_CLIENT_SECRET=abc123xyz
KEYCLOAK_URL=https://keycloak.agency.local
```

* * *

# 📍 AI MCP Server Integrations

Recognized MCP servers configured and ready:

*   `context7`: Available via `npx @upstash/context7-mcp`
*   `puppeteer`: Available via `curl` POST to [`http://localhost:3000/puppeteer`](http://localhost:3000/puppeteer)
*   `taskmaster-ai`: Available via `curl` POST to [`http://localhost:3000/taskmaster`](http://localhost:3000/taskmaster)

All dev scripts and AI workflows must be able to interact with these MCPs where appropriate.

* * *

# 📅 Development Host Environment

| Characteristic | Setup |
| ---| --- |
| Base OS | Windows Host |
| Terminal Dev OS | Ubuntu VM (via Windsurf terminal access) |
| Docker | Installed inside Ubuntu VM |
| Special Notes | Path and file handling must consider host/VM/container differences |

* * *

# 🛠️ Development Workflow

**Local:**

```vim
vim scripts/components/install_wordpress.sh
shellcheck scripts/components/install_wordpress.sh
make prep-dirs
make install-wordpress
make wordpress-status
make alpha-check
```

**Remote:**

```awk
curl -sSL https://stack.nerdofmouth.com/install.sh | sudo bash
sudo bash /opt/agency_stack/repo/scripts/install.sh
make alpha-check
```

**Host-to-Container Rule:**

*   Host is always authoritative.
*   Containers are disposable runtime artifacts.
*   No container-originated changes allowed.

* * *

# 💡 Development Mindset

> Build one new component per day: create, modularize, document, test.  
> Engineer for sovereignty, auditability, and repeatability.

**From zero to sovereign™ — one container at a time.**

* * *

# 🚀 END OF INSTRUCTIONS v2.2

* * *

(Ready to paste into repo, Claude inputs, or Agent onboarding.)