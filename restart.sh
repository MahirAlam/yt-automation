#!/bin/bash

if [ $# -eq 0 ]; then
    echo "Usage: ./restart.sh [service-name]"
    echo "Available services:"
    echo "  - minio"
    echo "  - ncatoolkit"
    echo "  - workflows"
    echo "  - kokorotts"
    echo "  - all (restarts all services)"
    exit 1
fi

SERVICE=$1

restart_service() {
    local service=$1
    local project_name=$2
    local container_name=$3
    
    echo "Restarting $service service..."
    
    if [ "$service" = "all" ]; then
        docker compose -f docker-compose.yml --project-name kokorotts stop kokorotts
        docker compose -f docker-compose.yml --project-name workflows stop workflows
        docker compose -f docker-compose.yml --project-name ncatoolkit stop ncatoolkit
        docker compose -f docker-compose.yml --project-name minio stop minio
        
        docker compose -f docker-compose.yml --project-name minio up -d minio
        
        # Wait for MinIO to be healthy
        echo "Waiting for MinIO to be healthy..."
        sleep 5
        
        docker compose -f docker-compose.yml --project-name ncatoolkit up -d ncatoolkit
        docker compose -f docker-compose.yml --project-name workflows up -d workflows
        docker compose -f docker-compose.yml --project-name kokorotts up -d kokorotts
        
        echo "All services restarted successfully!"
    else
        docker compose -f docker-compose.yml --project-name $project_name stop $container_name
        docker compose -f docker-compose.yml --project-name $project_name up -d $container_name
        
        echo "$service restarted successfully!"
    fi
}

case $SERVICE in
    minio)
        restart_service "MinIO" "minio" "minio"
        ;;
    ncatoolkit)
        restart_service "NCA Toolkit" "ncatoolkit" "ncatoolkit"
        ;;
    workflows)
        restart_service "Workflows" "workflows" "workflows"
        ;;
    kokorotts)
        restart_service "Kokoro TTS" "kokorotts" "kokorotts"
        ;;
    all)
        restart_service "all"
        ;;
    *)
        echo "Unknown service: $SERVICE"
        echo "Available services: minio, ncatoolkit, workflows, kokorotts, all"
        exit 1
        ;;
esac 