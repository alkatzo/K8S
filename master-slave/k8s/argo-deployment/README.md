# Argo Workflows Deployment Guide

This directory contains Helm-templated Kubernetes manifests for deploying the task-system using Argo Workflows.

## Prerequisites

1. **Argo Workflows installed**:
   ```bash
   kubectl create namespace argo
   kubectl apply -n argo -f https://github.com/argoproj/argo-workflows/releases/download/v3.5.5/install.yaml
   ```

2. **AWS EKS cluster** with EBS CSI driver
3. **ECR images** pushed to repository

## Deployment

### Option 1: Helm Template + kubectl (Recommended)
```bash
cd /home/myuser/GitHub/K8S/master-slave/k8s/argo-deployment

# Generate and apply manifests
helm template task-system . -f values-argo.yaml | kubectl apply -f -
```

### Option 2: Direct Helm Install
```bash
helm install task-system . -f values-argo.yaml
```

## Configuration

Edit `values-argo.yaml` to customize:
- ECR registry and repository
- Namespace names
- PostgreSQL credentials
- Resource limits
- Image tags

## Verify Deployment

```bash
# Check workflows
kubectl get workflows -n task-system-master

# Watch progress
kubectl get workflows -n task-system-master -w

# View logs
argo logs job-sequence-workflow -n task-system-master

# Check database
kubectl exec -n task-system-master postgres-0 -- \
  psql -U postgres -d taskdb -c "SELECT * FROM tasks;"
```

## Resubmit Workflows

```bash
# Delete and recreate
kubectl delete workflow job-sequence-workflow -n task-system-master
helm template task-system . -f values-argo.yaml | kubectl apply -f -
```

## Cleanup

```bash
helm template task-system . -f values-argo.yaml | kubectl delete -f -
```

## Benefits

- **Minimal boilerplate** - Uses Helm templating with shared helpers
- **Single source of truth** - All config in `values-argo.yaml`
- **No duplication** - Templates loop over namespaces
- **Fast sequencing** - Argo native orchestration (~5s between jobs vs 20s)
