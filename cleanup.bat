@echo off
echo ===================================================
echo      No-Code Architecture Stack Cleanup Script
echo ===================================================

echo.
echo This script will stop and remove all containers and volumes.
echo.
set /p CONFIRM=Are you sure you want to proceed? (y/n): 

if /i "%CONFIRM%" NEQ "y" (
    echo.
    echo Cleanup cancelled.
    goto :EOF
)

echo.
echo Stopping all services...
docker compose -f docker-compose.yml down

echo.
echo Removing external volumes...
set /p REMOVE_VOLUMES=Do you want to remove all data volumes? This will DELETE ALL DATA (y/n): 

if /i "%REMOVE_VOLUMES%" EQU "y" (
    echo Removing volumes...
    docker volume rm baserow_data 2>nul || echo Failed to remove baserow_data volume. It may be in use or doesn't exist.
    docker volume rm n8n_data 2>nul || echo Failed to remove n8n_data volume. It may be in use or doesn't exist.
    docker volume rm minio_data 2>nul || echo Failed to remove minio_data volume. It may be in use or doesn't exist.
    echo Volumes removed.
) else (
    echo Volumes preserved.
)

echo.
echo Removing Docker network...
docker network rm app-network 2>nul || echo Failed to remove app-network. It may be in use or doesn't exist.

echo.
echo ===================================================
echo Cleanup complete!
echo =================================================== 