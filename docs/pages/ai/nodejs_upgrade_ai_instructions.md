---
ai_doc_type: instruction
ai_audience: agent
ai_capabilities_required: [code_generation, reasoning, tool_use]
ai_domain_knowledge: [devops, containerization]
ai_task_relevance: [upgrading, installation]
version: 1.0.0
last_updated: 2025-04-10
repository_scope: component_specific
component_name: nodejs
---

# 🧠 AI Instructions: Node.js Upgrade Procedure

## Intent Declaration

This document provides structured instructions for AI systems to safely upgrade Node.js versions within the AgencyStack repository while maintaining full compliance with the AgencyStack Alpha Phase Repository Integrity Policy.

## Context

Node.js is a critical dependency for several AgencyStack components. Version upgrades MUST be performed with care to ensure backward compatibility and proper functioning of all dependent systems. The current LTS version should be preferred unless specific compatibility constraints exist.

## Requirements

MUST adhere to the AgencyStack Alpha Phase Repository Integrity Policy at all times.
MUST update all Node.js version references consistently across the repository.
MUST test compatibility with dependent components before recommending production deployment.
MUST document all changes in accordance with repository standards.
SHOULD prefer LTS (Long-Term Support) versions of Node.js.

## Upgrade Process

### Phase 1: Version Assessment

```
INSTRUCTION: Analyze current Node.js version
EXECUTE: /scripts/utils/version_manager.sh latest nodejs
VALIDATE: Compare with current version in repository
```

### Phase 2: Update Version References

The following files MUST be updated with the new Node.js version:

```
INSTRUCTION: Update version variables
LOCATIONS:
- /scripts/components/install_dashboard.sh (NODE_VERSION variable)
- /scripts/utils/node_version.sh (if exists)
- Any Dockerfile using Node.js (update FROM node:X-alpine directives)
VALIDATION: All references should be consistent with the selected version
```

### Phase 3: Update Docker Images

```
INSTRUCTION: Update Node.js base images
SEARCH_PATTERN: "FROM node:[0-9.]+-alpine"
REPLACE_WITH: "FROM node:<NEW_VERSION>-alpine"
CONSTRAINT: Only update in Dockerfiles, not in documentation examples
```

### Phase 4: Testing Procedure

```
INSTRUCTION: Verify updated components work correctly
EXECUTE:
  - make dashboard FORCE=true
  - make dashboard-status
VALIDATION: Dashboard should build and run without errors
```

## Example Implementation

```bash
# Example of updating NODE_VERSION in install_dashboard.sh
sed -i 's/NODE_VERSION="[0-9.]*"/NODE_VERSION="20.11.1"/' /scripts/components/install_dashboard.sh

# Example of updating Docker image in Dockerfile
sed -i 's/FROM node:[0-9.]*-alpine/FROM node:20.11.1-alpine/' /path/to/Dockerfile
```

## Validation Criteria

The upgrade is considered successful when:

1. All Node.js version references are consistently updated throughout the repository
2. All components dependent on Node.js build and run successfully
3. All tests pass
4. Documentation is updated to reflect the new version requirements
5. No repository policy violations are detected

## Special Considerations for AI

When performing this upgrade, AI MUST NOT:
- Make direct modifications to the VM outside of the repository code
- Update versions beyond the most recent LTS release unless explicitly instructed
- Change functionality beyond version numbers
- Ignore tests or validation steps

## Automated Tools

Use the provided version management utility for consistent handling:

```
TOOL: /scripts/utils/version_manager.sh
CAPABILITIES:
- Semantic version comparison
- Latest version detection
- Repository scanning for version references
- Automated updates of version variables
```
