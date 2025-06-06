@echo off
setlocal enabledelayedexpansion
echo ===================================================
echo      No-Code Architecture Stack Setup Script
echo ===================================================

echo Creating environment file...
if not exist .env (
    copy env.tmp .env
    echo Environment file created.
) else (
    echo Environment file already exists.
)

REM Load environment variables from .env file
if exist .env (
    for /F "tokens=1,* delims==" %%A in (.env) do (
        if not "%%A"=="" (
            if not "%%A:~0,1%"=="#" (
                set "%%A=%%B"
            )
        )
    )
)

echo.
echo Creating Docker network...
docker network create --subnet 172.28.0.0/16 app-network 2>nul || echo Network already exists.

echo.
echo Creating external Docker volumes...
@REM echo Creating baserow_data volume...
@REM docker volume create baserow_data 2>nul || echo baserow_data volume already exists.
echo Creating n8n_data volume...
docker volume create n8n_data 2>nul || echo n8n_data volume already exists.
echo Creating minio_data volume...
docker volume create minio_data 2>nul || echo minio_data volume already exists.
echo External volumes created successfully.

echo.
echo Starting MinIO service...
docker compose -f docker-compose.yml --project-name minio up -d minio
echo Waiting for MinIO to be healthy...

set "HEALTH_CHECK_COUNTER=0"
:HEALTH_CHECK_LOOP
timeout /t 2 /nobreak > nul
docker ps --filter "name=minio" --filter "health=healthy" | findstr "minio" > nul
if %ERRORLEVEL% NEQ 0 (
    set /a "HEALTH_CHECK_COUNTER=!HEALTH_CHECK_COUNTER!+1"
    echo Still waiting for MinIO health check to pass... Attempt !HEALTH_CHECK_COUNTER!
    
    REM Check if container is actually running
    docker ps --filter "name=minio" | findstr "minio" > nul
    if %ERRORLEVEL% NEQ 0 (
        echo ERROR: MinIO container is not running. Check logs with: docker logs minio
        exit /b 1
    )
    
    REM Check if it's been too long (20 seconds)
    if !HEALTH_CHECK_COUNTER! GEQ 10 (
        echo.
        echo MinIO health check is taking longer than expected.
        set /p PROCEED=Would you like to proceed with the setup anyway? (y/n): 
        if /i "!PROCEED!" NEQ "y" (
            echo.
            echo Setup cancelled. You can check MinIO logs with: docker logs minio
            exit /b 1
        )
        echo Proceeding with setup as requested...
        goto CONTINUE_SETUP
    )
    
    goto HEALTH_CHECK_LOOP
)
echo MinIO is healthy!

:CONTINUE_SETUP
echo.
echo Creating S3 bucket...
.\mc.exe config host add myminio http://localhost:9000 admin password123 --api s3v4
.\mc.exe mb myminio/nca-toolkit --ignore-existing
.\mc.exe anonymous set download myminio/nca-toolkit

echo.
echo Verifying S3 bucket...
.\mc.exe ls myminio/ | findstr "nca-toolkit" > nul
if %ERRORLEVEL% NEQ 0 (
    echo WARNING: Could not verify bucket creation. Services may not work correctly.
    echo Trying one more time to create bucket...
    .\mc.exe mb myminio/nca-toolkit --ignore-existing
    .\mc.exe anonymous set download myminio/nca-toolkit
) else (
    echo S3 bucket verified successfully.
)

echo.
echo Do you want to start the remaining services?
set /p START_SERVICES=Start NCA Toolkit, Baserow, Workflows, and Kokoro TTS? (y/n): 
if /i "!START_SERVICES!" NEQ "y" (
    echo.
    echo Setup paused. Only MinIO has been started.
    echo You can complete the setup later by running this script again.
    exit /b 0
)

echo.
echo Starting NCA Toolkit service...
docker compose -f docker-compose.yml --project-name ncatoolkit up -d ncatoolkit --no-deps

echo.
@REM echo Starting Baserow service...
@REM docker compose -f docker-compose.yml --project-name baserow up -d baserow --no-deps

echo.
echo Starting Workflows service...
docker compose -f docker-compose.yml --project-name workflows up -d workflows --no-deps

echo.
echo Starting Kokoro TTS service...
docker compose -f docker-compose.yml --project-name kokorotts up -d kokorotts --no-deps

echo.
echo ===================================================
echo Setup complete! Services should now be available at:
echo.
echo MinIO API: http://localhost:9000
echo MinIO Console: http://localhost:9001
echo NCA Toolkit: http://localhost:8080
@REM echo Baserow: http://localhost:8980
echo Workflows (n8n): http://localhost:5678
echo Kokoro TTS: http://localhost:8880
echo ===================================================

echo.
echo NOTE: Services may take a few minutes to become healthy.
echo You can check the status of all services with:
echo .\status.bat
echo. 
endlocal 