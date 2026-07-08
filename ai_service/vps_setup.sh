#!/bin/bash
################################################################################
# NumisTR AI Service - Complete VPS Setup Script
# OS: AlmaLinux 9.5 (Minimal Install)
# Target: Production-ready AI inference service
################################################################################

set -e  # Exit on error

echo "=================================="
echo "NumisTR AI Service VPS Setup"
echo "=================================="
echo ""

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Print functions
print_status() { echo -e "${GREEN}[✓]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[!]${NC} $1"; }
print_error() { echo -e "${RED}[✗]${NC} $1"; }

################################################################################
# 1. System Update & Essential Tools
################################################################################
echo -e "\n${GREEN}Step 1: System Update${NC}"
dnf update -y
print_status "System updated"

echo -e "\n${GREEN}Step 2: Installing Essential Tools${NC}"
dnf install -y \
    wget \
    curl \
    git \
    nano \
    vim \
    net-tools \
    bind-utils \
    tar \
    unzip \
    policycoreutils-python-utils \
    epel-release
print_status "Essential tools installed"

################################################################################
# 2. Firewall Configuration
################################################################################
echo -e "\n${GREEN}Step 3: Configuring Firewall${NC}"
dnf install -y firewalld
systemctl start firewalld
systemctl enable firewalld

# Allow HTTP/HTTPS
firewall-cmd --permanent --add-service=http
firewall-cmd --permanent --add-service=https

# Allow AI service port (will be behind Nginx)
firewall-cmd --permanent --add-port=8000/tcp

# SSH (should already be open, but ensure it)
firewall-cmd --permanent --add-service=ssh

# Reload firewall
firewall-cmd --reload
print_status "Firewall configured"

################################################################################
# 3. Docker Installation
################################################################################
echo -e "\n${GREEN}Step 4: Installing Docker${NC}"

# Remove old versions if any
dnf remove -y docker docker-client docker-client-latest docker-common \
    docker-latest docker-latest-logrotate docker-logrotate docker-engine

# Add Docker repo
dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

# Install Docker
dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Start Docker
systemctl start docker
systemctl enable docker

# Test Docker
docker run hello-world >/dev/null 2>&1
print_status "Docker installed and running"

################################################################################
# 4. Docker Compose Installation
################################################################################
echo -e "\n${GREEN}Step 5: Installing Docker Compose${NC}"

# Download latest Docker Compose
COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)
curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" \
    -o /usr/local/bin/docker-compose

# Make executable
chmod +x /usr/local/bin/docker-compose

# Verify
docker-compose version
print_status "Docker Compose installed"

################################################################################
# 5. Nginx Installation
################################################################################
echo -e "\n${GREEN}Step 6: Installing Nginx${NC}"

dnf install -y nginx
systemctl start nginx
systemctl enable nginx

print_status "Nginx installed and running"

################################################################################
# 6. Certbot (Let's Encrypt) Installation
################################################################################
echo -e "\n${GREEN}Step 7: Installing Certbot${NC}"

dnf install -y certbot python3-certbot-nginx

print_status "Certbot installed"

################################################################################
# 7. Python 3 (for utility scripts)
################################################################################
echo -e "\n${GREEN}Step 8: Installing Python 3${NC}"

dnf install -y python3 python3-pip python3-devel gcc

print_status "Python 3 installed"

################################################################################
# 8. Create Directory Structure
################################################################################
echo -e "\n${GREEN}Step 9: Creating Directory Structure${NC}"

mkdir -p /opt/ai_service/{models,index,logs,config,data}
mkdir -p /var/log/ai_service

print_status "Directory structure created"

################################################################################
# 9. SELinux Configuration
################################################################################
echo -e "\n${GREEN}Step 10: Configuring SELinux${NC}"

# Allow Nginx to connect to Docker
setsebool -P httpd_can_network_connect 1

# Allow Docker to bind to port 8000
semanage port -a -t http_port_t -p tcp 8000 2>/dev/null || \
    print_warning "SELinux port already configured or semanage not available"

print_status "SELinux configured"

################################################################################
# 10. Network Optimization
################################################################################
echo -e "\n${GREEN}Step 11: Network Optimization${NC}"

# Increase file descriptors
cat >> /etc/security/limits.conf <<EOF
* soft nofile 65536
* hard nofile 65536
EOF

# Kernel network tuning
cat >> /etc/sysctl.conf <<EOF
net.core.somaxconn = 1024
net.ipv4.tcp_max_syn_backlog = 2048
net.core.netdev_max_backlog = 2000
EOF

sysctl -p >/dev/null 2>&1
print_status "Network optimized"

################################################################################
# 11. Log Rotation Setup
################################################################################
echo -e "\n${GREEN}Step 12: Configuring Log Rotation${NC}"

cat > /etc/logrotate.d/ai_service <<EOF
/var/log/ai_service/*.log {
    daily
    rotate 14
    compress
    delaycompress
    notifempty
    create 0640 root root
    sharedscripts
    postrotate
        docker-compose -f /opt/ai_service/docker-compose.yml restart >/dev/null 2>&1 || true
    endscript
}
EOF

print_status "Log rotation configured"

################################################################################
# 12. Monitoring Tools
################################################################################
echo -e "\n${GREEN}Step 13: Installing Monitoring Tools${NC}"

dnf install -y htop iotop vnstat

# Start vnstat for bandwidth monitoring
systemctl start vnstat
systemctl enable vnstat

print_status "Monitoring tools installed"

################################################################################
# 13. Nginx Configuration Template
################################################################################
echo -e "\n${GREEN}Step 14: Creating Nginx Configuration${NC}"

cat > /etc/nginx/conf.d/ai.numistr.org.conf <<'EOF'
# Rate limiting
limit_req_zone $binary_remote_addr zone=ai_limit:10m rate=10r/s;

upstream ai_service {
    server localhost:8000;
}

server {
    listen 80;
    server_name ai.numistr.org;

    # Let's Encrypt ACME challenge
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }

    # Redirect to HTTPS (will be uncommented after SSL setup)
    # return 301 https://$host$request_uri;

    # Temporary proxy for testing (remove after SSL)
    location / {
        proxy_pass http://ai_service;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}

# HTTPS server (uncomment after SSL setup)
# server {
#     listen 443 ssl http2;
#     server_name ai.numistr.org;
#
#     ssl_certificate /etc/letsencrypt/live/ai.numistr.org/fullchain.pem;
#     ssl_certificate_key /etc/letsencrypt/live/ai.numistr.org/privkey.pem;
#
#     ssl_protocols TLSv1.2 TLSv1.3;
#     ssl_ciphers HIGH:!aNULL:!MD5;
#     ssl_prefer_server_ciphers on;
#
#     client_max_body_size 10M;
#
#     proxy_connect_timeout 60s;
#     proxy_send_timeout 60s;
#     proxy_read_timeout 60s;
#
#     location / {
#         limit_req zone=ai_limit burst=20 nodelay;
#
#         proxy_pass http://ai_service;
#         proxy_set_header Host $host;
#         proxy_set_header X-Real-IP $remote_addr;
#         proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
#         proxy_set_header X-Forwarded-Proto $scheme;
#     }
#
#     location /health {
#         proxy_pass http://ai_service;
#         access_log off;
#     }
# }
EOF

# Test Nginx config
nginx -t

# Reload Nginx
systemctl reload nginx

print_status "Nginx configured"

################################################################################
# 14. Docker Daemon Configuration
################################################################################
echo -e "\n${GREEN}Step 15: Configuring Docker${NC}"

mkdir -p /etc/docker

cat > /etc/docker/daemon.json <<EOF
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "3"
  },
  "storage-driver": "overlay2"
}
EOF

systemctl restart docker

print_status "Docker configured"

################################################################################
# Summary
################################################################################
echo ""
echo "=================================="
echo "Setup Complete!"
echo "=================================="
echo ""
echo "Installed Components:"
echo "  ✓ System tools and utilities"
echo "  ✓ Firewall (HTTP, HTTPS, 8000)"
echo "  ✓ Docker & Docker Compose"
echo "  ✓ Nginx web server"
echo "  ✓ Certbot (Let's Encrypt)"
echo "  ✓ Python 3"
echo "  ✓ Monitoring tools"
echo ""
echo "Directory Structure:"
echo "  /opt/ai_service/       - AI service files"
echo "  /var/log/ai_service/   - Application logs"
echo ""
echo "Next Steps:"
echo "  1. Setup DNS: ai.numistr.org → $(curl -s ifconfig.me)"
echo "  2. Copy AI service files to /opt/ai_service/"
echo "  3. Configure .env and database.yaml"
echo "  4. Run: certbot --nginx -d ai.numistr.org"
echo "  5. Uncomment HTTPS section in Nginx config"
echo "  6. Run: docker-compose up -d"
echo ""
echo "Useful Commands:"
echo "  docker-compose logs -f    - View logs"
echo "  systemctl status nginx    - Check Nginx"
echo "  firewall-cmd --list-all   - Check firewall"
echo "  htop                      - System monitor"
echo ""
print_status "VPS is ready for NumisTR AI Service!"
