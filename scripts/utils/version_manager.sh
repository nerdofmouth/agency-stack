#!/bin/bash
# version_manager.sh
# Utility for version detection, comparison, and updates for AgencyStack components
# Following the AgencyStack Alpha Phase Repository Integrity Policy

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Source common utilities if available
if [[ -f "${SCRIPT_DIR}/common.sh" ]]; then
    source "${SCRIPT_DIR}/common.sh"
else
    # Define minimal logging functions if common.sh is not available
    log_info() { echo "[INFO] $1"; }
    log_warning() { echo "[WARNING] $1"; }
    log_error() { echo "[ERROR] $1"; }
    log_success() { echo "[SUCCESS] $1"; }
fi

# Function to compare semantic versions
# Returns: 
#   0 if version1 = version2
#   1 if version1 > version2
#   2 if version1 < version2
compare_versions() {
    local version1="$1"
    local version2="$2"
    
    # Remove any 'v' prefix
    version1="${version1#v}"
    version2="${version2#v}"
    
    if [[ "$version1" == "$version2" ]]; then
        return 0
    fi
    
    # Split versions by dots
    IFS=. read -r -a v1_parts <<< "$version1"
    IFS=. read -r -a v2_parts <<< "$version2"
    
    # Compare version components
    local max_length=$((${#v1_parts[@]} > ${#v2_parts[@]} ? ${#v1_parts[@]} : ${#v2_parts[@]}))
    
    for ((i=0; i<max_length; i++)); do
        local v1_part=${v1_parts[i]:-0}
        local v2_part=${v2_parts[i]:-0}
        
        # Extract numbers from version parts (handling cases like '1rc1')
        v1_num=$(echo "$v1_part" | grep -o '^[0-9]*')
        v2_num=$(echo "$v2_part" | grep -o '^[0-9]*')
        
        v1_num=${v1_num:-0}
        v2_num=${v2_num:-0}
        
        if ((v1_num > v2_num)); then
            return 1
        elif ((v1_num < v2_num)); then
            return 2
        fi
        
        # If numbers are equal, compare the whole parts lexicographically
        # This handles cases like '1rc1' vs '1'
        if [[ "$v1_part" > "$v2_part" ]]; then
            return 1
        elif [[ "$v1_part" < "$v2_part" ]]; then
            return 2
        fi
    done
    
    return 0
}

# Function to check if a component needs updating
# $1: Component name
# $2: Current version
# $3: Available version
# Returns:
#   0 if update needed
#   1 if no update needed
needs_update() {
    local component="$1"
    local current_version="$2"
    local available_version="$3"
    
    # Handle "latest" tag
    if [[ "$current_version" == "latest" ]]; then
        log_info "Component '$component' uses 'latest' tag, which is not recommended for production"
        return 0
    fi
    
    # Compare versions
    compare_versions "$current_version" "$available_version"
    local result=$?
    
    if [[ $result -eq 2 ]]; then
        log_info "Component '$component' can be updated from $current_version to $available_version"
        return 0
    else
        log_info "Component '$component' is already at the latest version ($current_version)"
        return 1
    fi
}

# Function to detect the latest version of a component from GitHub
get_latest_github_version() {
    local repo="$1"
    local version_pattern="${2:-v[0-9]+\.[0-9]+\.[0-9]+}"
    
    if command -v curl &>/dev/null; then
        local latest_version=$(curl -s "https://api.github.com/repos/$repo/releases/latest" | grep -oP '"tag_name": "\K(.*)(?=")')
        if [[ -n "$latest_version" ]]; then
            echo "$latest_version"
            return 0
        fi
    fi
    
    log_error "Failed to get latest version for $repo"
    return 1
}

# Function to detect the latest version of NodeJS LTS
get_latest_nodejs_lts() {
    if command -v curl &>/dev/null; then
        local latest_version=$(curl -s https://nodejs.org/dist/index.json | grep -o '"lts":[^,]*' | grep -v false | head -1)
        if [[ -n "$latest_version" ]]; then
            local version=$(curl -s https://nodejs.org/dist/index.json | grep -o '"version":"[^"]*"' | head -1 | cut -d'"' -f4)
            echo "${version#v}"
            return 0
        fi
    fi
    
    log_error "Failed to get latest NodeJS LTS version"
    echo "20.11.1"  # Fallback to a known LTS version
    return 1
}

# Function to detect the latest version of a Docker image
get_latest_docker_image_version() {
    local image="$1"
    local tag_pattern="${2:-.*}"
    
    if command -v curl &>/dev/null && command -v jq &>/dev/null; then
        local image_name=${image%%:*}
        local tags_json=$(curl -s "https://hub.docker.com/v2/repositories/${image_name}/tags?page_size=100")
        local latest_tag=$(echo "$tags_json" | jq -r '.results[] | select(.name | test("'"$tag_pattern"'")) | .name' | grep -v latest | sort -V | tail -1)
        
        if [[ -n "$latest_tag" ]]; then
            echo "$latest_tag"
            return 0
        fi
    fi
    
    log_error "Failed to get latest version for Docker image $image"
    return 1
}

# Function to scan the entire repository for version references and suggest updates
scan_repository_versions() {
    local output_file="${1:-${REPO_ROOT}/version_scan_results.txt}"
    
    log_info "Scanning repository for component versions..."
    echo "AgencyStack Version Scan Results ($(date))" > "$output_file"
    echo "==========================================" >> "$output_file"
    echo "" >> "$output_file"
    
    # Find NodeJS version
    local current_nodejs_version=$(grep -r "NODE_VERSION" "${REPO_ROOT}/scripts" | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' | head -1)
    local latest_nodejs_version=$(get_latest_nodejs_lts)
    
    echo "## NodeJS" >> "$output_file"
    echo "Current version: ${current_nodejs_version:-Unknown}" >> "$output_file"
    echo "Latest LTS version: $latest_nodejs_version" >> "$output_file"
    
    if [[ -n "$current_nodejs_version" && -n "$latest_nodejs_version" ]]; then
        needs_update "NodeJS" "$current_nodejs_version" "$latest_nodejs_version"
        if [[ $? -eq 0 ]]; then
            echo "Status: UPDATE RECOMMENDED" >> "$output_file"
        else
            echo "Status: Up to date" >> "$output_file"
        fi
    else
        echo "Status: Cannot determine" >> "$output_file"
    fi
    echo "" >> "$output_file"
    
    # Find Traefik version
    local current_traefik_version=$(grep -r "TRAEFIK_VERSION" "${REPO_ROOT}/scripts" | grep -o '[0-9]\+\.[0-9]\+' | head -1)
    if [[ -n "$current_traefik_version" ]]; then
        current_traefik_version="${current_traefik_version}.0"  # Add patch version for comparison
    fi
    local latest_traefik_version=$(get_latest_github_version "traefik/traefik")
    
    echo "## Traefik" >> "$output_file"
    echo "Current version: ${current_traefik_version:-Unknown}" >> "$output_file"
    echo "Latest version: $latest_traefik_version" >> "$output_file"
    
    if [[ -n "$current_traefik_version" && -n "$latest_traefik_version" ]]; then
        needs_update "Traefik" "$current_traefik_version" "$latest_traefik_version"
        if [[ $? -eq 0 ]]; then
            echo "Status: UPDATE RECOMMENDED" >> "$output_file"
        else
            echo "Status: Up to date" >> "$output_file"
        fi
    else
        echo "Status: Cannot determine" >> "$output_file"
    fi
    echo "" >> "$output_file"
    
    # Find Keycloak version
    local current_keycloak_version=$(grep -r "KEYCLOAK_VERSION" "${REPO_ROOT}/scripts" | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+\|latest' | head -1)
    local latest_keycloak_version=$(get_latest_github_version "keycloak/keycloak")
    
    echo "## Keycloak" >> "$output_file"
    echo "Current version: ${current_keycloak_version:-Unknown}" >> "$output_file"
    echo "Latest version: $latest_keycloak_version" >> "$output_file"
    
    if [[ -n "$current_keycloak_version" && -n "$latest_keycloak_version" ]]; then
        needs_update "Keycloak" "$current_keycloak_version" "$latest_keycloak_version"
        if [[ $? -eq 0 ]]; then
            echo "Status: UPDATE RECOMMENDED" >> "$output_file"
        else
            echo "Status: Up to date" >> "$output_file"
        fi
    else
        echo "Status: Cannot determine" >> "$output_file"
    fi
    echo "" >> "$output_file"
    
    # Find other components with version information
    local components_dir="${REPO_ROOT}/scripts/components"
    for install_script in $(find "$components_dir" -name "install_*.sh"); do
        local component_name=$(basename "$install_script" | sed 's/install_//;s/\.sh//')
        local version_var=$(grep -o '[A-Z_]\+_VERSION="[^"]*"' "$install_script" | head -1)
        
        if [[ -n "$version_var" ]]; then
            local var_name=${version_var%%=*}
            local current_version=${version_var#*=\"}
            current_version=${current_version%\"}
            
            echo "## $component_name" >> "$output_file"
            echo "Current version: $current_version" >> "$output_file"
            
            if [[ "$current_version" == "latest" ]]; then
                echo "Status: Using 'latest' tag (not recommended for production)" >> "$output_file"
            else
                echo "Status: Version pinned" >> "$output_file"
            fi
            echo "" >> "$output_file"
        fi
    done
    
    log_success "Scan complete! Results saved to: $output_file"
    return 0
}

# Function to update a version reference in a file
update_version_in_file() {
    local file="$1"
    local var_name="$2"
    local new_version="$3"
    
    if [[ -f "$file" ]]; then
        sed -i "s/$var_name=\"[^\"]*\"/$var_name=\"$new_version\"/" "$file"
        return $?
    fi
    
    return 1
}

# Function to update a specific component version
update_component_version() {
    local component="$1"
    local new_version="$2"
    
    log_info "Updating $component to version $new_version..."
    
    local install_script="${REPO_ROOT}/scripts/components/install_${component}.sh"
    local var_name="${component^^}_VERSION"
    
    if [[ -f "$install_script" ]]; then
        if grep -q "$var_name" "$install_script"; then
            update_version_in_file "$install_script" "$var_name" "$new_version"
            log_success "Updated $component version to $new_version in $install_script"
            return 0
        else
            log_error "Could not find version variable $var_name in $install_script"
        fi
    else
        log_error "Installation script for $component not found"
    fi
    
    return 1
}

# Main function to display usage information
usage() {
    echo "Usage: $(basename "$0") [COMMAND] [OPTIONS]"
    echo ""
    echo "Commands:"
    echo "  scan                    Scan the repository for component versions"
    echo "  compare [VER1] [VER2]   Compare two semantic versions"
    echo "  update [COMPONENT] [VERSION]  Update a component to a specific version"
    echo "  latest [COMPONENT]      Get the latest version of a component"
    echo ""
    echo "Options:"
    echo "  --output-file FILE      Output file for scan results (default: version_scan_results.txt)"
    echo "  --help                  Display this help message"
    echo ""
    echo "Examples:"
    echo "  $(basename "$0") scan"
    echo "  $(basename "$0") compare 2.9.0 2.10.7"
    echo "  $(basename "$0") update traefik 2.10.7"
    echo "  $(basename "$0") latest nodejs"
}

# Main execution
main() {
    local command="$1"
    shift
    
    case "$command" in
        scan)
            local output_file="${REPO_ROOT}/version_scan_results.txt"
            while [[ $# -gt 0 ]]; do
                case "$1" in
                    --output-file)
                        output_file="$2"
                        shift 2
                        ;;
                    *)
                        echo "Unknown option: $1"
                        usage
                        exit 1
                        ;;
                esac
            done
            scan_repository_versions "$output_file"
            ;;
        compare)
            if [[ $# -ne 2 ]]; then
                echo "Error: compare command requires two version arguments"
                usage
                exit 1
            fi
            compare_versions "$1" "$2"
            local result=$?
            case $result in
                0) echo "Versions are equal: $1 = $2" ;;
                1) echo "First version is newer: $1 > $2" ;;
                2) echo "Second version is newer: $1 < $2" ;;
            esac
            ;;
        update)
            if [[ $# -ne 2 ]]; then
                echo "Error: update command requires component and version arguments"
                usage
                exit 1
            fi
            update_component_version "$1" "$2"
            ;;
        latest)
            if [[ $# -ne 1 ]]; then
                echo "Error: latest command requires a component argument"
                usage
                exit 1
            fi
            case "$1" in
                nodejs) 
                    get_latest_nodejs_lts
                    ;;
                traefik)
                    get_latest_github_version "traefik/traefik"
                    ;;
                keycloak)
                    get_latest_github_version "keycloak/keycloak"
                    ;;
                *)
                    echo "Unknown component: $1"
                    exit 1
                    ;;
            esac
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            echo "Unknown command: $command"
            usage
            exit 1
            ;;
    esac
    
    return $?
}

# Execute main function with all arguments if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ $# -eq 0 ]]; then
        usage
        exit 1
    fi
    
    main "$@"
fi
