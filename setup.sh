#!/bin/bash

echo "==================================================="
echo "     No-Code Architecture Stack Setup Script"
echo "==================================================="

echo "Creating environment file..."
if [ ! -f .env ]; then
    if [ -f env.tmp ]; then
        cp env.tmp .env
        echo "Environment file created."
    else
        echo "Error: env.tmp file not found."
        echo "Creating a basic .env file."
        cat > .env << EOL
# =============================================================================
# No-Code Architecture Stack Configuration
# =============================================================================

# -------------------------------------------------------------------------
# GLOBAL SETTINGS
# -------------------------------------------------------------------------
# Timezone for all services
TZ=UTC

# -------------------------------------------------------------------------
# STORAGE CONFIGURATION (MinIO)
# -------------------------------------------------------------------------
# MinIO admin credentials - CHANGE THESE IN PRODUCTION!
MINIO_ROOT_USER=admin
MINIO_ROOT_PASSWORD=password123
# S3 bucket and region settings
S3_BUCKET_NAME=nca-toolkit
S3_REGION=us-east-1

# -------------------------------------------------------------------------
# NCA TOOLKIT CONFIGURATION
# -------------------------------------------------------------------------
# API key for securing the NCA Toolkit API
NCA_API_KEY=the-api-key
# S3/MinIO access credentials for NCA Toolkit
S3_ACCESS_KEY=admin
S3_SECRET_KEY=password123

# -------------------------------------------------------------------------
# N8N CONFIGURATION
# -------------------------------------------------------------------------
# Path for n8n file storage
N8N_FILES_PATH=./n8n-files

# -------------------------------------------------------------------------
# RESOURCE LIMITS
# -------------------------------------------------------------------------
# Memory limits for each service
BASEROW_MEMORY_LIMIT=1G
N8N_MEMORY_LIMIT=4G
MINIO_MEMORY_LIMIT=512M
NCA_MEMORY_LIMIT=2G
KOKORO_MEMORY_LIMIT=2G
EOL
    fi
else
    echo "Environment file already exists."
fi

# Load environment variables from .env file
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
fi

echo
echo "Creating Docker network..."
docker network create --subnet 172.28.0.0/16 app-network 2>/dev/null || echo "Network already exists."

echo
echo "Creating external Docker volumes..."
echo "Creating n8n_data volume..."
docker volume create n8n_data 2>/dev/null || echo "n8n_data volume already exists."
echo "Creating minio_data volume..."
docker volume create minio_data 2>/dev/null || echo "minio_data volume already exists."
echo "External volumes created successfully."

echo
echo "Starting MinIO service..."
docker compose -f docker-compose.yml --project-name minio up -d minio
echo "Waiting for MinIO to be healthy..."

HEALTH_CHECK_COUNTER=0
MAX_ATTEMPTS=15

until docker ps --filter "name=minio" --filter "health=healthy" | grep -q "minio"; do
    HEALTH_CHECK_COUNTER=$((HEALTH_CHECK_COUNTER+1))
    echo "Still waiting for MinIO health check to pass... Attempt $HEALTH_CHECK_COUNTER"
    
    # Check if container is actually running
    docker ps --filter "name=minio" | grep -q "minio"
    if [ $? -ne 0 ]; then
        echo "ERROR: MinIO container is not running. Check logs with: docker logs minio"
        exit 1
    fi
    
    # Check if it's been too long
    if [ $HEALTH_CHECK_COUNTER -ge $MAX_ATTEMPTS ]; then
        echo
        echo "MinIO health check is taking longer than expected."
        read -p "Would you like to proceed with the setup anyway? (y/n): " PROCEED
        if [ "$PROCEED" != "y" ]; then
            echo
            echo "Setup cancelled. You can check MinIO logs with: docker logs minio"
            exit 1
        fi
        echo "Proceeding with setup as requested..."
        break
    fi
    
    sleep 2
done

if docker ps --filter "name=minio" --filter "health=healthy" | grep -q "minio"; then
    echo "MinIO is healthy!"
fi

echo
echo "Creating S3 bucket..."
# Check if mc is installed
if command -v mc > /dev/null; then
    MC_CMD="mc"
elif [ -f ./mc ]; then
    # If mc is in current directory, make it executable
    chmod +x ./mc
    MC_CMD="./mc"
else
    echo "MinIO client (mc) not found. Downloading..."
    curl -LO https://dl.min.io/client/mc/release/linux-amd64/mc
    chmod +x ./mc
    MC_CMD="./mc"
fi

$MC_CMD alias set myminio http://localhost:9000 admin password123
$MC_CMD mb myminio/nca-toolkit --ignore-existing
$MC_CMD anonymous set download myminio/nca-toolkit

echo
echo "Verifying S3 bucket..."
if ! $MC_CMD ls myminio/ | grep -q "nca-toolkit"; then
    echo "WARNING: Could not verify bucket creation. Services may not work correctly."
    echo "Trying one more time to create bucket..."
    $MC_CMD mb myminio/nca-toolkit --ignore-existing
    $MC_CMD anonymous set download myminio/nca-toolkit
else
    echo "S3 bucket verified successfully."
fi

echo
read -p "Start NCA Toolkit, Workflows, and Kokoro TTS? (y/n): " START_SERVICES
if [ "$START_SERVICES" != "y" ]; then
    echo
    echo "Setup paused. Only MinIO has been started."
    echo "You can complete the setup later by running this script again."
    exit 0
fi

echo
echo "Starting NCA Toolkit service..."
docker compose -f docker-compose.yml --project-name ncatoolkit up -d ncatoolkit --no-deps

echo
echo "Starting Workflows service..."
docker compose -f docker-compose.yml --project-name workflows up -d workflows --no-deps

echo
echo "Starting Kokoro TTS service..."
docker compose -f docker-compose.yml --project-name kokorotts up -d kokorotts --no-deps

echo
echo "==================================================="
echo "Setup complete! Services should now be available at:"
echo
echo "MinIO API: http://localhost:9000"
echo "MinIO Console: http://localhost:9001"
echo "NCA Toolkit: http://localhost:8080"
echo "Workflows (n8n): http://localhost:5678"
echo "Kokoro TTS: http://localhost:8880"
echo "==================================================="

echo
echo "NOTE: Services may take a few minutes to become healthy."
echo "You can check the status of all services with:"
echo "./status.sh"
echo 