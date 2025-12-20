#!/bin/bash

# Build all Docker images
echo "Building Docker images..."

cd "$(dirname "$0")"

echo "Building job-a..."
docker build -t job-a:latest ./job-a

echo "Building job-b..."
docker build -t job-b:latest ./job-b

echo "Building job-c..."
docker build -t job-c:latest ./job-c

echo "Building task-executor..."
docker build -t task-executor:latest ./task-executor-service

echo ""
echo "All images built successfully!"
echo ""
echo "To deploy with Helm, run:"
echo "  cd k8s/helm"
echo "  helm install task-system ./task-system"
