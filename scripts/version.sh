#!/bin/bash

# Version management script for the banking application
# This script handles version operations for all services

set -e

VERSION_FILE="VERSION"
REGISTRY="ghcr.io/speedscale/microsvc"
SERVICES=("user-service" "accounts-service" "transactions-service" "api-gateway" "frontend")
BACKEND_SERVICES=("user-service" "accounts-service" "transactions-service" "api-gateway")
FRONTEND_SERVICES=("frontend")
SIMULATION_SERVICES=("simulation-client")

# Get current version
get_version() {
    if [ -f "$VERSION_FILE" ]; then
        cat "$VERSION_FILE"
    else
        echo "0.0.0"
    fi
}

# Set version
set_version() {
    local version="$1"
    echo "$version" > "$VERSION_FILE"
    echo "Version set to: $version"
}

# Bump version (patch, minor, major)
bump_version() {
    local bump_type="$1"
    local current_version=$(get_version)
    local major minor patch
    
    IFS='.' read -r major minor patch <<< "$current_version"
    
    case "$bump_type" in
        "patch")
            patch=$((patch + 1))
            ;;
        "minor")
            minor=$((minor + 1))
            patch=0
            ;;
        "major")
            major=$((major + 1))
            minor=0
            patch=0
            ;;
        *)
            echo "Invalid bump type. Use: patch, minor, or major"
            exit 1
            ;;
    esac
    
    local new_version="$major.$minor.$patch"
    set_version "$new_version"
    echo "Version bumped to: $new_version"
}

# Get simple image tag (e.g., v1.2.3)
get_image_tag() {
    local version=$(get_version)
    echo "v${version}"
}

# Get image tag with Git SHA (e.g., v1.2.3-a1b2c3d)
get_image_tag_with_sha() {
    local version=$(get_version)
    local git_sha=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
    echo "v${version}-${git_sha}"
}

# Get full image name for a service
get_image_name() {
    local service="$1"
    # Use the tag with SHA by default for image names
    local tag=$(get_image_tag_with_sha)
    echo "${REGISTRY}/${service}:${tag}"
}

# Get latest image name for a service
get_latest_image_name() {
    local service="$1"
    echo "${REGISTRY}/${service}:latest"
}

# Update all project files with current version
update_all_versions() {
    local version=$(get_version)
    echo "Updating all project files with version: $version"
    
    # Update backend service pom.xml files
    for service in "${BACKEND_SERVICES[@]}"; do
        local pom_file="backend/${service}/pom.xml"
        if [ -f "$pom_file" ]; then
            # Update only the project version in pom.xml (after artifactId, before properties)
            sed -i.bak "/^[[:space:]]*<artifactId>${service}<\/artifactId>/,/^[[:space:]]*<properties>/ s|<version>[0-9]*\.[0-9]*\.[0-9]*</version>|<version>${version}</version>|" "$pom_file"
            echo "Updated $pom_file to version $version"
            rm -f "${pom_file}.bak"
        fi
    done
    
    # Update frontend package.json
    for service in "${FRONTEND_SERVICES[@]}"; do
        local package_file="${service}/package.json"
        if [ -f "$package_file" ]; then
            sed -i.bak "s|\"version\": \"[0-9]*\.[0-9]*\.[0-9]*\"|\"version\": \"${version}\"|" "$package_file"
            echo "Updated $package_file to version $version"
            rm -f "${package_file}.bak"
        fi
    done
    
    # Update simulation client package.json
    for service in "${SIMULATION_SERVICES[@]}"; do
        local package_file="${service}/package.json"
        if [ -f "$package_file" ]; then
            sed -i.bak "s|\"version\": \"[0-9]*\.[0-9]*\.[0-9]*\"|\"version\": \"${version}\"|" "$package_file"
            echo "Updated $package_file to version $version"
            rm -f "${package_file}.bak"
        fi
    done
}

# Validate that all versions are consistent
validate_versions() {
    local expected_version=$(get_version)
    local inconsistent_files=()
    
    echo "Validating version consistency (expected: $expected_version)..."
    
    # Check backend pom.xml files
    for service in "${BACKEND_SERVICES[@]}"; do
        local pom_file="backend/${service}/pom.xml"
        if [ -f "$pom_file" ]; then
            # Extract project version (first version tag after groupId/artifactId)
            local actual_version=$(grep -A 5 "<artifactId>${service}</artifactId>" "$pom_file" | grep "<version>" | head -1 | sed 's/.*<version>\(.*\)<\/version>.*/\1/' | tr -d ' ')
            if [ "$actual_version" != "$expected_version" ]; then
                inconsistent_files+=("$pom_file: $actual_version")
            fi
        fi
    done
    
    # Check frontend package.json
    for service in "${FRONTEND_SERVICES[@]}"; do
        local package_file="${service}/package.json"
        if [ -f "$package_file" ]; then
            local actual_version=$(grep '"version":' "$package_file" | sed 's/.*"version": "\([^"]*\)".*/\1/')
            if [ "$actual_version" != "$expected_version" ]; then
                inconsistent_files+=("$package_file: $actual_version")
            fi
        fi
    done
    
    # Check simulation client package.json
    for service in "${SIMULATION_SERVICES[@]}"; do
        local package_file="${service}/package.json"
        if [ -f "$package_file" ]; then
            local actual_version=$(grep '"version":' "$package_file" | sed 's/.*"version": "\([^"]*\)".*/\1/')
            if [ "$actual_version" != "$expected_version" ]; then
                inconsistent_files+=("$package_file: $actual_version")
            fi
        fi
    done
    
    if [ ${#inconsistent_files[@]} -eq 0 ]; then
        echo "✓ All versions are consistent with VERSION file ($expected_version)"
        return 0
    else
        echo "✗ Version inconsistencies found:"
        for file_info in "${inconsistent_files[@]}"; do
            echo "  $file_info (expected: $expected_version)"
        done
        return 1
    fi
}

# Update Kubernetes manifests with the simple version tag
update_k8s_manifests() {
    local tag=$(get_image_tag) # Explicitly use the simple tag
    local k8s_dir="kubernetes/base/deployments"
    
    echo "Updating Kubernetes manifests with version: $tag"
    
    # Update all deployment files
    for service in "${SERVICES[@]}"; do
        local deployment_file="$k8s_dir/${service}-deployment.yaml"
        if [ -f "$deployment_file" ]; then
            # Replace image references - handle latest, versioned tags, and old hash-based tags
            # Also handle short image names without registry prefix
            sed -i.bak "s|image: ${service}:latest|image: ${REGISTRY}/${service}:${tag}|g" "$deployment_file"
            sed -i.bak "s|${REGISTRY}/${service}:latest|${REGISTRY}/${service}:${tag}|g" "$deployment_file"
            sed -i.bak "s|${REGISTRY}/${service}:v[0-9]*\.[0-9]*\.[0-9]*-[a-f0-9]*|${REGISTRY}/${service}:${tag}|g" "$deployment_file"
            sed -i.bak "s|${REGISTRY}/${service}:v[0-9]*\.[0-9]*\.[0-9]*|${REGISTRY}/${service}:${tag}|g" "$deployment_file"
            rm -f "${deployment_file}.bak"
            echo "Updated $deployment_file"
        fi
    done
}

# Show version information
show_version_info() {
    local version=$(get_version)
    local simple_tag=$(get_image_tag)
    local sha_tag=$(get_image_tag_with_sha)
    
    echo "Current Version: $version"
    echo "Simple Image Tag: $simple_tag"
    echo "Image Tag with SHA: $sha_tag"
    echo ""
    echo "Service Images (using SHA tag):"
    for service in "${SERVICES[@]}"; do
        echo "  $service: $(get_image_name "$service")"
    done
}

# Main script logic
case "${1:-help}" in
    "get")
        get_version
        ;;
    "set")
        if [ -z "$2" ]; then
            echo "Usage: $0 set <version>"
            exit 1
        fi
        set_version "$2"
        ;;
    "bump")
        if [ -z "$2" ]; then
            echo "Usage: $0 bump <patch|minor|major>"
            exit 1
        fi
        bump_version "$2"
        ;;
    "tag")
        get_image_tag
        ;;
    "tag-sha")
        get_image_tag_with_sha
        ;;
    "image")
        if [ -z "$2" ]; then
            echo "Usage: $0 image <service-name>"
            exit 1
        fi
        get_image_name "$2"
        ;;
    "update-k8s")
        update_k8s_manifests
        ;;
    "update-all")
        update_all_versions
        ;;
    "validate")
        validate_versions
        ;;
    "sync")
        update_all_versions
        update_k8s_manifests
        ;;
    "info")
        show_version_info
        ;;
    "help"|*)
        echo "Version Management Script"
        echo ""
        echo "Usage: $0 <command> [args]"
        echo ""
        echo "Commands:"
        echo "  get                    - Get current version"
        echo "  set <version>          - Set version (e.g., 1.1.0)"
        echo "  bump <type>            - Bump version (patch|minor|major)"
        echo "  tag                    - Get simple image tag (e.g., v1.2.3)"
        echo "  tag-sha                - Get image tag with git hash (e.g., v1.2.3-a1b2c3d)"
        echo "  image <service>        - Get full image name for service with SHA"
        echo "  update-k8s             - Update Kubernetes manifests with simple version"
        echo "  update-all             - Update all project files (pom.xml, package.json) with current version"
        echo "  validate               - Validate that all project files have consistent versions"
        echo "  sync                   - Update all project files and Kubernetes manifests"
        echo "  info                   - Show version information"
        echo "  help                   - Show this help"
        echo ""
        echo "Examples:"
        echo "  $0 get                 # Get current version"
        echo "  $0 set 1.1.0           # Set version to 1.1.0"
        echo "  $0 bump patch          # Bump patch version"
        echo "  $0 tag                 # Get simple tag"
        echo "  $0 tag-sha             # Get tag with SHA"
        echo "  $0 image api-gateway   # Get image name for api-gateway"
        echo "  $0 update-k8s          # Update K8s manifests with simple version"
        echo "  $0 update-all          # Update all project files with current version"
        echo "  $0 validate            # Check version consistency"
        echo "  $0 sync                # Update all files and manifests"
        ;;
esac
