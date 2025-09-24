#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}SpaceNote Deployment Script${NC}"
echo "================================"

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
echo -e "\n${YELLOW}Checking prerequisites...${NC}"

if ! command_exists docker; then
    echo -e "${RED}Error: Docker is not installed${NC}"
    exit 1
fi

if ! command_exists docker-compose; then
    echo -e "${RED}Error: Docker Compose is not installed${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Docker and Docker Compose are installed${NC}"

# Check if .env file exists
if [ ! -f ".env" ]; then
    echo -e "${RED}Error: .env file not found${NC}"
    echo "Please copy .env.example to .env and configure it:"
    echo "  cp .env.example .env"
    exit 1
fi

# Load environment variables
source .env

# Validate critical environment variables
if [ "$DOMAIN" == "your-domain.com" ] || [ -z "$DOMAIN" ]; then
    echo -e "${RED}Error: Please set DOMAIN in .env file${NC}"
    exit 1
fi

if [ "$LETSENCRYPT_EMAIL" == "your-email@example.com" ] || [ -z "$LETSENCRYPT_EMAIL" ]; then
    echo -e "${RED}Error: Please set LETSENCRYPT_EMAIL in .env file${NC}"
    exit 1
fi

# Create necessary directories
echo -e "\n${YELLOW}Creating data directories...${NC}"
mkdir -p data/mongodb
mkdir -p data/traefik/certs
chmod 600 data/traefik/certs 2>/dev/null || true

# Build or pull images based on configuration
echo -e "\n${YELLOW}Preparing Docker images...${NC}"

# Check if we should build backend locally
if [ -z "$BACKEND_IMAGE" ] || [ "$BACKEND_IMAGE" == "spacenote-backend:latest" ]; then
    if [ -d "../spacenote-backend" ]; then
        echo "Building backend image from local repository..."
        (cd ../spacenote-backend && docker build -t spacenote-backend:latest .)
    else
        echo -e "${YELLOW}Warning: Backend repository not found at ../spacenote-backend${NC}"
        echo "Make sure spacenote-backend:latest image is available"
    fi
else
    echo "Pulling backend image: $BACKEND_IMAGE"
    docker pull "$BACKEND_IMAGE"
fi

# Check if we should build frontend locally
if [ -z "$FRONTEND_IMAGE" ] || [ "$FRONTEND_IMAGE" == "spacenote-frontend:latest" ]; then
    if [ -d "../spacenote-frontend" ]; then
        echo "Building frontend image from local repository..."
        (cd ../spacenote-frontend && docker build -t spacenote-frontend:latest \
            --build-arg VITE_API_URL=https://api.$DOMAIN/api/v1 .)
    else
        echo -e "${YELLOW}Warning: Frontend repository not found at ../spacenote-frontend${NC}"
        echo "Make sure spacenote-frontend:latest image is available"
    fi
else
    echo "Pulling frontend image: $FRONTEND_IMAGE"
    docker pull "$FRONTEND_IMAGE"
fi

# Deploy with docker-compose
echo -e "\n${YELLOW}Starting services...${NC}"

# Stop existing services if running
docker-compose down 2>/dev/null || true

# Start services
docker-compose up -d

# Wait for services to be ready
echo -e "\n${YELLOW}Waiting for services to start...${NC}"
sleep 10

# Check service status
echo -e "\n${YELLOW}Checking service status...${NC}"
docker-compose ps

# Show health status
echo -e "\n${YELLOW}Service health status:${NC}"
docker-compose ps | grep -E "healthy|unhealthy" || echo "Services are starting..."

# Display access URLs
echo -e "\n${GREEN}================================${NC}"
echo -e "${GREEN}Deployment completed!${NC}"
echo -e "${GREEN}================================${NC}"
echo -e "\nAccess your services at:"
echo -e "  Frontend: ${GREEN}https://$DOMAIN${NC}"
echo -e "  API:      ${GREEN}https://api.$DOMAIN${NC}"
echo -e "  Traefik:  ${GREEN}https://traefik.$DOMAIN${NC} (if enabled)"
echo ""
echo -e "Run '${YELLOW}docker-compose logs -f${NC}' to view logs"
echo -e "Run '${YELLOW}docker-compose down${NC}' to stop services"