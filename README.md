# SpaceNote Deployment

Production deployment configuration for SpaceNote application using Docker Compose.

## System Requirements

- Ubuntu 24.04 LTS (clean installation)
- Minimum 2GB RAM
- 10GB available disk space
- Domain name with DNS configured (A record pointing to server IP)
- Ports 80 and 443 open in firewall

## Architecture

- **Caddy** - Reverse proxy with automatic SSL/TLS
- **MongoDB** - Database backend
- **Backend** - Python FastAPI application
- **Frontend** - React application served by serve package on port 4173

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
mkdir -p /apps/spacenote
cd /apps/spacenote

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
```

Generate secure passwords:
```bash
# For MongoDB password
openssl rand -hex 32

# For session secret key
openssl rand -hex 32
```

### 4. Deploy application

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

### Volume management
```bash
# List all volumes
docker volume ls

# Inspect a volume
docker volume inspect spacenote-deploy_mongodb_data
docker volume inspect spacenote-deploy_caddy_data
docker volume inspect spacenote-deploy_caddy_config

# Remove volumes (WARNING: This will delete all data!)
docker compose down -v

# Backup volumes directly
docker run --rm -v spacenote-deploy_mongodb_data:/source -v $(pwd):/backup alpine tar czf /backup/mongodb-backup-$(date +%Y%m%d).tar.gz -C /source .

# Restore volumes directly
docker run --rm -v spacenote-deploy_mongodb_data:/target -v $(pwd):/backup alpine tar xzf /backup/mongodb-backup.tar.gz -C /target
```

## SSL/TLS Certificates

Caddy automatically manages certificates from Let's Encrypt or ZeroSSL.

### Certificate storage
Certificates are stored in Docker volumes and are automatically renewed.

### Force certificate renewal
```bash
# Stop Caddy
docker compose stop caddy

# Remove certificate volumes
docker volume rm spacenote-deploy_caddy_data
docker volume rm spacenote-deploy_caddy_config

# Restart Caddy (volumes will be recreated)
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
└── README.md            # This file
```

## Data Storage

All persistent data is stored in Docker named volumes:
- `mongodb_data` - MongoDB database files
- `caddy_data` - Caddy certificates and data
- `caddy_config` - Caddy configuration

These volumes are managed by Docker and provide better permission handling than local directory mounts.
