---
layout: default
title: Troubleshooting - AgencyStack Documentation
---

# Troubleshooting Guide

This guide will help you diagnose and resolve common issues with your AgencyStack installation.

## Initial Installation Issues

### Installation Script Fails

**Symptoms:** The one-line installer fails to complete or returns errors.

**Solutions:**

1. **Check system requirements:**
   ```bash
   # Check available memory
   free -h
   
   # Check available disk space
   df -h /
   ```

2. **Check internet connectivity:**
   ```bash
   ping -c 4 github.com
   ```

3. **Try manual installation:**
   ```bash
   git clone https://github.com/nerdofmouth/agency-stack.git /opt/agency-stack
   cd /opt/agency-stack
   chmod +x scripts/*.sh
   make install
   ```

4. **Check logs:**
   ```bash
   cat /var/log/agency_stack/install-*.log
   ```

### Docker Installation Issues

**Symptoms:** Docker fails to install or start properly.

**Solutions:**

1. **Check Docker service:**
   ```bash
   systemctl status docker
   ```

2. **Reinstall Docker:**
   ```bash
   apt-get remove --purge docker-ce docker-ce-cli containerd.io
   rm -rf /var/lib/docker
   apt-get install docker-ce docker-ce-cli containerd.io
   ```

3. **Check Docker logs:**
   ```bash
   journalctl -u docker
   ```

## Network and Domain Issues

### SSL Certificate Errors

**Symptoms:** Unable to obtain SSL certificates, or certificates not renewing.

**Solutions:**

1. **Check DNS configuration:**
   ```bash
   dig +short yourdomain.com
   dig +short www.yourdomain.com
   ```

2. **Verify port 80/443 accessibility:**
   ```bash
   # Test port 80
   curl -I http://yourdomain.com
   
   # Test port 443
   curl -I https://yourdomain.com
   ```

3. **Manual certificate renewal:**
   ```bash
   cd /opt/agency_stack
   ./scripts/renew_certificates.sh --force
   ```

### Network Connectivity Issues

**Symptoms:** Services can't connect to each other or external resources.

**Solutions:**

1. **Check Docker network:**
   ```bash
   docker network ls
   docker network inspect traefik
   ```

2. **Restart Traefik:**
   ```bash
   cd /opt/agency_stack
   docker-compose restart traefik
   ```

3. **Check firewall rules:**
   ```bash
   ufw status
   ```

## Service-Specific Issues

### WordPress Issues

**Symptoms:** WordPress site not loading, database connection issues.

**Solutions:**

1. **Check WordPress container:**
   ```bash
   docker ps | grep wordpress
   docker logs wordpress_clientdomain
   ```

2. **Reset WordPress database connection:**
   ```bash
   cd /opt/agency_stack/clients/client.domain.com
   docker-compose restart wordpress
   ```

### ERPNext Issues

**Symptoms:** ERPNext not loading or throwing errors.

**Solutions:**

1. **Check ERPNext containers:**
   ```bash
   docker ps | grep erpnext
   ```

2. **Restart ERPNext services:**
   ```bash
   cd /opt/agency_stack/clients/client.domain.com
   docker-compose restart erpnext erpnext-worker
   ```

3. **Check logs:**
   ```bash
   docker logs erpnext_clientdomain
   ```

## Backup and Restore Issues

### Backup Failures

**Symptoms:** Backups failing to complete or corrupted backups.

**Solutions:**

1. **Check disk space:**
   ```bash
   df -h /opt/agency_stack/backups
   ```

2. **Try manual backup:**
   ```bash
   cd /opt/agency_stack
   ./scripts/backup.sh --verbose
   ```

3. **Check backup logs:**
   ```bash
   cat /var/log/agency_stack/backup-*.log
   ```

### Restore Failures

**Symptoms:** Unable to restore from backup.

**Solutions:**

1. **Verify backup integrity:**
   ```bash
   tar -tzf /path/to/backup.tar.gz
   ```

2. **Try alternative restore method:**
   ```bash
   cd /opt/agency_stack
   ./scripts/restore.sh --alternative /path/to/backup.tar.gz
   ```

## Buddy System Issues

### Buddy System Not Monitoring

**Symptoms:** Buddy system fails to monitor or recover servers.

**Solutions:**

1. **Check buddy system configuration:**
   ```bash
   cat /opt/agency_stack/config/buddies.json
   ```

2. **Verify SSH connectivity:**
   ```bash
   ssh -i /opt/agency_stack/config/buddy_keys/server.key root@buddy-server-ip echo "Test"
   ```

3. **Restart buddy monitoring:**
   ```bash
   cd /opt/agency_stack
   make buddy-monitor
   ```

4. **Check logs:**
   ```bash
   cat /var/log/agency_stack/buddy-system.log
   ```

### DroneCI Integration Issues

**Symptoms:** DroneCI pipelines not running or failing.

**Solutions:**

1. **Check DroneCI containers:**
   ```bash
   docker ps | grep drone
   ```

2. **Restart DroneCI:**
   ```bash
   cd /opt/agency_stack
   docker-compose restart drone-server drone-runner
   ```

3. **Check logs:**
   ```bash
   docker logs drone-server
   docker logs drone-runner
   ```

## Performance Issues

### High CPU/Memory Usage

**Symptoms:** Server responding slowly, high CPU or memory usage.

**Solutions:**

1. **Check system resources:**
   ```bash
   cd /opt/agency_stack
   make rootofmouth
   ```

2. **Identify resource-intensive containers:**
   ```bash
   docker stats
   ```

3. **Adjust container resource limits:**
   Edit `/opt/agency_stack/clients/client.domain.com/docker-compose.yml` to add resource constraints.

### Disk Space Issues

**Symptoms:** Low disk space warnings, services failing to start.

**Solutions:**

1. **Check disk usage:**
   ```bash
   df -h
   ```

2. **Find large directories:**
   ```bash
   du -h --max-depth=1 /opt/agency_stack | sort -hr
   ```

3. **Clean old backups and logs:**
   ```bash
   cd /opt/agency_stack
   ./scripts/cleanup_old_backups.sh
   ./scripts/cleanup_logs.sh
   ```

4. **Prune Docker resources:**
   ```bash
   docker system prune -a
   ```

## Getting Help

If you've tried these troubleshooting steps and still have issues:

1. **Run diagnostic report:**
   ```bash
   cd /opt/agency_stack
   ./scripts/generate_diagnostic_report.sh
   ```

2. **Contact support:**
   Email the diagnostic report to [support@nerdofmouth.com](mailto:support@nerdofmouth.com)

3. **Check GitHub issues:**
   Visit [GitHub Issues](https://github.com/nerdofmouth/agency-stack/issues) to see if others have reported the same problem.

4. **Community resources:**
   Join our [Community Forum](https://community.nerdofmouth.com) for peer support.
