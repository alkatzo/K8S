# Build all Docker images
Write-Host "Building Docker images..." -ForegroundColor Green

$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $scriptPath

Write-Host "Building job-a..." -ForegroundColor Yellow
docker build -t job-a:latest ./job-a

Write-Host "Building job-b..." -ForegroundColor Yellow
docker build -t job-b:latest ./job-b

Write-Host "Building job-c..." -ForegroundColor Yellow
docker build -t job-c:latest ./job-c

Write-Host "Building task-executor..." -ForegroundColor Yellow
docker build -t task-executor:latest ./task-executor-service

Write-Host ""
Write-Host "All images built successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "To deploy with Helm, run:"
Write-Host "  cd k8s/helm"
Write-Host "  helm install task-system ./task-system"
