
#!/bin/bash
# FleetFlex Platform Setup - Corrected for existing repository
# Run from your fleetflex directory

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date '+%H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[$(date '+%H:%M:%S')] ERROR: $1${NC}"
}

log "\ud83d\ude80 Setting up FleetFlex platform..."

# Check if we're in the right directory
if [ ! -f "package.json" ]; then
    error "Please run this script from your fleetflex project directory"
    exit 1
fi

# Install backend dependencies
log "\ud83d\udce6 Installing backend dependencies..."
cd backend
npm install

# Install frontend dependencies
log "\ud83d\udce6 Installing frontend dependencies..."
cd ../frontend
npm install

# Build frontend for production
log "\ud83c\udfd7\ufe0f Building frontend..."
npm run build

# Create backend environment
log "\u2699\ufe0f Creating backend environment..."
cd ../backend
if [ ! -f ".env" ]; then
    cat > .env << EOF
NODE_ENV=production
PORT=3001
MONGODB_URI=mongodb://localhost:27017/fleetflex
REDIS_URL=redis://localhost:6379
JWT_SECRET=fleetflex-secure-jwt-key-2024
JWT_EXPIRES_IN=90d
JWT_COOKIE_EXPIRES_IN=90
FRONTEND_URL=https://fleetflex.app
API_URL=https://fleetflex.app/api/v1
ADMIN_EMAIL=admin@fleetflex.app
ADMIN_PASSWORD=Bigship247\$\$
EOF
fi

# Start backend with PM2
log "\ud83d\ude80 Starting backend with PM2..."
pm2 start server.js --name "fleetflex-backend" || npm install -g pm2 && pm2 start server.js --name "fleetflex-backend"
pm2 save
pm2 startup

log "\u2705 FleetFlex setup complete!"
log "\ud83d\udccb Next steps:"
log "1. Ensure MongoDB is running: systemctl status mongod"
log "2. Ensure Redis is running: systemctl status redis"
log "3. Check backend: pm2 status"
log "4. Check frontend is built: ls -la frontend/build/"
log "5. Configure Nginx to serve frontend and proxy API"
