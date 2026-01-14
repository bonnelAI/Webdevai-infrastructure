#!/bin/bash
set -euo pipefail

# Create WordPress Container Dynamically
# Usage: ./create-wordpress-container.sh <client_name> <source_url> <db_credentials>

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

# Validate arguments
if [[ $# -lt 2 ]]; then
    log_error "Usage: $0 <client_name> <source_wordpress_url> [db_host] [db_user] [db_password] [db_name]"
    echo "Example: $0 client-1 https://example.com"
    exit 1
fi

CLIENT_NAME="$1"
SOURCE_URL="$2"
DB_HOST="${3:-}"
DB_USER="${4:-}"
DB_PASSWORD="${5:-}"
DB_NAME="${6:-wordpress_${CLIENT_NAME//-/_}}"

CONTAINER_NAME="wordpress-${CLIENT_NAME}"
SUBDOMAIN="${CLIENT_NAME}.toctoc.com.au"

log_info "Creating WordPress container for: $CLIENT_NAME"
log_info "Source: $SOURCE_URL"
log_info "Subdomain: $SUBDOMAIN"

# ============================================
# 1. Create Docker volume for persistent data
# ============================================
VOLUME_NAME="${CONTAINER_NAME}-data"
log_info "Creating Docker volume: $VOLUME_NAME"
if docker volume inspect "$VOLUME_NAME" &>/dev/null; then
    log_warn "Volume $VOLUME_NAME already exists, using existing volume"
else
    docker volume create "$VOLUME_NAME"
fi

# ============================================
# 2. Create WordPress container
# ============================================
log_info "Creating WordPress container: $CONTAINER_NAME"

# If DB credentials not provided, get from AWS Secrets Manager
if [[ -z "$DB_HOST" ]]; then
    log_info "Fetching DB credentials from AWS Secrets Manager..."
    SECRET_JSON=$(aws secretsmanager get-secret-value \
        --secret-id "wordpress/${CLIENT_NAME}" \
        --query SecretString \
        --output text 2>/dev/null || echo "{}")
    
    if [[ "$SECRET_JSON" != "{}" ]]; then
        DB_HOST=$(echo "$SECRET_JSON" | jq -r '.db_host // empty')
        DB_USER=$(echo "$SECRET_JSON" | jq -r '.db_user // empty')
        DB_PASSWORD=$(echo "$SECRET_JSON" | jq -r '.db_password // empty')
        DB_NAME=$(echo "$SECRET_JSON" | jq -r '.db_name // empty')
    fi
fi

# Create container (will populate from source later)
docker run -d \
    --name "$CONTAINER_NAME" \
    --network wordpress-cloning-network \
    --restart unless-stopped \
    -e WORDPRESS_DB_HOST="${DB_HOST:-localhost}" \
    -e WORDPRESS_DB_USER="${DB_USER:-wordpress}" \
    -e WORDPRESS_DB_PASSWORD="${DB_PASSWORD:-wordpress}" \
    -e WORDPRESS_DB_NAME="$DB_NAME" \
    -e WORDPRESS_TABLE_PREFIX="wp_" \
    -e WORDPRESS_DEBUG="false" \
    -v "${VOLUME_NAME}:/var/www/html" \
    --label "client=${CLIENT_NAME}" \
    --label "source=${SOURCE_URL}" \
    --label "managed-by=wordpress-cloning-service" \
    wordpress:6.4-apache

log_info "Container created: $CONTAINER_NAME"

# ============================================
# 3. Wait for container to be ready
# ============================================
log_info "Waiting for WordPress container to be ready..."
RETRY=0
MAX_RETRIES=30
while [[ $RETRY -lt $MAX_RETRIES ]]; do
    if docker exec "$CONTAINER_NAME" test -f /var/www/html/wp-config.php 2>/dev/null; then
        log_info "WordPress is ready"
        break
    fi
    sleep 2
    ((RETRY++))
done

if [[ $RETRY -eq $MAX_RETRIES ]]; then
    log_error "WordPress container failed to initialize"
    exit 1
fi

# ============================================
# 4. Create Nginx vhost configuration
# ============================================
log_info "Creating Nginx configuration for $SUBDOMAIN"
NGINX_CONF="/opt/wordpress-cloning/nginx/conf.d/${CLIENT_NAME}.conf"

cat > "$NGINX_CONF" <<EOF
# WordPress Clone: ${CLIENT_NAME}
# Source: ${SOURCE_URL}
# Created: $(date -u +"%Y-%m-%d %H:%M:%S UTC")

server {
    listen 80;
    server_name ${SUBDOMAIN};

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # Logging
    access_log /var/log/nginx/${CLIENT_NAME}-access.log;
    error_log /var/log/nginx/${CLIENT_NAME}-error.log;

    # Proxy settings
    location / {
        proxy_pass http://${CONTAINER_NAME};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # Timeouts
        proxy_connect_timeout 300s;
        proxy_send_timeout 300s;
        proxy_read_timeout 300s;
        
        # Buffer settings
        proxy_buffering on;
        proxy_buffer_size 4k;
        proxy_buffers 8 4k;
        proxy_busy_buffers_size 8k;
    }

    # Health check endpoint
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}
EOF

log_info "Nginx config created: $NGINX_CONF"

# ============================================
# 5. Copy config to Nginx container and reload
# ============================================
log_info "Copying Nginx config to nginx-proxy container..."
docker cp "$NGINX_CONF" nginx-proxy:/etc/nginx/conf.d/"${CLIENT_NAME}.conf"

log_info "Testing Nginx configuration..."
if docker exec nginx-proxy nginx -t; then
    log_info "Reloading Nginx..."
    docker exec nginx-proxy nginx -s reload
    log_info "✓ Nginx reloaded successfully"
else
    log_error "Nginx configuration test failed"
    # Rollback
    docker exec nginx-proxy rm -f /etc/nginx/conf.d/"${CLIENT_NAME}.conf"
    exit 1
fi

# ============================================
# 6. Save metadata
# ============================================
METADATA_FILE="/opt/wordpress-cloning/data/${CLIENT_NAME}.json"
cat > "$METADATA_FILE" <<EOF
{
  "client_name": "${CLIENT_NAME}",
  "subdomain": "${SUBDOMAIN}",
  "source_url": "${SOURCE_URL}",
  "container_name": "${CONTAINER_NAME}",
  "volume_name": "${VOLUME_NAME}",
  "db_name": "${DB_NAME}",
  "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "status": "container_created"
}
EOF

log_info "Metadata saved: $METADATA_FILE"

# ============================================
# 7. Output summary
# ============================================
echo ""
log_info "=========================================="
log_info "WordPress Container Created Successfully"
log_info "=========================================="
echo "Client: $CLIENT_NAME"
echo "Container: $CONTAINER_NAME"
echo "Subdomain: $SUBDOMAIN"
echo "Volume: $VOLUME_NAME"
echo "Source: $SOURCE_URL"
echo ""
log_info "Next steps:"
echo "  1. Clone WordPress content from source"
echo "  2. Import database and run wp search-replace"
echo "  3. Test at: http://$SUBDOMAIN"
echo ""
log_info "Container IP: $(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$CONTAINER_NAME")"
