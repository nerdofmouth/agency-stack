#!/usr/bin/env node

/**
 * PeaceFestivalUSA WSL/Windows Integration Plan
 * Using Taskmaster-AI for Cross-Environment Deployment
 * 
 * Following AgencyStack Charter v1.0.3 principles:
 * - Repository as Source of Truth
 * - WSL2/Docker Mount Safety
 * - Strict Containerization
 * - Proper Change Workflow
 * - TDD Protocol with cross-environment validation
 */

const fs = require('fs');
const path = require('path');
const { promisify } = require('util');
const exec = promisify(require('child_process').exec);

// AgencyStack Charter-compliant paths
const REPO_ROOT = path.resolve(__dirname, '../../../');
const LOG_DIR = '/var/log/agency_stack/components';
const CLIENT_ID = 'peacefestivalusa';
const LOG_FILE = path.join(LOG_DIR, `${CLIENT_ID}_wsl_integration.log`);
const CLIENT_DIR = `/opt/agency_stack/clients/${CLIENT_ID}`;

// Ensure log directory exists
if (!fs.existsSync(LOG_DIR)) {
  fs.mkdirSync(LOG_DIR, { recursive: true });
}

// Logger function with timestamp
function log(message, type = 'INFO') {
  const timestamp = new Date().toISOString();
  const logMessage = `[${timestamp}] [${type}] ${message}`;
  
  console.log(logMessage);
  
  // Write to log file following Charter logging standards
  fs.appendFileSync(LOG_FILE, logMessage + '\n');
}

// Execute shell command with proper error handling
async function executeCommand(command, cwd = REPO_ROOT) {
  log(`Executing: ${command}`, 'COMMAND');
  
  try {
    const { stdout, stderr } = await exec(command, { cwd });
    if (stdout) log(stdout.trim(), 'STDOUT');
    if (stderr) log(stderr.trim(), 'STDERR');
    return { success: true, stdout, stderr };
  } catch (error) {
    log(`Error executing command: ${error.message}`, 'ERROR');
    if (error.stdout) log(error.stdout.trim(), 'STDOUT');
    if (error.stderr) log(error.stderr.trim(), 'STDERR');
    return { success: false, error };
  }
}

// WSL/Windows Environment Detection and Handling
async function detectEnvironment() {
  const results = {
    isWSL: false,
    isWindowsHost: false,
    dockerProvider: 'unknown',
    hostIp: '127.0.0.1', // Default fallback
  };
  
  try {
    // Check for WSL
    const wslCheck = await executeCommand('grep -i microsoft /proc/version || echo "Not WSL"');
    results.isWSL = wslCheck.stdout && !wslCheck.stdout.includes('Not WSL');
    
    if (results.isWSL) {
      log('Running in WSL environment', 'INFO');
      
      // Get Windows Host IP for proper hostname resolution
      const hostIp = await executeCommand('cat /etc/resolv.conf | grep nameserver | cut -d " " -f 2');
      if (hostIp.stdout && hostIp.stdout.trim()) {
        results.hostIp = hostIp.stdout.trim();
        log(`Windows host IP detected: ${results.hostIp}`, 'INFO');
      }
      
      // Detect Docker provider (WSL2 Docker or Windows Docker)
      const dockerInfo = await executeCommand('docker info');
      if (dockerInfo.stdout && dockerInfo.stdout.includes('linux')) {
        results.dockerProvider = 'wsl';
        log('Docker is running natively in WSL', 'INFO');
      } else {
        results.dockerProvider = 'windows';
        log('Docker is running on Windows host', 'INFO');
        results.isWindowsHost = true;
      }
    } else {
      log('Running in native Linux environment', 'INFO');
      results.dockerProvider = 'native';
    }
  } catch (error) {
    log(`Error detecting environment: ${error.message}`, 'ERROR');
  }
  
  return results;
}

// Integration steps for WSL/Windows compatibility
const integrationSteps = {
  // Phase 1: Environment Detection and Analysis
  async analyzeEnvironment() {
    log('PHASE 1: ANALYZING WSL/WINDOWS ENVIRONMENT', 'PHASE');
    
    const envInfo = await detectEnvironment();
    
    // Create environment info file for reference
    fs.writeFileSync(`${CLIENT_DIR}/environment.json`, JSON.stringify(envInfo, null, 2));
    log(`Environment information saved to ${CLIENT_DIR}/environment.json`, 'INFO');
    
    // Create hosts file entry instructions
    if (envInfo.isWSL) {
      log('Creating hosts file helpers for WSL...', 'INFO');
      
      const hostsEntryScript = `#!/bin/bash
# Add hosts entries to Windows hosts file from WSL
# Following AgencyStack Charter v1.0.3 principles

echo "Adding hosts entries to Windows hosts file..."
cat << EOF > /tmp/hosts_entries.txt
# AgencyStack PeaceFestivalUSA entries
127.0.0.1 peacefestivalusa.localhost
127.0.0.1 traefik.peacefestivalusa.localhost
EOF

echo "Run this command in a Windows PowerShell with Administrator privileges:"
echo "-----------------------------------------------------------------------"
echo "cat $(wslpath -w /tmp/hosts_entries.txt) | Add-Content -Path \$env:windir\\System32\\drivers\\etc\\hosts"
echo "-----------------------------------------------------------------------"
`;
      
      fs.writeFileSync(`${CLIENT_DIR}/add_windows_hosts.sh`, hostsEntryScript);
      chmod(`${CLIENT_DIR}/add_windows_hosts.sh`, '755');
      log(`Created Windows hosts file helper at ${CLIENT_DIR}/add_windows_hosts.sh`, 'INFO');
    }
    
    return envInfo;
  },
  
  // Phase 2: SQLite MCP Integration for WSL/Windows
  async integrateWithSQLite(envInfo) {
    log('PHASE 2: SQLITE MCP INTEGRATION FOR WSL/WINDOWS', 'PHASE');
    
    // Create a WSL-compatible SQLite wrapper to handle path differences
    const sqliteWrapperScript = `#!/bin/bash
# SQLite MCP WSL-Compatible Wrapper
# Following AgencyStack Charter v1.0.3 principles:
# - WSL2/Docker Mount Safety
# - Repository as Source of Truth

SCRIPT_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
DB_DIR="/opt/agency_stack/clients/peacefestivalusa/db"
LOG_DIR="/var/log/agency_stack/components"
MCP_VOLUME="mcp-peacefestivalusa"

# Ensure directories exist
mkdir -p "\${DB_DIR}"
mkdir -p "\${LOG_DIR}"

# Detect WSL environment
if grep -q Microsoft /proc/version; then
  echo "Running in WSL environment, applying path mappings..."
  # Convert WSL paths to Windows paths if needed for Docker volume mounts
  if docker info 2>/dev/null | grep -q 'windows'; then
    # Running Docker for Windows - need Windows-style paths
    DB_DIR_WIN="\$(wslpath -w "\${DB_DIR}")"
    VOLUME_MOUNT="-v \${DB_DIR_WIN}:/mcp"
    echo "Using Windows Docker with path: \${DB_DIR_WIN}"
  else
    # Running Docker in WSL - can use Linux paths
    VOLUME_MOUNT="-v \${DB_DIR}:/mcp"
    echo "Using WSL Docker with path: \${DB_DIR}"
  fi
else
  # Native Linux environment
  VOLUME_MOUNT="-v \${DB_DIR}:/mcp"
  echo "Using native Linux with path: \${DB_DIR}"
fi

# Force volume creation to avoid permission issues
docker volume create \${MCP_VOLUME} 2>/dev/null || true

# Run SQLite command with proper volume mount
if [ "\$1" = "query" ]; then
  # Handle the query subcommand for compatibility
  shift
  echo "\$1" | docker run --rm -i \\
    \${VOLUME_MOUNT} \\
    mcp/sqlite --db-path "/mcp/peacefestivalusa.db" \\
    -header -column
else
  # Pass all args to the container
  docker run --rm -i \\
    \${VOLUME_MOUNT} \\
    mcp/sqlite --db-path "/mcp/peacefestivalusa.db" "$@"
fi
`;
    
    const dbDir = `${CLIENT_DIR}/db`;
    if (!fs.existsSync(dbDir)) {
      fs.mkdirSync(dbDir, { recursive: true });
    }
    
    fs.writeFileSync(`${CLIENT_DIR}/sqlite_wrapper.sh`, sqliteWrapperScript);
    await executeCommand(`chmod +x ${CLIENT_DIR}/sqlite_wrapper.sh`);
    log(`Created WSL-compatible SQLite wrapper at ${CLIENT_DIR}/sqlite_wrapper.sh`, 'INFO');
    
    // Create a deployment learnings database schema
    const sqlSchema = `
-- AgencyStack Deployment Learnings Schema
-- Following AgencyStack Charter v1.0.3 principles

CREATE TABLE IF NOT EXISTS deployment_lessons (
  id INTEGER PRIMARY KEY,
  title TEXT NOT NULL,
  category TEXT NOT NULL,
  lesson TEXT NOT NULL,
  solution TEXT NOT NULL,
  environment TEXT,
  date TEXT NOT NULL
);

-- Create index on category
CREATE INDEX IF NOT EXISTS idx_category ON deployment_lessons(category);

-- Add WSL/Windows specific lessons
INSERT INTO deployment_lessons (title, category, lesson, solution, environment, date)
VALUES 
('WSL/Windows Host Resolution', 
 'Environment', 
 'Hostname resolution may fail across WSL/Windows boundary when using localhost aliases.',
 'Use direct IP addressing or add entries to both WSL and Windows hosts files.', 
 'WSL/Windows', 
 '${new Date().toISOString().split('T')[0]}'),
 
('Docker Volume Mounts in WSL', 
 'Docker', 
 'Docker volume mounts require different path formats depending on where Docker is running (WSL or Windows).',
 'Create environment-aware wrapper scripts that detect the environment and use appropriate path formats.', 
 'WSL/Windows', 
 '${new Date().toISOString().split('T')[0]}'),
 
('Cross-Environment Testing', 
 'Testing', 
 'Tests may pass in WSL but fail when accessed from Windows browser due to networking differences.',
 'Implement multi-environment testing that validates from both WSL and Windows perspectives.', 
 'WSL/Windows', 
 '${new Date().toISOString().split('T')[0]}');
`;
    
    fs.writeFileSync(`${CLIENT_DIR}/db/wsl_lessons.sql`, sqlSchema);
    log(`Created WSL-specific lessons schema at ${CLIENT_DIR}/db/wsl_lessons.sql`, 'INFO');
    
    // Initialize the database
    await executeCommand(`cat ${CLIENT_DIR}/db/wsl_lessons.sql | ${CLIENT_DIR}/sqlite_wrapper.sh`);
    log('Initialized SQLite database with WSL-specific lessons', 'INFO');
    
    return { success: true };
  },
  
  // Phase 3: Cross-Environment Testing Framework
  async setupCrossEnvironmentTesting(envInfo) {
    log('PHASE 3: CROSS-ENVIRONMENT TESTING FRAMEWORK', 'PHASE');
    
    const testScript = `#!/bin/bash
# PeaceFestivalUSA Cross-Environment Tests
# Following AgencyStack Charter v1.0.3 principles:
# - TDD Protocol
# - WSL2/Docker Mount Safety
# - Proper Change Workflow

CLIENT_DIR="/opt/agency_stack/clients/peacefestivalusa"
LOG_DIR="${CLIENT_DIR}/tests"
RESULTS_FILE="${LOG_DIR}/cross_env_results.log"

mkdir -p "$LOG_DIR"
echo "# Cross-Environment Test Results" > "$RESULTS_FILE"
echo "Date: $(date)" >> "$RESULTS_FILE"
echo "----------------------------------------" >> "$RESULTS_FILE"

# Detect environment
IS_WSL=false
WINDOWS_HOST_IP="127.0.0.1"

if grep -q Microsoft /proc/version 2>/dev/null; then
  IS_WSL=true
  WINDOWS_HOST_IP=$(cat /etc/resolv.conf | grep nameserver | cut -d " " -f 2)
  echo "WSL environment detected. Windows host IP: $WINDOWS_HOST_IP" >> "$RESULTS_FILE"
else
  echo "Native Linux environment detected." >> "$RESULTS_FILE"
fi

# Test Functions
test_local_access() {
  local service_name="$1"
  local url="$2"
  
  echo -n "Testing local access to $service_name... "
  if curl -s -o /dev/null -w "%{http_code}" "$url" | grep -q "200\\|301\\|302"; then
    echo "PASSED"
    echo "✅ Local access to $service_name: PASSED" >> "$RESULTS_FILE"
    return 0
  else
    echo "FAILED"
    echo "❌ Local access to $service_name: FAILED" >> "$RESULTS_FILE"
    return 1
  fi
}

# Windows host access simulation if in WSL
test_windows_access() {
  local service_name="$1"
  local hostname="$2"
  local port="$3"
  
  if [ "$IS_WSL" = true ]; then
    # In WSL, we can test access via Windows host IP
    echo -n "Testing Windows host access to $service_name... "
    if curl -s -o /dev/null -w "%{http_code}" -H "Host: $hostname" "http://$WINDOWS_HOST_IP:$port" | grep -q "200\\|301\\|302"; then
      echo "PASSED"
      echo "✅ Windows host access to $service_name: PASSED" >> "$RESULTS_FILE"
      return 0
    else
      echo "FAILED"
      echo "❌ Windows host access to $service_name: FAILED" >> "$RESULTS_FILE"
      echo "   NOTE: This may require adding '$hostname' to Windows hosts file." >> "$RESULTS_FILE"
      return 1
    fi
  else
    # Not in WSL, skip this test
    echo "Skipping Windows host access test (not in WSL)"
    echo "ℹ️ Windows host access to $service_name: SKIPPED (not in WSL)" >> "$RESULTS_FILE"
    return 0
  fi
}

# Run tests
echo "Running cross-environment tests..."

# Test WordPress and Traefik access
test_local_access "WordPress" "http://peacefestivalusa.localhost"
test_local_access "WordPress direct port" "http://localhost:8082"
test_local_access "Traefik dashboard" "http://traefik.peacefestivalusa.localhost"

# Test Windows host access if in WSL
if [ "$IS_WSL" = true ]; then
  test_windows_access "WordPress" "peacefestivalusa.localhost" "80"
  test_windows_access "Traefik dashboard" "traefik.peacefestivalusa.localhost" "80"
fi

# Check SQLite accessibility
echo -n "Testing SQLite MCP accessibility... "
if ${CLIENT_DIR}/sqlite_wrapper.sh query "SELECT 1 as test" | grep -q "test.*1"; then
  echo "PASSED"
  echo "✅ SQLite MCP accessibility: PASSED" >> "$RESULTS_FILE"
else
  echo "FAILED"
  echo "❌ SQLite MCP accessibility: FAILED" >> "$RESULTS_FILE"
fi

echo "Tests completed. Results saved to $RESULTS_FILE"
echo "For Windows browser access, ensure hostname entries are in the Windows hosts file."
echo "Run '${CLIENT_DIR}/add_windows_hosts.sh' for instructions."
`;
    
    fs.writeFileSync(`${CLIENT_DIR}/tests/cross_env_test.sh`, testScript);
    await executeCommand(`chmod +x ${CLIENT_DIR}/tests/cross_env_test.sh`);
    log(`Created cross-environment test script at ${CLIENT_DIR}/tests/cross_env_test.sh`, 'INFO');
    
    // Run the cross-environment tests
    await executeCommand(`${CLIENT_DIR}/tests/cross_env_test.sh`);
    
    return { success: true };
  },
  
  // Phase 4: Charter Updates for WSL/Windows Considerations
  async updateCharter() {
    log('PHASE 4: CHARTER UPDATES FOR WSL/WINDOWS CONSIDERATIONS', 'PHASE');
    
    const charterUpdates = `# WSL/Windows Hybrid Environment Considerations
## AgencyStack Charter v1.0.3 Addendum

Following the existing "WSL2/Docker Mount Safety" principle, this addendum provides specific guidance for working in hybrid WSL/Windows environments:

### 1. Path Mapping Requirements

- **Always detect environment type** before performing path-sensitive operations
- **Use wrapper scripts** that handle path translation between WSL and Windows formats
- **Never hardcode Windows-style paths** in repository-tracked scripts
- **Document required hosts file entries** for both WSL and Windows environments

### 2. Network Access Considerations

- **Prefer IP-based access** over hostname resolution for cross-environment services
- **Test service access from both environments** (WSL terminal and Windows browser)
- **Document port forwarding requirements** when WSL network isolation is in effect

### 3. Docker Volume Mounts

- **Always validate volume mounts** in both WSL and Windows Docker contexts
- **Use Docker named volumes** when possible to avoid path translation issues
- **Document volume mount strategies** specific to WSL/Windows hybrid environments

### 4. Development Environment Setup

- **Provide both WSL and Windows setup instructions** for developer onboarding
- **Validate scripts in both environments** before merging to main branch
- **Use containerized tooling** where possible to minimize environment-specific issues

This addendum extends but does not replace any existing Charter principles.
`;
    
    fs.writeFileSync(`${CLIENT_DIR}/WSL_CHARTER_ADDENDUM.md`, charterUpdates);
    log(`Created WSL/Windows Charter addendum at ${CLIENT_DIR}/WSL_CHARTER_ADDENDUM.md`, 'INFO');
    
    return { success: true };
  },
  
  // Phase 5: TaskMaster-AI Integration with WSL Awareness
  async updateTaskmasterAI() {
    log('PHASE 5: TASKMASTER-AI INTEGRATION WITH WSL AWARENESS', 'PHASE');
    
    const taskmasterUpdates = `// WSL-Aware TaskMaster-AI Integration
// Add to the beginning of all TaskMaster scripts

/**
 * WSL/Windows Environment Detection
 * Following AgencyStack Charter v1.0.3 principles:
 * - WSL2/Docker Mount Safety
 * - Repository as Source of Truth
 * - Proper Change Workflow
 */
async function detectEnvironment() {
  try {
    // Check for WSL
    const { stdout: wslCheck } = await exec('grep -i microsoft /proc/version || echo "Not WSL"');
    const isWSL = wslCheck && !wslCheck.includes('Not WSL');
    
    if (isWSL) {
      log('WSL environment detected - applying path mappings and host resolution fixes', 'INFO');
      
      // Get Windows Host IP for proper hostname resolution
      const { stdout: hostIp } = await exec('cat /etc/resolv.conf | grep nameserver | cut -d " " -f 2');
      const windowsHostIp = (hostIp && hostIp.trim()) ? hostIp.trim() : '127.0.0.1';
      
      // Detect Docker provider (WSL2 Docker or Windows Docker)
      const { stdout: dockerInfo } = await exec('docker info');
      const dockerProvider = (dockerInfo && dockerInfo.includes('linux')) ? 'wsl' : 'windows';
      
      return {
        isWSL: true,
        windowsHostIp,
        dockerProvider,
        pathTranslator: (linuxPath) => {
          // Convert paths if using Windows Docker
          if (dockerProvider === 'windows') {
            // Use wslpath to convert Linux paths to Windows paths for volume mounts
            const { stdout: windowsPath } = await exec(\`wslpath -w "\${linuxPath}"\`);
            return windowsPath.trim();
          }
          return linuxPath;
        }
      };
    } else {
      return {
        isWSL: false,
        windowsHostIp: null,
        dockerProvider: 'native',
        pathTranslator: (path) => path
      };
    }
  } catch (error) {
    log(\`Error detecting environment: \${error.message}\`, 'ERROR');
    return {
      isWSL: false,
      windowsHostIp: null,
      dockerProvider: 'unknown',
      pathTranslator: (path) => path
    };
  }
}

// Then use it in your scripts:
// const env = await detectEnvironment();
// const mountPath = env.pathTranslator('/path/to/mount');
// const hostAccess = env.isWSL ? env.windowsHostIp : 'localhost';
`;
    
    fs.writeFileSync(`${CLIENT_DIR}/wsl_taskmaster_integration.js`, taskmasterUpdates);
    log(`Created TaskMaster-AI WSL integration at ${CLIENT_DIR}/wsl_taskmaster_integration.js`, 'INFO');
    
    // Create a starter template for new TaskMaster scripts
    fs.writeFileSync(`${REPO_ROOT}/scripts/components/taskmaster/template_wsl_aware.js`, `#!/usr/bin/env node

/**
 * WSL-Aware TaskMaster Template
 * Following AgencyStack Charter v1.0.3 principles:
 * - WSL2/Docker Mount Safety
 * - Repository as Source of Truth
 * - Proper Change Workflow
 */

const fs = require('fs');
const path = require('path');
const { promisify } = require('util');
const exec = promisify(require('child_process').exec);

// Environment detection - following Charter principles
async function detectEnvironment() {
  try {
    // Check for WSL
    const { stdout: wslCheck } = await exec('grep -i microsoft /proc/version || echo "Not WSL"');
    const isWSL = wslCheck && !wslCheck.includes('Not WSL');
    
    if (isWSL) {
      console.log('WSL environment detected - applying path mappings and host resolution fixes');
      
      // Get Windows Host IP for proper hostname resolution
      const { stdout: hostIp } = await exec('cat /etc/resolv.conf | grep nameserver | cut -d " " -f 2');
      const windowsHostIp = (hostIp && hostIp.trim()) ? hostIp.trim() : '127.0.0.1';
      
      // Detect Docker provider (WSL2 Docker or Windows Docker)
      const { stdout: dockerInfo } = await exec('docker info');
      const dockerProvider = (dockerInfo && dockerInfo.includes('linux')) ? 'wsl' : 'windows';
      
      return {
        isWSL: true,
        windowsHostIp,
        dockerProvider,
        pathTranslator: async (linuxPath) => {
          // Convert paths if using Windows Docker
          if (dockerProvider === 'windows') {
            // Use wslpath to convert Linux paths to Windows paths for volume mounts
            const { stdout: windowsPath } = await exec(\`wslpath -w "\${linuxPath}"\`);
            return windowsPath.trim();
          }
          return linuxPath;
        }
      };
    } else {
      return {
        isWSL: false,
        windowsHostIp: null,
        dockerProvider: 'native',
        pathTranslator: async (path) => path
      };
    }
  } catch (error) {
    console.error(\`Error detecting environment: \${error.message}\`);
    return {
      isWSL: false,
      windowsHostIp: null,
      dockerProvider: 'unknown',
      pathTranslator: async (path) => path
    };
  }
}

// Main function with environment awareness
async function main() {
  console.log('Starting WSL-aware TaskMaster script...');
  
  // Detect environment following Charter principles
  const env = await detectEnvironment();
  console.log(\`Environment: \${env.isWSL ? 'WSL' : 'Native Linux'}\`);
  console.log(\`Docker provider: \${env.dockerProvider}\`);
  
  if (env.isWSL) {
    console.log(\`Windows host IP: \${env.windowsHostIp}\`);
    
    // Example path translation
    const linuxPath = '/opt/agency_stack/data';
    const translatedPath = await env.pathTranslator(linuxPath);
    console.log(\`Translated path: \${linuxPath} → \${translatedPath}\`);
    
    // Example docker command with proper path mapping
    const dockerCmd = \`docker run -v \${translatedPath}:/data alpine ls /data\`;
    console.log(\`WSL-aware docker command: \${dockerCmd}\`);
  }
  
  console.log('WSL-aware TaskMaster script completed successfully');
}

// Run main function
main().catch(error => {
  console.error(\`Error: \${error.message}\`);
  process.exit(1);
});
`);
    
    log(`Created WSL-aware TaskMaster template at ${REPO_ROOT}/scripts/components/taskmaster/template_wsl_aware.js`, 'INFO');
    
    return { success: true };
  }
};

// Main execution function - sequential orchestration
async function runIntegration() {
  log('STARTING PEACEFESTIVALUSA WSL/WINDOWS INTEGRATION', 'START');
  
  try {
    // Phase 1: Environment detection
    log('Starting environment analysis...', 'INFO');
    const envInfo = await integrationSteps.analyzeEnvironment();
    
    // Phase 2: SQLite integration
    log('Starting SQLite integration...', 'INFO');
    await integrationSteps.integrateWithSQLite(envInfo);
    
    // Phase 3: Cross-environment testing
    log('Setting up cross-environment testing...', 'INFO');
    await integrationSteps.setupCrossEnvironmentTesting(envInfo);
    
    // Phase 4: Charter updates
    log('Updating Charter for WSL considerations...', 'INFO');
    await integrationSteps.updateCharter();
    
    // Phase 5: TaskMaster-AI integration
    log('Integrating WSL awareness into TaskMaster-AI...', 'INFO');
    await integrationSteps.updateTaskmasterAI();
    
    log('WSL/WINDOWS INTEGRATION COMPLETED SUCCESSFULLY', 'SUCCESS');
    log(`Access documentation at ${CLIENT_DIR}/WSL_CHARTER_ADDENDUM.md`, 'INFO');
    log(`Run cross-environment tests with ${CLIENT_DIR}/tests/cross_env_test.sh`, 'INFO');
    
  } catch (error) {
    log(`INTEGRATION FAILED: ${error.message}`, 'ERROR');
    process.exit(1);
  }
}

// Helper function to change file permissions
function chmod(filePath, mode) {
  try {
    fs.chmodSync(filePath, parseInt(mode, 8));
  } catch (error) {
    log(`Error changing permissions for ${filePath}: ${error.message}`, 'ERROR');
  }
}

// Execute the integration plan
runIntegration();
