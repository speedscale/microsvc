#!/bin/bash

# Version management script for the banking application
# This script handles version operations for all services

set -e

VERSION_FILE="VERSION"
REGISTRY="ghcr.io/speedscale/microsvc"
SERVICES=("user-service" "accounts-service" "transactions-service" "api-gateway" "frontend")

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
        ;;
esac
