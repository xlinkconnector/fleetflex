
#!/bin/bash
# FleetFlex Final Setup - Run after unzipping to public_html

log() {
    echo -e "\033[0;32m[$(date '+%H:%M:%S')] $1\033[0m"
}

log "\ud83d\ude80 Setting up FleetFlex Multi-Service Logistics Platform..."

# Navigate to public_html
cd /home/fleetflex/public_html

# Check structure
log "\ud83d\udcc1 Checking current structure..."
ls -la

# Set proper permissions
log "\ud83d\udd10 Setting permissions..."
chown -R fleetflex:fleetflex /home/fleetflex/public_html
chmod -R 755 /home/fleetflex/public_html

# Setup backend
log "\ud83d\udd27 Setting up backend..."

# Create backend directory if not exists
mkdir -p backend

# Create backend package.json
cat > backend/package.json << 'EOF'
{
  "name": "fleetflex-backend",
  "version": "1.0.0",
  "description": "FleetFlex Multi-Service Logistics Platform Backend",
  "main": "server.js",
  "scripts": {
    "start": "node server.js",
    "dev": "nodemon server.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "mongoose": "^7.5.0",
    "cors": "^2.8.5",
    "dotenv": "^16.3.1",
    "bcryptjs": "^2.4.3",
    "jsonwebtoken": "^9.0.2",
    "multer": "^1.4.5-lts.1",
    "nodemailer": "^6.9.4",
    "stripe": "^13.3.0",
    "socket.io": "^4.7.2",
    "redis": "^4.6.7"
  }
}
EOF

# Create backend server.js
cat > backend/server.js << 'EOF'
const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
require('dotenv').config();

const app = express();

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Routes
app.get('/api/v1/health', (req, res) => {
  res.json({ status: 'OK', message: 'FleetFlex API is running' });
});

app.get('/api/v1', (req, res) => {
  res.json({ 
    message: 'FleetFlex Multi-Service Logistics Platform API',
    version: '1.0.0',
    services: ['Food Delivery', 'Rideshare', 'Package Shipping', 'Moving Services', 'Freight Transport']
  });
});

// Error handling
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({ error: 'Something went wrong!' });
});

const PORT = process.env.PORT || 3001;
app.listen(PORT, () => {
  console.log(`\ud83d\ude80 FleetFlex backend server running on port ${PORT}`);
});
EOF

# Create environment file
cat > backend/.env << EOF
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

# Install backend dependencies
log "\ud83d\udce6 Installing backend dependencies..."
cd backend
npm install

# Start backend with PM2
log "\ud83d\ude80 Starting backend services..."
npm install -g pm2
pm2 start server.js --name "fleetflex-backend"
pm2 startup
pm2 save

# Configure Nginx
log "\ud83c\udf10 Configuring Nginx..."

# Create nginx configuration
cat > /etc/nginx/conf.d/fleetflex.conf << EOF
server {
    listen 80;
    server_name fleetflex.app www.fleetflex.app;
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name fleetflex.app www.fleetflex.app;

    root /home/fleetflex/public_html;
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

# Restart services
log "\ud83d\udd04 Restarting services..."
systemctl restart nginx

# Final checks
log "\u2705 Running final checks..."
pm2 status
sleep 5
curl -f http://localhost:3001/api/v1/health || log "\u26a0\ufe0f Backend health check failed - check logs with 'pm2 logs'"

log "\ud83c\udf89 FleetFlex platform is now live!"
log "\ud83c\udf10 Access at: https://fleetflex.app"
log "\ud83d\udd10 Admin login: admin@fleetflex.app / Bigship247$$"
