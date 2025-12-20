# Master-Slave Task Processing System

This project implements a master-slave task processing system using Kubernetes with the following components:

## Architecture

### Components

1. **Jobs (job-a, job-b, job-c)**: Python applications that create tasks in PostgreSQL
   - Job-A: Creates the tasks table and inserts 3 tasks
   - Job-B: Inserts 3 additional tasks (runs after Job-A)
   - Job-C: Inserts 3 more tasks (runs after Job-B)

2. **Task Executor Service**: A Python service that continuously polls PostgreSQL for pending tasks, executes them (prints task name), and marks them as completed

3. **PostgreSQL**: Database with 2 replicas storing tasks

### Master-Slave Paradigm

The system deploys identical workloads into two separate namespaces:
- `task-system-master`: Master namespace
- `task-system-slave`: Slave namespace

Each namespace has:
- 2 PostgreSQL replicas (StatefulSet)
- 3 Jobs (job-a, job-b, job-c) that run sequentially
- 2 Task Executor service replicas (Deployment)

Both master and slave environments operate independently with their own databases and task processing.

## Prerequisites

- Kubernetes cluster (minikube, kind, or cloud provider)
- kubectl configured
- Helm 3.x installed
- Docker for building images

## Building Docker Images

Before deploying, build all Docker images:

```bash
cd master-slave

# Build Job A
docker build -t job-a:latest ./job-a

# Build Job B
docker build -t job-b:latest ./job-b

# Build Job C
docker build -t job-c:latest ./job-c

# Build Task Executor
docker build -t task-executor:latest ./task-executor-service
```

**For Minikube users:**
```bash
# Use minikube's Docker daemon
eval $(minikube docker-env)

# Then build the images as shown above
```

**For remote clusters:**
```bash
# Tag and push to your registry
docker tag job-a:latest your-registry/job-a:latest
docker push your-registry/job-a:latest
# ... repeat for other images

# Update values.yaml with your registry paths
```

## Deployment

### Option 1: Deploy with Default Values

```bash
cd k8s/helm

# Install the chart
helm install task-system ./task-system

# Or upgrade if already installed
helm upgrade --install task-system ./task-system
```

### Option 2: Deploy with Custom Values

Create a `custom-values.yaml`:

```yaml
postgresql:
  auth:
    password: "your-secure-password"
  replicas: 2
  
taskExecutor:
  replicas: 2

jobA:
  image:
    repository: your-registry/job-a
    tag: v1.0.0
```

Deploy:
```bash
helm install task-system ./task-system -f custom-values.yaml
```

## Verification

### Check Namespaces
```bash
kubectl get namespaces | grep task-system
```

### Check PostgreSQL Pods
```bash
kubectl get pods -n task-system-master -l app=postgres
kubectl get pods -n task-system-slave -l app=postgres
```

### Check Jobs Status
```bash
# Master namespace
kubectl get jobs -n task-system-master

# Slave namespace
kubectl get jobs -n task-system-slave
```

### Check Task Executor
```bash
# Master namespace
kubectl get pods -n task-system-master -l app=task-executor

# Slave namespace
kubectl get pods -n task-system-slave -l app=task-executor
```

### View Task Executor Logs
```bash
# Master namespace
kubectl logs -n task-system-master -l app=task-executor -f

# Slave namespace
kubectl logs -n task-system-slave -l app=task-executor -f
```

### View Job Logs
```bash
# Job A logs (master)
kubectl logs -n task-system-master job/job-a

# Job B logs (master)
kubectl logs -n task-system-master job/job-b

# Job C logs (master)
kubectl logs -n task-system-master job/job-c
```

## How It Works

1. **Deployment**: Helm creates both master and slave namespaces with all resources

2. **PostgreSQL**: Two StatefulSet replicas start in each namespace with persistent volumes

3. **Sequential Job Execution**:
   - Job-A runs first, creates the tasks table, and inserts 3 tasks
   - Job-B waits for Job-A to complete, then inserts 3 more tasks
   - Job-C waits for Job-B to complete, then inserts 3 final tasks

4. **Task Execution**:
   - Task Executor service (2 replicas) polls the database every 5 seconds
   - When pending tasks are found, they are executed (printed) and marked as completed
   - Both replicas can process tasks independently

5. **Master-Slave Independence**: Both environments run the same workload completely independently

## Database Schema

```sql
CREATE TABLE tasks (
    id SERIAL PRIMARY KEY,
    task_name VARCHAR(255) NOT NULL,
    status VARCHAR(50) DEFAULT 'pending',
    created_by VARCHAR(50) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP
);
```

## Accessing PostgreSQL

To connect to PostgreSQL directly:

```bash
# Master namespace
kubectl run psql-client --rm -it --restart=Never \
  --namespace task-system-master \
  --image postgres:15-alpine \
  --env="PGPASSWORD=postgres123" \
  -- psql -h postgres-service -U postgres -d taskdb

# Slave namespace
kubectl run psql-client --rm -it --restart=Never \
  --namespace task-system-slave \
  --image postgres:15-alpine \
  --env="PGPASSWORD=postgres123" \
  -- psql -h postgres-service -U postgres -d taskdb
```

Query tasks:
```sql
SELECT * FROM tasks ORDER BY created_at;
SELECT * FROM tasks WHERE status = 'pending';
SELECT * FROM tasks WHERE status = 'completed';
```

## Troubleshooting

### Jobs Not Running Sequentially

Check RBAC permissions:
```bash
kubectl get serviceaccount -n task-system-master
kubectl get role -n task-system-master
kubectl get rolebinding -n task-system-master
```

### PostgreSQL Connection Issues

Check if PostgreSQL is ready:
```bash
kubectl exec -it postgres-0 -n task-system-master -- pg_isready -U postgres
```

### Task Executor Not Processing Tasks

Check logs for errors:
```bash
kubectl logs -n task-system-master -l app=task-executor --tail=100
```

## Cleanup

```bash
# Uninstall the Helm release
helm uninstall task-system

# Delete namespaces (if needed)
kubectl delete namespace task-system-master task-system-slave

# Delete PVCs manually if they persist
kubectl delete pvc -n task-system-master --all
kubectl delete pvc -n task-system-slave --all
```

## Configuration Reference

### PostgreSQL Values

| Parameter | Description | Default |
|-----------|-------------|---------|
| `postgresql.enabled` | Enable PostgreSQL | `true` |
| `postgresql.replicas` | Number of replicas | `2` |
| `postgresql.auth.database` | Database name | `taskdb` |
| `postgresql.auth.username` | Database user | `postgres` |
| `postgresql.auth.password` | Database password | `postgres123` |
| `postgresql.persistence.size` | Storage size | `1Gi` |

### Task Executor Values

| Parameter | Description | Default |
|-----------|-------------|---------|
| `taskExecutor.enabled` | Enable task executor | `true` |
| `taskExecutor.replicas` | Number of replicas | `2` |
| `taskExecutor.image.repository` | Image repository | `task-executor` |
| `taskExecutor.image.tag` | Image tag | `latest` |

### Replication Values

| Parameter | Description | Default |
|-----------|-------------|---------|
| `replication.enabled` | Enable master-slave | `true` |
| `replication.namespaces.master` | Master namespace | `task-system-master` |
| `replication.namespaces.slave` | Slave namespace | `task-system-slave` |

## License

MIT
