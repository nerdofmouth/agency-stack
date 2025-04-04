#!/bin/bash
# agency_branding.sh - Branding utilities for AgencyStack by Nerd of Mouth
# https://stack.nerdofmouth.com

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
BRANDING_FILE="$SCRIPT_DIR/branding.json"

# Function to get value from branding.json
get_branding_value() {
    local key="$1"
    if [ -f "$BRANDING_FILE" ]; then
        if command -v jq &> /dev/null; then
            jq -r ".$key" "$BRANDING_FILE" 2>/dev/null
        else
            grep -o "\"$key\": *\"[^\"]*\"" "$BRANDING_FILE" | sed "s/\"$key\": *\"\(.*\)\"/\1/" 2>/dev/null
        fi
    else
        # Fallback values if branding file not found
        case "$key" in
            "product_name") echo "AgencyStack" ;;
            "creator") echo "Nerd of Mouth" ;;
            "slogan") echo "Deploy Smart. Speak Nerd." ;;
            "homepage") echo "https://stack.nerdofmouth.com" ;;
            "support") echo "support@nerdofmouth.com" ;;
            "version") echo "0.0.1.2025.04.04" ;;
            *) echo "Unknown" ;;
        esac
    fi
}

# Display a random tagline
random_tagline() {
    if [ -f "$BRANDING_FILE" ] && command -v jq &> /dev/null; then
        # Get total taglines count
        local count=$(jq -r '.taglines | length' "$BRANDING_FILE")
        # Select random tagline
        local index=$((RANDOM % count))
        local tagline=$(jq -r ".taglines[$index]" "$BRANDING_FILE")
        echo -e "${MAGENTA}${BOLD}\"$tagline\"${NC}"
    else
        # Fallback taglines if jq not available or branding file not found
        local taglines=(
            "Run your agency. Reclaim your agency."
            "Tools for freedom, proof of power."
            "The Agency Project: Metal + Meaning."
            "Don't just deploy. Declare independence."
            "Freedom starts with a shell prompt."
            "From Zero to Sovereign."
            "CLI-tested. Compliance-detested."
            "An agency stack with an agenda: yours."
        )
        local index=$((RANDOM % ${#taglines[@]}))
        echo -e "${MAGENTA}${BOLD}\"${taglines[$index]}\"${NC}"
    fi
}

# Display full branding banner
display_banner() {
    local product_name=$(get_branding_value "product_name")
    local creator=$(get_branding_value "creator")
    local slogan=$(get_branding_value "slogan")
    local homepage=$(get_branding_value "homepage")
    
    echo -e "${MAGENTA}${BOLD}"
    cat << "EOF"
    _                            ____  _             _    
   / \   __ _  ___ _ __   ___ _/ ___|| |_ __ _  ___| | __
  / _ \ / _` |/ _ \ '_ \ / __| \___ \| __/ _` |/ __| |/ /
 / ___ \ (_| |  __/ | | | (__| |___) | || (_| | (__|   < 
/_/   \_\__, |\___|_| |_|\___|_|____/ \__\__,_|\___|_|\_\
        |___/                                            
EOF
    echo -e "${NC}\n"
    echo -e "${CYAN}${BOLD}$product_name${NC} by ${YELLOW}$creator${NC}"
    echo -e "${BLUE}$slogan${NC}"
    echo -e "${GREEN}$homepage${NC}\n"
    random_tagline
    echo ""
}

# Display small branding header
display_header() {
    local product_name=$(get_branding_value "product_name")
    local creator=$(get_branding_value "creator")
    
    echo -e "${CYAN}${BOLD}$product_name${NC} by ${YELLOW}$creator${NC}"
    random_tagline
    echo ""
}

# Run appropriate function if script called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ "$1" == "banner" ]]; then
        display_banner
    elif [[ "$1" == "header" ]]; then
        display_header
    elif [[ "$1" == "tagline" ]]; then
        random_tagline
    else
        display_banner
    fi
fi
