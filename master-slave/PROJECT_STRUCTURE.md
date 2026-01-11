# Project Structure

```
master-slave/
│
├── README.md                          # Comprehensive documentation
├── QUICKSTART.md                      # Quick start guide
├── docker-compose.yaml                # Local testing setup
├── build-images.sh                    # Linux/Mac build script
├── build-images.ps1                   # Windows PowerShell build script
│
├── job-a/                             # Job A - Creates tasks table
│   ├── app.py                         # Python application
│   ├── requirements.txt               # Python dependencies
│   └── Dockerfile                     # Container image
│
├── job-b/                             # Job B - Adds more tasks
│   ├── app.py                         # Python application
│   ├── requirements.txt               # Python dependencies
│   └── Dockerfile                     # Container image
│
├── job-c/                             # Job C - Adds final tasks
│   ├── app.py                         # Python application
│   ├── requirements.txt               # Python dependencies
│   └── Dockerfile                     # Container image
│
├── task-executor/             # Service that executes tasks
│   ├── app.py                         # Python polling service
│   ├── requirements.txt               # Python dependencies
│   └── Dockerfile                     # Container image
│
└── k8s/
    └── helm/
        └── task-system/               # Helm chart
            ├── Chart.yaml             # Chart metadata
            ├── values.yaml            # Default configuration
            ├── .helmignore            # Helm ignore patterns
            │
            └── templates/             # Kubernetes manifests
                ├── _helpers.tpl       # Template helpers
                ├── NOTES.txt          # Post-install notes
                ├── namespaces.yaml    # Master/Slave namespaces
                ├── postgresql.yaml    # PostgreSQL StatefulSet
                ├── rbac.yaml          # ServiceAccount, Role, RoleBinding
                ├── job-a.yaml         # Job A manifests
                ├── job-b.yaml         # Job B manifests (waits for A)
                ├── job-c.yaml         # Job C manifests (waits for B)
                └── task-executor.yaml # Task executor deployment
```

## Component Details

### Python Applications

All Python apps use:
- **Python 3.11-slim** base image
- **psycopg2-binary** for PostgreSQL connectivity
- Environment variables for configuration
- Error handling and proper exit codes

### Kubernetes Resources

#### Namespaces
- `task-system-master` - Master workload
- `task-system-slave` - Slave workload (identical)

#### PostgreSQL (per namespace)
- **Type**: StatefulSet
- **Replicas**: 2
- **Storage**: PersistentVolumeClaim (1Gi per replica)
- **Service**: Headless ClusterIP
- **Init Script**: Creates tasks table

#### Jobs (per namespace)
- **Job-A**: Runs first, creates table + tasks
- **Job-B**: Waits for Job-A, adds tasks
- **Job-C**: Waits for Job-B, adds tasks
- **Sequential Execution**: Using init containers with `kubectl wait`
- **RBAC**: ServiceAccount with role to watch jobs

#### Task Executor (per namespace)
- **Type**: Deployment
- **Replicas**: 2
- **Strategy**: Both replicas poll independently
- **Polling Interval**: 5 seconds
- **Reconnection**: Automatic on DB errors

### Database Schema

```sql
tasks
├── id (SERIAL PRIMARY KEY)
├── task_name (VARCHAR(255))
├── status (VARCHAR(50)) - 'pending' or 'completed'
├── created_by (VARCHAR(50)) - job identifier
├── created_at (TIMESTAMP)
└── completed_at (TIMESTAMP)
```

### Helm Chart Structure

**Values Configuration**:
- Replication settings (master/slave namespaces)
- PostgreSQL configuration (replicas, auth, resources)
- Job images and resources
- Task executor configuration

**Templates**:
- Uses Go templating with loops for master/slave
- Helm hooks for job sequencing
- RBAC for job coordination
- Health checks and resource limits

## Deployment Flow

1. **Namespaces Created**: master and slave
2. **PostgreSQL Deployed**: 2 StatefulSet replicas per namespace
3. **Job-A Runs**: Creates table, inserts 3 tasks
4. **Job-B Waits & Runs**: Inserts 3 more tasks
5. **Job-C Waits & Runs**: Inserts 3 final tasks
6. **Task Executor**: 2 replicas continuously poll and execute tasks

## Master-Slave Architecture

Both namespaces are:
- **Independent**: Separate databases and resources
- **Identical**: Same workload configuration
- **Isolated**: No cross-namespace communication
- **Self-contained**: Each has 2 PostgreSQL + 2 executor replicas

This creates a true master-slave paradigm where both environments execute the same workload independently.
