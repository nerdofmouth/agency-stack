# Erpnext

## Overview
Enterprise Resource Planning system

## Installation

### Prerequisites
- List of prerequisites

### Installation Process
The installation is handled by the `install_erpnext.sh` script, which can be executed using:

```bash
make erpnext
```

## Configuration

### Default Configuration
- Configuration details

### Customization
- How to customize

## Ports & Endpoints

| Service | Port | Protocol | Description |
|---------|------|----------|-------------|
| Web UI  | XXXX | HTTP/S   | Main web interface |

## Logs & Monitoring

### Log Files
- `/var/log/agency_stack/components/erpnext.log`

### Monitoring
- Metrics and monitoring information

## Usage

### Accessing ERPNext

Access the ERPNext web interface:

```bash
# Open ERPNext interface
open https://erp.yourdomain.com

# Login credentials:
# - Default Admin: administrator (password from installation log)
# - Keycloak SSO (if configured)
```

### Setting Up Your Company

Configure your company information:

```bash
# 1. Navigate to Setup → Company
# 2. Create New Company
# 3. Fill in details:
#   - Company name
#   - Default currency
#   - Chart of accounts
#   - Domain (Manufacturing, Services, Retail, etc.)
```

### Managing Users and Permissions

Create and manage user accounts:

```bash
# Create a new user
# 1. User → Add User
# 2. Enter email, first name, last name
# 3. Assign roles (Accounts Manager, HR Manager, etc.)
# 4. Set user type (System User, Website User)

# Create user permission rules
# 1. User Permissions → Add User Permission
# 2. Select User, Document Type, and Value
# 3. Apply appropriate restrictions
```

### Working with Modules

ERPNext is organized into functional modules:

```bash
# Core Modules:
# - Accounting: Ledgers, invoices, taxes
# - Selling: Sales orders, customers, quotations
# - Buying: Purchase orders, suppliers
# - Inventory: Stock management, warehouses
# - Manufacturing: Production planning, BOM
# - HR: Employees, payroll, leave management
# - CRM: Leads, opportunities, communication
# - Projects: Tasks, time logs, billing
```

### Document Workflow

ERPNext follows a sequential workflow for most transactions:

```bash
# Example: Sales Workflow
# 1. Lead → Opportunity → Quotation → Sales Order
# 2. Delivery Note → Sales Invoice → Payment

# Example: Purchase Workflow
# 1. Material Request → Supplier Quotation → Purchase Order
# 2. Purchase Receipt → Purchase Invoice → Payment
```

### Customization

Customize ERPNext to fit your business needs:

```bash
# Customize forms
# 1. Customize Form → Select DocType
# 2. Add/remove fields, change labels, set permissions

# Create custom fields
# 1. Custom Field → New
# 2. Select DocType and field properties

# Create custom reports
# 1. Report Builder → New Report
# 2. Select DocType and columns
# 3. Add filters and grouping
```

### Data Import/Export

Manage bulk data operations:

```bash
# Export data
# 1. Data Export → Select DocType
# 2. Choose fields to export
# 3. Download CSV file

# Import data
# 1. Data Import → New
# 2. Select DocType and CSV file
# 3. Map columns and import
```

### API Integration

Integrate ERPNext with other systems:

```bash
# Generate API keys
# 1. User → API Access → Generate Keys

# Example API call (Python)
import requests
import json

url = "https://erp.yourdomain.com/api/resource/Sales Order"
headers = {
    "Authorization": "token api_key:api_secret"
}
response = requests.get(url, headers=headers)
sales_orders = response.json()
```

### Multi-tenant Usage

For environments with multiple clients:

```bash
# ERPNext supports multi-tenancy through:
# 1. Separate sites for each client
# 2. Custom domains for each site
# 3. Isolated databases for complete data separation

# Path structure:
# /opt/agency_stack/clients/${CLIENT_ID}/erpnext/
```

## Troubleshooting

### Common Issues
- List of common issues and their solutions

## Makefile Targets

| Target | Description |
|--------|-------------|
| `make erpnext` | Install erpnext |
| `make erpnext-status` | Check status of erpnext |
| `make erpnext-logs` | View erpnext logs |
| `make erpnext-restart` | Restart erpnext services |
