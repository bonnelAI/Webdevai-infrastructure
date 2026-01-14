#!/bin/bash
set -euo pipefail

# Phase A Infrastructure Test Script
# Tests EC2 setup, Docker containers, and Nginx routing

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

TESTS_PASSED=0
TESTS_FAILED=0

test_pass() {
    echo -e "${GREEN}✓${NC} $1"
    ((TESTS_PASSED++))
}

test_fail() {
    echo -e "${RED}✗${NC} $1"
    ((TESTS_FAILED++))
}

test_warn() {
    echo -e "${YELLOW}!${NC} $1"
}

echo "=========================================="
echo "Phase A Infrastructure Tests"
echo "=========================================="
echo ""

# Test 1: Docker installed and running
echo "[1/10] Testing Docker..."
if docker --version &>/dev/null && systemctl is-active --quiet docker; then
    test_pass "Docker installed and running: $(docker --version)"
else
    test_fail "Docker not installed or not running"
fi

# Test 2: Docker Compose installed
echo "[2/10] Testing Docker Compose..."
if docker compose version &>/dev/null; then
    test_pass "Docker Compose installed: $(docker compose version | head -1)"
else
    test_fail "Docker Compose not installed"
fi

# Test 3: WP-CLI installed
echo "[3/10] Testing WP-CLI..."
if wp --version --allow-root &>/dev/null; then
    test_pass "WP-CLI installed: $(wp --version --allow-root)"
else
    test_fail "WP-CLI not installed"
fi

# Test 4: AWS CLI installed
echo "[4/10] Testing AWS CLI..."
if aws --version &>/dev/null; then
    test_pass "AWS CLI installed: $(aws --version | cut -d' ' -f1)"
else
    test_fail "AWS CLI not installed"
fi

# Test 5: Nginx installed
echo "[5/10] Testing Nginx..."
if systemctl is-active --quiet nginx 2>/dev/null || docker ps | grep -q nginx-proxy; then
    test_pass "Nginx running"
else
    test_warn "Nginx not running (expected if not started yet)"
fi

# Test 6: Directory structure
echo "[6/10] Testing directory structure..."
if [[ -d /opt/wordpress-cloning/scripts ]] && \
   [[ -d /opt/wordpress-cloning/data ]] && \
   [[ -d /opt/wordpress-cloning/logs ]] && \
   [[ -d /opt/wordpress ]]; then
    test_pass "Directory structure exists"
else
    test_fail "Directory structure incomplete"
fi

# Test 7: Docker containers (if started)
echo "[7/10] Testing Docker containers..."
RUNNING_CONTAINERS=$(docker ps --format '{{.Names}}' 2>/dev/null | wc -l)
if [[ $RUNNING_CONTAINERS -gt 0 ]]; then
    test_pass "Docker containers running: $RUNNING_CONTAINERS"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
else
    test_warn "No containers running (run: docker compose up -d)"
fi

# Test 8: WordPress container health
echo "[8/10] Testing WordPress containers..."
for i in {1..3}; do
    CONTAINER="wordpress-clone-$i"
    if docker ps --filter "name=$CONTAINER" --format '{{.Names}}' | grep -q "$CONTAINER"; then
        HEALTH=$(docker inspect --format='{{.State.Health.Status}}' "$CONTAINER" 2>/dev/null || echo "unknown")
        if [[ "$HEALTH" == "healthy" ]]; then
            test_pass "$CONTAINER is healthy"
        else
            test_warn "$CONTAINER status: $HEALTH"
        fi
    else
        test_warn "$CONTAINER not running"
    fi
done

# Test 9: Nginx proxy health
echo "[9/10] Testing Nginx proxy..."
if docker ps --filter "name=nginx-proxy" --format '{{.Names}}' | grep -q "nginx-proxy"; then
    if docker exec nginx-proxy nginx -t &>/dev/null; then
        test_pass "Nginx configuration valid"
    else
        test_fail "Nginx configuration invalid"
    fi
else
    test_warn "Nginx proxy not running"
fi

# Test 10: Network connectivity
echo "[10/10] Testing network..."
if docker network ls | grep -q "wordpress-cloning-network"; then
    test_pass "Docker network exists"
    
    # Test if containers can communicate
    if docker ps | grep -q nginx-proxy; then
        for i in {1..3}; do
            if docker exec nginx-proxy ping -c 1 "wordpress-$i" &>/dev/null; then
                test_pass "nginx-proxy can reach wordpress-$i"
            fi
        done
    fi
else
    test_warn "Docker network not created"
fi

echo ""
echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo -e "${GREEN}Passed:${NC} $TESTS_PASSED"
echo -e "${RED}Failed:${NC} $TESTS_FAILED"
echo ""

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "${GREEN}✓ All critical tests passed!${NC}"
    exit 0
else
    echo -e "${RED}✗ Some tests failed. Please review above.${NC}"
    exit 1
fi
