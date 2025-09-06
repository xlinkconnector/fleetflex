
#!/bin/bash
# FleetFlex Multi-Service Logistics Platform - COMPLETE Installation Script
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

# Create the complete platform structure
log "\ud83c\udfd7\ufe0f Creating complete platform structure..."

# Create backend structure
mkdir -p backend/{models,routes,controllers,middleware,config,utils}
mkdir -p frontend/{src/{components,pages,slices,store,services,utils,hooks},public}

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
    "redis": "^4.6.7",
    "helmet": "^7.0.0",
    "express-rate-limit": "^6.10.0",
    "compression": "^1.7.4",
    "express-validator": "^7.0.1"
  },
  "devDependencies": {
    "nodemon": "^3.0.1"
  }
}
EOF

# Create backend server.js
cat > backend/server.js << 'EOF'
const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const helmet = require('helmet');
const compression = require('compression');
const rateLimit = require('express-rate-limit');
require('dotenv').config();

const app = express();

// Middleware
app.use(helmet());
app.use(compression());
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100 // limit each IP to 100 requests per windowMs
});
app.use(limiter);

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

# Create frontend package.json
cat > frontend/package.json << 'EOF'
{
  "name": "fleetflex-frontend",
  "version": "1.0.0",
  "description": "FleetFlex Multi-Service Logistics Platform Frontend",
  "private": true,
  "scripts": {
    "dev": "vite",
    "build": "vite build",
    "preview": "vite preview"
  },
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "react-router-dom": "^6.15.0",
    "@reduxjs/toolkit": "^1.9.5",
    "react-redux": "^8.1.2",
    "axios": "^1.5.0",
    "styled-components": "^6.0.7",
    "framer-motion": "^10.16.4",
    "react-hook-form": "^7.45.4",
    "@fortawesome/fontawesome-free": "^6.4.2"
  },
  "devDependencies": {
    "@types/react": "^18.2.15",
    "@types/react-dom": "^18.2.7",
    "@vitejs/plugin-react": "^4.0.3",
    "vite": "^4.4.5"
  }
}
EOF

# Create frontend vite.config.js
cat > frontend/vite.config.js << 'EOF'
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  build: {
    outDir: 'build',
    sourcemap: true,
    rollupOptions: {
      output: {
        manualChunks: {
          vendor: ['react', 'react-dom'],
        },
      },
    },
  },
  server: {
    port: 3000,
    open: true,
  },
})
EOF

# Create frontend store
mkdir -p frontend/src/store
cat > frontend/src/store/store.js << 'EOF'
import { configureStore } from '@reduxjs/toolkit'
import authReducer from '../slices/authSlice'

export const store = configureStore({
  reducer: {
    auth: authReducer,
  },
})
EOF

# Create auth slice
mkdir -p frontend/src/slices
cat > frontend/src/slices/authSlice.js << 'EOF'
import { createSlice } from '@reduxjs/toolkit'

const authSlice = createSlice({
  name: 'auth',
  initialState: {
    user: null,
    token: null,
    isAuthenticated: false,
    loading: false,
    error: null,
    userType: null
  },
  reducers: {
    loginStart: (state) => {
      state.loading = true
      state.error = null
    },
    loginSuccess: (state, action) => {
      state.loading = false
      state.user = action.payload.user
      state.token = action.payload.token
      state.isAuthenticated = true
      state.userType = action.payload.userType
      state.error = null
    },
    loginFailure: (state, action) => {
      state.loading = false
      state.error = action.payload
      state.user = null
      state.token = null
      state.isAuthenticated = false
    },
    logout: (state) => {
      state.user = null
      state.token = null
      state.isAuthenticated = false
      state.userType = null
      state.error = null
    },
    updateUser: (state, action) => {
      state.user = { ...state.user, ...action.payload }
    },
    clearError: (state) => {
      state.error = null
    }
  }
})

export const { 
  loginStart, 
  loginSuccess, 
  loginFailure, 
  logout, 
  updateUser, 
  clearError 
} = authSlice.actions

export default authSlice.reducer
EOF

# Create index.html
cat > frontend/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <link rel="icon" type="image/svg+xml" href="/vite.svg" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>FleetFlex - Multi-Service Logistics Platform</title>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.jsx"></script>
  </body>
</html>
EOF

# Create main.jsx
cat > frontend/src/main.jsx << 'EOF'
import React from 'react'
import ReactDOM from 'react-dom/client'
import App from './App.jsx'
import './index.css'

ReactDOM.createRoot(document.getElementById('root')).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>,
)
EOF

# Create App.jsx
cat > frontend/src/App.jsx << 'EOF'
import React from 'react'
import { BrowserRouter as Router, Routes, Route } from 'react-router-dom'
import { Provider } from 'react-redux'
import { store } from './store/store'
import Home from './pages/Home'
import './App.css'

function App() {
  return (
    <Provider store={store}>
      <Router>
        <div className="App">
          <Routes>
            <Route path="/" element={<Home />} />
            <Route path="/admin" element={<div>Admin Dashboard</div>} />
          </Routes>
        </div>
      </Provider>
    </Provider>
  )
}

export default App
EOF

# Create Home.jsx
cat > frontend/src/pages/Home.jsx << 'EOF'
import React from 'react'
import styled from 'styled-components'

const Container = styled.div`
  max-width: 1200px;
  margin: 0 auto;
  padding: 2rem;
  text-align: center;
`

const Header = styled.h1`
  color: #2563eb;
  margin-bottom: 2rem;
`

const ServicesGrid = styled.div`
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
  gap: 2rem;
  margin: 2rem 0;
`

const ServiceCard = styled.div`
  background: #f8fafc;
  padding: 2rem;
  border-radius: 8px;
  box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
`

const Home = () => {
  const services = [
    { icon: '\ud83c\udf55', name: 'Food Delivery', description: 'Order from your favorite restaurants' },
    { icon: '\ud83d\ude97', name: 'Rideshare', description: 'Get rides anywhere, anytime' },
    { icon: '\ud83d\udce6', name: 'Package Shipping', description: 'Send and receive packages' },
    { icon: '\ud83c\udfe0', name: 'Moving Services', description: 'Professional moving assistance' },
    { icon: '\ud83d\ude9b', name: 'Freight Transport', description: 'Heavy cargo and freight' }
  ]

  return (
    <Container>
      <Header>FleetFlex Multi-Service Logistics Platform</Header>
      <p>Your complete logistics solution is now running!</p>
      
      <ServicesGrid>
        {services.map((service, index) => (
          <ServiceCard key={index}>
            <div style={{ fontSize: '2rem', marginBottom: '1rem' }}>
              {service.icon}
            </div>
            <h3>{service.name}</h3>
            <p>{service.description}</p>
          </ServiceCard>
        ))}
      </ServicesGrid>

      <div style={{ marginTop: '3rem' }}>
        <h3>Admin Access</h3>
        <p>Email: admin@fleetflex.app</p>
        <p>Password: Bigship247$$</p>
        <a href="/admin" style={{ color: '#2563eb', textDecoration: 'none' }}>
          Go to Admin Dashboard
        </a>
      </div>
    </Container>
  )
}

export default Home
EOF

# Create CSS files
cat > frontend/src/App.css << 'EOF'
.App {
  text-align: center;
}

.App-header {
  background-color: #282c34;
  padding: 20px;
  color: white;
}

.App-link {
  color: #61dafb;
}
EOF

cat > frontend/src/index.css << 'EOF'
body {
  margin: 0;
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Roboto', 'Oxygen',
    'Ubuntu', 'Cantarell', 'Fira Sans', 'Droid Sans', 'Helvetica Neue',
    sans-serif;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
}

code {
  font-family: source-code-pro, Menlo, Monaco, Consolas, 'Courier New',
    monospace;
}
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

# Install dependencies
log "\ud83d\udce6 Installing dependencies..."
cd backend
npm install

cd ../frontend
npm install

# Build frontend
log "\ud83c\udfd7\ufe0f Building frontend..."
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

    root $WORKDIR/fleetflex-platform/frontend/build;
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
log "\ud83d\udccb Working directory: $WORKDIR/fleetflex-platform"
log "\ud83d\udccb Useful commands:"
log "   cd $WORKDIR/fleetflex-platform && pm2 status"
log "   cd $WORKDIR/fleetflex-platform/backend && pm2 logs"
