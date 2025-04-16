#!/bin/bash
# test_environment.sh - Tests the AgencyStack environment and services
# https://stack.nerdofmouth.com

# Colors and formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Visual feedback framework
print_header() { echo -e "\n${MAGENTA}${BOLD}$1${NC}\n"; }
print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_info() { echo -e "${BLUE}🔹 $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️ $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }

# Log file setup
LOGDIR="/var/log/agency_stack"
LOGFILE="$LOGDIR/test-$(date +%Y%m%d-%H%M%S).log"
mkdir -p "$LOGDIR"
touch "$LOGFILE"

# Logging function
log() {
  local level="$1"
  local message="$2"
  local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  echo -e "[$timestamp] [AgencyStack] [$level] $message" | tee -a "$LOGFILE"
}

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then
  print_error "Please run as root or with sudo"
  exit 1
fi

# Display header
cat << "EOF"
🧪🧪🧪🧪🧪🧪🧪🧪🧪🧪🧪🧪🧪🧪🧪🧪🧪🧪🧪🧪🧪🧪🧪🧪🧪🧪🧪🧪🧪
🧪                                                    🧪
🧪    AgencyStack Environment Test Suite               🧪
🧪    https://stack.nerdofmouth.com                    🧪
🧪                                                    🧪
🧪🧪🧪🧪🧪🧪🧪🧪🧪🧪🧪🧪🧪🧪🧪🧪🧪🧪🧪🧪🧪🧪🧪🧪🧪🧪🧪🧪🧪
EOF
echo ""

log "INFO" "Starting AgencyStack test suite"
print_info "Test results will be logged to: $LOGFILE"

# Display motto
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
if [ -f "$SCRIPT_DIR/motto.sh" ]; then
  source "$SCRIPT_DIR/motto.sh" && random_motto
  echo ""
fi

# Check system requirements
print_header "System Requirements Check"

# Check CPU
CPU_CORES=$(grep -c processor /proc/cpuinfo)
if [ "$CPU_CORES" -ge 2 ]; then
  print_success "CPU: $CPU_CORES cores (Recommended: 2+ cores)"
  log "INFO" "CPU check passed: $CPU_CORES cores"
else
  print_warning "CPU: $CPU_CORES cores (Recommended: 2+ cores)"
  log "WARN" "CPU below recommended: $CPU_CORES cores"
fi

# Check RAM
TOTAL_RAM=$(free -m | awk '/^Mem:/{print $2}')
if [ "$TOTAL_RAM" -ge 4000 ]; then
  print_success "Memory: $TOTAL_RAM MB (Recommended: 4000+ MB)"
  log "INFO" "Memory check passed: $TOTAL_RAM MB"
else
  print_warning "Memory: $TOTAL_RAM MB (Recommended: 4000+ MB)"
  log "WARN" "Memory below recommended: $TOTAL_RAM MB"
fi

# Check disk space
ROOT_SPACE=$(df -m / | awk 'NR==2 {print $4}')
if [ "$ROOT_SPACE" -ge 20000 ]; then
  print_success "Disk Space: $ROOT_SPACE MB (Recommended: 20000+ MB)"
  log "INFO" "Disk space check passed: $ROOT_SPACE MB"
else
  print_warning "Disk Space: $ROOT_SPACE MB (Recommended: 20000+ MB)"
  log "WARN" "Disk space below recommended: $ROOT_SPACE MB"
fi

# Docker check
print_header "Docker Check"
if command -v docker &> /dev/null; then
  if docker info &> /dev/null; then
    print_success "Docker is installed and running"
    log "INFO" "Docker check passed"
    # Check Docker version
    DOCKER_VERSION=$(docker version --format '{{.Server.Version}}')
    print_info "Docker version: $DOCKER_VERSION"
    log "INFO" "Docker version: $DOCKER_VERSION"
  else
    print_error "Docker is installed but not running"
    log "ERROR" "Docker is not running"
    print_info "Try starting Docker: sudo systemctl start docker"
  fi
else
  print_error "Docker is not installed"
  log "ERROR" "Docker is not installed"
  print_info "Install Docker first: sudo make install"
fi

# Docker Compose check
print_header "Docker Compose Check"
if command -v docker-compose &> /dev/null; then
  print_success "Docker Compose is installed"
  log "INFO" "Docker Compose check passed"
  # Check Docker Compose version
  DC_VERSION=$(docker-compose version --short)
  print_info "Docker Compose version: $DC_VERSION"
  log "INFO" "Docker Compose version: $DC_VERSION"
else
  print_error "Docker Compose is not installed"
  log "ERROR" "Docker Compose is not installed"
  print_info "Install Docker Compose first: sudo make install"
fi

# Network configuration check
print_header "Network Configuration Check"

# Check if Traefik is running
if docker ps | grep -q traefik; then
  print_success "Traefik is running"
  log "INFO" "Traefik check passed"
  
  # Check Traefik configuration
  if [ -d "/etc/traefik" ]; then
    print_success "Traefik configuration directory exists"
    log "INFO" "Traefik configuration directory check passed"
    
    # Check if SSL certificates exist
    if [ -d "/etc/traefik/certs" ]; then
      print_success "SSL certificates directory exists"
      log "INFO" "SSL certificates directory check passed"
    else
      print_warning "SSL certificates directory does not exist"
      log "WARN" "SSL certificates directory check failed"
      print_info "Create SSL directory: mkdir -p /etc/traefik/certs"
    fi
  else
    print_warning "Traefik configuration directory does not exist"
    log "WARN" "Traefik configuration directory check failed"
    print_info "Create Traefik directory: mkdir -p /etc/traefik"
  fi
else
  print_warning "Traefik is not running"
  log "WARN" "Traefik check failed"
  print_info "Start Traefik first: sudo make install (choose Traefik)"
fi

# Check required ports
print_header "Port Configuration Check"

# Function to check if a port is in use
check_port() {
  local port="$1"
  local service="$2"
  
  if ss -tuln | grep -q ":$port "; then
    print_success "Port $port is in use by $service"
    log "INFO" "Port $port check passed"
    return 0
  else
    print_warning "Port $port is not in use (expected by $service)"
    log "WARN" "Port $port check failed"
    return 1
  fi
}

# Check core ports
check_port 80 "HTTP/Traefik"
check_port 443 "HTTPS/Traefik"
check_port 9443 "Portainer"

# Load port allocation if exists
PORT_MANAGER="/home/revelationx/CascadeProjects/foss-server-stack/scripts/port_manager.sh"
if [ -f "$PORT_MANAGER" ]; then
  print_success "Port manager found"
  log "INFO" "Port manager check passed"
  source "$PORT_MANAGER"
  echo -e "\n${CYAN}Current Port Allocations:${NC}"
  list_ports
else
  print_warning "Port manager not found"
  log "WARN" "Port manager check failed"
fi

# Check running containers
print_header "Container Status Check"

# Get list of running containers
RUNNING_CONTAINERS=$(docker ps --format '{{.Names}}' 2>/dev/null)
TOTAL_CONTAINERS=$(docker ps -a --format '{{.Names}}' 2>/dev/null)

if [ -n "$RUNNING_CONTAINERS" ]; then
  print_success "Running containers: $(echo "$RUNNING_CONTAINERS" | wc -l)"
  log "INFO" "Running containers: $(echo "$RUNNING_CONTAINERS" | wc -l)"
  
  # Check core services
  for service in traefik portainer; do
    if echo "$RUNNING_CONTAINERS" | grep -q "$service"; then
      print_success "$service is running"
      log "INFO" "$service check passed"
    else
      print_warning "$service is not running"
      log "WARN" "$service check failed"
    fi
  done
  
  # List all running containers
  echo -e "\n${CYAN}Running Containers:${NC}"
  docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
else
  print_error "No containers are running"
  log "ERROR" "No containers are running"
  print_info "Start containers first: sudo make install"
fi

# DNS check for configured domains
print_header "DNS Configuration Check"

# Check if config.env exists
if [ -f "/opt/agency_stack/config.env" ]; then
  source "/opt/agency_stack/config.env"
  
  if [ -n "$PRIMARY_DOMAIN" ]; then
    if [ "$PRIMARY_DOMAIN" = "example.com" ]; then
      print_warning "PRIMARY_DOMAIN is set to example.com (placeholder)"
      log "WARN" "PRIMARY_DOMAIN is set to example.com"
    else
      print_info "Checking DNS for $PRIMARY_DOMAIN..."
      if host "$PRIMARY_DOMAIN" &>/dev/null; then
        print_success "DNS resolved for $PRIMARY_DOMAIN"
        log "INFO" "DNS check passed for $PRIMARY_DOMAIN"
      else
        print_warning "DNS failed for $PRIMARY_DOMAIN"
        log "WARN" "DNS check failed for $PRIMARY_DOMAIN"
      fi
    fi
  else
    print_warning "No PRIMARY_DOMAIN set in config (found: 'example.com' placeholder)"
    log "WARN" "No PRIMARY_DOMAIN configured properly"
  fi
  
  # Check client domains if they exist
  if [ -d "/opt/agency_stack/clients" ]; then
    for client_dir in /opt/agency_stack/clients/*; do
      if [ -d "$client_dir" ] && [ -f "$client_dir/.env" ]; then
        CLIENT_DOMAIN=$(grep CLIENT_DOMAIN "$client_dir/.env" | cut -d'=' -f2)
        if [ -n "$CLIENT_DOMAIN" ]; then
          print_info "Checking DNS for $CLIENT_DOMAIN..."
          if host "$CLIENT_DOMAIN" &>/dev/null; then
            print_success "DNS resolved for $CLIENT_DOMAIN"
            log "INFO" "DNS check passed for $CLIENT_DOMAIN"
          else
            print_warning "DNS failed for $CLIENT_DOMAIN"
            log "WARN" "DNS check failed for $CLIENT_DOMAIN"
          fi
        fi
      fi
    done
  fi
else
  print_warning "No configuration file found at /opt/agency_stack/config.env"
  log "WARN" "Configuration file check failed"
fi

# Test summary
print_header "Test Summary"
log "INFO" "Completed AgencyStack test suite"
print_info "All tests completed. Check the log for details: $LOGFILE"

# Check if there were any errors
if grep -q "ERROR" "$LOGFILE"; then
  print_error "Some critical tests failed. Please address the issues."
  log "ERROR" "Test suite completed with errors"
  exit 1
elif grep -q "WARN" "$LOGFILE"; then
  print_warning "Some non-critical tests failed. The system may still work but with limited functionality."
  log "WARN" "Test suite completed with warnings"
  exit 0
else
  print_success "All tests passed successfully! AgencyStack is ready."
  log "INFO" "Test suite completed successfully"
  exit 0
fi
