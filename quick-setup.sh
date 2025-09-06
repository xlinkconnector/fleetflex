
#!/bin/bash
# Quick FleetFlex setup script for your current directory

echo "\ud83d\ude80 FleetFlex Quick Setup for Almalinux + Webuzo"

# Check if we're in fleetflex directory
if [ ! -d "backend" ] || [ ! -d "frontend" ]; then
    echo "\u274c Please run this from your fleetflex project directory"
    exit 1
fi

echo "\ud83d\udce6 Installing backend dependencies..."
cd backend && npm install

echo "\ud83d\udce6 Installing frontend dependencies..."
cd ../frontend && npm install

echo "\ud83c\udfd7\ufe0f Building frontend..."
npm run build

echo "\u2699\ufe0f Setting up backend..."
cd ../backend

# Create .env file if it doesn't exist
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
    echo "\u2705 Created .env file"
fi

echo "\ud83d\ude80 Starting backend..."
npm install -g pm2
pm2 start server.js --name "fleetflex-backend"
pm2 save

echo "\u2705 Setup complete!"
echo ""
echo "\ud83d\udccb Next steps:"
echo "1. Ensure MongoDB is running: systemctl status mongod"
echo "2. Ensure Redis is running: systemctl status redis"
echo "3. Check backend: pm2 status"
echo "4. Configure Nginx for Webuzo"
echo ""
echo "\ud83c\udf10 Platform will be available at: https://fleetflex.app"
echo "\ud83d\udd10 Admin login: admin@fleetflex.app / Bigship247$$"
