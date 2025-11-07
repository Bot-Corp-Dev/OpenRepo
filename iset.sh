#!/bin/bash

# ============================================
# RelyBot VPS Automated Setup Script
# Installs ALL dependencies and configures the server
# ============================================

set -e  # Exit on any error

# ============================================
# CONFIGURATION - Edit these before running!
# ============================================
DOMAIN_NAME="rely.bot"                 # Your domain (lowercase for consistency)
APP_PORT=3000                          # Node.js app port (default: 3000)
ADMIN_EMAIL="admin@rely.bot"           # Email for SSL certificate notifications

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║          RelyBot VPS Automated Setup Script               ║"
echo "║                                                            ║"
echo "║  This script will install and configure:                  ║"
echo "║  • Node.js v22 LTS (Active until April 2027)               ║"
echo "║  • Redis 7.2+ (Latest Stable)                              ║"
echo "║  • PM2 Process Manager                                     ║"
echo "║  • Nginx Web Server + Reverse Proxy                        ║"
echo "║  • Certbot (SSL Certificates - Let's Encrypt)              ║"
echo "║  • SSH Key for GitHub (Auto-generated)                     ║"
echo "║                                                            ║"
echo "║  Note: MySQL Server NOT needed (using GoDaddy database)   ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Check if running as root
if [ "$EUID" -eq 0 ]; then 
    echo "❌ Please DO NOT run this script as root (don't use sudo)"
    echo "The script will ask for sudo password when needed."
    exit 1
fi

# ============================================
# Step 1: System Update
# ============================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 Step 1/9: Updating system packages..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
sudo apt update
sudo apt upgrade -y
echo "✅ System updated"
echo ""

# ============================================
# Step 2: Install Node.js 22.x LTS
# ============================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 Step 2/9: Installing Node.js v22 LTS (Latest)..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt install -y nodejs
echo "✅ Node.js installed: $(node --version)"
echo "✅ npm installed: $(npm --version)"
echo ""


# ============================================
# Step 3: Install Redis 7.2+ (Latest Stable)
# ============================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 Step 3/9: Installing Redis 7.2+ (Latest Stable)..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Add Redis official repository
curl -fsSL https://packages.redis.io/gpg | sudo gpg --dearmor -o /usr/share/keyrings/redis-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/redis-archive-keyring.gpg] https://packages.redis.io/deb $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/redis.list

# Update and install Redis
sudo apt update
sudo apt install -y redis

# Start Redis service
sudo systemctl start redis-server
sudo systemctl enable redis-server

# Test Redis
redis-cli ping > /dev/null && echo "✅ Redis 7.2+ installed and running (PONG received)" || echo "⚠️  Redis installed but not responding"
echo ""

# ============================================
# Step 4: Install PM2 Process Manager
# ============================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 Step 4/9: Installing PM2 Process Manager..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
sudo npm install -g pm2

echo "✅ PM2 installed: $(pm2 --version)"
echo ""

# Setup PM2 startup script
echo "Setting up PM2 to start on system boot..."
pm2 startup | grep "sudo" | bash
echo "✅ PM2 startup configured"
echo ""

# ============================================
# Step 5: Install Nginx
# ============================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 Step 5/9: Installing Nginx Web Server..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
sudo apt install -y nginx

# Start Nginx
sudo systemctl start nginx
sudo systemctl enable nginx

echo "✅ Nginx installed and running"
echo ""

# ============================================
# Step 6: Generate SSH Key for GitHub
# ============================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 Step 6/9: Generating SSH Key for GitHub..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Set SSH key identifier (change this to your preference)
SSH_KEY_LABEL="RelyBot-VPS"

# Create .ssh directory if it doesn't exist
mkdir -p ~/.ssh
chmod 700 ~/.ssh

# Generate SSH key (ED25519 is more secure than RSA)
if [ ! -f ~/.ssh/id_ed25519 ]; then
    ssh-keygen -t ed25519 -C "${SSH_KEY_LABEL}" -f ~/.ssh/id_ed25519 -N ""
    echo "✅ SSH key generated successfully"
else
    echo "⚠️  SSH key already exists, skipping generation"
fi

# Start SSH agent and add key
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519

echo ""
echo "✅ SSH key ready for GitHub"
echo ""

# ============================================
# Step 7: Install Certbot (SSL Certificates)
# ============================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 Step 7/9: Installing Certbot (Let's Encrypt SSL)..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Install Certbot and Nginx plugin
sudo apt install -y certbot python3-certbot-nginx

echo "✅ Certbot installed: $(certbot --version)"
echo ""

# ============================================
# Step 8: Configure Nginx Reverse Proxy
# ============================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 Step 8/9: Configuring Nginx Reverse Proxy..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Create Nginx configuration file
sudo tee /etc/nginx/sites-available/${DOMAIN_NAME} > /dev/null <<EOF
server {
    listen 80;
    server_name ${DOMAIN_NAME} www.${DOMAIN_NAME};

    # Increase client body size for file uploads
    client_max_body_size 50M;

    # Proxy settings
    location / {
        proxy_pass http://localhost:${APP_PORT};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        
        # WebSocket support
        proxy_read_timeout 86400;
    }
}
EOF

# Enable the site by creating a symbolic link
sudo ln -sf /etc/nginx/sites-available/${DOMAIN_NAME} /etc/nginx/sites-enabled/

# Remove default Nginx site
sudo rm -f /etc/nginx/sites-enabled/default

# Test Nginx configuration
sudo nginx -t

# Reload Nginx
sudo systemctl reload nginx

echo "✅ Nginx reverse proxy configured for ${DOMAIN_NAME}"
echo ""

# ============================================
# Step 9: Setup SSL Certificate
# ============================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 Step 9/9: Setting up SSL Certificate..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "⚠️  IMPORTANT: SSL Certificate Setup"
echo ""
echo "To enable HTTPS, you need to:"
echo ""
echo "1️⃣  Make sure your domain ${DOMAIN_NAME} points to this server's IP"
echo "   → Check with: dig ${DOMAIN_NAME} +short"
echo ""
echo "2️⃣  Run this command to get a FREE SSL certificate:"
echo "   sudo certbot --nginx -d ${DOMAIN_NAME} -d www.${DOMAIN_NAME} --non-interactive --agree-tos -m ${ADMIN_EMAIL}"
echo ""
echo "3️⃣  Certbot will automatically configure HTTPS and set up auto-renewal"
echo ""
echo "Note: SSL setup requires your domain to be pointing to this server!"
echo "      If not ready now, you can run the certbot command later."
echo ""

# ============================================
# Final Summary
# ============================================
echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║              ✅ INSTALLATION COMPLETE! ✅                   ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "📦 Installed Software (Latest Stable Versions):"
echo "   ✅ Node.js $(node --version) LTS (Maintained until April 2027)"
echo "   ✅ npm $(npm --version)"
echo "   ✅ Redis 7.2+ (Latest Stable)"
echo "   ✅ PM2 $(pm2 --version) (Latest)"
echo "   ✅ Nginx (Latest Stable) - Configured as reverse proxy"
echo "   ✅ Certbot - Ready for SSL certificates"
echo "   ✅ SSH Key for GitHub (Generated)"
echo ""
echo "📝 Database: Using GoDaddy MySQL (credentials in your .env file)"
echo "📝 Domain: ${DOMAIN_NAME} (configured for reverse proxy)"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 ADD THIS SSH KEY TO GITHUB:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
cat ~/.ssh/id_ed25519.pub
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "⚠️  IMPORTANT: Next Steps!"
echo ""
echo "1️⃣  Copy the SSH key above"
echo ""
echo "2️⃣  Add it to GitHub:"
echo "   → Go to: https://github.com/settings/keys"
echo "   → Click: 'New SSH key'"
echo "   → Paste the key above"
echo "   → Click: 'Add SSH key'"
echo ""
echo "3️⃣  Clone your repository:"
echo "   cd ~"
echo "   git clone git@github.com:Bot-Corp-Dev/RelyBot.git"
echo "   cd RelyBot"
echo ""
echo "4️⃣  Install npm dependencies:"
echo "   npm install"
echo ""
echo "5️⃣  Create your .env file:"
echo "   cp .env.example .env"
echo "   nano .env  # Edit with your actual credentials"
echo ""
echo "6️⃣  Start the application:"
echo "   npm run pm2:start"
echo ""
echo "7️⃣  Setup SSL certificate (after domain points to this server):"
echo "   sudo certbot --nginx -d ${DOMAIN_NAME} -d www.${DOMAIN_NAME} --non-interactive --agree-tos -m ${ADMIN_EMAIL}"
echo ""
echo "🎉 Your VPS is ready!"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🌐 Access your application at: http://${DOMAIN_NAME}"
echo "🔒 After SSL setup: https://${DOMAIN_NAME}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

