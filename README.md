# SpaceNote Deployment

Production deployment configuration for SpaceNote application using Docker Compose.

## Project Repositories

- **Backend**: [spacenote-backend](https://github.com/spacenote-projects/spacenote-backend) - FastAPI backend service
- **Frontend**: [spacenote-frontend](https://github.com/spacenote-projects/spacenote-frontend) - React web application
- **Deploy**: [spacenote-deploy](https://github.com/spacenote-projects/spacenote-deploy) - Docker deployment configuration (this repository)

## Architecture

- **Traefik** - Reverse proxy with automatic SSL/TLS via Let's Encrypt
- **MongoDB** - Database backend
- **Backend** - Python FastAPI application
- **Frontend** - React application served by Nginx

## Prerequisites

- Docker & Docker Compose installed
- Domain name with DNS configured
- Access to server with ports 80 and 443 open

## Quick Start

### 1. Clone repository
```bash
git clone https://github.com/spacenote-projects/spacenote-deploy.git
cd spacenote-deploy
```

### 2. Configure environment
```bash
cp .env.example .env
nano .env
```

Update these values in `.env`:
- `DOMAIN` - Your domain (e.g., spacenote.com)
- `LETSENCRYPT_EMAIL` - Email for SSL certificates
- `MONGO_ROOT_PASSWORD` - Generate secure password
- `MONGO_PASSWORD` - Generate secure password
- `SESSION_SECRET_KEY` - Generate secure key (min 32 chars)

Generate secure passwords:
```bash
openssl rand -hex 32
```

### 3. Deploy
```bash
./deploy.sh
```

## Manual Deployment

### Build images locally
```bash
# Backend
cd ../spacenote-backend
docker build -t spacenote-backend:latest .

# Frontend
cd ../spacenote-frontend
docker build -t spacenote-frontend:latest \
  --build-arg VITE_API_URL=https://api.your-domain.com/api/v1 .
```

### Or use remote registry
Update `.env`:
```
BACKEND_IMAGE=your-registry/spacenote-backend:latest
FRONTEND_IMAGE=your-registry/spacenote-frontend:latest
```

### Start services
```bash
docker-compose up -d
```

## Management

### View logs
```bash
docker-compose logs -f            # All services
docker-compose logs -f backend    # Backend only
docker-compose logs -f frontend   # Frontend only
```

### Restart services
```bash
docker-compose restart backend
docker-compose restart frontend
```

### Stop all services
```bash
docker-compose down
```

### Update services
```bash
docker-compose pull
docker-compose up -d
```

### Database backup
```bash
docker exec spacenote-mongodb mongodump --out /backup
docker cp spacenote-mongodb:/backup ./backup-$(date +%Y%m%d)
```

### Database restore
```bash
docker cp ./backup spacenote-mongodb:/backup
docker exec spacenote-mongodb mongorestore /backup
```

## SSL/TLS Configuration

Traefik automatically obtains and renews Let's Encrypt certificates.

### Testing with staging certificates
Edit `traefik.yml` and uncomment:
```yaml
caServer: https://acme-staging-v02.api.letsencrypt.org/directory
```

### Force certificate renewal
```bash
docker-compose exec traefik rm /letsencrypt/acme.json
docker-compose restart traefik
```

## Monitoring

### Check service health
```bash
docker-compose ps
curl https://api.your-domain.com/health
```

### Traefik dashboard
Access at `https://traefik.your-domain.com` if enabled

## Troubleshooting

### Port already in use
```bash
sudo lsof -i :80
sudo lsof -i :443
```

### Certificate issues
1. Check DNS propagation: `nslookup your-domain.com`
2. Check Traefik logs: `docker-compose logs traefik`
3. Use staging certificates for testing

### MongoDB connection issues
```bash
docker exec -it spacenote-mongodb mongosh -u root -p
```

### Container networking
```bash
docker network ls
docker network inspect spacenote-deploy_spacenote-network
```

## Security Notes

1. Always use strong passwords in production
2. Keep `.env` file secure and never commit to git
3. Regularly update Docker images
4. Configure firewall to only allow necessary ports
5. Enable MongoDB authentication
6. Use HTTPS everywhere

## Directory Structure
```
spacenote-deploy/
├── docker-compose.yml    # Service orchestration
├── traefik.yml          # Traefik configuration
├── .env                 # Environment variables (not in git)
├── .env.example         # Example configuration
├── init-mongo.js        # MongoDB initialization
├── deploy.sh            # Deployment script
├── data/                # Persistent data (not in git)
│   ├── mongodb/         # MongoDB data
│   └── traefik/         # SSL certificates
└── README.md            # This file
```