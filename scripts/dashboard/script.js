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
    }
};
let currentCategory = 'all';
let currentView = 'services-view';

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

// View switching
function switchView(viewId) {
    // Hide all views
    viewContainers.forEach(container => {
        container.classList.add('hidden');
    });
    
    // Show selected view
    document.getElementById(viewId).classList.remove('hidden');
    
    // Update current view
    currentView = viewId;
    
    // Update nav buttons
    navButtons.forEach(btn => {
        if (btn.dataset.view && btn.dataset.view === viewId.replace('-view', '')) {
            btn.classList.add('active');
        } else if (btn.dataset.category && viewId === 'services-view') {
            if (btn.dataset.category === currentCategory) {
                btn.classList.add('active');
            } else {
                btn.classList.remove('active');
            }
        } else {
            btn.classList.remove('active');
        }
    });
}

// Event listeners
document.addEventListener('DOMContentLoaded', () => {
    // Load initial data
    loadDashboardData();
    
    // Set up category filter button listeners
    navButtons.forEach(btn => {
        btn.addEventListener('click', () => {
            if (btn.dataset.category) {
                // Category filter button
                currentCategory = btn.dataset.category;
                navButtons.forEach(b => b.classList.remove('active'));
                btn.classList.add('active');
                displayServices(currentCategory);
                switchView('services-view');
            } else if (btn.dataset.view) {
                // View switch button
                switchView(`${btn.dataset.view}-view`);
            }
        });
    });
    
    // Set up action button listeners
    refreshButton.addEventListener('click', refreshDashboard);
    integrateButton.addEventListener('click', integrateComponents);
    healthCheckButton.addEventListener('click', healthCheck);
    viewLogsButton.addEventListener('click', viewLogs);
    detectPortsButton.addEventListener('click', detectPorts);
    
    // Set up integration button listeners
    runAllIntegrationsButton.addEventListener('click', () => runIntegration('all'));
    runSsoIntegrationButton.addEventListener('click', () => runIntegration('sso'));
    runEmailIntegrationButton.addEventListener('click', () => runIntegration('email'));
    runMonitoringIntegrationButton.addEventListener('click', () => runIntegration('monitoring'));
    runDataBridgeIntegrationButton.addEventListener('click', () => runIntegration('data-bridge'));
    
    // Set up port management button listeners
    detectPortConflictsButton.addEventListener('click', detectPortConflicts);
    remapPortsButton.addEventListener('click', remapPorts);
    scanPortsButton.addEventListener('click', scanPorts);
});
