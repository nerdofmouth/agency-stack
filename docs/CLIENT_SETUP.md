# Client Setup Guide

This guide explains how to set up new client instances on your FOSS server stack after the main installation is complete.

## Overview

The FOSS server stack supports multi-tenancy through a client bootstrapping system. Each client gets their own instances of:

- ERPNext (ERP system)
- PeerTube (video platform)
- Optional Builder.io space (if enabled)

All client services are managed through Traefik, allowing each client to have their own subdomain or domain.

## Prerequisites

Before setting up a client, ensure:

1. The FOSS server stack is properly installed
2. Traefik is configured and running
3. DNS records for the client domain/subdomain are properly configured
4. You have access to the server where the stack is installed

## Client Setup Process

### Step 1: Navigate to the Scripts Directory

```bash
cd /path/to/foss-server-stack/scripts/agency_stack_bootstrap_bundle_v10
```

### Step 2: Run the Bootstrap Client Script

```bash
bash bootstrap_client.sh client.domain.com
```

Replace `client.domain.com` with the actual domain for the client.

### Step 3: Configure Builder.io Integration (Optional)

If you want to enable Builder.io integration for the client:

1. Edit the client's `.env` file:
   ```bash
   nano clients/client.domain.com/.env
   ```

2. Set `BUILDER_ENABLE=true`:
   ```
   BUILDER_ENABLE=true
   ```

3. Ensure you have set your Builder.io API key in your environment:
   ```bash
   export BUILDER_API_KEY="your_builder_api_key"
   ```

4. Run the bootstrap script again:
   ```bash
   bash bootstrap_client.sh client.domain.com
   ```

### Step 4: Start the Client Services

```bash
cd clients/client.domain.com
docker compose up -d
```

## Client Directory Structure

After bootstrapping a client, the following directory structure is created:

```
clients/
└── client.domain.com/
    ├── .env                  # Environment variables for the client
    └── docker-compose.yml    # Docker configuration for client services
```

## Accessing Client Services

After setup, you can access:

- ERPNext: `https://client.domain.com`
- PeerTube: `https://media.client.domain.com`
- Builder.io (if enabled): Access through the Builder.io dashboard

## Troubleshooting

### Services Not Accessible

1. Check if the services are running:
   ```bash
   docker ps | grep client.domain.com
   ```

2. Verify Traefik is correctly routing traffic:
   ```bash
   docker logs traefik
   ```

3. Ensure DNS records are correctly configured:
   ```bash
   ping client.domain.com
   ping media.client.domain.com
   ```

### Builder.io Integration Issues

If Builder.io integration fails:

1. Check that your Builder.io API key is correct:
   ```bash
   echo $BUILDER_API_KEY
   ```

2. Verify the organization ID in the builderio_provision.sh script:
   ```bash
   grep "YOUR_ORG_ID" ../../scripts/builderio_provision.sh
   ```
   Replace `YOUR_ORG_ID` with your actual Builder.io organization ID.

## Maintaining Client Instances

For ongoing maintenance of client instances, refer to the [Maintenance Guide](MAINTENANCE.md).

## Removing a Client

To remove a client instance:

```bash
cd /path/to/foss-server-stack/clients/client.domain.com
docker compose down
cd ../..
rm -rf clients/client.domain.com
```

> **Note**: This will permanently delete all client data. Make sure to back up any important information first.
