# No-Code Architecture Stack Setup Script
Write-Host "===================================================" -ForegroundColor Cyan
Write-Host "     No-Code Architecture Stack Setup Script" -ForegroundColor Cyan
Write-Host "===================================================" -ForegroundColor Cyan

# Create environment file
Write-Host "Creating environment file..." -ForegroundColor Yellow
if (-not (Test-Path -Path ".env")) {
    Copy-Item -Path "env.tmp" -Destination ".env"
    Write-Host "Environment file created." -ForegroundColor Green
} else {
    Write-Host "Environment file already exists." -ForegroundColor Green
}

# Load environment variables from .env file
if (Test-Path -Path ".env") {
    Get-Content ".env" | ForEach-Object {
        if (-not [string]::IsNullOrWhiteSpace($_)) {
            if (-not $_.StartsWith("#")) {
                $key, $value = $_ -split '=', 2
                [Environment]::SetEnvironmentVariable($key, $value)
            }
        }
    }
}

Write-Host ""
Write-Host "Creating Docker network..." -ForegroundColor Yellow
try {
    docker network create --subnet 172.28.0.0/16 app-network 2>$null
    Write-Host "Network created." -ForegroundColor Green
} catch {
    Write-Host "Network already exists." -ForegroundColor Green
}

Write-Host ""
Write-Host "Creating external Docker volumes..." -ForegroundColor Yellow
Write-Host "Creating baserow_data volume..." -ForegroundColor Yellow
docker volume create baserow_data 2>$null
Write-Host "Creating n8n_data volume..." -ForegroundColor Yellow
docker volume create n8n_data 2>$null
Write-Host "Creating minio_data volume..." -ForegroundColor Yellow
docker volume create minio_data 2>$null
Write-Host "External volumes created successfully." -ForegroundColor Green

Write-Host ""
Write-Host "Starting MinIO service..." -ForegroundColor Yellow
docker compose -f docker-compose.yml --project-name minio up -d minio
Write-Host "Waiting for MinIO to be healthy..." -ForegroundColor Yellow

$healthCheckCounter = 0
$maxAttempts = 15

do {
    Start-Sleep -Seconds 2
    $healthCheckCounter++
    Write-Host "Still waiting for MinIO health check to pass... Attempt $healthCheckCounter" -ForegroundColor Yellow
    
    # Check if container is actually running
    $containerRunning = docker ps --filter "name=minio" | Select-String -Pattern "minio"
    if (-not $containerRunning) {
        Write-Host "ERROR: MinIO container is not running. Check logs with: docker logs minio" -ForegroundColor Red
        exit 1
    }
    
    # Check if health is good
    $isHealthy = docker ps --filter "name=minio" --filter "health=healthy" | Select-String -Pattern "minio"
    
    # Check if it's been too long
    if ($healthCheckCounter -ge $maxAttempts -and -not $isHealthy) {
        Write-Host ""
        Write-Host "MinIO health check is taking longer than expected." -ForegroundColor Yellow
        $proceed = Read-Host "Would you like to proceed with the setup anyway? (y/n)"
        if ($proceed -ne "y") {
            Write-Host ""
            Write-Host "Setup cancelled. You can check MinIO logs with: docker logs minio" -ForegroundColor Red
            exit 1
        }
        Write-Host "Proceeding with setup as requested..." -ForegroundColor Yellow
        break
    }
} while (-not $isHealthy)

if ($isHealthy) {
    Write-Host "MinIO is healthy!" -ForegroundColor Green
}

Write-Host ""
Write-Host "Creating S3 bucket..." -ForegroundColor Yellow
.\mc.exe alias set myminio http://localhost:9000 admin password123
.\mc.exe mb myminio/nca-toolkit --ignore-existing
.\mc.exe anonymous set download myminio/nca-toolkit

Write-Host ""
Write-Host "Verifying S3 bucket..." -ForegroundColor Yellow
$bucketExists = .\mc.exe ls myminio/ | Select-String -Pattern "nca-toolkit"
if (-not $bucketExists) {
    Write-Host "WARNING: Could not verify bucket creation. Services may not work correctly." -ForegroundColor Red
    Write-Host "Trying one more time to create bucket..." -ForegroundColor Yellow
    .\mc.exe mb myminio/nca-toolkit --ignore-existing
    .\mc.exe anonymous set download myminio/nca-toolkit
} else {
    Write-Host "S3 bucket verified successfully." -ForegroundColor Green
}

Write-Host ""
$startServices = Read-Host "Do you want to start the remaining services? Start NCA Toolkit, Baserow, Workflows, and Kokoro TTS? (y/n)"
if ($startServices -ne "y") {
    Write-Host ""
    Write-Host "Setup paused. Only MinIO has been started." -ForegroundColor Yellow
    Write-Host "You can complete the setup later by running this script again." -ForegroundColor Yellow
    exit 0
}

Write-Host ""
Write-Host "Starting NCA Toolkit service..." -ForegroundColor Yellow
docker compose -f docker-compose.yml --project-name ncatoolkit up -d ncatoolkit --no-deps

Write-Host ""
Write-Host "Starting Baserow service..." -ForegroundColor Yellow
docker compose -f docker-compose.yml --project-name baserow up -d baserow --no-deps

Write-Host ""
Write-Host "Starting Workflows service..." -ForegroundColor Yellow
docker compose -f docker-compose.yml --project-name workflows up -d workflows --no-deps

Write-Host ""
Write-Host "Starting Kokoro TTS service..." -ForegroundColor Yellow
docker compose -f docker-compose.yml --project-name kokorotts up -d kokorotts --no-deps

Write-Host ""
Write-Host "===================================================" -ForegroundColor Cyan
Write-Host "Setup complete! Services should now be available at:" -ForegroundColor Green
Write-Host ""
Write-Host "MinIO API: http://localhost:9000" -ForegroundColor Cyan
Write-Host "MinIO Console: http://localhost:9001" -ForegroundColor Cyan
Write-Host "NCA Toolkit: http://localhost:8080" -ForegroundColor Cyan
Write-Host "Baserow: http://localhost:8980" -ForegroundColor Cyan
Write-Host "Workflows (n8n): http://localhost:5678" -ForegroundColor Cyan
Write-Host "Kokoro TTS: http://localhost:8880" -ForegroundColor Cyan
Write-Host "===================================================" -ForegroundColor Cyan

Write-Host ""
Write-Host "NOTE: Services may take a few minutes to become healthy." -ForegroundColor Yellow
Write-Host "You can check the status of all services with:" -ForegroundColor Yellow
Write-Host ".\status.bat" -ForegroundColor Cyan
Write-Host "" 