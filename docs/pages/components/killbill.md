# Kill Bill

## Overview

Kill Bill is a comprehensive open-source subscription billing, invoicing, and contract management platform integrated into AgencyStack. It provides a robust system for managing recurring payments, subscriptions, usage-based billing, and complex contract scenarios across multiple clients.

### Key Features

- **Subscription Management**: Create and manage complex subscription plans
- **Contract Management**: Handle contracts, amendments, and terms
- **Multi-Tenant Architecture**: Support for isolated client environments
- **Advanced Invoicing**: Generate and manage invoices with customizable templates
- **Payment Gateway Integration**: Support for multiple payment processors
- **Dunning Management**: Configure automated payment retry logic
- **Usage-Based Billing**: Track and bill for metered usage
- **Catalog Management**: Define and manage product catalogs with pricing
- **APIs & SDKs**: RESTful API for integration with other systems
- **Analytics & Reporting**: Track revenue, churn, and other metrics
- **Multi-Currency Support**: Billing in different currencies
- **Tax Integration**: Calculate and apply taxes automatically

## Architecture

Kill Bill consists of two main components:

1. **Kill Bill Server** - Core billing engine that provides the REST API and business logic
2. **Kaui (Kill Bill Admin UI)** - Administrative interface for managing Kill Bill configuration

The system uses MariaDB for data storage, configured for multi-tenant operation with proper security hardening and resource controls.

## Installation

### Prerequisites

- Docker and Docker Compose
- Traefik configured as reverse proxy
- Valid domain name with DNS configured
- SMTP server for email notifications (Mailu integration recommended)
- Minimum 2GB RAM and 2 CPU cores recommended

### Installation Methods

#### Using Makefile (Recommended)

The simplest way to install Kill Bill is using the provided Makefile targets:

```bash
# Interactive installation
make killbill

# Direct installation with parameters
make killbill DOMAIN=billing.example.com CLIENT_ID=client1 MAILU_DOMAIN=mail.example.com
```

#### Manual Installation

You can also install Kill Bill manually using the installation script:

```bash
sudo /home/revelationx/CascadeProjects/foss-server-stack/scripts/components/install_killbill.sh \
  --domain billing.example.com \
  --admin-email admin@example.com \
  --client-id client1 \
  --mailu-domain mail.example.com \
  --with-deps
```

### Installation Parameters

| Parameter | Description | Example |
|-----------|-------------|---------|
| `DOMAIN` | Domain for Kill Bill access | `billing.example.com` |
| `CLIENT_ID` | Client ID for multi-tenant setup | `client1` |
| `ADMIN_EMAIL` | Admin email address | `admin@example.com` |
| `MAILU_DOMAIN` | Domain of Mailu server for SMTP | `mail.example.com` |
| `FORCE` | Force reinstallation if already installed | `true` |
| `WITH_DEPS` | Install dependencies automatically | `true` |

## Directory Structure

Kill Bill follows the AgencyStack standardized directory structure:

```
/opt/agency_stack/clients/[CLIENT_ID]/killbill/
├── config/                            # Configuration files
│   ├── killbill.properties            # Kill Bill server config
│   ├── kaui.yml                       # Kaui admin UI config
│   └── init.sql                       # Database initialization
├── data/                              # Persistent data
│   └── mariadb/                       # MariaDB database files
├── docker-compose.yml                 # Docker Compose configuration
└── .installed                         # Installation marker file

/opt/agency_stack/secrets/killbill/[CLIENT_ID]/
└── [DOMAIN].env                       # Credentials file

/var/log/agency_stack/components/
└── killbill.log                       # Installation and operation logs
```

## Configuration

### Kill Bill Server Configuration

The main configuration file for Kill Bill server is located at:

```
/opt/agency_stack/clients/[CLIENT_ID]/killbill/config/killbill.properties
```

Key settings include:

```properties
# Multi-tenant configuration
org.killbill.server.multitenant=true
org.killbill.tenant.broadcast.rate=5000

# Email notifications
org.killbill.mail.smtp.host=mail.example.com
org.killbill.mail.smtp.port=587
org.killbill.mail.smtp.auth=true
org.killbill.mail.smtp.user=killbill@example.com
org.killbill.mail.smtp.password=your_password
org.killbill.mail.from.address=billing@example.com

# Metrics configuration
org.killbill.metrics.prometheus.enabled=true
org.killbill.metrics.prometheus.hotspot.enabled=true
org.killbill.metrics.prometheus.port=9092
```

### Kaui Admin UI Configuration

The Kaui configuration file is located at:

```
/opt/agency_stack/clients/[CLIENT_ID]/killbill/config/kaui.yml
```

### Database Configuration

Kill Bill uses MariaDB as its database backend. The database is automatically configured during installation with proper user permissions and schema setup.

### Mailu Integration

To configure Kill Bill to use Mailu for email notifications:

```bash
make killbill-mailu DOMAIN=billing.example.com MAILU_DOMAIN=mail.example.com
```

This sets up the SMTP configuration to use your AgencyStack Mailu server for sending invoices, payment reminders, and other notifications.

## Ports & Endpoints

| Service | Port | Protocol | Description |
|---------|------|----------|-------------|
| Kill Bill Server | 8080 | HTTP | API and core services |
| Kaui Admin UI | 9090 | HTTP | Administration interface |
| Prometheus Metrics | 9092 | HTTP | Monitoring metrics endpoint |
| MariaDB | 3306 | TCP | Database (internal only) |

All services are fronted by Traefik, which handles TLS termination and routing:

- **Kill Bill API**: `https://billing.example.com/api/`
- **Kaui Admin UI**: `https://billing.example.com/`
- **Metrics Endpoint**: `http://localhost:9092/metrics` (internal only)

## Multi-Tenant Configuration

Kill Bill supports multi-tenancy through the AgencyStack client isolation system. Each client environment is configured with:

1. **Isolated Database**: Separate database schema for each tenant
2. **Client-Specific Configuration**: Custom settings per client
3. **Separate Credentials**: Unique admin accounts for each client

To set up a new tenant:

```bash
make killbill DOMAIN=billing.client1.com CLIENT_ID=client1
```

### Example Multi-Tenant Setup

```
# Client 1: Voluntaria
make killbill DOMAIN=billing.voluntaria.org CLIENT_ID=voluntaria

# Client 2: Uptrade
make killbill DOMAIN=billing.uptrade.com CLIENT_ID=uptrade

# Client 3: SavviSound
make killbill DOMAIN=billing.savvisound.com CLIENT_ID=savvisound
```

Each client gets their own isolated Kill Bill instance with separate data, while sharing the same underlying infrastructure.

## Creating a New Product / Billing Plan

To create a new billing plan in Kill Bill:

1. **Access Kaui Admin UI**: Navigate to `https://billing.example.com/`
2. **Create a Product Catalog**:
   - Go to Configuration → Catalog
   - Create a new product with price points
   - Define available plans and pricing tiers
3. **Upload Catalog**:
   - Select the XML catalog file
   - Click "Upload Catalog"
4. **Create Subscribers**:
   - Go to Accounts → Create New Account
   - Fill in customer details
   - Link to payment methods
5. **Create Subscriptions**:
   - Go to the customer account
   - Click "Create Subscription"
   - Select the plan and configure details

### Example Catalog XML

```xml
<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<catalog xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:noNamespaceSchemaLocation="CatalogSchema.xsd">
    <effectiveDate>2025-04-12T00:00:00+00:00</effectiveDate>
    <catalogName>AgencyStack Default</catalogName>
    <recurringBillingMode>IN_ADVANCE</recurringBillingMode>
    <currencies>
        <currency>USD</currency>
        <currency>EUR</currency>
    </currencies>
    <products>
        <product name="standard">
            <category>BASE</category>
        </product>
        <product name="premium">
            <category>BASE</category>
        </product>
    </products>
    <rules>
        <changePolicy>
            <changePolicyCase>
                <policy>IMMEDIATE</policy>
            </changePolicyCase>
        </changePolicy>
        <cancelPolicy>
            <cancelPolicyCase>
                <policy>IMMEDIATE</policy>
            </cancelPolicyCase>
        </cancelPolicy>
    </rules>
    <plans>
        <plan name="standard-monthly">
            <product>standard</product>
            <initialPhases />
            <finalPhase type="EVERGREEN">
                <duration>
                    <unit>UNLIMITED</unit>
                </duration>
                <recurring>
                    <billingPeriod>MONTHLY</billingPeriod>
                    <recurringPrice>
                        <price>
                            <currency>USD</currency>
                            <value>9.99</value>
                        </price>
                        <price>
                            <currency>EUR</currency>
                            <value>8.99</value>
                        </price>
                    </recurringPrice>
                </recurring>
            </finalPhase>
        </plan>
        <plan name="premium-monthly">
            <product>premium</product>
            <initialPhases />
            <finalPhase type="EVERGREEN">
                <duration>
                    <unit>UNLIMITED</unit>
                </duration>
                <recurring>
                    <billingPeriod>MONTHLY</billingPeriod>
                    <recurringPrice>
                        <price>
                            <currency>USD</currency>
                            <value>19.99</value>
                        </price>
                        <price>
                            <currency>EUR</currency>
                            <value>17.99</value>
                        </price>
                    </recurringPrice>
                </recurring>
            </finalPhase>
        </plan>
    </plans>
</catalog>
```

## Alpha Integration Status

KillBill has reached Alpha status in the AgencyStack with the following integration points:

| Integration | Status | Details |
|-------------|--------|---------|
| **TLS Termination** | ✅ Complete | Properly configured with Traefik including HTTP to HTTPS redirection |
| **SSO** | ✅ Complete | Integrated with Keycloak for authentication and authorization |  
| **Multi-tenancy** | ✅ Complete | Full client isolation with separate databases, configurations, and access controls |
| **Monitoring** | ✅ Complete | Prometheus metrics exposed on port 9092, integrated with AgencyStack monitoring |
| **Logging** | ✅ Complete | Logs available at `/var/log/agency_stack/components/killbill.log` |
| **Makefile Targets** | ✅ Complete | Standardized targets for installation, status, logs, restart, and validation |
| **Dashboard Integration** | ✅ Complete | Accessible through the AgencyStack dashboard |
| **Documentation** | ✅ Complete | Installation, configuration, and integration documentation available |

## Validation and Security

KillBill integration has been hardened according to AgencyStack standards to ensure proper security, SSL configuration, and SSO integration. The following validation tools are available:

```bash
# Validate TLS, SSO, and metrics configuration
make killbill-validate DOMAIN=billing.example.com [CLIENT_ID=tenant1]

# Run comprehensive alpha milestone validation
make billing-alpha-check DOMAIN=billing.example.com [CLIENT_ID=tenant1]
```

The validation suite checks:

1. **TLS Configuration**:
   - HTTPS accessibility for both KillBill API and KAUI UI
   - Certificate validity and expiration dates
   - HTTP to HTTPS redirection

2. **SSO Integration**:
   - Keycloak connectivity
   - SSO configuration in docker-compose.yml
   - KAUI login redirection to Keycloak

3. **Metrics Configuration**:
   - Prometheus metrics endpoint availability
   - Metrics integration in Prometheus configuration

### Security Recommendations

For production deployments, we recommend the following additional security measures:

1. Enable CSRF protection for the API
2. Configure IP-based access restrictions for administrative functions
3. Implement API rate limiting
4. Regularly rotate all database credentials
5. Keep all components updated to the latest version

## Alpha Milestone Requirements

Kill Bill meets all requirements for the AgencyStack Alpha milestone:
- Consistently follows AgencyStack installation patterns
- Uses proper validation and security practices
- Complies with multi-tenant approach
- Follows documentation standards
- Provides Makefile targets aligned with other components
- Integrates with monitoring, TLS, and SSO

## Security

Kill Bill in AgencyStack is configured with security best practices:

1. **Database Security**:
   - Random generated secure passwords
   - Minimal database privilege grants
   - Connection encryption

2. **Container Security**:
   - Resource limits to prevent DoS
   - Non-root user execution
   - Minimal exposed ports

3. **Credential Management**:
   - Secure storage of credentials in `/opt/agency_stack/secrets/killbill/`
   - File permissions limited to root only (0600)
   - Passwords never exposed in logs

4. **Network Security**:
   - TLS encryption via Traefik
   - Internal network isolation
   - API authentication required for all endpoints

5. **Audit Logging**:
   - All administrative actions logged
   - Changes tracked with user attribution
   - Logs secured from tampering

## Logs & Monitoring

### Log Locations

- **Installation Logs**: `/var/log/agency_stack/components/killbill.log`
- **Kill Bill Server Logs**: 
  ```bash
  make killbill-logs DOMAIN=billing.example.com CONTAINER=app
  ```
- **Kaui Logs**:
  ```bash
  make killbill-logs DOMAIN=billing.example.com CONTAINER=kaui
  ```
- **Database Logs**:
  ```bash
  make killbill-logs DOMAIN=billing.example.com CONTAINER=mariadb
  ```

### Monitoring

Kill Bill exposes Prometheus-compatible metrics at `/metrics`. Key metrics include:

- **API Performance**: Request latency, throughput, and error rates
- **Database Performance**: Connection pool usage, query times
- **Business Metrics**: Active subscriptions, revenue, etc.
- **System Metrics**: CPU, memory, and disk usage

To view metrics:

```bash
curl http://localhost:9092/metrics
```

Integration with Prometheus and Grafana provides dashboards for monitoring Kill Bill health and performance.

## Makefile Targets

| Target | Description | Example |
|--------|-------------|---------|
| `make killbill` | Install Kill Bill | `make killbill DOMAIN=billing.example.com` |
| `make killbill-status` | Check Kill Bill status | `make killbill-status DOMAIN=billing.example.com` |
| `make killbill-logs` | View Kill Bill logs | `make killbill-logs DOMAIN=billing.example.com` |
| `make killbill-restart` | Restart Kill Bill | `make killbill-restart DOMAIN=billing.example.com` |
| `make killbill-test` | Test Kill Bill API | `make killbill-test DOMAIN=billing.example.com` |
| `make killbill-mailu` | Integrate with Mailu | `make killbill-mailu DOMAIN=billing.example.com MAILU_DOMAIN=mail.example.com` |

All targets support the common parameters:
- `DOMAIN`: The domain name (required)
- `CLIENT_ID`: For multi-tenant setups (optional)

## Dashboard Integration

Kill Bill is integrated with the AgencyStack dashboard, providing:

- **Component Status**: Running status and health indicators
- **Quick Actions**: Start/Stop, Restart, View Logs, Access Documentation
- **Metrics Display**: Key performance indicators
- **Client Selector**: For multi-tenant environments

## Troubleshooting

### Common Issues

1. **Database Connection Errors**
   - Check MariaDB container is running: `docker ps | grep killbill_mariadb`
   - Verify database credentials in configuration
   - Check database logs: `make killbill-logs DOMAIN=billing.example.com CONTAINER=mariadb`

2. **API Connection Issues**
   - Verify Kill Bill server is running: `make killbill-status DOMAIN=billing.example.com`
   - Check DNS configuration for the domain
   - Test API connectivity: `make killbill-test DOMAIN=billing.example.com`

3. **Email Notification Problems**
   - Confirm SMTP settings in configuration
   - Verify Mailu integration: `make killbill-mailu DOMAIN=billing.example.com MAILU_DOMAIN=mail.example.com`
   - Test SMTP connection: `telnet mail.example.com 587`

4. **Performance Issues**
   - Check container resource usage: `docker stats killbill_app_default`
   - Optimize MariaDB configuration for your workload
   - Consider increasing container resource limits in `docker-compose.yml`

## Reference Documentation

- [Kill Bill Official Documentation](https://docs.killbill.io/)
- [Kill Bill API Reference](https://killbill.github.io/slate/)
- [Kaui Administration Guide](https://docs.killbill.io/latest/kaui.html)
- [Catalog Configuration](https://docs.killbill.io/latest/userguide_subscription.html#_catalog)
