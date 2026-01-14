#!/bin/bash
set -euo pipefail

# Delete WordPress Container
# Usage: ./delete-wordpress-container.sh <client_name>

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

# Validate arguments
if [[ $# -lt 1 ]]; then
    log_error "Usage: $0 <client_name>"
    echo "Example: $0 client-1"
    exit 1
fi

CLIENT_NAME="$1"
CONTAINER_NAME="wordpress-${CLIENT_NAME}"
VOLUME_NAME="${CONTAINER_NAME}-data"
SUBDOMAIN="${CLIENT_NAME}.toctoc.com.au"

log_warn "This will DELETE all data for: $CLIENT_NAME"
echo "Container: $CONTAINER_NAME"
echo "Volume: $VOLUME_NAME"
echo "Subdomain: $SUBDOMAIN"
echo ""
read -p "Are you sure? (type 'yes' to confirm): " CONFIRM

if [[ "$CONFIRM" != "yes" ]]; then
    log_info "Cancelled"
    exit 0
fi

# ============================================
# 1. Stop and remove container
# ============================================
log_info "Stopping container: $CONTAINER_NAME"
if docker ps -a --filter "name=$CONTAINER_NAME" --format '{{.Names}}' | grep -q "$CONTAINER_NAME"; then
    docker stop "$CONTAINER_NAME" || true
    docker rm "$CONTAINER_NAME"
    log_info "✓ Container removed"
else
    log_warn "Container not found: $CONTAINER_NAME"
fi

# ============================================
# 2. Remove Docker volume
# ============================================
log_info "Removing Docker volume: $VOLUME_NAME"
if docker volume inspect "$VOLUME_NAME" &>/dev/null; then
    docker volume rm "$VOLUME_NAME"
    log_info "✓ Volume removed"
else
    log_warn "Volume not found: $VOLUME_NAME"
fi

# ============================================
# 3. Remove Nginx configuration
# ============================================
log_info "Removing Nginx configuration..."
NGINX_CONF="/opt/wordpress-cloning/nginx/conf.d/${CLIENT_NAME}.conf"

# Remove from host
if [[ -f "$NGINX_CONF" ]]; then
    rm "$NGINX_CONF"
    log_info "✓ Nginx config removed from host"
fi

# Remove from nginx container
if docker exec nginx-proxy test -f /etc/nginx/conf.d/"${CLIENT_NAME}.conf" 2>/dev/null; then
    docker exec nginx-proxy rm -f /etc/nginx/conf.d/"${CLIENT_NAME}.conf"
    log_info "✓ Nginx config removed from container"
    
    # Reload nginx
    docker exec nginx-proxy nginx -s reload
    log_info "✓ Nginx reloaded"
fi

# ============================================
# 4. Remove metadata
# ============================================
METADATA_FILE="/opt/wordpress-cloning/data/${CLIENT_NAME}.json"
if [[ -f "$METADATA_FILE" ]]; then
    rm "$METADATA_FILE"
    log_info "✓ Metadata removed"
fi

# ============================================
# 5. Remove database (optional - commented out for safety)
# ============================================
log_warn "Database NOT removed (manual cleanup required)"
echo "To remove database, run:"
echo "  psql -h <rds-host> -U postgres -c 'DROP DATABASE wordpress_${CLIENT_NAME//-/_};'"

echo ""
log_info "=========================================="
log_info "WordPress Container Deleted Successfully"
log_info "=========================================="
echo "Client: $CLIENT_NAME"
echo "Container: $CONTAINER_NAME (removed)"
echo "Volume: $VOLUME_NAME (removed)"
echo "Subdomain: $SUBDOMAIN (no longer routed)"
