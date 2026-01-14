#!/bin/bash
set -euo pipefail

# WordPress Cloning Service - EC2 Setup Script
# This script configures a fresh Amazon Linux 2023 instance with all dependencies

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   log_error "This script must be run as root (use sudo)"
   exit 1
fi

log_info "Starting WordPress Cloning Service EC2 setup..."

# ============================================
# 1. System Update
# ============================================
log_info "Updating system packages..."
dnf update -y

# ============================================
# 2. Install System Dependencies
# ============================================
log_info "Installing system dependencies..."
dnf install -y \
    wget \
    git \
    jq \
    unzip \
    tar \
    gzip \
    rsync \
    openssh-clients \
    cronie \
    mariadb105 || true  # Continue even if some packages fail

# Curl already installed (curl-minimal)

# ============================================
# 3. Install Docker Engine
# ============================================
log_info "Installing Docker Engine..."
dnf install -y docker

log_info "Starting Docker service..."
systemctl start docker
systemctl enable docker

# Verify Docker installation
if docker --version; then
    log_info "Docker installed successfully: $(docker --version)"
else
    log_error "Docker installation failed"
    exit 1
fi

# ============================================
# 4. Install Docker Compose v2
# ============================================
log_info "Installing Docker Compose v2..."
DOCKER_COMPOSE_VERSION="v2.24.5"
COMPOSE_PLUGIN_DIR="/usr/local/lib/docker/cli-plugins"

mkdir -p "$COMPOSE_PLUGIN_DIR"
curl -SL "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-linux-x86_64" \
    -o "$COMPOSE_PLUGIN_DIR/docker-compose"
chmod +x "$COMPOSE_PLUGIN_DIR/docker-compose"

# Create symlink for docker-compose command
ln -sf "$COMPOSE_PLUGIN_DIR/docker-compose" /usr/local/bin/docker-compose

# Verify Docker Compose installation
if docker compose version; then
    log_info "Docker Compose installed successfully: $(docker compose version)"
else
    log_error "Docker Compose installation failed"
    exit 1
fi

# ============================================
# 5. Configure Docker Daemon
# ============================================
log_info "Configuring Docker daemon..."
cat > /etc/docker/daemon.json <<'EOF'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2",
  "storage-opts": [
    "overlay2.override_kernel_check=true"
  ],
  "live-restore": true
}
EOF

log_info "Restarting Docker to apply configuration..."
systemctl restart docker

# ============================================
# 6. Install WP-CLI
# ============================================
log_info "Installing WP-CLI..."
curl -o /usr/local/bin/wp https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
chmod +x /usr/local/bin/wp

# Verify WP-CLI installation
if wp --version --allow-root; then
    log_info "WP-CLI installed successfully: $(wp --version --allow-root)"
else
    log_error "WP-CLI installation failed"
    exit 1
fi

# ============================================
# 7. Install AWS CLI v2
# ============================================
log_info "Installing AWS CLI v2..."
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
./aws/install --update
rm -rf aws awscliv2.zip

# Verify AWS CLI installation
if aws --version; then
    log_info "AWS CLI installed successfully: $(aws --version)"
else
    log_error "AWS CLI installation failed"
    exit 1
fi

# ============================================
# 8. Create Directory Structure
# ============================================
log_info "Creating directory structure..."
mkdir -p /opt/wordpress-cloning/{scripts,data,logs}
mkdir -p /opt/wordpress
mkdir -p /etc/nginx/templates

# Set ownership
chown -R ec2-user:ec2-user /opt/wordpress-cloning
chown -R ec2-user:ec2-user /opt/wordpress

log_info "Directory structure created:"
tree -L 2 /opt/wordpress-cloning 2>/dev/null || find /opt/wordpress-cloning -type d

# ============================================
# 9. Configure Log Rotation
# ============================================
log_info "Configuring log rotation for WordPress cloning service..."
cat > /etc/logrotate.d/wordpress-cloning <<'EOF'
/opt/wordpress-cloning/logs/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 0644 ec2-user ec2-user
}
EOF

# ============================================
# 10. Configure Firewall (if firewalld is running)
# ============================================
if systemctl is-active --quiet firewalld; then
    log_info "Configuring firewall rules..."
    firewall-cmd --permanent --add-service=http
    firewall-cmd --permanent --add-service=https
    firewall-cmd --reload
    log_info "Firewall rules configured"
else
    log_info "Firewalld not active, skipping firewall configuration"
fi

# ============================================
# 11. Create Service User (if needed)
# ============================================
log_info "Ensuring ec2-user has Docker access..."
usermod -aG docker ec2-user

# ============================================
# 12. System Limits
# ============================================
log_info "Configuring system limits..."
cat >> /etc/security/limits.conf <<'EOF'
# WordPress Cloning Service
ec2-user soft nofile 65536
ec2-user hard nofile 65536
ec2-user soft nproc 4096
ec2-user hard nproc 4096
EOF

# ============================================
# 13. Install Nginx
# ============================================
log_info "Installing Nginx..."
dnf install -y nginx

log_info "Starting Nginx service..."
systemctl start nginx
systemctl enable nginx

# Verify Nginx installation
if nginx -v; then
    log_info "Nginx installed successfully"
else
    log_error "Nginx installation failed"
    exit 1
fi

# ============================================
# 14. Create Status Check Script
# ============================================
log_info "Creating status check script..."
cat > /opt/wordpress-cloning/scripts/check-status.sh <<'EOF'
#!/bin/bash
echo "=== WordPress Cloning Service Status ==="
echo ""
echo "Docker:"
docker --version
echo ""
echo "Docker Compose:"
docker compose version
echo ""
echo "WP-CLI:"
wp --version --allow-root
echo ""
echo "AWS CLI:"
aws --version
echo ""
echo "Nginx:"
nginx -v
echo ""
echo "Running Containers:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
echo ""
echo "Disk Usage:"
df -h /opt/wordpress
echo ""
echo "Memory Usage:"
free -h
EOF

chmod +x /opt/wordpress-cloning/scripts/check-status.sh
chown ec2-user:ec2-user /opt/wordpress-cloning/scripts/check-status.sh

# ============================================
# 15. Completion
# ============================================
log_info "✓ EC2 setup complete!"
echo ""
log_info "Summary:"
echo "  - Docker Engine: $(docker --version)"
echo "  - Docker Compose: $(docker compose version | head -1)"
echo "  - WP-CLI: $(wp --version --allow-root)"
echo "  - AWS CLI: $(aws --version | cut -d' ' -f1)"
echo "  - Nginx: $(nginx -v 2>&1 | cut -d'/' -f2)"
echo ""
log_info "Next steps:"
echo "  1. Upload Docker Compose configuration to /opt/wordpress-cloning/"
echo "  2. Upload Nginx configuration to /etc/nginx/"
echo "  3. Upload cloning scripts to /opt/wordpress-cloning/scripts/"
echo "  4. Run: docker compose up -d"
echo ""
log_info "Status check: /opt/wordpress-cloning/scripts/check-status.sh"
