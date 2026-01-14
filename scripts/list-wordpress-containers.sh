#!/bin/bash
set -euo pipefail

# List all WordPress cloning containers
# Usage: ./list-wordpress-containers.sh

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=========================================="
echo "WordPress Cloning Service - Containers"
echo "=========================================="
echo ""

# Get all WordPress containers
CONTAINERS=$(docker ps -a --filter "label=managed-by=wordpress-cloning-service" --format '{{.Names}}' | sort)

if [[ -z "$CONTAINERS" ]]; then
    echo "No WordPress clone containers found"
    exit 0
fi

echo -e "${GREEN}Found $(echo "$CONTAINERS" | wc -l) container(s)${NC}"
echo ""

# Print table header
printf "%-20s %-15s %-30s %-40s\n" "CLIENT" "STATUS" "SUBDOMAIN" "SOURCE"
printf "%-20s %-15s %-30s %-40s\n" "--------------------" "---------------" "------------------------------" "----------------------------------------"

for container in $CONTAINERS; do
    # Get container info
    STATUS=$(docker inspect --format='{{.State.Status}}' "$container" 2>/dev/null || echo "unknown")
    CLIENT=$(docker inspect --format='{{index .Config.Labels "client"}}' "$container" 2>/dev/null || echo "unknown")
    SOURCE=$(docker inspect --format='{{index .Config.Labels "source"}}' "$container" 2>/dev/null || echo "unknown")
    SUBDOMAIN="${CLIENT}.toctoc.com.au"
    
    # Color status
    if [[ "$STATUS" == "running" ]]; then
        STATUS_COLOR="${GREEN}${STATUS}${NC}"
    else
        STATUS_COLOR="${YELLOW}${STATUS}${NC}"
    fi
    
    printf "%-20s %-24s %-30s %-40s\n" "$CLIENT" "$STATUS_COLOR" "$SUBDOMAIN" "$SOURCE"
done

echo ""
echo "=========================================="
echo "Container Details"
echo "=========================================="
docker ps -a --filter "label=managed-by=wordpress-cloning-service" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "=========================================="
echo "Nginx Virtual Hosts"
echo "=========================================="
docker exec nginx-proxy ls -1 /etc/nginx/conf.d/ 2>/dev/null | grep -v default.conf || echo "None configured"
