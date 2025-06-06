@echo off
echo ===================================================
echo      No-Code Architecture Stack Restart Script
echo ===================================================

if "%~1"=="" (
    echo Please specify which service to restart:
    echo.
    echo Usage: restart.bat [service-name]
    echo.
    echo Available services:
    echo   all       - Restart all services
    echo   minio     - Restart MinIO S3
    echo   ncatoolkit - Restart NCA Toolkit
    echo   baserow   - Restart Baserow
    echo   workflows - Restart Workflows (n8n)
    echo   kokorotts - Restart Kokoro TTS
    echo.
    exit /b 1
)

if /i "%~1"=="all" (
    echo Restarting all services...
    
    echo.
    echo Stopping all services...
    docker compose down
    
    echo.
    echo Running setup to restart all services...
    call setup.bat
    
    echo.
    echo All services have been restarted.
    exit /b 0
)

echo.
echo Restarting %~1 service...

if /i "%~1"=="minio" (
    docker compose restart minio
    
    echo Waiting for MinIO to be healthy...
    set COUNTER=0
    
    :MINIO_WAIT_LOOP
    timeout /t 2 /nobreak > nul
    set /a COUNTER+=1
    docker ps --filter "name=minio" --filter "health=healthy" | findstr "minio" > nul
    
    if %ERRORLEVEL% NEQ 0 (
        echo Still waiting for MinIO to be ready...
        if %COUNTER% GEQ 15 (
            echo WARNING: MinIO health check taking longer than expected.
            echo Proceeding anyway, but services might not work correctly.
            goto MINIO_CONTINUE
        )
        goto MINIO_WAIT_LOOP
    )
    echo MinIO is healthy!
    
    :MINIO_CONTINUE
    echo.
    echo Recreating S3 bucket...
    .\mc.exe config host add myminio http://localhost:9000 admin password123 --api s3v4 --quiet
    .\mc.exe mb myminio/nca-toolkit --ignore-existing
    .\mc.exe anonymous set download myminio/nca-toolkit
) else (
    docker compose restart %~1
)

echo.
echo Service %~1 has been restarted.
echo Run status.bat to check service status.
echo =================================================== 