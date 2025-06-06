#!/bin/bash

echo "==================================================="
echo "            No-Code Architecture Stack"
echo "                Service Status Check"
echo "==================================================="
echo

# Function to check service status
check_service() {
    local container=$1
    local service_name=$2
    local url=$3
    
    # Check if container exists
    if docker ps -a --format '{{.Names}}' | grep -q "^${container}$"; then
        # Get container status
        local status=$(docker inspect --format='{{.State.Status}}' $container)
        local health=$(docker inspect --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}N/A{{end}}' $container 2>/dev/null)
        
        echo -n "$service_name: "
        
        # Determine status message and color
        if [ "$status" = "running" ]; then
            if [ "$health" = "healthy" ]; then
                echo -e "\033[32mRunning (Healthy)\033[0m"
                echo "   URL: $url"
            elif [ "$health" = "starting" ]; then
                echo -e "\033[33mStarting\033[0m"
                echo "   URL: $url"
            elif [ "$health" = "unhealthy" ]; then
                echo -e "\033[31mRunning (Unhealthy)\033[0m"
                echo "   URL: $url"
                echo "   ⚠️  Health checks failing. Check logs: docker logs $container"
            else
                echo -e "\033[32mRunning\033[0m"
                echo "   URL: $url"
            fi
        else
            echo -e "\033[31mNot Running (Status: $status)\033[0m"
            echo "   ⚠️  Container is not running. Start with: docker start $container"
        fi
    else
        echo -n "$service_name: "
        echo -e "\033[31mNot Found\033[0m"
        echo "   ⚠️  Container doesn't exist. Run setup script to create."
    fi
    echo
}

# Check status of each service
check_service "minio" "MinIO API" "http://localhost:9000"
check_service "minio" "MinIO Console" "http://localhost:9001"
check_service "ncatoolkit" "NCA Toolkit" "http://localhost:8080"
check_service "workflows" "Workflows (n8n)" "http://localhost:5678"
check_service "kokoro-tts-cpu" "Kokoro TTS" "http://localhost:8880"

echo "==================================================="
echo "Note: Services may take a few minutes to become healthy after starting."
echo "===================================================" 