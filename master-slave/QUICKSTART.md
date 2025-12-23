# Quick Start Guide

## Local Testing with Docker Compose

Test the system locally before deploying to Kubernetes:

```bash
# Start all services
docker-compose up

# View logs
docker-compose logs -f task-executor

# Stop services
docker-compose down -v
```

## Kubernetes Deployment

### 1. Build Images

**Windows (PowerShell):**
```powershell
.\build-images.ps1
```

**Linux/Mac:**
```bash
chmod +x build-images.sh
./build-images.sh
```

**For Minikube:**
```bash
eval $(minikube docker-env)
.\build-images.ps1  # or ./build-images.sh
```

### 2. Deploy with Helm

```bash
cd k8s/helm
helm install task-system ./task-system
```

### 3. Monitor Deployment

```bash
# Watch all resources
watch kubectl get all -n task-system-master
watch kubectl get all -n task-system-slave

# Check jobs
kubectl get jobs -n task-system-master -w

# View task executor logs
kubectl logs -n task-system-master -l app=task-executor -f
```

### 4. Verify Tasks

```bash
# Connect to PostgreSQL (master)
kubectl run psql-client --rm -it --restart=Never \
  --namespace task-system-master \
  --image postgres:15-alpine \
  --env="PGPASSWORD=postgres123" \
  -- psql -h postgres-service -U postgres -d taskdb

# Run queries
SELECT * FROM tasks ORDER BY created_at;
SELECT COUNT(*), status FROM tasks GROUP BY status;
```

## Expected Results

After deployment, you should see:

1. **Master Namespace:**
   - 2 PostgreSQL pods running
   - 3 completed jobs (job-a, job-b, job-c)
   - 2 task-executor pods running
   - 9 total tasks created (3 per job)

2. **Slave Namespace:**
   - Same as master, operating independently

3. **Task Executor Logs:**
   ```
   EXECUTING TASK: Task-A-1
   Task ID: 1
   Timestamp: 2025-12-20T...
   ========================================
   Task Task-A-1 marked as completed
   ```

## Troubleshooting Commands

```bash
# Check job status
kubectl describe job job-a -n task-system-master

# View job logs
kubectl logs job/job-a -n task-system-master

# Check PostgreSQL
kubectl exec -it postgres-0 -n task-system-master -- pg_isready -U postgres

# View task executor errors
kubectl logs -n task-system-master -l app=task-executor --tail=50

# Check RBAC
kubectl get serviceaccount,role,rolebinding -n task-system-master
```

## Cleanup

```bash
# Remove Helm release
helm uninstall task-system

# Delete namespaces (and all resources)
kubectl delete namespace task-system-master task-system-slave
```

## Architecture Summary

```
┌─────────────────────────────────────────────────────────────┐
│                    MASTER NAMESPACE                          │
├─────────────────────────────────────────────────────────────┤
│  ┌──────────┐  ┌──────────┐                                 │
│  │PostgreSQL│  │PostgreSQL│  (StatefulSet, 2 replicas)      │
│  │  Pod 0   │  │  Pod 1   │                                 │
│  └──────────┘  └──────────┘                                 │
│       │              │                                       │
│       └──────┬───────┘                                       │
│              │                                               │
│     ┌────────┴────────┐                                     │
│     │   Job-A (runs)  │  → Creates table + 3 tasks         │
│     └────────┬────────┘                                     │
│              ↓                                               │
│     ┌────────┴────────┐                                     │
│     │   Job-B (waits) │  → Inserts 3 tasks                 │
│     └────────┬────────┘                                     │
│              ↓                                               │
│     ┌────────┴────────┐                                     │
│     │   Job-C (waits) │  → Inserts 3 tasks                 │
│     └─────────────────┘                                     │
│                                                              │
│  ┌────────────────┐  ┌────────────────┐                    │
│  │ Task Executor  │  │ Task Executor  │  (Deployment, 2x)  │
│  │   Replica 1    │  │   Replica 2    │                    │
│  └────────────────┘  └────────────────┘                    │
│         │                    │                               │
│         └─────────┬──────────┘                              │
│                   │                                          │
│          Polls for pending tasks                            │
│          Executes & marks complete                          │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                     SLAVE NAMESPACE                          │
│              (Identical setup, independent)                  │
└─────────────────────────────────────────────────────────────┘
```

## Key Features

✅ **Sequential Job Execution** - Jobs run in order using init containers and kubectl wait
✅ **Master-Slave Architecture** - Two independent namespaces with identical workloads
✅ **High Availability** - 2 replicas for PostgreSQL and task executors
✅ **Persistent Storage** - StatefulSets with PVCs for PostgreSQL
✅ **RBAC** - Proper service accounts and roles for job coordination
✅ **Health Checks** - Liveness and readiness probes
✅ **Resource Management** - CPU and memory limits/requests
