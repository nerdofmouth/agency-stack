#!/bin/bash
# system_performance.sh - System performance stats for AgencyStack by Nerd of Mouth
# https://stack.nerdofmouth.com

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# ASCII art
echo -e "${CYAN}${BOLD}"
cat << "EOF"
 ____             _      ___   __  __  __  __            _   _     
|  _ \ ___   ___ | |_   / _ \ / _|/ _|/ _|/ _| ___  ___ | |_| |__  
| |_) / _ \ / _ \| __| | | | | |_| |_| |_| |_ / _ \/ _ \| __| '_ \ 
|  _ < (_) | (_) | |_  | |_| |  _|  _|  _|  _|  __/ (_) | |_| | | |
|_| \_\___/ \___/ \__|  \___/|_| |_| |_| |_|  \___|\___/ \__|_| |_|
EOF
echo -e "${NC}\n"

# System info
echo -e "${YELLOW}${BOLD}System Information:${NC}"
echo -e "${CYAN}Hostname:${NC} $(hostname)"
echo -e "${CYAN}Kernel:${NC} $(uname -r)"
echo -e "${CYAN}Uptime:${NC} $(uptime -p)"
echo -e "${CYAN}Last Boot:${NC} $(who -b | awk '{print $3, $4}')"
echo ""

# CPU info
echo -e "${YELLOW}${BOLD}CPU Information:${NC}"
echo -e "${CYAN}CPU Model:${NC} $(grep "model name" /proc/cpuinfo | head -1 | cut -d ":" -f2 | sed 's/^[ \t]*//')"
echo -e "${CYAN}CPU Cores:${NC} $(grep -c processor /proc/cpuinfo)"
echo -e "${CYAN}CPU Usage:${NC}"
mpstat 1 1 | awk '/Average:/ {printf "%.2f%%\n", 100 - $12}' || echo "mpstat not installed"
echo ""

# Memory info
echo -e "${YELLOW}${BOLD}Memory Information:${NC}"
free -h | awk '/^Mem:/ {print "Total: " $2 "    Used: " $3 "    Free: " $4 "    Buffers/Cache: " $6}'
echo ""

# Disk info
echo -e "${YELLOW}${BOLD}Disk Information:${NC}"
df -h | grep -v "tmpfs\|udev" | awk 'NR==1 || /^\/dev\// {print}'
echo ""

# Docker info
echo -e "${YELLOW}${BOLD}Docker Information:${NC}"
if command -v docker &> /dev/null; then
    echo -e "${CYAN}Docker Version:${NC} $(docker --version)"
    echo -e "${CYAN}Running Containers:${NC} $(docker ps --format '{{.Names}}' | wc -l)"
    echo -e "${CYAN}Total Containers:${NC} $(docker ps -a --format '{{.Names}}' | wc -l)"
    echo -e "${CYAN}Total Images:${NC} $(docker images | wc -l)"
else
    echo -e "${RED}Docker not installed${NC}"
fi
echo ""

# Network info
echo -e "${YELLOW}${BOLD}Network Information:${NC}"
ip -4 addr | grep inet | grep -v "127.0.0.1" | awk '{print $NF, $2}'
echo ""

# System load
echo -e "${YELLOW}${BOLD}System Load (1, 5, 15 min):${NC}"
uptime | awk -F'[a-z]:' '{ print $2}' | awk -F',' '{ print $1, $2, $3 }'
echo ""

# Top processes
echo -e "${YELLOW}${BOLD}Top 5 CPU Consuming Processes:${NC}"
ps -eo pid,ppid,cmd,%mem,%cpu --sort=-%cpu | head -n 6
echo ""

# AgencyStack tag
echo -e "${GREEN}${BOLD}Powered by Nerd of Mouth${NC}"
