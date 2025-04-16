#!/bin/bash
# Environment Validation Script for FOSS Server Stack
# This script checks if the server meets the minimum requirements

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}==============================================${NC}"
echo -e "${BLUE}    FOSS Server Stack Environment Check      ${NC}"
echo -e "${BLUE}==============================================${NC}"
echo ""

# Check OS
echo -e "${YELLOW}Checking Operating System...${NC}"
if [ -f /etc/os-release ]; then
    . /etc/os-release
    echo -e "OS: ${GREEN}$NAME $VERSION_ID${NC}"
    if [[ "$ID" == "ubuntu" || "$ID" == "debian" ]]; then
        echo -e "OS Check: ${GREEN}PASSED${NC}"
    else
        echo -e "OS Check: ${YELLOW}WARNING${NC} - This script is optimized for Ubuntu/Debian."
    fi
else
    echo -e "OS Check: ${RED}FAILED${NC} - Could not determine OS."
fi
echo ""

# Check Memory
echo -e "${YELLOW}Checking Memory...${NC}"
MEM_TOTAL=$(grep MemTotal /proc/meminfo | awk '{print $2}')
MEM_TOTAL_GB=$(echo "scale=2; $MEM_TOTAL/1024/1024" | bc)
echo -e "Total Memory: ${GREEN}${MEM_TOTAL_GB} GB${NC}"
if (( $(echo "$MEM_TOTAL_GB >= 7.5" | bc -l) )); then
    echo -e "Memory Check: ${GREEN}PASSED${NC} - Sufficient for full stack."
elif (( $(echo "$MEM_TOTAL_GB >= 3.5" | bc -l) )); then
    echo -e "Memory Check: ${YELLOW}WARNING${NC} - Minimum 8GB recommended for full stack."
else
    echo -e "Memory Check: ${RED}FAILED${NC} - Less than 4GB available, insufficient for reliable operation."
fi
echo ""

# Check CPU
echo -e "${YELLOW}Checking CPU...${NC}"
CPU_CORES=$(grep -c ^processor /proc/cpuinfo)
echo -e "CPU Cores: ${GREEN}$CPU_CORES${NC}"
if [ "$CPU_CORES" -ge 4 ]; then
    echo -e "CPU Check: ${GREEN}PASSED${NC} - Sufficient for full stack."
elif [ "$CPU_CORES" -ge 2 ]; then
    echo -e "CPU Check: ${YELLOW}WARNING${NC} - Minimum 4 cores recommended for full stack."
else
    echo -e "CPU Check: ${RED}FAILED${NC} - Less than 2 cores available, insufficient for reliable operation."
fi
echo ""

# Check Disk Space
echo -e "${YELLOW}Checking Disk Space...${NC}"
ROOT_DISK=$(df -h / | grep -v Filesystem)
ROOT_SIZE=$(echo $ROOT_DISK | awk '{print $2}')
ROOT_USED=$(echo $ROOT_DISK | awk '{print $3}')
ROOT_AVAIL=$(echo $ROOT_DISK | awk '{print $4}')
echo -e "Disk Size: ${GREEN}$ROOT_SIZE${NC}"
echo -e "Disk Used: ${YELLOW}$ROOT_USED${NC}"
echo -e "Disk Available: ${GREEN}$ROOT_AVAIL${NC}"

# Convert available space to GB for comparison (approximate)
AVAIL_GB=$(echo $ROOT_AVAIL | sed 's/G//' | sed 's/T/*1000/' | bc)
if (( $(echo "$AVAIL_GB >= 100" | bc -l) )); then
    echo -e "Disk Check: ${GREEN}PASSED${NC} - Sufficient for full stack."
elif (( $(echo "$AVAIL_GB >= 50" | bc -l) )); then
    echo -e "Disk Check: ${YELLOW}WARNING${NC} - Minimum 100GB recommended for full stack."
else
    echo -e "Disk Check: ${RED}FAILED${NC} - Less than 50GB available, insufficient for reliable operation."
fi
echo ""

# Check if Docker is installed
echo -e "${YELLOW}Checking for Docker...${NC}"
if command -v docker &> /dev/null; then
    DOCKER_VERSION=$(docker --version)
    echo -e "Docker: ${GREEN}$DOCKER_VERSION${NC}"
    echo -e "Docker Check: ${GREEN}PASSED${NC}"
else
    echo -e "Docker: ${YELLOW}Not installed${NC}"
    echo -e "Docker Check: ${YELLOW}WARNING${NC} - Will be installed by the setup script."
fi
echo ""

# Check if Docker Compose is installed
echo -e "${YELLOW}Checking for Docker Compose...${NC}"
if command -v docker-compose &> /dev/null; then
    COMPOSE_VERSION=$(docker-compose --version)
    echo -e "Docker Compose: ${GREEN}$COMPOSE_VERSION${NC}"
    echo -e "Docker Compose Check: ${GREEN}PASSED${NC}"
else
    echo -e "Docker Compose: ${YELLOW}Not installed${NC}"
    echo -e "Docker Compose Check: ${YELLOW}WARNING${NC} - Will be installed by the setup script."
fi
echo ""

# Check internet connectivity
echo -e "${YELLOW}Checking Internet Connectivity...${NC}"
if ping -c 1 google.com &> /dev/null; then
    echo -e "Internet Connectivity: ${GREEN}PASSED${NC}"
else
    echo -e "Internet Connectivity: ${RED}FAILED${NC} - Cannot reach internet."
fi
echo ""

# Check if ports 80 and 443 are available
echo -e "${YELLOW}Checking if ports 80 and 443 are available...${NC}"
if netstat -tuln | grep ':80 ' &> /dev/null; then
    echo -e "Port 80: ${RED}IN USE${NC} - May conflict with Traefik"
else
    echo -e "Port 80: ${GREEN}AVAILABLE${NC}"
fi

if netstat -tuln | grep ':443 ' &> /dev/null; then
    echo -e "Port 443: ${RED}IN USE${NC} - May conflict with Traefik"
else
    echo -e "Port 443: ${GREEN}AVAILABLE${NC}"
fi
echo ""

# Summary
echo -e "${BLUE}==============================================${NC}"
echo -e "${BLUE}              Summary                        ${NC}"
echo -e "${BLUE}==============================================${NC}"
echo -e "This server appears to be ${GREEN}adequate${NC} for running the FOSS stack."
echo -e "Please review any ${YELLOW}WARNING${NC} or ${RED}FAILED${NC} messages above before proceeding."
echo -e ""
echo -e "Next steps:"
echo -e "1. Review the PRE_INSTALLATION_CHECKLIST.md"
echo -e "2. Run the install.sh script to begin installation"
echo -e "${BLUE}==============================================${NC}"
