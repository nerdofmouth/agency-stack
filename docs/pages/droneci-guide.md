---
layout: default
title: DroneCI Integration - AgencyStack Documentation
---

# DroneCI Integration Guide

AgencyStack includes DroneCI as a powerful continuous integration and delivery platform that integrates with your development workflow and supports the self-healing buddy system.

## What is DroneCI?

DroneCI is an open-source continuous integration platform built on container technology. In AgencyStack, it provides:

- Automated testing and deployment
- Integration with Git repositories
- Self-healing infrastructure pipelines
- Monitoring and system checks

## Accessing DroneCI

After installation, access your DroneCI instance at:

```
https://drone.yourdomain.com
```

## Basic Configuration

DroneCI is pre-configured with the AgencyStack installation, but requires a few steps to connect to your repositories:

1. Log in using your configured authentication method
2. Connect your Git provider (GitHub, GitLab, etc.)
3. Activate repositories you want to build

## Self-Healing Integration

DroneCI is a key component of the AgencyStack buddy system:

### Monitoring Pipelines

The buddy system uses DroneCI to run regular health checks:

```yaml
kind: pipeline
type: docker
name: system-health-check

trigger:
  event:
    - cron
  cron:
    - health-check

steps:
  - name: check-system-health
    image: alpine
    commands:
      - apk add --no-cache bash jq curl
      - /opt/agency_stack/scripts/system_check.sh

  - name: notify-on-failure
    image: plugins/slack
    settings:
      webhook: 
        from_secret: slack_webhook
      channel: alerts
      template: >
        {{#success build.status}}
          ✅ System health check passed
        {{else}}
          ❌ System health check failed
          {{build.link}}
        {{/success}}
    when:
      status: [success, failure]
```

### Recovery Pipelines

The buddy system can trigger recovery actions through DroneCI:

```yaml
kind: pipeline
type: docker
name: system-recovery

trigger:
  event:
    - custom
  
steps:
  - name: backup-before-recovery
    image: alpine
    commands:
      - apk add --no-cache bash
      - /opt/agency_stack/scripts/backup.sh

  - name: perform-recovery
    image: alpine
    commands:
      - apk add --no-cache bash
      - /opt/agency_stack/scripts/recovery.sh

  - name: notify-recovery-status
    image: plugins/slack
    settings:
      webhook:
        from_secret: slack_webhook
      channel: alerts
      template: >
        {{#success build.status}}
          ✅ System recovery completed successfully
        {{else}}
          ❌ System recovery failed
          {{build.link}}
        {{/success}}
    when:
      status: [success, failure]
```

## Setting Up Custom Pipelines

You can create custom pipelines for your specific needs:

1. Create a `.drone.yml` file in your repository
2. Define your pipeline steps
3. Push to your Git repository
4. Activate the repository in DroneCI

## Common Pipeline Examples

### WordPress Theme/Plugin Deployment

```yaml
kind: pipeline
type: docker
name: deploy-wordpress

steps:
  - name: deploy-to-staging
    image: alpine
    commands:
      - apk add --no-cache rsync openssh-client
      - mkdir -p ~/.ssh
      - echo "$SSH_KEY" > ~/.ssh/id_rsa
      - chmod 600 ~/.ssh/id_rsa
      - rsync -avz --delete ./plugin/ user@staging-server:/path/to/wordpress/wp-content/plugins/my-plugin/
    environment:
      SSH_KEY:
        from_secret: ssh_key
    when:
      branch: develop

  - name: deploy-to-production
    image: alpine
    commands:
      - apk add --no-cache rsync openssh-client
      - mkdir -p ~/.ssh
      - echo "$SSH_KEY" > ~/.ssh/id_rsa
      - chmod 600 ~/.ssh/id_rsa
      - rsync -avz --delete ./plugin/ user@production-server:/path/to/wordpress/wp-content/plugins/my-plugin/
    environment:
      SSH_KEY:
        from_secret: ssh_key
    when:
      branch: main
```

### Database Backup

```yaml
kind: pipeline
type: docker
name: database-backup

trigger:
  event:
    - cron
  cron:
    - daily-backup
    
steps:
  - name: backup-databases
    image: alpine
    commands:
      - apk add --no-cache bash
      - /opt/agency_stack/scripts/backup_databases.sh
      
  - name: upload-to-s3
    image: plugins/s3
    settings:
      bucket: my-backup-bucket
      region: us-east-1
      source: /opt/agency_stack/backups/latest/*.sql.gz
      target: /databases/
      access_key:
        from_secret: aws_access_key_id
      secret_key:
        from_secret: aws_secret_access_key
```

## Best Practices

1. **Secrets Management**: Store sensitive information as DroneCI secrets
2. **Reuse Steps**: Create reusable pipeline steps for common tasks
3. **Notifications**: Configure notifications for pipeline statuses
4. **Resource Limits**: Set resource limits for pipeline steps
5. **Caching**: Use caching to speed up builds

## Troubleshooting

If you encounter issues with DroneCI:

1. Check the logs in Drone's web interface
2. Verify container health: `docker ps | grep drone`
3. Check the DroneCI configuration: `/opt/agency_stack/config/drone/`
4. Restart the DroneCI service: `docker-compose restart drone-server drone-runner`

For more assistance, see our [Troubleshooting Guide](troubleshooting.html) or contact [support@nerdofmouth.com](mailto:support@nerdofmouth.com).
