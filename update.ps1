# PowerShell script to update Python scripts in the Docker container
Write-Host "Updating scripts in the Docker container..."

# Ensure /opt/scripts exists in the container
$null = docker exec workflows mkdir -p /opt/scripts/

# Copy the updated scripts to the container
& docker cp short-story/scripts/video_splitter.py workflows:/opt/scripts/video_splitter.py
& docker cp short-story/scripts/clip_cutter.py workflows:/opt/scripts/clip_cutter.py
& docker cp short-story/scripts/a4f-local.py workflows:/opt/scripts/a4f-local.py

# Note: chmod is not needed and not permitted in this container

Write-Host "Scripts updated successfully!" 