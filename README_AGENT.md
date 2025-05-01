# AgencyStack - AI Agent Guidelines

## Repository Purpose & Structure

AgencyStack is a sovereign, auditable, and repeatable infrastructure platform for small agencies, creators, and co-ops. It enables secure, multi-tenant, AI-enhanced, and customizable deployments—spanning foundational infrastructure, business productivity, communication, and AI-driven SaaS—using only repository-tracked, idempotent, and documented workflows.

## AI Agent Interaction Guidelines

### 🚫 Critical Restrictions

- **NEVER install any component directly on the host system**
- **NEVER modify files outside of the container/VM environment**
- **NEVER write to `/usr`, `$HOME`, or system paths unless explicitly instructed**
- **ALL changes must be repository-tracked and follow the Charter**

### ✅ Required Practices

1. **Repository as Source of Truth:** All installation, configuration, and operational logic must be defined and tracked in the repository.
2. **Idempotency & Automation:** All scripts, Makefile targets, and Docker builds must be rerunnable without harmful side effects.
3. **Containerization:** All services must be properly containerized with Docker following separation of concerns.
4. **Proper Change Workflow:** All changes must be made in the local repo, tested, committed, and deployed only via tracked scripts.
5. **Validation:** Always call `exit_with_warning_if_host()` early in installation scripts to prevent host contamination.

### 📁 Directory Structure

```
/root/_repos/agency-stack/
├── docs/           # Documentation including Charter
├── makefiles/      # Component-specific Makefile includes 
├── scripts/        # Installation and utility scripts
│   ├── components/ # Component-specific installation scripts
│   └── utils/      # Shared utility functions and helpers
└── services/       # Service configuration templates
```

## Key References

- [AgencyStack Charter v1.0.3](/docs/charter/v1.0.3.md)
- [Test-Driven Development Protocol](/docs/charter/tdd_protocol.md)
- [Component Documentation](/docs/pages/components/)

For all operations, assume strict containerization and never perform actions that would modify the host system directly. All installations must happen inside containers or VMs, and all behavior must be tracked in the repository.
