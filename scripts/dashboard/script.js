// AgencyStack Dashboard Script

// DOM elements
const servicesGrid = document.getElementById('services-grid');
const loadingIndicator = document.getElementById('loading-indicator');
const serverNameElement = document.getElementById('server-name');
const domainNameElement = document.getElementById('domain-name');
const lastUpdatedElement = document.getElementById('last-updated');
const refreshButton = document.getElementById('refresh-dashboard');
const integrateButton = document.getElementById('integrate-components');
const healthCheckButton = document.getElementById('health-check');
const viewLogsButton = document.getElementById('view-logs');
const detectPortsButton = document.getElementById('detect-ports');
const navButtons = document.querySelectorAll('.nav-btn');
const serviceCardTemplate = document.getElementById('service-card-template');
const integrationBadgeTemplate = document.getElementById('integration-badge-template');
const portConflictTemplate = document.getElementById('port-conflict-template');
const viewContainers = document.querySelectorAll('.view-container');
const securityAuditButton = document.getElementById('security-audit');

// Integration UI elements
const runAllIntegrationsButton = document.getElementById('run-all-integrations');
const runSsoIntegrationButton = document.getElementById('run-sso-integration');
const runEmailIntegrationButton = document.getElementById('run-email-integration');
const runMonitoringIntegrationButton = document.getElementById('run-monitoring-integration');
const runDataBridgeIntegrationButton = document.getElementById('run-data-bridge-integration');

// Port management UI elements
const detectPortConflictsButton = document.getElementById('detect-port-conflicts');
const remapPortsButton = document.getElementById('remap-ports');
const scanPortsButton = document.getElementById('scan-ports');
const portTableBody = document.getElementById('port-table-body');
const portsLastUpdatedElement = document.getElementById('ports-last-updated');
const totalPortsElement = document.getElementById('total-ports');
const conflictCountElement = document.getElementById('conflict-count');
const portConflictsContainer = document.getElementById('port-conflicts');
const conflictsContainer = document.getElementById('conflicts-container');

// Alerts & Logs UI elements
const refreshAlertsButton = document.getElementById('refresh-alerts');
const testAlertButton = document.getElementById('test-alert');
const logFilterSelect = document.getElementById('log-filter');
const autoRefreshCheckbox = document.getElementById('auto-refresh');
const totalAlertsElement = document.getElementById('total-alerts');
const recentIssuesElement = document.getElementById('recent-issues');
const lastAlertTimeElement = document.getElementById('last-alert-time');
const alertsTableBody = document.getElementById('alerts-table-body');

// Security UI elements
const runSecurityAuditButton = document.getElementById('run-security-audit');
const verifyCertsButton = document.getElementById('verify-certs');
const verifyAuthButton = document.getElementById('verify-auth');
const rotateSecretsButton = document.getElementById('rotate-secrets');
const refreshSecurityButton = document.getElementById('refresh-security');
const validCertsElement = document.getElementById('valid-certs');
const totalCertsElement = document.getElementById('total-certs');
const ssoProtectedElement = document.getElementById('sso-protected');
const totalServicesElement = document.getElementById('total-services');
const exposedPortsElement = document.getElementById('exposed-ports');
const securityIssuesElement = document.getElementById('security-issues');
const certsLastCheckedElement = document.getElementById('certs-last-checked');
const servicesWithSsoElement = document.getElementById('services-with-sso');
const totalClientsElement = document.getElementById('total-clients');
const certTableBody = document.getElementById('cert-table-body');
const authTableBody = document.getElementById('auth-table-body');
const failedLoginsBody = document.getElementById('failed-logins-body');
const tenancyTableBody = document.getElementById('tenancy-table-body');
const auditSummaryElement = document.getElementById('audit-summary');
const certRowTemplate = document.getElementById('cert-row-template');
const authRowTemplate = document.getElementById('auth-row-template');
const tenancyRowTemplate = document.getElementById('tenancy-row-template');

// Global variables
let dashboardData = {
    services: [],
    server: '',
    domain: '',
    generated_at: '',
    integration: {
        sso: { applied: false, components: [], last_updated: null },
        email: { applied: false, components: [], last_updated: null },
        monitoring: { applied: false, components: [], last_updated: null },
        'data-bridge': { applied: false, components: [], last_updated: null },
    },
    ports: {
        ports: { updated_at: '', ports_in_use: {} },
        conflicts: []
    },
    security: {
        certificates: [],
        authStatus: [],
        failedLogins: [],
        multiTenancy: [],
        auditResults: {},
        lastChecked: '',
        summary: {
            validCerts: 0,
            totalCerts: 0,
            ssoProtected: 0,
            totalServices: 0,
            exposedPorts: 0,
            securityIssues: 0,
            totalClients: 0
        }
    }
};
let currentCategory = 'all';
let currentView = 'services-view';

// Global variables for alerts
let alertsData = [];
let alertsAutoRefreshInterval = null;

// Load dashboard data
async function loadDashboardData() {
    try {
        loadingIndicator.style.display = 'flex';
        servicesGrid.innerHTML = '';
        
        const response = await fetch('/dashboard_data.json');
        if (!response.ok) {
            throw new Error('Failed to load dashboard data');
        }
        
        dashboardData = await response.json();
        
        // Update metadata
        updateMetadata();
        
        // Display services
        displayServices(currentCategory);
        
        // Update integration status
        updateIntegrationStatus();
        
        // Update port information
        updatePortInformation();
        
        // Update security status
        updateSecurityStatus();
    } catch (error) {
        console.error('Error loading dashboard data:', error);
        servicesGrid.innerHTML = `<div class="error-message">
            <h3>Failed to load dashboard data</h3>
            <p>${error.message}</p>
            <p>Please check if the dashboard data generator has been run.</p>
        </div>`;
    } finally {
        loadingIndicator.style.display = 'none';
    }
}

// Update metadata display
function updateMetadata() {
    serverNameElement.textContent = dashboardData.server || 'Unknown';
    domainNameElement.textContent = dashboardData.domain || 'Unknown';
    lastUpdatedElement.textContent = formatDate(dashboardData.generated_at);
}

// Display services based on category filter
function displayServices(category) {
    servicesGrid.innerHTML = '';
    
    const services = dashboardData.services || [];
    const filteredServices = category === 'all' 
        ? services 
        : services.filter(service => service.category === category);
    
    if (filteredServices.length === 0) {
        servicesGrid.innerHTML = `<div class="no-services-message">
            <p>No services found in this category.</p>
        </div>`;
        return;
    }
    
    // Sort services alphabetically by name within each category
    filteredServices.sort((a, b) => a.name.localeCompare(b.name));
    
    filteredServices.forEach(service => {
        const serviceCard = createServiceCard(service);
        servicesGrid.appendChild(serviceCard);
    });
}

// Create service card from template
function createServiceCard(service) {
    const card = serviceCardTemplate.content.cloneNode(true);
    
    // Set service name and category
    card.querySelector('.service-name').textContent = service.name;
    card.querySelector('.service-category').textContent = service.category;
    
    // Set status indicator
    const statusIndicator = card.querySelector('.status-indicator');
    if (service.status === 'running') {
        statusIndicator.classList.add('running');
    } else if (service.installed) {
        statusIndicator.classList.add('stopped');
    } else {
        statusIndicator.classList.add('not-installed');
    }
    
    // Set domain link
    const domainElem = card.querySelector('.service-domain');
    const domainLink = domainElem.querySelector('a');
    if (service.domain) {
        domainLink.textContent = service.domain;
        domainLink.href = `https://${service.domain}`;
    } else {
        domainElem.style.display = 'none';
    }
    
    // Set ports
    const portsElem = card.querySelector('.service-ports');
    const portsSpan = portsElem.querySelector('span');
    if (service.ports && service.ports !== '') {
        portsSpan.textContent = service.ports;
    } else {
        portsElem.style.display = 'none';
    }
    
    // Add integration badges
    addIntegrationBadges(card, service.name);
    
    // Configure buttons based on service state
    const openBtn = card.querySelector('.open-btn');
    const installBtn = card.querySelector('.install-btn');
    const startBtn = card.querySelector('.start-btn');
    const stopBtn = card.querySelector('.stop-btn');
    const integrateBtn = card.querySelector('.integrate-btn');
    
    if (service.status === 'running') {
        // Service is running
        if (service.domain) {
            openBtn.onclick = () => window.open(`https://${service.domain}`, '_blank');
        } else if (service.ports) {
            const firstPort = service.ports.split(',')[0];
            openBtn.onclick = () => window.open(`http://localhost:${firstPort}`, '_blank');
        } else {
            openBtn.style.display = 'none';
        }
        
        installBtn.style.display = 'none';
        startBtn.style.display = 'none';
        stopBtn.onclick = () => stopService(service.name);
        
        // Show integrate button only for services that can be integrated
        if (isIntegratable(service.name)) {
            integrateBtn.onclick = () => integrateService(service.name);
        } else {
            integrateBtn.style.display = 'none';
        }
    } else if (service.installed) {
        // Service is installed but not running
        openBtn.style.display = 'none';
        installBtn.style.display = 'none';
        startBtn.onclick = () => startService(service.name);
        stopBtn.style.display = 'none';
        integrateBtn.style.display = 'none';
    } else {
        // Service is not installed
        openBtn.style.display = 'none';
        installBtn.onclick = () => installService(service.name);
        startBtn.style.display = 'none';
        stopBtn.style.display = 'none';
        integrateBtn.style.display = 'none';
    }
    
    return card;
}

// Check if service can be integrated
function isIntegratable(serviceName) {
    const integratableServices = [
        'WordPress', 'ERPNext', 'Grafana', 'Keycloak', 'Mailu', 'Loki'
    ];
    
    return integratableServices.includes(serviceName);
}

// Add integration badges to service card
function addIntegrationBadges(card, serviceName) {
    const badgesContainer = card.querySelector('.integration-badges');
    const integration = dashboardData.integration || {};
    const integrationTypes = {
        sso: { name: 'SSO', icon: '🔑' },
        email: { name: 'Email', icon: '📧' },
        monitoring: { name: 'Monitoring', icon: '📊' },
        'data-bridge': { name: 'Data Bridge', icon: '🔄' }
    };
    
    // Check each integration type for this service
    Object.entries(integrationTypes).forEach(([type, info]) => {
        const integrationData = integration[type] || { applied: false, components: [] };
        const hasComponent = integrationData.components.some(comp => comp.name === serviceName);
        
        if (integrationData.applied && hasComponent) {
            // Add active badge
            const badge = integrationBadgeTemplate.content.cloneNode(true);
            const badgeElement = badge.querySelector('.integration-badge');
            badgeElement.classList.add('active');
            badge.querySelector('.badge-icon').textContent = info.icon;
            badge.querySelector('.badge-text').textContent = info.name;
            badgesContainer.appendChild(badge);
        } else if (isEligibleForIntegration(serviceName, type)) {
            // Add inactive badge for eligible services
            const badge = integrationBadgeTemplate.content.cloneNode(true);
            const badgeElement = badge.querySelector('.integration-badge');
            badgeElement.classList.add('inactive');
            badge.querySelector('.badge-icon').textContent = info.icon;
            badge.querySelector('.badge-text').textContent = info.name;
            badgesContainer.appendChild(badge);
        }
    });
}

// Check if service is eligible for a specific integration
function isEligibleForIntegration(serviceName, integrationType) {
    // Define which services are eligible for each integration type
    const eligibilityMap = {
        sso: ['WordPress', 'ERPNext', 'Grafana'],
        email: ['WordPress', 'ERPNext', 'Mailu'],
        monitoring: ['WordPress', 'ERPNext', 'Loki', 'Grafana', 'Mailu'],
        'data-bridge': ['WordPress', 'ERPNext']
    };
    
    return eligibilityMap[integrationType]?.includes(serviceName) || false;
}

// Update integration status UI
function updateIntegrationStatus() {
    const integration = dashboardData.integration || {};
    
    // Update SSO integration
    updateIntegrationCard('sso-integration', integration.sso || {});
    
    // Update Email integration
    updateIntegrationCard('email-integration', integration.email || {});
    
    // Update Monitoring integration
    updateIntegrationCard('monitoring-integration', integration.monitoring || {});
    
    // Update Data Bridge integration
    updateIntegrationCard('data-bridge-integration', integration['data-bridge'] || {});
}

// Update a single integration card
function updateIntegrationCard(cardId, integrationData) {
    const card = document.getElementById(cardId);
    if (!card) return;
    
    const statusElement = card.querySelector('.integration-status');
    const lastUpdatedElement = card.querySelector('.last-updated span');
    const componentsList = card.querySelector('.component-list');
    
    // Update status
    if (integrationData.applied) {
        const componentCount = integrationData.components?.length || 0;
        const totalEligible = getEligibleComponentCount(cardId.replace('-integration', ''));
        
        if (componentCount === totalEligible) {
            statusElement.dataset.status = 'applied';
            statusElement.textContent = '✅ Applied';
        } else {
            statusElement.dataset.status = 'partial';
            statusElement.textContent = '⚠️ Partial';
        }
    } else {
        statusElement.dataset.status = 'missing';
        statusElement.textContent = '❌ Not Applied';
    }
    
    // Update last updated
    if (integrationData.last_updated) {
        lastUpdatedElement.textContent = formatDate(integrationData.last_updated);
    } else {
        lastUpdatedElement.textContent = 'Never';
    }
    
    // Update components list
    componentsList.innerHTML = '';
    if (integrationData.components && integrationData.components.length > 0) {
        integrationData.components.forEach(component => {
            const li = document.createElement('li');
            li.textContent = `${component.name} (v${component.version}) - ${component.details || 'No details'}`;
            componentsList.appendChild(li);
        });
    } else {
        const li = document.createElement('li');
        li.textContent = 'No components integrated';
        li.classList.add('loading-placeholder');
        componentsList.appendChild(li);
    }
}

// Get eligible component count for an integration type
function getEligibleComponentCount(integrationType) {
    const eligibilityMap = {
        sso: 3, // WordPress, ERPNext, Grafana
        email: 3, // WordPress, ERPNext, Mailu
        monitoring: 5, // WordPress, ERPNext, Loki, Grafana, Mailu
        'data-bridge': 2 // WordPress, ERPNext
    };
    
    return eligibilityMap[integrationType] || 0;
}

// Update port information UI
function updatePortInformation() {
    const portData = dashboardData.ports || { ports: { updated_at: '', ports_in_use: {} }, conflicts: [] };
    const ports = portData.ports || { updated_at: '', ports_in_use: {} };
    const conflicts = portData.conflicts || [];
    
    // Update port summary
    portsLastUpdatedElement.textContent = formatDate(ports.updated_at);
    
    const portCount = Object.keys(ports.ports_in_use || {}).length;
    totalPortsElement.textContent = portCount;
    
    conflictCountElement.textContent = conflicts.length;
    
    // Update port table
    updatePortTable(ports.ports_in_use || {}, conflicts);
    
    // Update conflicts section
    updateConflictsSection(conflicts);
}

// Update port table
function updatePortTable(portsInUse, conflicts) {
    portTableBody.innerHTML = '';
    
    if (Object.keys(portsInUse).length === 0) {
        const row = document.createElement('tr');
        row.innerHTML = `<td colspan="4" class="loading-placeholder">No port information available</td>`;
        portTableBody.appendChild(row);
        return;
    }
    
    // Convert to array and sort by port number
    const portEntries = Object.entries(portsInUse)
        .map(([port, info]) => ({ port, ...info }))
        .sort((a, b) => parseInt(a.port) - parseInt(b.port));
    
    // Create conflict port map for quick lookup
    const conflictPortMap = new Map();
    conflicts.forEach(conflict => {
        conflictPortMap.set(conflict.port, conflict.type);
    });
    
    // Add rows to table
    portEntries.forEach(entry => {
        const row = document.createElement('tr');
        
        // Add port column
        const portCell = document.createElement('td');
        portCell.textContent = entry.port;
        row.appendChild(portCell);
        
        // Add service column
        const serviceCell = document.createElement('td');
        serviceCell.textContent = entry.service;
        row.appendChild(serviceCell);
        
        // Add description column
        const descCell = document.createElement('td');
        descCell.textContent = entry.description || 'No description';
        row.appendChild(descCell);
        
        // Add status column
        const statusCell = document.createElement('td');
        const statusSpan = document.createElement('span');
        statusSpan.classList.add('port-status');
        
        if (conflictPortMap.has(entry.port)) {
            const conflictType = conflictPortMap.get(entry.port);
            statusSpan.classList.add('conflict');
            statusSpan.textContent = conflictType === 'system' ? 'System Conflict' : 'Duplicate';
            row.classList.add('conflict-row');
        } else {
            statusSpan.classList.add('ok');
            statusSpan.textContent = 'OK';
        }
        
        statusCell.appendChild(statusSpan);
        row.appendChild(statusCell);
        
        portTableBody.appendChild(row);
    });
}

// Update conflicts section
function updateConflictsSection(conflicts) {
    if (conflicts.length === 0) {
        portConflictsContainer.classList.add('hidden');
        return;
    }
    
    portConflictsContainer.classList.remove('hidden');
    conflictsContainer.innerHTML = '';
    
    conflicts.forEach(conflict => {
        const conflictItem = portConflictTemplate.content.cloneNode(true);
        
        // Set conflict description
        const description = conflictItem.querySelector('.conflict-description');
        description.textContent = `Port ${conflict.port} (${conflict.service}): ${conflict.type === 'system' ? 'System port conflict' : 'Duplicate port mapping'}`;
        
        // Set suggested port
        const suggestedPort = conflictItem.querySelector('.suggested-port span');
        suggestedPort.textContent = (parseInt(conflict.port) + 1000).toString();
        
        // Set resolve button action
        const resolveBtn = conflictItem.querySelector('.resolve-btn');
        resolveBtn.onclick = () => resolvePortConflict(conflict.port);
        
        conflictsContainer.appendChild(conflictItem);
    });
}

// Format date for display
function formatDate(dateString) {
    if (!dateString) return 'Unknown';
    
    try {
        const date = new Date(dateString);
        return date.toLocaleString();
    } catch (e) {
        return dateString;
    }
}

// Service actions
function refreshDashboard() {
    // Make a POST request to trigger dashboard update
    fetch('/api/dashboard/refresh', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
        }
    })
    .then(response => {
        if (!response.ok) {
            throw new Error('Failed to refresh dashboard');
        }
        return response.json();
    })
    .then(data => {
        window.location.reload();
    })
    .catch(error => {
        console.error('Error refreshing dashboard:', error);
        alert('Failed to refresh dashboard: ' + error.message);
    });
}

function integrateComponents() {
    // Switch to integrations view
    switchView('integrations-view');
}

function detectPorts() {
    // Switch to ports view
    switchView('ports-view');
}

function healthCheck() {
    // Redirect to health check page or trigger backend action
    window.location.href = '/health-check.html';
}

function viewLogs() {
    // Redirect to logs viewer page
    window.location.href = '/logs.html';
}

function installService(serviceName) {
    alert(`Installing ${serviceName}... This would trigger a backend action in the production version.`);
}

function startService(serviceName) {
    alert(`Starting ${serviceName}... This would trigger a backend action in the production version.`);
}

function stopService(serviceName) {
    alert(`Stopping ${serviceName}... This would trigger a backend action in the production version.`);
}

function integrateService(serviceName) {
    alert(`Integrating ${serviceName}... This would trigger a backend action in the production version.`);
}

// Integration actions
function runIntegration(type) {
    // Make a POST request to trigger integration
    fetch(`/api/integration/${type}`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
        }
    })
    .then(response => {
        if (!response.ok) {
            throw new Error(`Failed to run ${type} integration`);
        }
        return response.json();
    })
    .then(data => {
        alert(`${type.charAt(0).toUpperCase() + type.slice(1)} integration started. Check logs for details.`);
        // Refresh dashboard after a delay
        setTimeout(() => {
            loadDashboardData();
        }, 3000);
    })
    .catch(error => {
        console.error(`Error running ${type} integration:`, error);
        alert(`Failed to run ${type} integration: ${error.message}`);
    });
}

// Port management actions
function detectPortConflicts() {
    fetch('/api/ports/detect', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
        }
    })
    .then(response => {
        if (!response.ok) {
            throw new Error('Failed to detect port conflicts');
        }
        return response.json();
    })
    .then(data => {
        alert('Port conflict detection completed. Refreshing data...');
        // Refresh dashboard after a delay
        setTimeout(() => {
            loadDashboardData();
        }, 1000);
    })
    .catch(error => {
        console.error('Error detecting port conflicts:', error);
        alert('Failed to detect port conflicts: ' + error.message);
    });
}

function remapPorts() {
    fetch('/api/ports/remap', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
        }
    })
    .then(response => {
        if (!response.ok) {
            throw new Error('Failed to remap ports');
        }
        return response.json();
    })
    .then(data => {
        alert('Port remapping completed. Refreshing data...');
        // Refresh dashboard after a delay
        setTimeout(() => {
            loadDashboardData();
        }, 1000);
    })
    .catch(error => {
        console.error('Error remapping ports:', error);
        alert('Failed to remap ports: ' + error.message);
    });
}

function scanPorts() {
    fetch('/api/ports/scan', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
        }
    })
    .then(response => {
        if (!response.ok) {
            throw new Error('Failed to scan ports');
        }
        return response.json();
    })
    .then(data => {
        alert('Port scanning completed. Refreshing data...');
        // Refresh dashboard after a delay
        setTimeout(() => {
            loadDashboardData();
        }, 1000);
    })
    .catch(error => {
        console.error('Error scanning ports:', error);
        alert('Failed to scan ports: ' + error.message);
    });
}

function resolvePortConflict(port) {
    fetch(`/api/ports/resolve/${port}`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
        }
    })
    .then(response => {
        if (!response.ok) {
            throw new Error(`Failed to resolve port conflict for port ${port}`);
        }
        return response.json();
    })
    .then(data => {
        alert(`Port conflict for port ${port} resolved. Refreshing data...`);
        // Refresh dashboard after a delay
        setTimeout(() => {
            loadDashboardData();
        }, 1000);
    })
    .catch(error => {
        console.error(`Error resolving port conflict for port ${port}:`, error);
        alert(`Failed to resolve port conflict for port ${port}: ${error.message}`);
    });
}

// Alerts & Logs functionality
function loadAlerts() {
    fetch('/api/alerts/logs')
    .then(response => {
        if (!response.ok) {
            throw new Error('Failed to load alerts and logs');
        }
        return response.json();
    })
    .then(data => {
        alertsData = data.logs || [];
        updateAlertsView();
    })
    .catch(error => {
        console.error('Error loading alerts and logs:', error);
        alertsTableBody.innerHTML = `<tr><td colspan="5" class="error-message">Failed to load alerts: ${error.message}</td></tr>`;
    });
}

function updateAlertsView() {
    const filter = logFilterSelect.value;
    let filteredLogs = alertsData;
    
    // Apply filter
    if (filter !== 'all') {
        filteredLogs = alertsData.filter(log => log.type === filter);
    }
    
    // Update summary information
    const totalAlerts = alertsData.filter(log => log.type === 'alert').length;
    const recentIssues = alertsData.filter(log => 
        (log.status === 'error' || log.status === 'warning') && 
        new Date(log.timestamp) > new Date(Date.now() - 24*60*60*1000)
    ).length;
    
    totalAlertsElement.textContent = totalAlerts;
    recentIssuesElement.textContent = recentIssues;
    
    // Find the most recent alert
    const alerts = alertsData.filter(log => log.type === 'alert');
    if (alerts.length > 0) {
        alerts.sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp));
        lastAlertTimeElement.textContent = formatDate(alerts[0].timestamp);
    } else {
        lastAlertTimeElement.textContent = 'Never';
    }
    
    // Update table
    alertsTableBody.innerHTML = '';
    
    if (filteredLogs.length === 0) {
        alertsTableBody.innerHTML = '<tr><td colspan="5" class="loading-placeholder">No logs found</td></tr>';
        return;
    }
    
    // Sort logs by timestamp (newest first)
    filteredLogs.sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp));
    
    // Display logs in table
    filteredLogs.forEach(log => {
        const row = document.createElement('tr');
        
        // Time column
        const timeCell = document.createElement('td');
        timeCell.textContent = formatDate(log.timestamp);
        row.appendChild(timeCell);
        
        // Type column
        const typeCell = document.createElement('td');
        const typeSpan = document.createElement('span');
        typeSpan.classList.add('log-type');
        typeSpan.classList.add(log.type);
        typeSpan.textContent = log.type.toUpperCase();
        typeCell.appendChild(typeSpan);
        row.appendChild(typeCell);
        
        // Component column
        const componentCell = document.createElement('td');
        componentCell.textContent = log.component || '-';
        row.appendChild(componentCell);
        
        // Message column
        const messageCell = document.createElement('td');
        messageCell.textContent = log.message;
        row.appendChild(messageCell);
        
        // Status column
        const statusCell = document.createElement('td');
        const statusSpan = document.createElement('span');
        statusSpan.classList.add('log-status');
        statusSpan.classList.add(log.status || 'info');
        statusSpan.textContent = (log.status || 'info').toUpperCase();
        statusCell.appendChild(statusSpan);
        row.appendChild(statusCell);
        
        alertsTableBody.appendChild(row);
    });
}

function sendTestAlert() {
    fetch('/api/alerts/test', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
        }
    })
    .then(response => {
        if (!response.ok) {
            throw new Error('Failed to send test alert');
        }
        return response.json();
    })
    .then(data => {
        alert('Test alert sent successfully. Check the Alerts & Logs tab in a few seconds.');
        // Refresh alerts after a delay
        setTimeout(loadAlerts, 3000);
    })
    .catch(error => {
        console.error('Error sending test alert:', error);
        alert('Failed to send test alert: ' + error.message);
    });
}

function setupAlertsAutoRefresh() {
    // Clear any existing interval
    if (alertsAutoRefreshInterval) {
        clearInterval(alertsAutoRefreshInterval);
    }
    
    // Set up new interval if enabled
    if (autoRefreshCheckbox.checked) {
        alertsAutoRefreshInterval = setInterval(loadAlerts, 30000); // Refresh every 30 seconds
    }
}

// Security functionality
function updateSecurityStatus() {
    // Update summary stats
    validCertsElement.textContent = dashboardData.security.summary.validCerts;
    totalCertsElement.textContent = dashboardData.security.summary.totalCerts;
    ssoProtectedElement.textContent = dashboardData.security.summary.ssoProtected;
    totalServicesElement.textContent = dashboardData.security.summary.totalServices;
    exposedPortsElement.textContent = dashboardData.security.summary.exposedPorts;
    securityIssuesElement.textContent = dashboardData.security.summary.securityIssues;
    totalClientsElement.textContent = dashboardData.security.summary.totalClients;
    
    // Update last checked timestamp
    if (dashboardData.security.lastChecked) {
        certsLastCheckedElement.textContent = formatDate(dashboardData.security.lastChecked);
    } else {
        certsLastCheckedElement.textContent = 'Never';
    }
    
    // Update services with SSO
    servicesWithSsoElement.textContent = `${dashboardData.security.summary.ssoProtected} of ${dashboardData.security.summary.totalServices}`;
    
    // Update tables
    updateCertificateTable();
    updateAuthenticationTable();
    updateFailedLoginsTable();
    updateMultiTenancyTable();
    updateAuditSummary();
}

function updateCertificateTable() {
    certTableBody.innerHTML = '';
    
    if (dashboardData.security.certificates.length === 0) {
        const row = document.createElement('tr');
        row.innerHTML = '<td colspan="5">No certificate data available</td>';
        certTableBody.appendChild(row);
        return;
    }
    
    dashboardData.security.certificates.forEach(cert => {
        const template = certRowTemplate.content.cloneNode(true);
        
        template.querySelector('.domain').textContent = cert.domain;
        
        const statusCell = template.querySelector('.status');
        statusCell.textContent = cert.status;
        if (cert.status === 'Valid') {
            statusCell.classList.add('status-valid');
        } else if (cert.status === 'Expiring Soon') {
            statusCell.classList.add('status-warning');
        } else {
            statusCell.classList.add('status-error');
        }
        
        template.querySelector('.expiration').textContent = cert.expiration;
        template.querySelector('.issuer').textContent = cert.issuer;
        
        const renewButton = template.querySelector('.renew-cert');
        renewButton.addEventListener('click', () => renewCertificate(cert.domain));
        
        certTableBody.appendChild(template);
    });
}

function updateAuthenticationTable() {
    authTableBody.innerHTML = '';
    
    if (dashboardData.security.authStatus.length === 0) {
        const row = document.createElement('tr');
        row.innerHTML = '<td colspan="5">No authentication data available</td>';
        authTableBody.appendChild(row);
        return;
    }
    
    dashboardData.security.authStatus.forEach(auth => {
        const template = authRowTemplate.content.cloneNode(true);
        
        template.querySelector('.service-name').textContent = auth.service;
        
        const ssoStatusCell = template.querySelector('.sso-status');
        ssoStatusCell.textContent = auth.ssoEnabled ? 'Enabled' : 'Disabled';
        ssoStatusCell.classList.add(auth.ssoEnabled ? 'status-valid' : 'status-error');
        
        template.querySelector('.middleware').textContent = auth.middleware || 'None';
        template.querySelector('.auth-method').textContent = auth.authMethod;
        
        const enableSsoButton = template.querySelector('.enable-sso');
        if (auth.ssoEnabled) {
            enableSsoButton.textContent = 'Configure SSO';
        }
        enableSsoButton.addEventListener('click', () => configureSso(auth.service));
        
        authTableBody.appendChild(template);
    });
}

function updateFailedLoginsTable() {
    failedLoginsBody.innerHTML = '';
    
    if (dashboardData.security.failedLogins.length === 0) {
        const row = document.createElement('tr');
        row.innerHTML = '<td colspan="5">No failed login data available</td>';
        failedLoginsBody.appendChild(row);
        return;
    }
    
    dashboardData.security.failedLogins.forEach(login => {
        const row = document.createElement('tr');
        
        const timestampCell = document.createElement('td');
        timestampCell.textContent = formatDate(login.timestamp);
        
        const ipCell = document.createElement('td');
        ipCell.textContent = login.ipAddress;
        
        const serviceCell = document.createElement('td');
        serviceCell.textContent = login.service;
        
        const usernameCell = document.createElement('td');
        usernameCell.textContent = login.username;
        
        const clientIdCell = document.createElement('td');
        clientIdCell.textContent = login.clientId || 'N/A';
        
        row.appendChild(timestampCell);
        row.appendChild(ipCell);
        row.appendChild(serviceCell);
        row.appendChild(usernameCell);
        row.appendChild(clientIdCell);
        
        failedLoginsBody.appendChild(row);
    });
}

function updateMultiTenancyTable() {
    tenancyTableBody.innerHTML = '';
    
    if (dashboardData.security.multiTenancy.length === 0) {
        const row = document.createElement('tr');
        row.innerHTML = '<td colspan="5">No client data available</td>';
        tenancyTableBody.appendChild(row);
        return;
    }
    
    dashboardData.security.multiTenancy.forEach(client => {
        const template = tenancyRowTemplate.content.cloneNode(true);
        
        template.querySelector('.client-id').textContent = client.id;
        
        const networkCell = template.querySelector('.network-isolation');
        networkCell.textContent = client.networkIsolation ? 'Enabled' : 'Disabled';
        networkCell.classList.add(client.networkIsolation ? 'status-valid' : 'status-error');
        
        const backupCell = template.querySelector('.backup-separation');
        backupCell.textContent = client.backupSeparation ? 'Enabled' : 'Disabled';
        backupCell.classList.add(client.backupSeparation ? 'status-valid' : 'status-error');
        
        const logCell = template.querySelector('.log-segmentation');
        logCell.textContent = client.logSegmentation ? 'Enabled' : 'Disabled';
        logCell.classList.add(client.logSegmentation ? 'status-valid' : 'status-error');
        
        const realmCell = template.querySelector('.client-realm');
        realmCell.textContent = client.realmConfigured ? 'Configured' : 'Missing';
        realmCell.classList.add(client.realmConfigured ? 'status-valid' : 'status-error');
        
        tenancyTableBody.appendChild(template);
    });
}

function updateAuditSummary() {
    auditSummaryElement.innerHTML = '';
    
    if (!dashboardData.security.auditResults || Object.keys(dashboardData.security.auditResults).length === 0) {
        auditSummaryElement.innerHTML = '<p>No security audit data available. Run a security audit to see results.</p>';
        return;
    }
    
    const results = dashboardData.security.auditResults;
    
    const summaryDiv = document.createElement('div');
    summaryDiv.className = 'audit-results';
    summaryDiv.innerHTML = `
        <p class="audit-timestamp">Last run: ${formatDate(results.timestamp)}</p>
        <div class="audit-stats">
            <div class="audit-stat pass"><span class="stat-count">${results.passing}</span> Passing</div>
            <div class="audit-stat warning"><span class="stat-count">${results.warnings}</span> Warnings</div>
            <div class="audit-stat fail"><span class="stat-count">${results.failing}</span> Failing</div>
        </div>
    `;
    
    // Add issues list if there are any
    if (results.issues && results.issues.length > 0) {
        const issuesDiv = document.createElement('div');
        issuesDiv.className = 'audit-issues';
        issuesDiv.innerHTML = '<h4>Issues Requiring Attention</h4>';
        
        const issuesList = document.createElement('ul');
        results.issues.forEach(issue => {
            const issueItem = document.createElement('li');
            issueItem.className = `${issue.severity}-severity`;
            issueItem.textContent = issue.description;
            issuesList.appendChild(issueItem);
        });
        issuesDiv.appendChild(issuesList);
        summaryDiv.appendChild(issuesDiv);
    }
    
    const reportLink = document.createElement('a');
    reportLink.href = '#';
    reportLink.className = 'view-full-report';
    reportLink.textContent = 'View Full Report';
    reportLink.addEventListener('click', viewFullAuditReport);
    summaryDiv.appendChild(reportLink);
    
    auditSummaryElement.appendChild(summaryDiv);
}

// Load security data
function loadSecurityData() {
    // This would normally fetch data from the server
    // Simulate fetch with setTimeout
    setTimeout(() => {
        // Sample data
        dashboardData.security = {
            lastChecked: new Date().toISOString(),
            certificates: [
                { domain: 'dashboard.example.com', status: 'Valid', expiration: '2025-06-30', issuer: 'Let\'s Encrypt' },
                { domain: 'wordpress.example.com', status: 'Valid', expiration: '2025-06-30', issuer: 'Let\'s Encrypt' },
                { domain: 'mail.example.com', status: 'Expiring Soon', expiration: '2025-04-15', issuer: 'Let\'s Encrypt' },
                { domain: 'erp.example.com', status: 'Invalid', expiration: '2025-03-01', issuer: 'Let\'s Encrypt' }
            ],
            authStatus: [
                { service: 'WordPress', ssoEnabled: true, middleware: 'forward-auth', authMethod: 'Keycloak OIDC' },
                { service: 'ERPNext', ssoEnabled: true, middleware: 'forward-auth', authMethod: 'Keycloak OIDC' },
                { service: 'Mailu', ssoEnabled: false, middleware: 'None', authMethod: 'Basic Auth' },
                { service: 'Grafana', ssoEnabled: true, middleware: 'forward-auth', authMethod: 'Keycloak OIDC' },
                { service: 'Traefik Dashboard', ssoEnabled: false, middleware: 'basic-auth', authMethod: 'Basic Auth' }
            ],
            failedLogins: [
                { timestamp: '2025-04-04T10:15:23Z', ipAddress: '192.168.1.100', service: 'Keycloak', username: 'admin', clientId: 'N/A' },
                { timestamp: '2025-04-04T08:32:11Z', ipAddress: '203.0.113.42', service: 'WordPress', username: 'editor', clientId: 'acme' },
                { timestamp: '2025-04-03T22:45:18Z', ipAddress: '198.51.100.73', service: 'ERPNext', username: 'user123', clientId: 'acme' }
            ],
            multiTenancy: [
                { id: 'acme', networkIsolation: true, backupSeparation: true, logSegmentation: true, realmConfigured: true },
                { id: 'globex', networkIsolation: true, backupSeparation: true, logSegmentation: false, realmConfigured: true },
                { id: 'initech', networkIsolation: true, backupSeparation: false, logSegmentation: false, realmConfigured: false }
            ],
            auditResults: {
                timestamp: '2025-04-04T14:30:00Z',
                passing: 12,
                warnings: 3,
                failing: 2,
                issues: [
                    { severity: 'high', description: 'Default credentials found for Traefik Dashboard' },
                    { severity: 'medium', description: 'Mailu service not using SSO authentication' },
                    { severity: 'medium', description: 'Client "initech" missing log segmentation' },
                    { severity: 'low', description: 'Minimum TLS version not explicitly set' },
                    { severity: 'low', description: 'Port 8080 exposed to public network' }
                ]
            },
            summary: {
                validCerts: 2,
                totalCerts: 4,
                ssoProtected: 3,
                totalServices: 5,
                exposedPorts: 7,
                securityIssues: 5,
                totalClients: 3
            }
        };
        
        // Update UI with the data
        updateSecurityStatus();
    }, 500);
}

// Security action functions
function runSecurityAudit() {
    showNotification('Running security audit...', 'info');
    setTimeout(() => {
        dashboardData.security.auditResults = {
            timestamp: new Date().toISOString(),
            passing: 12,
            warnings: 3,
            failing: 2,
            issues: [
                { severity: 'high', description: 'Default credentials found for Traefik Dashboard' },
                { severity: 'medium', description: 'Mailu service not using SSO authentication' },
                { severity: 'medium', description: 'Client "initech" missing log segmentation' },
                { severity: 'low', description: 'Minimum TLS version not explicitly set' },
                { severity: 'low', description: 'Port 8080 exposed to public network' }
            ]
        };
        dashboardData.security.summary.securityIssues = dashboardData.security.auditResults.issues.length;
        updateAuditSummary();
        showNotification('Security audit completed', 'success');
    }, 2000);
}

function verifyCertificates() {
    showNotification('Verifying TLS certificates...', 'info');
    setTimeout(() => {
        dashboardData.security.lastChecked = new Date().toISOString();
        dashboardData.security.summary.validCerts = dashboardData.security.certificates.filter(cert => cert.status === 'Valid').length;
        updateCertificateTable();
        validCertsElement.textContent = dashboardData.security.summary.validCerts;
        certsLastCheckedElement.textContent = formatDate(dashboardData.security.lastChecked);
        showNotification('Certificate verification completed', 'success');
    }, 1500);
}

function verifyAuthentication() {
    showNotification('Verifying authentication configuration...', 'info');
    setTimeout(() => {
        dashboardData.security.summary.ssoProtected = dashboardData.security.authStatus.filter(auth => auth.ssoEnabled).length;
        updateAuthenticationTable();
        ssoProtectedElement.textContent = dashboardData.security.summary.ssoProtected;
        servicesWithSsoElement.textContent = `${dashboardData.security.summary.ssoProtected} of ${dashboardData.security.summary.totalServices}`;
        showNotification('Authentication verification completed', 'success');
    }, 1500);
}

function rotateSecrets() {
    showNotification('Rotating secrets...', 'info');
    setTimeout(() => {
        showNotification('Secrets rotated successfully', 'success');
    }, 2000);
}

function renewCertificate(domain) {
    showNotification(`Renewing certificate for ${domain}...`, 'info');
    setTimeout(() => {
        const certIndex = dashboardData.security.certificates.findIndex(cert => cert.domain === domain);
        if (certIndex !== -1) {
            dashboardData.security.certificates[certIndex].status = 'Valid';
            dashboardData.security.certificates[certIndex].expiration = '2025-07-04';
            dashboardData.security.summary.validCerts = dashboardData.security.certificates.filter(cert => cert.status === 'Valid').length;
            updateCertificateTable();
            validCertsElement.textContent = dashboardData.security.summary.validCerts;
        }
        showNotification(`Certificate for ${domain} renewed successfully`, 'success');
    }, 2000);
}

function configureSso(service) {
    showNotification(`Configuring SSO for ${service}...`, 'info');
    setTimeout(() => {
        const serviceIndex = dashboardData.security.authStatus.findIndex(auth => auth.service === service);
        if (serviceIndex !== -1 && !dashboardData.security.authStatus[serviceIndex].ssoEnabled) {
            dashboardData.security.authStatus[serviceIndex].ssoEnabled = true;
            dashboardData.security.authStatus[serviceIndex].middleware = 'forward-auth';
            dashboardData.security.authStatus[serviceIndex].authMethod = 'Keycloak OIDC';
            dashboardData.security.summary.ssoProtected = dashboardData.security.authStatus.filter(auth => auth.ssoEnabled).length;
            updateAuthenticationTable();
            ssoProtectedElement.textContent = dashboardData.security.summary.ssoProtected;
            servicesWithSsoElement.textContent = `${dashboardData.security.summary.ssoProtected} of ${dashboardData.security.summary.totalServices}`;
        }
        showNotification(`SSO for ${service} configured successfully`, 'success');
    }, 2000);
}

function viewFullAuditReport() {
    window.open('/security_audit_report.html', '_blank');
}

function refreshSecurityData() {
    showNotification('Refreshing security data...', 'info');
    loadSecurityData();
    setTimeout(() => {
        showNotification('Security data refreshed', 'success');
    }, 1000);
}

// View switching
function switchView(viewId) {
    // Get current active view and deactivate it
    const currentActiveBtn = document.querySelector('.nav-btn.active[data-view]');
    if (currentActiveBtn) {
        currentActiveBtn.classList.remove('active');
    }
    
    // Hide all view containers
    viewContainers.forEach(container => {
        container.classList.add('hidden');
    });
    
    // Show requested view and activate its nav button
    if (viewId === 'services') {
        document.getElementById('services-view').classList.remove('hidden');
        document.querySelector('.nav-btn[data-category="all"]').classList.add('active');
    } else if (viewId === 'integrations') {
        document.getElementById('integrations-view').classList.remove('hidden');
        document.querySelector('.nav-btn[data-view="integrations"]').classList.add('active');
        updateIntegrationStatus();
    } else if (viewId === 'ports') {
        document.getElementById('ports-view').classList.remove('hidden');
        document.querySelector('.nav-btn[data-view="ports"]').classList.add('active');
        updatePortInformation();
    } else if (viewId === 'alerts') {
        document.getElementById('alerts-view').classList.remove('hidden');
        document.querySelector('.nav-btn[data-view="alerts"]').classList.add('active');
        loadAlerts();
    } else if (viewId === 'security') {
        document.getElementById('security-view').classList.remove('hidden');
        document.querySelector('.nav-btn[data-view="security"]').classList.add('active');
        loadSecurityData();
    }
}

// Event listeners
document.addEventListener('DOMContentLoaded', () => {
    // Load initial data
    loadDashboardData();
    
    // Add event listeners for service actions
    refreshButton.addEventListener('click', refreshDashboard);
    integrateButton.addEventListener('click', integrateComponents);
    healthCheckButton.addEventListener('click', healthCheck);
    viewLogsButton.addEventListener('click', viewLogs);
    detectPortsButton.addEventListener('click', detectPorts);
    securityAuditButton.addEventListener('click', runSecurityAudit);
    
    // Add event listeners for integration actions
    runAllIntegrationsButton.addEventListener('click', () => runIntegration('all'));
    runSsoIntegrationButton.addEventListener('click', () => runIntegration('sso'));
    runEmailIntegrationButton.addEventListener('click', () => runIntegration('email'));
    runMonitoringIntegrationButton.addEventListener('click', () => runIntegration('monitoring'));
    runDataBridgeIntegrationButton.addEventListener('click', () => runIntegration('data-bridge'));
    
    // Add event listeners for port management actions
    detectPortConflictsButton.addEventListener('click', detectPortConflicts);
    remapPortsButton.addEventListener('click', remapPorts);
    scanPortsButton.addEventListener('click', scanPorts);
    
    // Add event listeners for alerts & logs actions
    refreshAlertsButton.addEventListener('click', loadAlerts);
    testAlertButton.addEventListener('click', sendTestAlert);
    autoRefreshCheckbox.addEventListener('change', setupAlertsAutoRefresh);
    logFilterSelect.addEventListener('change', updateAlertsView);
    
    // Add event listeners for security actions
    runSecurityAuditButton.addEventListener('click', runSecurityAudit);
    verifyCertsButton.addEventListener('click', verifyCertificates);
    verifyAuthButton.addEventListener('click', verifyAuthentication);
    rotateSecretsButton.addEventListener('click', rotateSecrets);
    refreshSecurityButton.addEventListener('click', refreshSecurityData);
});
