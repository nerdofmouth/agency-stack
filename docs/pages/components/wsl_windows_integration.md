# WSL/Windows Integration Guide for PeaceFestivalUSA Deployment

## Overview

This document provides guidance for deploying PeaceFestivalUSA WordPress in a Windows with WSL2 environment, adhering to the AgencyStack Charter v1.0.3 principles, particularly "WSL2/Docker Mount Safety" and "Repository as Source of Truth."

## Environment-Specific Challenges

When deploying in a Windows/WSL hybrid environment, several key issues require specific handling:

1. **Path Resolution**: Windows and Linux use different path formats
2. **File/Directory Type Consistency**: Docker mounts may encounter issues across environments
3. **Network Routing**: Hostname resolution may differ between WSL and Windows
4. **Docker Runtime Location**: Docker may run natively in WSL or in Windows host

## Installation Components

Following the AgencyStack Repository Integrity Policy, all components are properly defined in the repository:

| Component | Repository Location | Purpose |
|-----------|---------------------|---------|
| WSL Integration Script | `/scripts/components/taskmaster/peacefestival_wsl_integration.js` | Environment detection and integration setup |
| SQLite Wrapper | `/opt/agency_stack/clients/peacefestivalusa/sqlite_wrapper.sh` | WSL-compatible SQLite MCP access |
| Cross-Environment Tests | `/opt/agency_stack/clients/peacefestivalusa/tests/cross_env_test.sh` | Testing from both WSL and Windows perspectives |
| Charter Addendum | `/opt/agency_stack/clients/peacefestivalusa/WSL_CHARTER_ADDENDUM.md` | WSL-specific updates to Charter principles |
| TaskMaster WSL Integration | `/root/_repos/agency-stack/scripts/components/taskmaster/template_wsl_aware.js` | WSL-aware TaskMaster template |

## WSL/Windows Installation Process

### 1. Environment Detection

The system automatically detects whether it's running in WSL and configures paths accordingly:

```javascript
// Detection code from peacefestival_wsl_integration.js
async function detectEnvironment() {
  const wslCheck = await executeCommand('grep -i microsoft /proc/version || echo "Not WSL"');
  const isWSL = wslCheck.stdout && !wslCheck.stdout.includes('Not WSL');
  
  if (isWSL) {
    // WSL-specific configuration
    const hostIp = await executeCommand('cat /etc/resolv.conf | grep nameserver | cut -d " " -f 2');
    // ...
  }
}
```

### 2. Path Translation

When running in a WSL environment with Windows Docker, paths must be translated:

```javascript
// Windows path translation
const pathTranslator = async (linuxPath) => {
  if (dockerProvider === 'windows') {
    const { stdout: windowsPath } = await exec(`wslpath -w "${linuxPath}"`);
    return windowsPath.trim();
  }
  return linuxPath;
};
```

### 3. Cross-Environment Testing

Each deployment is validated from both WSL and Windows perspectives:

```bash
# Testing Windows access from WSL
test_windows_access() {
  local service_name="$1"
  local hostname="$2"
  local port="$3"
  
  if [ "$IS_WSL" = true ]; then
    curl -s -o /dev/null -w "%{http_code}" -H "Host: $hostname" "http://$WINDOWS_HOST_IP:$port"
  fi
}
```

## Hostname Resolution

For proper hostname resolution across environments:

1. Add entries to both WSL `/etc/hosts` and Windows `C:\Windows\System32\drivers\etc\hosts`:
   ```
   127.0.0.1 peacefestivalusa.localhost
   127.0.0.1 traefik.peacefestivalusa.localhost
   ```

2. Use the provided helper script:
   ```bash
   /opt/agency_stack/clients/peacefestivalusa/add_windows_hosts.sh
   ```

## Docker Volume Mounts

Docker volume mounts are handled differently based on the environment:

1. **WSL with WSL Docker**: Use Linux paths directly
   ```
   -v /opt/agency_stack/data:/container/path
   ```

2. **WSL with Windows Docker**: Convert paths using wslpath
   ```
   -v $(wslpath -w /opt/agency_stack/data):/container/path
   ```

3. **Preferred Approach**: Use named volumes to avoid path issues
   ```
   docker volume create my_data_volume
   -v my_data_volume:/container/path
   ```

## SQLite MCP Integration

The SQLite wrapper script handles environment-specific path differences:

```bash
# From sqlite_wrapper.sh
if grep -q Microsoft /proc/version; then
  # WSL environment
  if docker info 2>/dev/null | grep -q 'windows'; then
    # Windows Docker needs Windows-style paths
    DB_DIR_WIN="$(wslpath -w "${DB_DIR}")"
    VOLUME_MOUNT="-v ${DB_DIR_WIN}:/mcp"
  else
    # WSL Docker can use Linux paths
    VOLUME_MOUNT="-v ${DB_DIR}:/mcp"
  fi
else
  # Native Linux
  VOLUME_MOUNT="-v ${DB_DIR}:/mcp"
fi
```

## Testing in WSL/Windows Environment

To test the deployment in a WSL/Windows environment:

1. Run the cross-environment test script:
   ```bash
   /opt/agency_stack/clients/peacefestivalusa/tests/cross_env_test.sh
   ```

2. Check the results for both WSL and Windows access:
   ```bash
   cat /opt/agency_stack/clients/peacefestivalusa/tests/cross_env_results.log
   ```

## TaskMaster-AI Integration

All TaskMaster scripts should include WSL awareness:

1. Use the provided template:
   ```bash
   cp /root/_repos/agency-stack/scripts/components/taskmaster/template_wsl_aware.js /path/to/new_script.js
   ```

2. Incorporate environment detection:
   ```javascript
   const env = await detectEnvironment();
   const mountPath = await env.pathTranslator('/path/to/mount');
   ```

## Troubleshooting

Common issues and solutions when running in WSL/Windows:

| Issue | Solution |
|-------|----------|
| Hostname not resolving | Add entries to both WSL and Windows hosts files |
| Docker volume mount errors | Use named volumes or proper path translation |
| Network connectivity issues | Check firewall settings and WSL network integration |
| Docker socket connection issues | Ensure Docker is running and socket is accessible |

## Conclusion

By following these guidelines, you can successfully deploy PeaceFestivalUSA WordPress in a Windows/WSL hybrid environment while adhering to the AgencyStack Charter v1.0.3 principles and Repository Integrity Policy.

This document is a living component of the AgencyStack repository and should be updated as new WSL/Windows integration patterns emerge.
