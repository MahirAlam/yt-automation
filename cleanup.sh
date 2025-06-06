#!/bin/bash

echo "==================================================="
echo "     No-Code Architecture Stack Cleanup Script"
echo "==================================================="
echo

read -p "This will stop and remove all containers and volumes. Continue? (y/n): " CONFIRM

if [ "$CONFIRM" != "y" ]; then
    echo "Cleanup cancelled."
    exit 0
fi

echo
echo "Stopping containers..."

echo "Stopping Kokoro TTS..."
docker compose -f docker-compose.yml --project-name kokorotts stop kokorotts

echo "Stopping Workflows..."
docker compose -f docker-compose.yml --project-name workflows stop workflows

echo "Stopping NCA Toolkit..."
docker compose -f docker-compose.yml --project-name ncatoolkit stop ncatoolkit

echo "Stopping MinIO..."
docker compose -f docker-compose.yml --project-name minio stop minio

echo
echo "Removing containers..."
docker compose -f docker-compose.yml --project-name kokorotts rm -f kokorotts
docker compose -f docker-compose.yml --project-name workflows rm -f workflows
docker compose -f docker-compose.yml --project-name ncatoolkit rm -f ncatoolkit
docker compose -f docker-compose.yml --project-name minio rm -f minio

echo
read -p "Remove volumes? This will delete all data. (y/n): " REMOVE_VOLUMES

if [ "$REMOVE_VOLUMES" = "y" ]; then
    echo "Removing volumes..."
    docker volume rm n8n_data minio_data
    echo "Volumes removed."
fi

echo
read -p "Remove Docker network? (y/n): " REMOVE_NETWORK

if [ "$REMOVE_NETWORK" = "y" ]; then
    echo "Removing Docker network..."
    docker network rm app-network
    echo "Network removed."
fi

echo
echo "==================================================="
echo "Cleanup complete!"
echo "===================================================" 