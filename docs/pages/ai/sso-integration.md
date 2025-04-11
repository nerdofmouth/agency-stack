---
layout: default
title: AI Services SSO Integration - AgencyStack Documentation
---

# AI Services SSO Integration

This guide explains how to integrate AgencyStack AI services with Keycloak Single Sign-On (SSO) capabilities.

## Overview

AgencyStack AI components can be integrated with Keycloak to provide unified authentication and authorization. This ensures that access to sensitive AI capabilities is properly secured and governed by the same identity management system used by other AgencyStack components.

## Supported AI Components

The following AI components support Keycloak SSO integration:

| Component | Integration Status | Description |
|-----------|-------------------|-------------|
| LangChain | ✅ Supported | Framework for LLM-powered applications |
| Ollama | ✅ Supported | Local LLM deployment and API service |
| Archon | ✅ Supported | Custom AgencyStack AI orchestration layer |
| Bolt DIY | ✅ Supported | No-code AI workflow builder |

## Integration Architecture

AI services use OpenID Connect (OIDC) to authenticate with Keycloak, following this workflow:

1. User attempts to access an AI service
2. AI service redirects to Keycloak for authentication
3. User logs in through Keycloak
4. Keycloak issues JWT tokens for the AI service
5. AI service validates tokens and authorizes user actions

## Configuration Steps

### Prerequisites

- Keycloak installed and running (`make install-keycloak`)
- The AI service installed and running (e.g., `make langchain`)
- Admin access to both systems

### LangChain SSO Integration

To integrate LangChain with Keycloak:

```bash
make langchain-sso-configure DOMAIN=yourdomain.com
```

This command will:
1. Create a LangChain client in Keycloak
2. Configure proper redirect URIs
3. Set up role mappings
4. Update LangChain's configuration

### Ollama SSO Integration

To integrate Ollama with Keycloak:

```bash
make ollama-sso-configure DOMAIN=yourdomain.com
```

### Archon SSO Integration

To integrate Archon with Keycloak:

```bash
make archon-sso-configure DOMAIN=yourdomain.com
```

### Bolt DIY SSO Integration

To integrate Bolt DIY with Keycloak:

```bash
make bolt-diy-sso-configure DOMAIN=yourdomain.com
```

## Role Mapping

AI services typically use the following roles for authorization:

| Keycloak Role | AI Service Role | Capabilities |
|---------------|-----------------|--------------|
| ai-admin | Administrator | Full administrative access, model deployment, prompt development |
| ai-developer | Developer | Can create and modify prompts, chains, and workflows |
| ai-user | User | Can use pre-built AI applications and services |
| ai-readonly | Read-only | Can only view outputs from existing AI applications |

## Security Considerations

When integrating AI services with SSO, consider these security aspects:

1. **Prompt Injection Protection**: Even with SSO, ensure prompt validation to prevent injection attacks
2. **Data Access Controls**: Configure granular permissions for accessing data sources
3. **API Rate Limiting**: Implement per-user rate limits to prevent abuse
4. **Audit Logging**: Enable comprehensive logging for all AI service access and usage
5. **Token Validation**: Ensure proper JWT validation including expiration and signature

## Troubleshooting

### Common SSO Issues

1. **Connection Refused**:
   - Ensure Keycloak is running: `make keycloak-status`
   - Check network connectivity between the AI service and Keycloak

2. **Authentication Failed**:
   - Verify client secret in the AI service configuration
   - Check client configuration in Keycloak

3. **Authorization Failed**:
   - Ensure the user has the required roles in Keycloak
   - Verify role mapping is correctly configured

4. **Token Validation Errors**:
   - Check the time synchronization between services
   - Verify the signing keys are correctly configured

## Remote Deployment of SSO Components

Following AgencyStack's repository integrity policy, all SSO component changes must be made to the local repository first, then deployed to remote VMs through proper channels:

### Deploying Keycloak OAuth to Remote VMs

To deploy Keycloak OAuth Identity Provider changes to a remote VM:

```bash
# Deploy Keycloak component to a remote VM
make deploy-keycloak-remote REMOTE_HOST=hostname.example.com

# With custom SSH settings
make deploy-keycloak-remote REMOTE_HOST=hostname.example.com REMOTE_USER=admin SSH_KEY=~/.ssh/id_rsa SSH_PORT=2222
```

### Configuring OAuth Identity Providers on Remote VMs

To configure OAuth Identity Providers (Google, GitHub, Apple, LinkedIn, Microsoft) on a remote VM:

```bash
# Configure Google OAuth on remote VM
make configure-keycloak-remote REMOTE_HOST=hostname.example.com DOMAIN=auth.example.com ENABLE_OAUTH_GOOGLE=true

# Configure multiple OAuth providers 
make configure-keycloak-remote REMOTE_HOST=hostname.example.com DOMAIN=auth.example.com \
  ENABLE_OAUTH_GOOGLE=true \
  ENABLE_OAUTH_GITHUB=true \
  ENABLE_OAUTH_LINKEDIN=true
```

This approach ensures that:
1. All code changes are tracked in the repository
2. VM state can be reproduced from the repository
3. Changes follow proper deployment protocols
4. No direct modifications happen on production systems

### Remote Deployment Workflow for AI SSO Integration

1. **Local Development**: Make and test changes locally
2. **Commit Changes**: Commit all changes to the repository
3. **Remote Deployment**: Use the deployment targets to push changes to remote VMs
4. **Verification**: Verify the deployment with remote status checks

```bash
# Example complete workflow
# 1. Make local changes to SSO components
# 2. Commit changes to repository
git add .
git commit -m "Enhanced Keycloak OAuth providers for AI services"

# 3. Deploy to remote VM
make deploy-keycloak-remote REMOTE_HOST=hostname.example.com

# 4. Configure OAuth on remote VM
make configure-keycloak-remote REMOTE_HOST=hostname.example.com DOMAIN=auth.example.com ENABLE_OAUTH_GOOGLE=true

# 5. Test AI service SSO integration on remote VM
ssh user@hostname.example.com "cd /opt/agency_stack && make langchain-sso-test DOMAIN=auth.example.com"
```

## Testing SSO Integration

To verify the SSO integration is working:

```bash
# For LangChain
make langchain-sso-test DOMAIN=yourdomain.com

# For Ollama
make ollama-sso-test DOMAIN=yourdomain.com

# For other AI services
make <service>-sso-test DOMAIN=yourdomain.com
```

## References

- [AgencyStack Keycloak Documentation](/docs/pages/components/keycloak.md)
- [OpenID Connect for AI Systems](https://openid.net/specs/openid-connect-core-1_0.html)
- [Securing AI Services Best Practices](https://stack.nerdofmouth.com/ai-security)
