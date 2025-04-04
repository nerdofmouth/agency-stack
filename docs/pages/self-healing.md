---
layout: default
title: Self-Healing Setup - AgencyStack Documentation
---

# Self-Healing Infrastructure Setup

AgencyStack supports a self-healing "buddy system" architecture where multiple servers monitor each other and automatically recover from failures.

## How It Works

The buddy system uses a combination of DroneCI and custom scripts to:

1. **Monitor:** Regularly check the health of other nodes in the cluster
2. **Detect:** Identify when a node has failed or is experiencing issues
3. **Recover:** Automatically restore or rebuild failing nodes
4. **Notify:** Alert administrators of issues and recovery actions

![Buddy System Architecture](../images/buddy-system-diagram.png)

## Setup Instructions

### Prerequisites

- At least two servers running AgencyStack
- Both servers must have public IP addresses or be mutually accessible
- DroneCI installed on all servers (included in AgencyStack by default)

### Configuration Steps

1. **Enable DroneCI monitoring:**

```bash
cd /opt/agency_stack
make enable-monitoring
```

2. **Configure buddy relationships:**

Edit the `/opt/agency_stack/config/buddies.json` file:

```json
{
  "name": "server1.example.com",
  "buddies": [
    {
      "name": "server2.example.com",
      "ip": "192.168.1.2",
      "ssh_key": "/opt/agency_stack/config/buddy_keys/server2.key",
      "check_interval_minutes": 5,
      "recovery_actions": ["restart", "rebuild", "notify"]
    }
  ],
  "notification_email": "admin@example.com",
  "notification_slack_webhook": "https://hooks.slack.com/services/XXX/YYY/ZZZ"
}
```

3. **Generate and exchange SSH keys:**

```bash
cd /opt/agency_stack
make generate-buddy-keys
# Then manually exchange keys between servers
```

4. **Start the buddy monitoring system:**

```bash
make start-buddy-system
```

## Recovery Actions

The system supports multiple recovery actions:

- **restart:** Restart failed services
- **rebuild:** Completely rebuild the server from scratch
- **restore:** Restore from the latest backup
- **notify:** Send notifications but take no action

## DroneCI Integration

DroneCI runs monitoring pipelines that:

1. Check server health metrics
2. Run buddy system monitoring scripts
3. Execute scheduled backups
4. Perform security scans

You can view the DroneCI dashboard at `https://drone.your-agency-stack-domain.com`

## Advanced Configuration

For more advanced configuration options, including custom monitoring checks and recovery scripts, see the [Advanced Monitoring Guide](monitoring-advanced.html).

## Troubleshooting

If you encounter issues with the buddy system:

1. Check the buddy system logs: `/var/log/agency_stack/buddy-system.log`
2. Verify DroneCI is running: `docker ps | grep drone`
3. Check connectivity between servers
4. Review the DroneCI pipeline logs

For assistance, contact [support@nerdofmouth.com](mailto:support@nerdofmouth.com).
