#!/bin/bash

# Gateway API Migration Helper Script
# This script helps convert Ingress resources to HTTPRoute resources

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APPS_DIR="$SCRIPT_DIR/clusters/sirius/apps"

print_usage() {
    echo "Usage: $0 [OPTIONS] <app-name>"
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  -d, --dry-run  Show what would be generated without writing files"
    echo "  -l, --list     List all apps with ingress resources"
    echo ""
    echo "Examples:"
    echo "  $0 --list                 # List all apps with ingress"
    echo "  $0 --dry-run plex         # Preview HTTPRoute for plex"
    echo "  $0 jellyfin               # Convert jellyfin ingress to HTTPRoute"
}

list_apps_with_ingress() {
    echo "Apps with ingress resources:"
    for app_dir in "$APPS_DIR"/*; do
        if [[ -d "$app_dir" && -f "$app_dir/ingress.yaml" ]]; then
            app_name=$(basename "$app_dir")
            echo "  - $app_name"
        fi
    done
}

generate_httproute() {
    local app_name="$1"
    local dry_run="$2"
    local app_dir="$APPS_DIR/$app_name"
    
    if [[ ! -d "$app_dir" ]]; then
        echo "Error: App directory '$app_dir' not found" >&2
        return 1
    fi
    
    if [[ ! -f "$app_dir/ingress.yaml" ]]; then
        echo "Error: No ingress.yaml found in '$app_dir'" >&2
        return 1
    fi
    
    echo "Processing $app_name..."
    
    # Extract ingress information (this is a simplified parser)
    local internal_host=$(grep -E "^\s*- host:" "$app_dir/ingress.yaml" | head -1 | awk '{print $3}' | grep "sirius.moonblade.work" || true)
    local external_host=$(grep -E "^\s*- host:" "$app_dir/ingress.yaml" | grep -v "sirius.moonblade.work" | head -1 | awk '{print $3}' || true)
    local service_name=$(grep -E "^\s*name:" "$app_dir/ingress.yaml" | grep -A5 "service:" | tail -1 | awk '{print $2}' || echo "$app_name")
    local service_port=$(grep -E "^\s*(number|name):" "$app_dir/ingress.yaml" | head -1 | awk '{print $2}' || echo "80")
    
    # Check if service.yaml exists to get correct port
    if [[ -f "$app_dir/service.yaml" ]]; then
        local actual_port=$(grep -E "^\s*port:" "$app_dir/service.yaml" | head -1 | awk '{print $2}' || echo "$service_port")
        service_port="$actual_port"
    fi
    
    local httproute_content="apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: ${app_name}-internal
  namespace: ${app_name}
spec:
  parentRefs:
  - name: sirius-gateway
    namespace: nginx-gateway
    sectionName: https
  hostnames:
  - ${internal_host}
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /
    backendRefs:
    - name: ${service_name}
      port: ${service_port}
      namespace: ${app_name}"

    if [[ -n "$external_host" ]]; then
        httproute_content="$httproute_content
---
# External HTTPS route for ${external_host}
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: ${app_name}-external-https
  namespace: ${app_name}
spec:
  parentRefs:
  - name: external-gateway
    namespace: nginx-gateway
    sectionName: https-external
  hostnames:
  - ${external_host}
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /
    backendRefs:
    - name: ${service_name}
      port: ${service_port}
      namespace: ${app_name}
---
# HTTP redirect for ${external_host}
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: ${app_name}-external-redirect
  namespace: ${app_name}
spec:
  parentRefs:
  - name: external-gateway
    namespace: nginx-gateway
    sectionName: http-external
  hostnames:
  - ${external_host}
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /
    filters:
    - type: RequestRedirect
      requestRedirect:
        scheme: https
        port: 8443"
    fi
    
    # Add any existing DNSEndpoint
    if grep -q "kind: DNSEndpoint" "$app_dir/ingress.yaml" 2>/dev/null; then
        echo "---" >> /tmp/dnsendpoint_section
        grep -A20 "kind: DNSEndpoint" "$app_dir/ingress.yaml" | sed '/^---$/,$d' >> /tmp/dnsendpoint_section
        httproute_content="$httproute_content
---
$(cat /tmp/dnsendpoint_section | tail -n +2)"
        rm -f /tmp/dnsendpoint_section
    fi
    
    if [[ "$dry_run" == "true" ]]; then
        echo "Generated HTTPRoute for $app_name:"
        echo "================================"
        echo "$httproute_content"
        echo ""
    else
        echo "$httproute_content" > "$app_dir/httproutes.yaml"
        echo "Created $app_dir/httproutes.yaml"
        
        # Update kustomization.yaml if it exists
        if [[ -f "$app_dir/kustomization.yaml" ]] && ! grep -q "httproutes.yaml" "$app_dir/kustomization.yaml"; then
            echo "  - ./httproutes.yaml" >> "$app_dir/kustomization.yaml"
            echo "Updated $app_dir/kustomization.yaml"
        fi
    fi
}

# Parse command line arguments
DRY_RUN=false
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            print_usage
            exit 0
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -l|--list)
            list_apps_with_ingress
            exit 0
            ;;
        -*)
            echo "Unknown option: $1" >&2
            print_usage
            exit 1
            ;;
        *)
            break
            ;;
    esac
done

if [[ $# -eq 0 ]]; then
    echo "Error: App name required" >&2
    print_usage
    exit 1
fi

APP_NAME="$1"
generate_httproute "$APP_NAME" "$DRY_RUN"