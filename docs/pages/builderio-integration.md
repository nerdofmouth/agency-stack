---
layout: default
title: Builder.io Integration - AgencyStack Documentation
---

# Builder.io Integration

AgencyStack includes comprehensive integration with Builder.io, a powerful visual content management system that allows you to create and manage content without developer involvement.

## Prerequisites

Before using the Builder.io integration in AgencyStack, you need to:

1. **Create a Builder.io Account**:
   - Sign up at [builder.io](https://builder.io)
   - Create an organization or use an existing one

2. **Get Your API Keys**:
   - Navigate to your Builder.io dashboard
   - Go to Account Settings → API Keys
   - Create a Personal Access Token with admin permissions (for provisioning spaces)
   - Copy your Organization ID from the URL or settings page

3. **Update Your AgencyStack Configuration**:
   - Edit the script at `/home/revelationx/CascadeProjects/foss-server-stack/scripts/builderio_provision.sh`
   - Replace `YOUR_ORG_ID` on line 42 with your actual Builder.io organization ID
   - Set the environment variable: `export BUILDER_API_KEY="your-personal-access-token"`

## Provisioning Builder.io for Clients

Builder.io provisioning is integrated into the client creation workflow:

```bash
# Set your Builder.io API key as an environment variable
export BUILDER_API_KEY="your-personal-access-token"

# Create a new client (including Builder.io space)
make client
```

This will:
1. Create a new client in your AgencyStack installation
2. Provision a dedicated Builder.io space for the client
3. Configure all necessary integrations
4. Update the client's .env file with Builder.io credentials

## Manual Provisioning

If you need to manually provision Builder.io for an existing client:

```bash
# Set your API key
export BUILDER_API_KEY="your-personal-access-token"

# Run the provisioning script directly
/opt/agency_stack/scripts/builderio_provision.sh client_name client.domain.com
```

## Using Builder.io with Clients

After provisioning, clients can access their Builder.io dashboard at [builder.io](https://builder.io) using the credentials you provide to them. Content created in Builder.io will automatically appear on their website.

For detailed Builder.io usage instructions, refer to the [official Builder.io documentation](https://www.builder.io/c/docs/getting-started).

## Troubleshooting

### Common Issues

- **API Key Error**: Ensure your Personal Access Token has admin permissions
- **Organization ID Error**: Verify the Organization ID in the provisioning script
- **Connection Error**: Check your internet connection and firewall settings

### Getting Help

If you encounter issues with Builder.io integration:
- Check the Builder.io logs at `/var/log/agency_stack/builder-*.log`
- Contact support@nerdofmouth.com for assistance
