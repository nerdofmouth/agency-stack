# Calcom

## Overview
Scheduling and appointment application

## Installation

### Prerequisites
- List of prerequisites

### Installation Process
The installation is handled by the `install_calcom.sh` script, which can be executed using:

```bash
make calcom
```

## Configuration

### Default Configuration
- Configuration details

### Customization
- How to customize

Configuration files can be found at `/opt/agency_stack/clients/${CLIENT_ID}/calcom/config/`.

## Usage

### Initial Setup

After installation, complete the setup by:

```bash
# Access Cal.com admin interface
open https://calendar.yourdomain.com/setup
```

### Creating Booking Types

1. **Event Types**:
   ```bash
   # Login to Cal.com
   # Navigate to "Event Types"
   # Click "New Event Type"
   # Configure duration, availability, and questions
   ```

2. **Managing Availability**:
   ```bash
   # Go to "Availability" section
   # Set your working hours
   # Add date overrides for special schedules
   ```

3. **Team Scheduling**:
   ```bash
   # Create a team under "Teams"
   # Add members to the team
   # Create team event types with round-robin or collective assignments
   ```

### Integrations

Cal.com integrates with various calendars and services:

```bash
# Connect Google Calendar
# Settings → Connected Accounts → Connect Google Calendar

# Connect Microsoft Outlook
# Settings → Connected Accounts → Connect Microsoft Outlook

# Add Zoom for video meetings
# Settings → Connected Accounts → Connect Zoom
```

### Multi-tenant Usage

For organizations with multiple tenants:

```bash
# Create an organization 
# Settings → Organizations → New Organization

# Add members to organization
# Invite members via email
```

### Using the API

Access the Cal.com API for custom integrations:

```bash
# Generate API key
# Settings → Developer → API Keys → Create

# Fetch available times 
curl -X GET "https://calendar.yourdomain.com/api/availability" \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"eventTypeId": 123, "date": "2025-04-15"}'
```

### Custom Booking Pages

Create custom booking pages by:

```bash
# Settings → Appearance
# Customize colors, logo, and theme
# Add custom CSS if needed
```

## Ports & Endpoints

| Service | Port | Protocol | Description |
|---------|------|----------|-------------|
| Web UI  | XXXX | HTTP/S   | Main web interface |

## Logs & Monitoring

### Log Files
- `/var/log/agency_stack/components/calcom.log`

### Monitoring
- Metrics and monitoring information

## Troubleshooting

### Common Issues
- List of common issues and their solutions

## Makefile Targets

| Target | Description |
|--------|-------------|
| `make calcom` | Install calcom |
| `make calcom-status` | Check status of calcom |
| `make calcom-logs` | View calcom logs |
| `make calcom-restart` | Restart calcom services |
