---
layout: default
title: Keycloak OAuth Provider Examples - AgencyStack Documentation
---

# Keycloak OAuth Provider Configuration Examples

This document provides comprehensive examples and step-by-step guides for configuring OAuth Identity Providers with Keycloak in AgencyStack.

## Table of Contents

- [Introduction](#introduction)
- [Provider Setup Guides](#provider-setup-guides)
  - [Google](#google)
  - [GitHub](#github)
  - [Apple](#apple)
  - [LinkedIn](#linkedin)
  - [Microsoft/Azure AD](#microsoftazure-ad)
- [Multi-Tenant Examples](#multi-tenant-examples)
- [Integration Examples](#integration-examples)
- [Troubleshooting](#troubleshooting)
- [Rollback Procedures](#rollback-procedures)
- [Upgrade Guide](#upgrade-guide)

## Introduction

AgencyStack integrates external OAuth providers through Keycloak, preserving sovereignty while offering users the convenience of social login. This guide provides practical examples that complement the [Keycloak documentation](./keycloak.md#external-oauth-via-keycloak-idps).

## Provider Setup Guides

### Google

#### Step 1: Create OAuth Credentials in Google Cloud Console

1. Navigate to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select an existing one
3. Go to "APIs & Services" > "Credentials"
4. Click "Create Credentials" > "OAuth client ID"
5. Select "Web application" as the application type
6. Set up the OAuth consent screen with required information
7. Add authorized JavaScript origins: `https://auth.example.com`
8. Add authorized redirect URIs: `https://auth.example.com/auth/realms/agency/broker/google/endpoint`
9. Click "Create" to generate your credentials
10. Note your **Client ID** and **Client Secret**

#### Step 2: Configure Keycloak with Google OAuth

```bash
# Set environment variables with your credentials
export GOOGLE_CLIENT_ID="your-client-id-from-google"
export GOOGLE_CLIENT_SECRET="your-client-secret-from-google"

# Install or update Keycloak with Google OAuth
make install-keycloak DOMAIN=auth.example.com ADMIN_EMAIL=admin@example.com ENABLE_OAUTH_GOOGLE=true

# Or configure Google OAuth on existing Keycloak
make keycloak-oauth-configure DOMAIN=auth.example.com ENABLE_OAUTH_GOOGLE=true
```

#### Step 3: Verify Google OAuth Configuration

```bash
# Test the OAuth configuration
make keycloak-idp-test DOMAIN=auth.example.com PROVIDER=google

# Check the status
make keycloak-idp-status DOMAIN=auth.example.com
```

#### Example Google OAuth Configuration

```json
{
  "alias": "google",
  "displayName": "Google",
  "providerId": "google",
  "enabled": true,
  "updateProfileFirstLoginMode": "on",
  "trustEmail": false,
  "storeToken": false,
  "addReadTokenRoleOnCreate": false,
  "authenticateByDefault": false,
  "linkOnly": false,
  "firstBrokerLoginFlowAlias": "first broker login",
  "config": {
    "clientId": "YOUR_GOOGLE_CLIENT_ID",
    "clientSecret": "YOUR_GOOGLE_CLIENT_SECRET",
    "defaultScope": "openid profile email",
    "useJwksUrl": "true",
    "syncMode": "IMPORT"
  }
}
```

### GitHub

#### Step 1: Create OAuth App in GitHub

1. Go to [GitHub Developer Settings](https://github.com/settings/developers)
2. Click "New OAuth App"
3. Fill in the application details:
   - Application name: "AgencyStack Keycloak"
   - Homepage URL: `https://auth.example.com`
   - Authorization callback URL: `https://auth.example.com/auth/realms/agency/broker/github/endpoint`
4. Click "Register application"
5. Generate a new client secret
6. Note your **Client ID** and **Client Secret**

#### Step 2: Configure Keycloak with GitHub OAuth

```bash
# Set environment variables with your credentials
export GITHUB_CLIENT_ID="your-client-id-from-github"
export GITHUB_CLIENT_SECRET="your-client-secret-from-github"

# Install or update Keycloak with GitHub OAuth
make install-keycloak DOMAIN=auth.example.com ADMIN_EMAIL=admin@example.com ENABLE_OAUTH_GITHUB=true

# Or configure GitHub OAuth on existing Keycloak
make keycloak-oauth-configure DOMAIN=auth.example.com ENABLE_OAUTH_GITHUB=true
```

#### Step 3: Verify GitHub OAuth Configuration

```bash
# Test the OAuth configuration
make keycloak-idp-test DOMAIN=auth.example.com PROVIDER=github

# Check the status
make keycloak-idp-status DOMAIN=auth.example.com
```

#### Example GitHub OAuth Configuration

```json
{
  "alias": "github",
  "displayName": "GitHub",
  "providerId": "github",
  "enabled": true,
  "updateProfileFirstLoginMode": "on",
  "trustEmail": false,
  "storeToken": false,
  "addReadTokenRoleOnCreate": false,
  "authenticateByDefault": false,
  "linkOnly": false,
  "firstBrokerLoginFlowAlias": "first broker login",
  "config": {
    "clientId": "YOUR_GITHUB_CLIENT_ID",
    "clientSecret": "YOUR_GITHUB_CLIENT_SECRET",
    "defaultScope": "user:email",
    "syncMode": "IMPORT"
  }
}
```

### Apple

#### Step 1: Configure Sign in with Apple

1. Go to the [Apple Developer Portal](https://developer.apple.com/)
2. Navigate to "Certificates, IDs & Profiles"
3. Create a new App ID with "Sign In with Apple" capability
4. Create a Services ID with "Sign In with Apple" capability
5. Configure the return URL: `https://auth.example.com/auth/realms/agency/broker/apple/endpoint`
6. Create a private key for Sign In with Apple
7. Note your **Team ID**, **Services ID**, **Key ID**, and download the **Private Key**

#### Step 2: Convert Apple Private Key to Proper Format

```bash
# Convert .p8 file to base64 string for environment variable
KEY_CONTENT=$(cat AuthKey_KEYID.p8 | base64 -w 0)
echo "APPLE_PRIVATE_KEY=\"$KEY_CONTENT\"" > apple_key.env
```

#### Step 3: Configure Keycloak with Apple OAuth

```bash
# Set environment variables with your credentials
export APPLE_CLIENT_ID="your-services-id"  # This is your Services ID
export APPLE_TEAM_ID="your-team-id"
export APPLE_KEY_ID="your-key-id"
source apple_key.env  # Load private key

# Install or update Keycloak with Apple OAuth
make install-keycloak DOMAIN=auth.example.com ADMIN_EMAIL=admin@example.com ENABLE_OAUTH_APPLE=true

# Or configure Apple OAuth on existing Keycloak
make keycloak-oauth-configure DOMAIN=auth.example.com ENABLE_OAUTH_APPLE=true
```

#### Step 4: Verify Apple OAuth Configuration

```bash
# Test the OAuth configuration
make keycloak-idp-test DOMAIN=auth.example.com PROVIDER=apple

# Check the status
make keycloak-idp-status DOMAIN=auth.example.com
```

#### Example Apple OAuth Configuration

```json
{
  "alias": "apple",
  "displayName": "Apple",
  "providerId": "apple",
  "enabled": true,
  "updateProfileFirstLoginMode": "on",
  "trustEmail": false,
  "storeToken": false,
  "addReadTokenRoleOnCreate": false,
  "authenticateByDefault": false,
  "linkOnly": false,
  "firstBrokerLoginFlowAlias": "first broker login",
  "config": {
    "clientId": "YOUR_APPLE_SERVICES_ID",
    "teamId": "YOUR_APPLE_TEAM_ID",
    "keyId": "YOUR_APPLE_KEY_ID",
    "privateKey": "YOUR_BASE64_ENCODED_PRIVATE_KEY",
    "defaultScope": "name email",
    "syncMode": "IMPORT"
  }
}
```

### LinkedIn

#### Step 1: Create LinkedIn OAuth Application

1. Go to [LinkedIn Developers](https://www.linkedin.com/developers/)
2. Click "Create App"
3. Fill in the app details:
   - App name: "AgencyStack Keycloak"
   - LinkedIn Page: Your company LinkedIn page
   - App logo: Upload an appropriate logo
4. Add the OAuth 2.0 authorized redirect URLs: `https://auth.example.com/auth/realms/agency/broker/linkedin/endpoint`
5. Request the following permissions:
   - r_liteprofile
   - r_emailaddress
6. Note your **Client ID** and **Client Secret**

#### Step 2: Configure Keycloak with LinkedIn OAuth

```bash
# Set environment variables with your credentials
export LINKEDIN_CLIENT_ID="your-client-id-from-linkedin"
export LINKEDIN_CLIENT_SECRET="your-client-secret-from-linkedin"

# Install or update Keycloak with LinkedIn OAuth
make install-keycloak DOMAIN=auth.example.com ADMIN_EMAIL=admin@example.com ENABLE_OAUTH_LINKEDIN=true

# Or configure LinkedIn OAuth on existing Keycloak
make keycloak-oauth-configure DOMAIN=auth.example.com ENABLE_OAUTH_LINKEDIN=true
```

#### Step 3: Verify LinkedIn OAuth Configuration

```bash
# Test the OAuth configuration
make keycloak-idp-test DOMAIN=auth.example.com PROVIDER=linkedin

# Check the status
make keycloak-idp-status DOMAIN=auth.example.com
```

#### Example LinkedIn OAuth Configuration

```json
{
  "alias": "linkedin",
  "displayName": "LinkedIn",
  "providerId": "linkedin",
  "enabled": true,
  "updateProfileFirstLoginMode": "on",
  "trustEmail": false,
  "storeToken": false,
  "addReadTokenRoleOnCreate": false,
  "authenticateByDefault": false,
  "linkOnly": false,
  "firstBrokerLoginFlowAlias": "first broker login",
  "config": {
    "clientId": "YOUR_LINKEDIN_CLIENT_ID",
    "clientSecret": "YOUR_LINKEDIN_CLIENT_SECRET",
    "defaultScope": "r_liteprofile r_emailaddress",
    "syncMode": "IMPORT"
  }
}
```

### Microsoft/Azure AD

#### Step 1: Register an Application in Azure AD

1. Go to the [Azure Portal](https://portal.azure.com/)
2. Navigate to "Azure Active Directory" > "App registrations"
3. Click "New registration"
4. Enter a name for your application
5. Set the redirect URI: `https://auth.example.com/auth/realms/agency/broker/microsoft/endpoint`
6. Select supported account types (typically "Accounts in any organizational directory and personal Microsoft accounts")
7. Click "Register"
8. Under "Certificates & secrets", create a new client secret
9. Note your **Application (client) ID** and **Client Secret**

#### Step 2: Configure API Permissions

1. In your app registration, go to "API permissions"
2. Click "Add a permission"
3. Select "Microsoft Graph"
4. Choose "Delegated permissions"
5. Add the following permissions:
   - User.Read
   - email
   - openid
   - profile
6. Click "Add permissions"

#### Step 3: Configure Keycloak with Microsoft OAuth

```bash
# Set environment variables with your credentials
export MICROSOFT_CLIENT_ID="your-application-client-id"
export MICROSOFT_CLIENT_SECRET="your-client-secret"

# Install or update Keycloak with Microsoft OAuth
make install-keycloak DOMAIN=auth.example.com ADMIN_EMAIL=admin@example.com ENABLE_OAUTH_MICROSOFT=true

# Or configure Microsoft OAuth on existing Keycloak
make keycloak-oauth-configure DOMAIN=auth.example.com ENABLE_OAUTH_MICROSOFT=true
```

#### Step 4: Verify Microsoft OAuth Configuration

```bash
# Test the OAuth configuration
make keycloak-idp-test DOMAIN=auth.example.com PROVIDER=microsoft

# Check the status
make keycloak-idp-status DOMAIN=auth.example.com
```

#### Example Microsoft OAuth Configuration

```json
{
  "alias": "microsoft",
  "displayName": "Microsoft",
  "providerId": "microsoft",
  "enabled": true,
  "updateProfileFirstLoginMode": "on",
  "trustEmail": false,
  "storeToken": false,
  "addReadTokenRoleOnCreate": false,
  "authenticateByDefault": false,
  "linkOnly": false,
  "firstBrokerLoginFlowAlias": "first broker login",
  "config": {
    "clientId": "YOUR_MICROSOFT_CLIENT_ID",
    "clientSecret": "YOUR_MICROSOFT_CLIENT_SECRET",
    "defaultScope": "openid profile email",
    "validateSignature": "true",
    "useJwksUrl": "true",
    "syncMode": "IMPORT"
  }
}
```

## Multi-Tenant Examples

AgencyStack supports multi-tenant OAuth configurations where each tenant (client) can have its own set of OAuth providers.

### Example: Configuring OAuth Providers for a Specific Tenant

```bash
# Create a new tenant with Google OAuth
make install-keycloak DOMAIN=auth.example.com CLIENT_ID=tenant1 ADMIN_EMAIL=admin@tenant1.com ENABLE_OAUTH_GOOGLE=true

# Add GitHub OAuth to an existing tenant
make keycloak-oauth-configure DOMAIN=auth.example.com CLIENT_ID=tenant1 ENABLE_OAUTH_GITHUB=true

# Check OAuth status for a specific tenant
make keycloak-idp-status DOMAIN=auth.example.com CLIENT_ID=tenant1
```

### Multi-Tenant Remote Deployment

To deploy multi-tenant OAuth configurations to a remote VM:

```bash
# Deploy Keycloak to remote VM
make deploy-keycloak-remote REMOTE_HOST=hostname.example.com

# Configure tenant-specific OAuth on remote VM
make configure-keycloak-remote REMOTE_HOST=hostname.example.com DOMAIN=auth.example.com CLIENT_ID=tenant1 ENABLE_OAUTH_GOOGLE=true
```

## Integration Examples

### Integrating with LangChain AI Service

```bash
# First, ensure Keycloak is configured with OAuth providers
make keycloak-oauth-configure DOMAIN=auth.example.com ENABLE_OAUTH_GOOGLE=true

# Then configure LangChain to use Keycloak for authentication
make langchain-sso-configure DOMAIN=auth.example.com
```

### Integrating with PeerTube

```bash
# Configure PeerTube with Keycloak SSO that includes OAuth providers
make peertube-sso DOMAIN=peertube.example.com SSO_DOMAIN=auth.example.com
```

## Troubleshooting

### Common Issues and Solutions

| Issue | Solution |
|-------|----------|
| "Redirect URI mismatch" error | Double-check the exact redirect URI in provider settings. It should be: `https://auth.example.com/auth/realms/{realm-name}/broker/{provider}/endpoint` |
| "Invalid client ID" error | Verify your client ID is copied correctly, with no extra spaces |
| "Invalid client secret" error | Regenerate client secret and update configuration |
| OAuth buttons not appearing | Make sure the Identity Provider Redirector is enabled in the browser authentication flow |
| Email verification issues | Check if the email mapper is properly configured and if `trustEmail` is set appropriately |

### Diagnostic Commands

```bash
# Check OAuth provider status
make keycloak-idp-status DOMAIN=auth.example.com

# Run comprehensive health check
make keycloak-oauth-health DOMAIN=auth.example.com VERBOSE=true

# Check Keycloak logs for errors
make keycloak-logs DOMAIN=auth.example.com

# Run diagnostics on identity provider integration
make keycloak-idp-test DOMAIN=auth.example.com PROVIDER=google
```

## Rollback Procedures

If you encounter issues with an OAuth provider configuration, you can follow these rollback procedures:

### Disabling a Problematic Provider

```bash
# Access Keycloak Admin UI
# Navigate to Identity Providers
# Disable the problematic provider
```

Or through API (Makefile target coming soon):

```bash
# Get admin token
ADMIN_TOKEN=$(curl -s -X POST "https://auth.example.com/auth/realms/master/protocol/openid-connect/token" \
  -d "client_id=admin-cli" \
  -d "username=admin" \
  -d "password=password" \
  -d "grant_type=password" | jq -r .access_token)

# Disable provider
curl -X PUT "https://auth.example.com/auth/realms/agency/identity-provider/instances/google" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"enabled": false}'
```

### Complete Removal

```bash
# Get admin token (see above)

# Delete provider
curl -X DELETE "https://auth.example.com/auth/realms/agency/identity-provider/instances/google" \
  -H "Authorization: Bearer $ADMIN_TOKEN"
```

## Upgrade Guide

When upgrading Keycloak or adding new OAuth providers to an existing installation, follow these steps:

### Backup Current Configuration

```bash
# Create a backup directory
mkdir -p ~/keycloak-backups/$(date +%Y%m%d)

# Backup the existing configuration
docker exec -it keycloak_auth.example.com /opt/jboss/keycloak/bin/standalone.sh \
  -Djboss.socket.binding.port-offset=100 \
  -Dkeycloak.migration.action=export \
  -Dkeycloak.migration.provider=singleFile \
  -Dkeycloak.migration.file=/tmp/keycloak-export.json \
  -Dkeycloak.migration.strategy=OVERWRITE_EXISTING

# Copy the export file
docker cp keycloak_auth.example.com:/tmp/keycloak-export.json ~/keycloak-backups/$(date +%Y%m%d)/
```

### Incremental Updates

When adding a new OAuth provider to an existing Keycloak installation:

```bash
# Add a new provider without affecting existing ones
make keycloak-oauth-configure DOMAIN=auth.example.com ENABLE_OAUTH_LINKEDIN=true

# Verify the new provider while ensuring existing ones still work
make keycloak-idp-test DOMAIN=auth.example.com PROVIDER=linkedin
make keycloak-idp-status DOMAIN=auth.example.com
```

### Complete Upgrade

For major version upgrades or comprehensive reconfiguration:

```bash
# Backup existing configuration (see above)

# Perform the upgrade with all required OAuth providers
make install-keycloak DOMAIN=auth.example.com ADMIN_EMAIL=admin@example.com \
  ENABLE_OAUTH_GOOGLE=true \
  ENABLE_OAUTH_GITHUB=true \
  ENABLE_OAUTH_LINKEDIN=true \
  FORCE=true

# Verify all providers are working
make keycloak-idp-status DOMAIN=auth.example.com
```
