#!/bin/bash

# Deploy Bitwarden (Vaultwarden)
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "Deploying Bitwarden (Vaultwarden)..."

# Check if env file exists
if [ ! -f $HOME/projects/secrets/bitwarden.env ]; then
    echo "Error: $HOME/projects/secrets/bitwarden.env not found."
    exit 1
fi

# Create data directory in centralized location
mkdir -p /home/administrator/projects/data/bitwarden

# Pull latest image
docker compose pull

# Stop and remove existing container
docker compose down

# Start the service
docker compose up -d

echo "Bitwarden deployed successfully!"
echo ""
echo "Access URLs:"
echo "  - Web Vault:  https://bitwarden.ai-servicers.com"
echo "  - Admin:      https://bitwarden.ai-servicers.com/admin"
echo ""
echo "Admin Token: See $HOME/projects/secrets/bitwarden.env"
echo ""
echo "Check logs with: docker compose logs -f"
