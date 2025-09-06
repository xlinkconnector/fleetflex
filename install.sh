
#!/bin/bash
# FleetFlex Multi-Service Logistics Platform - WORKING Installation Script
# Usage: curl -fsSL https://raw.githubusercontent.com/xlinkconnector/fleetflex/main/install.sh | sudo bash

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date '+%H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[$(date '+%H:%M:%S')] ERROR: $1${NC}"
}

# Check root
if [[ $EUID -ne 0 ]]; then
    error "This script must be run as root"
    exit 1
fi

WORKDIR="/opt/fleetflex"

log "\ud83d\ude80 Installing FleetFlex Multi-Service Logistics Platform..."

# Create and enter working directory
mkdir -p $WORKDIR
cd $WORKDIR

# Update system
log "\ud83d\udce6 Updating system packages..."
dnf update -y
dnf install -y wget curl git nano htop unzip tar gcc-c++ make

# Install Node.js 18.x
log "\ud83d\udce5 Installing Node.js..."
curl -fsSL https://rpm.nodesource.com/setup_18.x | bash -
dnf install -y nodejs

# Install MongoDB
log "\ud83d\uddc4\ufe0f Installing MongoDB..."
cat > /etc/yum.repos.d/mongodb-org-6.0.repo << EOF
[mongodb-org-6.0]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/redhat/\$releasever/mongodb-org/6.0/x86_64/
gpgcheck=1
enabled=1
gpgkey=https://www.mongodb.org/static/pgp/server-6.0.asc
EOF

dnf install -y mongodb-org
systemctl start mongod
systemctl enable mongod

# Install Redis
log "\ud83d\udd34 Installing Redis..."
dnf install -y redis
systemctl start redis
systemctl enable redis

# Install PM2
log "\u26a1 Installing PM2..."
npm install -g pm2

# Download and extract the platform
log "\ud83d\udce6 Downloading FleetFlex platform..."
curl -fsSL https://raw.githubusercontent.com/xlinkconnector/fleetflex/main/fleetflex.zip -o fleetflex.zip
unzip -o fleetflex.zip

# Find the actual platform directory
PLATFORM_DIR=$(find . -name "fleetflex-platform" -type d | head -1)
if [ -z "$PLATFORM_DIR" ]; then
    log "\ud83d\udcc1 Extracting platform files..."
    unzip -o fleetflex.zip
    PLATFORM_DIR="fleetflex-platform"
fi

# Navigate to platform directory
cd "$PLATFORM_DIR" || error "Could not find platform directory"

# Install backend dependencies
log "\ud83d\udd27 Installing backend dependencies..."
cd backend
npm install

# Create environment file
log "\u2699\ufe0f Creating environment configuration..."
cat > .env << EOF
NODE_ENV=production
PORT=3001
MONGODB_URI=mongodb://localhost:27017/fleetflex
REDIS_URL=redis://localhost:6379
JWT_SECRET=fleetflex-secure-jwt-key-2024-production
JWT_EXPIRES_IN=90d
JWT_COOKIE_EXPIRES_IN=90
FRONTEND_URL=https://fleetflex.app
API_URL=https://fleetflex.app/api/v1
ADMIN_EMAIL=admin@fleetflex.app
ADMIN_PASSWORD=Bigship247\$\$
EOF

# Install frontend dependencies and build
log "\ud83c\udfa8 Installing frontend dependencies..."
cd ../frontend
npm install
npm run build

# Start backend with PM2
log "\ud83d\ude80 Starting backend services..."
cd ../backend
pm2 start server.js --name "fleetflex-backend"
pm2 startup
pm2 save

# Configure Nginx
log "\ud83c\udf10 Configuring Nginx..."
cat > /etc/nginx/conf.d/fleetflex.conf << EOF
server {
    listen 80;
    server_name fleetflex.app www.fleetflex.app;
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name fleetflex.app www.fleetflex.app;

    root $WORKDIR/$PLATFORM_DIR/frontend/build;
    index index.html index.htm;

    ssl_certificate /etc/letsencrypt/live/fleetflex.app/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/fleetflex.app/privkey.pem;

    location / {
        try_files \$uri \$uri/ /index.html;
    }

    location /api {
        proxy_pass http://localhost:3001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }

    location /socket.io {
        proxy_pass http://localhost:3001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
    }
}
EOF

# Install SSL certificate
log "\ud83d\udd12 Installing SSL certificate..."
dnf install -y certbot python3-certbot-nginx
certbot --nginx -d fleetflex.app -d www.fleetflex.app --email admin@fleetflex.app --agree-tos --non-interactive

# Initialize database
log "\ud83d\uddc3\ufe0f Initializing database..."
mongo fleetflex --eval "db.createCollection('users')"
mongo fleetflex --eval "db.createCollection('drivers')"
mongo fleetflex --eval "db.createCollection('orders')"
mongo fleetflex --eval "db.createCollection('restaurants')"
mongo fleetflex --eval "db.createCollection('vehicles')"

# Restart services
log "\ud83d\udd04 Restarting services..."
systemctl restart nginx

# Final checks
log "\u2705 Running final checks..."
pm2 status
sleep 5
curl -f http://localhost:3001/api/v1/health || log "\u26a0\ufe0f Backend health check failed - check logs with 'pm2 logs'"

log ""
log "\ud83c\udf89 Installation complete!"
log "\ud83c\udf10 Your FleetFlex platform is live at: https://fleetflex.app"
log "\ud83d\udd10 Admin Panel: https://fleetflex.app/admin"
log "\ud83d\udce7 Login: admin@fleetflex.app / Bigship247$$"
log ""
log "\ud83d\udccb Working directory: $WORKDIR/$PLATFORM_DIR"
log "\ud83d\udccb Useful commands:"
log "   cd $WORKDIR/$PLATFORM_DIR && pm2 status"
log "   cd $WORKDIR/$PLATFORM_DIR/backend && pm2 logs"
