# Kubernetes Deployment Guide

This folder contains Kubernetes manifests for the three microservices: `auth-api`, `users-api`, and `tasks-api`.

## Quick Start: Deploy on Minikube

### Prerequisites
- **Minikube** installed: [Install Minikube](https://minikube.sigs.k8s.io/docs/start/)
- **kubectl** installed: [Install kubectl](https://kubernetes.io/docs/tasks/tools/)
- **Docker** (local): for building images (or Minikube's built-in Docker)

### Step 1: Start Minikube
```powershell
minikube start
```
This creates a local Kubernetes cluster. Minikube includes a default StorageClass named `standard`, which will satisfy the PVC in `tasks-deployment-service.yaml`.

Check that Minikube started:
```powershell
kubectl cluster-info
kubectl get nodes
```

### Step 2: Build and Push Docker Images to Docker Hub

Navigate to the project root (where `docker-compose.yaml` is located).

#### Prerequisite: Log in to Docker Hub
```powershell
docker login
# Enter your Docker Hub username (alkatzo) and password/token
```

#### Build the three images
```powershell
docker build -t alkatzo/kube-networking:auth-api ./auth-api
docker build -t alkatzo/kube-networking:users-api ./users-api
docker build -t alkatzo/kube-networking:tasks-api ./tasks-api
```

Verify images are built:
```powershell
docker images | Select-String "alkatzo/kube-networking"
```

#### Push to Docker Hub
```powershell
docker push alkatzo/kube-networking:auth-api
docker push alkatzo/kube-networking:users-api
docker push alkatzo/kube-networking:tasks-api
```

Verify on Docker Hub: visit https://hub.docker.com/r/alkatzo/kube-networking and confirm the repository exists with three tags:
- `alkatzo/kube-networking:auth-api`
- `alkatzo/kube-networking:users-api`
- `alkatzo/kube-networking:tasks-api`

**Note:** The Kubernetes manifests in this folder are already configured to pull from `alkatzo/kube-networking` with the appropriate tags. If you change the image names, update the `image:` field in each YAML file.

### Step 3: Deploy Manifests
From the project root, apply all manifests:
```powershell
kubectl apply -f .\k8s\
```

Verify deployments and services:
```powershell
kubectl get deployments
kubectl get services
kubectl get pvc
```

Expected output:
- 3 deployments (auth-deployment, users-deployment, tasks-deployment) all in Running state
- 3 services (auth, users, tasks)
- 1 PVC (tasks-data-pvc) in Bound state

### Step 4: Check Logs
```powershell
kubectl logs deploy/auth-deployment
kubectl logs deploy/users-deployment
kubectl logs deploy/tasks-deployment
```

If any pod is not Running, describe it:
```powershell
kubectl describe pod -l app=auth
kubectl describe pod -l app=users
kubectl describe pod -l app=tasks
```

### Step 5: Test the Services
Get the Minikube IP:
```powershell
$MINIKUBE_IP = minikube ip
Write-Host "Minikube IP: $MINIKUBE_IP"
```

Users service (NodePort 30080):
```powershell
# Login (should return token: abc)
$response = Invoke-RestMethod -Uri "http://$MINIKUBE_IP`:30080/login" `
  -Method Post `
  -Body (@{ email='test@test.com'; password='pw' } | ConvertTo-Json) `
  -ContentType 'application/json'
Write-Host "Token: $($response.token)"
```

Tasks service (NodePort 30000, requires Bearer token from login):
```powershell
# Set token from previous login (or use the hardcoded 'abc')
$token = "abc"

# Create a task
Invoke-RestMethod -Uri "http://$MINIKUBE_IP`:30000/tasks" `
  -Method Post `
  -Body (@{ title='Test Task'; text='Do this task' } | ConvertTo-Json) `
  -ContentType 'application/json' `
  -Headers @{ Authorization = "Bearer $token" }

# List tasks
Invoke-RestMethod -Uri "http://$MINIKUBE_IP`:30000/tasks" `
  -Method Get `
  -Headers @{ Authorization = "Bearer $token" }
```

### Step 6: Inspect Persistent Storage
The `tasks` PVC is bound to a dynamic PV created by Minikube's default StorageClass. To check:
```powershell
kubectl describe pvc tasks-data-pvc
kubectl get pv
```

To access the mounted data from Minikube:
```powershell
# SSH into the Minikube VM
minikube ssh

# Inside Minikube, navigate to the PV location (varies by provider; for docker driver, check /tmp/...)
ls -la /tmp/...
```

Alternatively, exec into the `tasks` pod to see files:
```powershell
kubectl exec -it deploy/tasks-deployment -- sh
cd /app/tasks
ls -la
cat tasks.txt
exit
```

## Troubleshooting

### PVC remains Pending
- Check if the StorageClass exists: `kubectl get storageclass`
- If no StorageClass, Minikube may not have the default provisioner. Reinstall or check Minikube version.
- Describe PVC for events: `kubectl describe pvc tasks-data-pvc`

### Pods fail to start
- Check pod status: `kubectl get pods`
- Describe pod: `kubectl describe pod <pod-name>`
- Check logs: `kubectl logs <pod-name>`
- Common issues: missing images (ensure build step was done), incorrect image names in YAML.

### Services not reachable
- Ensure NodePort services are available: `kubectl get svc`
- Test connectivity to the Minikube IP directly: `curl http://<minikube-ip>:30080/`
- If using a VM (Minikube on Windows with Hyper-V), you may need to open firewall or use `minikube tunnel` for port access.

### Volume mount errors
- Check if the mount target exists: `kubectl exec -it deploy/tasks-deployment -- ls -la /app/tasks`
- Check pod events: `kubectl describe pod <pod-name>` under "Events" section.

## Cleanup

To stop Minikube:
```powershell
minikube stop
```

To delete everything and restart fresh:
```powershell
minikube delete
minikube start
# Re-run steps 2-3 above
```

To delete only Kubernetes resources (keep Minikube running):
```powershell
kubectl delete -f .\k8s\
```

## Files in this Directory

- `auth-deployment-service.yaml` — Deployment and ClusterIP Service for `auth-api` (port 80, internal only).
- `users-deployment-service.yaml` — Deployment and NodePort Service for `users-api` (port 8080 → NodePort 30080).
- `tasks-deployment-service.yaml` — Deployment (with PVC mount), PersistentVolumeClaim, and NodePort Service for `tasks-api` (port 8000 → NodePort 30000).

## StorageClass / PersistentVolume Notes

The `tasks-data-pvc` uses `storageClassName: standard`, which Minikube provides by default. The StorageClass enables dynamic provisioning: when the PVC is created, Minikube automatically provisions a PersistentVolume and binds it to the claim.

For **AWS EFS** (later), see the main project README or contact the team for EFS setup and CSI driver installation instructions.

## Next Steps

- Scale deployments: `kubectl scale deployment <name> --replicas=3`
- Add resource requests/limits to deployments for better scheduling.
- Add Ingress for HTTP routing (if needed for multi-service access).
- Set up CI/CD to build and push images on code changes.
