
#!/bin/bash

# FleetFlex Multi-Service Logistics Platform Deployment Script for AlmaLinux
# This script will deploy the FleetFlex platform on AlmaLinux systems

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Define the installation directory
INSTALL_DIR="$(pwd)/fleetflex"

# Define Docker Compose command
DOCKER_COMPOSE="/usr/local/bin/docker-compose"

# Logging functions
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
}

warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

info() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

# Check system requirements
check_system_requirements() {
    log "Checking system requirements..."
    
    # Check CPU cores
    CPU_CORES=$(nproc)
    if [ "$CPU_CORES" -lt 2 ]; then
        warning "Your system has only $CPU_CORES CPU core. Minimum recommended is 2 cores."
    else
        info "CPU: $CPU_CORES cores - OK"
    fi
    
    # Check RAM
    TOTAL_RAM=$(free -m | awk '/^Mem:/{print $2}')
    if [ "$TOTAL_RAM" -lt 4000 ]; then
        warning "Your system has only $TOTAL_RAM MB RAM. Minimum recommended is 4GB."
    else
        info "RAM: $TOTAL_RAM MB - OK"
    fi
    
    # Check disk space
    FREE_DISK=$(df -h / | awk 'NR==2 {print $4}')
    info "Available disk space: $FREE_DISK"
    
    log "System requirements check completed."
}

# Function to install dependencies
install_dependencies() {
    log "Installing dependencies..."
    
    # Update package lists
    sudo dnf update -y
    
    # Install required packages
    sudo dnf install -y curl wget git tar unzip
    
    # Install Docker if not already installed
    if ! command -v docker &> /dev/null; then
        info "Installing Docker..."
        sudo dnf config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo
        sudo dnf install -y docker-ce docker-ce-cli containerd.io
        sudo systemctl start docker
        sudo systemctl enable docker
        sudo usermod -aG docker $USER
        info "Docker installed successfully. You may need to log out and back in for group changes to take effect."
    else
        info "Docker is already installed."
    fi
    
    # Install Docker Compose if not already installed
    if [ ! -f "$DOCKER_COMPOSE" ]; then
        info "Installing Docker Compose..."
        sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o "$DOCKER_COMPOSE"
        sudo chmod +x "$DOCKER_COMPOSE"
        info "Docker Compose installed successfully at $DOCKER_COMPOSE"
    else
        info "Docker Compose is already installed at $DOCKER_COMPOSE"
    fi
    
    # Verify Docker Compose installation
    if [ -f "$DOCKER_COMPOSE" ]; then
        info "Docker Compose version: $($DOCKER_COMPOSE --version)"
    else
        error "Docker Compose installation failed. Please install it manually."
        exit 1
    fi
    
    log "Dependencies installed successfully."
}

# Function to create project structure
create_project_structure() {
    log "Creating project structure..."
    
    # Create directories
    mkdir -p "$INSTALL_DIR"/{backend,frontend,mongodb}
    
    # Create docker-compose.yml
    cat > "$INSTALL_DIR/docker-compose.yml" << 'EOF'
version: '3.8'

services:
  # Backend API
  backend:
    image: node:18-alpine
    container_name: fleetflex-backend
    restart: unless-stopped
    ports:
      - "5000:5000"
    volumes:
      - ./backend:/app
      - /app/node_modules
    working_dir: /app
    command: sh -c "npm install && npm start"
    environment:
      - NODE_ENV=development
      - PORT=5000
      - MONGODB_URI=mongodb://mongodb:27017/fleetflex
    depends_on:
      - mongodb

  # Frontend Web App
  frontend:
    image: node:18-alpine
    container_name: fleetflex-frontend
    restart: unless-stopped
    ports:
      - "3000:3000"
    volumes:
      - ./frontend:/app
      - /app/node_modules
    working_dir: /app
    command: sh -c "npm install && npm start"
    environment:
      - REACT_APP_API_URL=http://localhost:5000
    depends_on:
      - backend

  # MongoDB Database
  mongodb:
    image: mongo:6.0
    container_name: fleetflex-mongodb
    restart: unless-stopped
    ports:
      - "27017:27017"
    volumes:
      - mongodb_data:/data/db

volumes:
  mongodb_data:
EOF
    
    # Create backend files
    cat > "$INSTALL_DIR/backend/package.json" << 'EOF'
{
  "name": "fleetflex-backend",
  "version": "1.0.0",
  "description": "FleetFlex Multi-Service Logistics Platform Backend",
  "main": "index.js",
  "scripts": {
    "start": "node index.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "mongoose": "^7.5.0",
    "cors": "^2.8.5",
    "dotenv": "^16.3.1",
    "jsonwebtoken": "^9.0.2",
    "bcryptjs": "^2.4.3"
  }
}
EOF
    
    cat > "$INSTALL_DIR/backend/index.js" << 'EOF'
const express = require('express');
const cors = require('cors');
const mongoose = require('mongoose');

const app = express();
const PORT = process.env.PORT || 5000;

// Middleware
app.use(cors());
app.use(express.json());

// Connect to MongoDB
mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/fleetflex')
  .then(() => console.log('MongoDB connected'))
  .catch(err => console.error('MongoDB connection error:', err));

// Define User Schema
const userSchema = new mongoose.Schema({
  name: String,
  email: String,
  role: String
});

const User = mongoose.model('User', userSchema);

// Routes
app.get('/', (req, res) => {
  res.send('FleetFlex API is running');
});

app.get('/health', (req, res) => {
  res.status(200).json({ status: 'ok', message: 'Service is healthy' });
});

app.get('/api/users', async (req, res) => {
  try {
    const users = await User.find();
    res.json(users);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// Seed initial data
const seedData = async () => {
  const count = await User.countDocuments();
  if (count === 0) {
    await User.create([
      { name: 'Admin User', email: 'admin@fleetflex.com', role: 'admin' },
      { name: 'Driver User', email: 'driver@fleetflex.com', role: 'driver' },
      { name: 'Customer User', email: 'customer@fleetflex.com', role: 'customer' }
    ]);
    console.log('Sample data seeded');
  }
};

// Start server
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
  seedData();
});
EOF
    
    # Create frontend files
    cat > "$INSTALL_DIR/frontend/package.json" << 'EOF'
{
  "name": "fleetflex-frontend",
  "version": "1.0.0",
  "description": "FleetFlex Multi-Service Logistics Platform Frontend",
  "scripts": {
    "start": "react-scripts start",
    "build": "react-scripts build"
  },
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "react-scripts": "5.0.1",
    "axios": "^1.4.0"
  },
  "browserslist": {
    "production": [
      ">0.2%",
      "not dead",
      "not op_mini all"
    ],
    "development": [
      "last 1 chrome version",
      "last 1 firefox version",
      "last 1 safari version"
    ]
  }
}
EOF
    
    mkdir -p "$INSTALL_DIR/frontend/src"
    cat > "$INSTALL_DIR/frontend/src/index.js" << 'EOF'
import React from 'react';
import ReactDOM from 'react-dom/client';
import App from './App';
import './index.css';

const root = ReactDOM.createRoot(document.getElementById('root'));
root.render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
EOF
    
    cat > "$INSTALL_DIR/frontend/src/App.js" << 'EOF'
import React, { useState, useEffect } from 'react';
import axios from 'axios';
import './App.css';

function App() {
  const [status, setStatus] = useState('Loading...');
  const [users, setUsers] = useState([]);

  useEffect(() => {
    // Check API health
    axios.get('http://localhost:5000/health')
      .then(response => setStatus(response.data.message))
      .catch(error => setStatus('Error connecting to API'));
    
    // Fetch users
    axios.get('http://localhost:5000/api/users')
      .then(response => setUsers(response.data))
      .catch(error => console.error('Error fetching users:', error));
  }, []);

  return (
    <div className="app">
      <header className="app-header">
        <h1>FleetFlex Platform</h1>
        <h2>Multi-Service Logistics Solution</h2>
        <p className="status">API Status: {status}</p>
      </header>
      
      <main className="app-main">
        <section className="users-section">
          <h3>Sample Users</h3>
          <div className="users-list">
            {users.map(user => (
              <div key={user._id} className="user-card">
                <h4>{user.name}</h4>
                <p>Email: {user.email}</p>
                <p>Role: {user.role}</p>
              </div>
            ))}
          </div>
        </section>
      </main>
      
      <footer className="app-footer">
        <p>&copy; 2025 FleetFlex. All rights reserved.</p>
      </footer>
    </div>
  );
}

export default App;
EOF
    
    cat > "$INSTALL_DIR/frontend/src/index.css" << 'EOF'
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
    
    cat > "$INSTALL_DIR/frontend/src/App.css" << 'EOF'
.app {
  text-align: center;
  max-width: 1200px;
  margin: 0 auto;
  padding: 20px;
}

.app-header {
  background-color: #282c34;
  padding: 20px;
  color: white;
  border-radius: 8px;
  margin-bottom: 20px;
}

.status {
  background-color: #444;
  padding: 10px;
  border-radius: 4px;
  display: inline-block;
}

.app-main {
  background-color: #f5f5f5;
  padding: 20px;
  border-radius: 8px;
  margin-bottom: 20px;
}

.users-section {
  margin-bottom: 20px;
}

.users-list {
  display: flex;
  flex-wrap: wrap;
  justify-content: center;
  gap: 20px;
}

.user-card {
  background-color: white;
  padding: 15px;
  border-radius: 8px;
  box-shadow: 0 2px 5px rgba(0,0,0,0.1);
  width: 250px;
}

.app-footer {
  background-color: #282c34;
  color: white;
  padding: 10px;
  border-radius: 8px;
}
EOF
    
    mkdir -p "$INSTALL_DIR/frontend/public"
    cat > "$INSTALL_DIR/frontend/public/index.html" << 'EOF'
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <meta name="theme-color" content="#000000" />
    <meta name="description" content="FleetFlex Multi-Service Logistics Platform" />
    <title>FleetFlex Platform</title>
  </head>
  <body>
    <noscript>You need to enable JavaScript to run this app.</noscript>
    <div id="root"></div>
  </body>
</html>
EOF
    
    # Create install script
    cat > "$INSTALL_DIR/install.sh" << EOF
#!/bin/bash

# FleetFlex Installation Script for AlmaLinux
set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "\${GREEN}Starting FleetFlex installation...${NC}"

# Check if Docker is running
if ! systemctl is-active --quiet docker; then
    echo -e "\${BLUE}Starting Docker service...${NC}"
    sudo systemctl start docker
fi

# Configure SELinux if it's enforcing
if [ "\$(getenforce)" == "Enforcing" ]; then
    echo -e "\${BLUE}Setting SELinux to permissive mode for Docker...${NC}"
    sudo setenforce 0
    echo -e "\${BLUE}For permanent change, edit /etc/selinux/config${NC}"
fi

# Configure firewall
echo -e "\${BLUE}Configuring firewall...${NC}"
sudo firewall-cmd --permanent --add-port=3000/tcp
sudo firewall-cmd --permanent --add-port=5000/tcp
sudo firewall-cmd --permanent --add-port=27017/tcp
sudo firewall-cmd --reload

# Start the services
echo -e "\${GREEN}Starting FleetFlex services...${NC}"
$DOCKER_COMPOSE up -d

echo -e "\${GREEN}FleetFlex installation completed!${NC}"
echo -e "\${BLUE}Frontend:${NC} http://localhost:3000"
echo -e "\${BLUE}Backend API:${NC} http://localhost:5000"
echo -e "\${BLUE}MongoDB:${NC} mongodb://localhost:27017/fleetflex"
EOF
    
    chmod +x "$INSTALL_DIR/install.sh"
    
    log "Project structure created successfully at $INSTALL_DIR"
}

# Function to configure firewall
configure_firewall() {
    log "Configuring firewall..."
    
    # Check if firewalld is installed and running
    if ! command -v firewall-cmd &> /dev/null; then
        info "Installing firewalld..."
        sudo dnf install -y firewalld
        sudo systemctl enable firewalld
        sudo systemctl start firewalld
    fi
    
    # Configure firewall rules
    sudo firewall-cmd --permanent --add-port=3000/tcp
    sudo firewall-cmd --permanent --add-port=5000/tcp
    sudo firewall-cmd --permanent --add-port=27017/tcp
    sudo firewall-cmd --reload
    
    info "Firewall configured successfully."
}

# Function to handle SELinux
configure_selinux() {
    log "Configuring SELinux..."
    
    # Check if SELinux is enforcing
    if [ "$(getenforce)" == "Enforcing" ]; then
        warning "SELinux is in enforcing mode. This might cause issues with Docker volumes."
        warning "Setting SELinux to permissive mode for Docker..."
        sudo setenforce 0
        
        # For a permanent change
        if [ -f "/etc/selinux/config" ]; then
            sudo sed -i 's/SELINUX=enforcing/SELINUX=permissive/g' /etc/selinux/config
            info "SELinux permanently set to permissive mode."
        fi
    else
        info "SELinux is not in enforcing mode. No changes needed."
    fi
}

# Function to deploy the application
deploy_application() {
    log "Deploying FleetFlex application..."
    
    # Navigate to project directory
    cd "$INSTALL_DIR"
    
    # Build and start services
    $DOCKER_COMPOSE up -d
    
    # Wait for services to start
    info "Waiting for services to start..."
    sleep 10
    
    # Check if services are running
    if [ "$(docker ps -q -f name=fleetflex-backend)" ]; then
        info "Backend service is running."
    else
        error "Backend service failed to start."
    fi
    
    if [ "$(docker ps -q -f name=fleetflex-frontend)" ]; then
        info "Frontend service is running."
    else
        error "Frontend service failed to start."
    fi
    
    if [ "$(docker ps -q -f name=fleetflex-mongodb)" ]; then
        info "MongoDB service is running."
    else
        error "MongoDB service failed to start."
    fi
    
    log "FleetFlex application deployed successfully."
}

# Function to display deployment summary
display_summary() {
    log "FleetFlex deployment completed successfully!"
    echo ""
    echo -e "${GREEN}=== FleetFlex Services ===${NC}"
    echo -e "${BLUE}Frontend:${NC} http://localhost:3000"
    echo -e "${BLUE}Backend API:${NC} http://localhost:5000"
    echo -e "${BLUE}MongoDB:${NC} mongodb://localhost:27017/fleetflex"
    echo ""
    echo -e "${GREEN}=== Management Commands ===${NC}"
    echo -e "${BLUE}Start services:${NC} cd $INSTALL_DIR && $DOCKER_COMPOSE up -d"
    echo -e "${BLUE}Stop services:${NC} cd $INSTALL_DIR && $DOCKER_COMPOSE down"
    echo -e "${BLUE}View logs:${NC} cd $INSTALL_DIR && $DOCKER_COMPOSE logs -f"
    echo -e "${BLUE}Restart a service:${NC} cd $INSTALL_DIR && $DOCKER_COMPOSE restart [service_name]"
    echo ""
    echo -e "${GREEN}Thank you for deploying FleetFlex!${NC}"
}

# Main function
main() {
    log "Starting FleetFlex deployment on AlmaLinux..."
    
    check_system_requirements
    install_dependencies
    create_project_structure
    configure_selinux
    configure_firewall
    deploy_application
    display_summary
}

# Run the main function
main "$@"
