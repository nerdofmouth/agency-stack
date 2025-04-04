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
const navButtons = document.querySelectorAll('.nav-btn');
const serviceCardTemplate = document.getElementById('service-card-template');

// Global variables
let servicesData = [];
let currentCategory = 'all';

// Load service status data
async function loadServiceStatus() {
    try {
        loadingIndicator.style.display = 'flex';
        servicesGrid.innerHTML = '';
        
        const response = await fetch('/service_status.json');
        if (!response.ok) {
            throw new Error('Failed to load service status data');
        }
        
        const data = await response.json();
        servicesData = data.services;
        
        // Update metadata
        serverNameElement.textContent = data.server || 'Unknown';
        domainNameElement.textContent = data.domain || 'Unknown';
        lastUpdatedElement.textContent = formatDate(data.generated_at);
        
        // Display services
        displayServices(currentCategory);
    } catch (error) {
        console.error('Error loading service status:', error);
        servicesGrid.innerHTML = `<div class="error-message">
            <h3>Failed to load service data</h3>
            <p>${error.message}</p>
            <p>Please check if the service status generator has been run.</p>
        </div>`;
    } finally {
        loadingIndicator.style.display = 'none';
    }
}

// Display services based on category filter
function displayServices(category) {
    servicesGrid.innerHTML = '';
    
    const filteredServices = category === 'all' 
        ? servicesData 
        : servicesData.filter(service => service.category === category);
    
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
    
    // Configure buttons based on service state
    const openBtn = card.querySelector('.open-btn');
    const installBtn = card.querySelector('.install-btn');
    const startBtn = card.querySelector('.start-btn');
    const stopBtn = card.querySelector('.stop-btn');
    
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
    } else if (service.installed) {
        // Service is installed but not running
        openBtn.style.display = 'none';
        installBtn.style.display = 'none';
        startBtn.onclick = () => startService(service.name);
        stopBtn.style.display = 'none';
    } else {
        // Service is not installed
        openBtn.style.display = 'none';
        installBtn.onclick = () => installService(service.name);
        startBtn.style.display = 'none';
        stopBtn.style.display = 'none';
    }
    
    return card;
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
    // Reload the page to refresh the dashboard
    window.location.reload();
}

function integrateComponents() {
    // Redirect to integration page or trigger backend action
    window.location.href = '/integrate.html';
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

// Event listeners
document.addEventListener('DOMContentLoaded', () => {
    // Load initial data
    loadServiceStatus();
    
    // Set up nav button listeners
    navButtons.forEach(button => {
        button.addEventListener('click', () => {
            navButtons.forEach(btn => btn.classList.remove('active'));
            button.classList.add('active');
            currentCategory = button.dataset.category;
            displayServices(currentCategory);
        });
    });
    
    // Set up action button listeners
    refreshButton.addEventListener('click', refreshDashboard);
    integrateButton.addEventListener('click', integrateComponents);
    healthCheckButton.addEventListener('click', healthCheck);
    viewLogsButton.addEventListener('click', viewLogs);
});

// Auto-refresh timer (10 minutes)
setTimeout(() => {
    loadServiceStatus();
}, 600000);
