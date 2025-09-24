# SpaceNote Deployment

Production deployment configuration for SpaceNote application using Docker Compose.

## System Requirements

- Ubuntu 24.04 LTS (clean installation)
- Minimum 2GB RAM
- 10GB available disk space
- Domain name with DNS configured (A record pointing to server IP)
- Ports 80 and 443 open in firewall

## Architecture

- **Caddy** - Reverse proxy with automatic SSL/TLS (simpler than Traefik!)
- **MongoDB** - Database backend
- **Backend** - Python FastAPI application
- **Frontend** - React application served by Nginx

## Installation on Ubuntu 24.04

### 1. Install Docker

```bash
# Update package index
sudo apt update

# Install prerequisites
sudo apt install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# Add Docker's official GPG key
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Add Docker repository
echo \
  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine and Docker Compose plugin
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Add current user to docker group (optional, for running docker without sudo)
sudo usermod -aG docker $USER

# Apply group changes (or logout and login again)
newgrp docker

# Verify installation
docker --version
docker compose version
```

### 2. Prepare deployment directory

```bash
# Create project directory
mkdir -p ~/spacenote
cd ~/spacenote

# Download deployment files
curl -O https://raw.githubusercontent.com/spacenote-projects/spacenote-deploy/main/docker-compose.yml
curl -O https://raw.githubusercontent.com/spacenote-projects/spacenote-deploy/main/.env.example

# Or clone the entire repository
git clone https://github.com/spacenote-projects/spacenote-deploy.git
cd spacenote-deploy
```

### 3. Configure environment

```bash
# Copy example configuration
cp .env.example .env

# Edit configuration file
nano .env
```

Required configuration in `.env`:
```env
# Domain configuration
DOMAIN=your-domain.com             # Your domain without https://
EMAIL=admin@your-domain.com        # Optional: for Let's Encrypt notifications

# MongoDB configuration
MONGODB_ROOT_USERNAME=root         # Keep as root
MONGODB_ROOT_PASSWORD=<secure_password>  # Generate secure password

# Backend configuration
SESSION_SECRET_KEY=<secure_32_char_key>  # Minimum 32 characters

# Docker images (optional, use defaults for local builds)
BACKEND_IMAGE=spacenote-backend:latest
FRONTEND_IMAGE=spacenote-frontend:latest

# Debug mode
DEBUG=false
```

Generate secure passwords:
```bash
# For MongoDB password
openssl rand -hex 32

# For session secret key
openssl rand -hex 32
```

### 4. Create data directories

```bash
# Create directories for persistent data
mkdir -p data/mongodb
mkdir -p data/caddy/data
mkdir -p data/caddy/config
```

### 5. Build or pull Docker images

#### Option A: Using pre-built images

If you have access to a Docker registry with pre-built images:

```bash
# Update .env with your registry URLs
nano .env

# Add/modify these lines:
# BACKEND_IMAGE=your-registry/spacenote-backend:latest
# FRONTEND_IMAGE=your-registry/spacenote-frontend:latest

# Pull images
docker compose pull
```

#### Option B: Build images locally

If you have the source code:

```bash
# Clone backend repository
git clone https://github.com/spacenote-projects/spacenote-backend.git
cd spacenote-backend
docker build -t spacenote-backend:latest .
cd ..

# Clone frontend repository
git clone https://github.com/spacenote-projects/spacenote-frontend.git
cd spacenote-frontend

# Build frontend (API_URL will be set at runtime)
docker build -t spacenote-frontend:latest .
cd ..
```

### 6. Deploy application

```bash
# Start all services
docker compose up -d

# Check service status
docker compose ps

# View logs
docker compose logs -f
```

## Service URLs

After deployment, services will be available at:
- Frontend: `https://your-domain.com`
- API: `https://your-domain.com/api`

## Why Caddy?

We use Caddy instead of Traefik because:
- **Zero configuration for SSL** - Automatic HTTPS with no setup
- **No separate config files** - Everything in docker-compose.yml
- **Simpler syntax** - Minimal configuration needed
- **Automatic certificate management** - Works with Let's Encrypt and ZeroSSL
- **HTTP to HTTPS redirect** - Automatic, no configuration required

## Management Commands

### Service control
```bash
# Start services
docker compose up -d

# Stop services
docker compose down

# Restart specific service
docker compose restart backend
docker compose restart frontend
docker compose restart caddy

# View logs
docker compose logs -f            # All services
docker compose logs -f backend    # Specific service
docker compose logs --tail=100    # Last 100 lines
```

### Updates and maintenance
```bash
# Update images
docker compose pull
docker compose up -d

# Rebuild and restart
docker compose up -d --build

# Remove unused resources
docker system prune -a
```

### Database operations
```bash
# Backup database
docker exec spacenote-mongodb mongodump --out /backup
docker cp spacenote-mongodb:/backup ./backup-$(date +%Y%m%d)

# Restore database
docker cp ./backup spacenote-mongodb:/backup
docker exec spacenote-mongodb mongorestore /backup

# Access MongoDB shell
docker exec -it spacenote-mongodb mongosh -u root -p
```

## SSL/TLS Certificates

Caddy automatically manages certificates from Let's Encrypt or ZeroSSL.

### Certificate storage
Certificates are stored in `./data/caddy/` and are automatically renewed.

### Force certificate renewal
```bash
# Stop Caddy
docker compose stop caddy

# Remove certificates
rm -rf ./data/caddy/data/*
rm -rf ./data/caddy/config/*

# Restart Caddy
docker compose up -d caddy
```

### Using staging certificates for testing
To use Let's Encrypt staging certificates (for testing), modify the Caddy configuration in docker-compose.yml:
```yaml
command: >
  -c "echo '
  {
    email ${EMAIL:-}
    acme_ca https://acme-staging-v02.api.letsencrypt.org/directory
  }
  # ... rest of config
```

## Troubleshooting

### Check service health
```bash
# Service status
docker compose ps

# Test API endpoint
curl https://your-domain.com/api/v1/health

# Check container logs
docker compose logs caddy
docker compose logs backend
docker compose logs mongodb
```

### Common issues

#### Port conflicts
```bash
# Check what's using ports
sudo lsof -i :80
sudo lsof -i :443

# Stop conflicting service
sudo systemctl stop nginx  # Example
```

#### DNS issues
```bash
# Verify DNS resolution
nslookup your-domain.com
dig your-domain.com

# Check DNS propagation
curl https://dns.google/resolve?name=your-domain.com
```

#### Certificate problems
1. Ensure DNS is properly configured
2. Check Caddy logs: `docker compose logs caddy`
3. Verify ports 80/443 are accessible
4. Email is optional but recommended for renewal notifications

#### MongoDB connection errors
```bash
# Test MongoDB connectivity
docker exec -it spacenote-mongodb mongosh -u root -p

# Check MongoDB logs
docker compose logs mongodb
```

#### Container networking
```bash
# List networks
docker network ls

# Inspect network
docker network inspect spacenote_spacenote-network

# Test internal connectivity
docker compose exec backend ping mongodb
```

## Security Recommendations

1. **Firewall configuration**
   ```bash
   # Configure UFW firewall
   sudo ufw allow 22/tcp    # SSH
   sudo ufw allow 80/tcp    # HTTP
   sudo ufw allow 443/tcp   # HTTPS
   sudo ufw enable
   ```

2. **Secure passwords**
   - Use strong, unique passwords for all services
   - Store `.env` file securely
   - Never commit `.env` to version control

3. **Regular updates**
   ```bash
   # Update system packages
   sudo apt update && sudo apt upgrade

   # Update Docker images
   docker compose pull
   docker compose up -d
   ```

4. **Backup strategy**
   - Regular database backups
   - Store backups off-server
   - Test restore procedures

5. **Monitoring**
   - Set up log monitoring
   - Configure alerts for service failures
   - Monitor disk space and resource usage

## Directory Structure
```
spacenote-deploy/
├── docker-compose.yml    # Service orchestration with Caddy config
├── .env                 # Environment variables (create from .env.example)
├── .env.example         # Example configuration
├── data/                # Persistent data (created during setup)
│   ├── mongodb/         # MongoDB data files
│   └── caddy/          # SSL certificates and Caddy data
│       ├── data/
│       └── config/
└── README.md            # This file
```

## Configuration Simplicity

This deployment uses Caddy's inline configuration directly in docker-compose.yml:
- No separate web server configuration files
- All settings in one place
- Automatic SSL with minimal configuration
- Easy to understand and modify

## Support

For issues and questions:
- Backend: https://github.com/spacenote-projects/spacenote-backend/issues
- Frontend: https://github.com/spacenote-projects/spacenote-frontend/issues
- Deployment: https://github.com/spacenote-projects/spacenote-deploy/issues