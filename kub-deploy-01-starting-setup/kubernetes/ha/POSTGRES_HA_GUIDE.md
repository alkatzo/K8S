# PostgreSQL High Availability with Zalando Operator

## Overview

The Zalando PostgreSQL Operator automates:
- ✅ Master-Replica setup (1 primary + N replicas)
- ✅ Streaming replication
- ✅ Automatic failover
- ✅ Connection pooling (PgBouncer)
- ✅ Backup to S3
- ✅ Point-in-time recovery

## Installation

### Step 1: Install the Operator

```bash
# Add Helm repo
helm repo add postgres-operator-charts https://opensource.zalando.com/postgres-operator/charts/postgres-operator
helm repo update

# Install operator
helm install postgres-operator postgres-operator-charts/postgres-operator \
  --namespace postgres-operator \
  --create-namespace

# Verify
kubectl get pods -n postgres-operator
```

### Step 2: Install UI (Optional)

```bash
helm install postgres-operator-ui postgres-operator-charts/postgres-operator-ui \
  --namespace postgres-operator

# Port forward to access UI
kubectl port-forward svc/postgres-operator-ui -n postgres-operator 8081:80
# Open: http://localhost:8081
```

## Deploy PostgreSQL Cluster with 2 Replicas

### Example: PostgreSQL cluster manifest

```yaml
apiVersion: "acid.zalan.do/v1"
kind: postgresql
metadata:
  name: users-db-cluster
  namespace: default
spec:
  # Team name (used for naming)
  teamId: "users-team"
  
  # PostgreSQL version
  version: "15"
  
  # Number of instances (1 primary + 2 replicas = 3 total)
  numberOfInstances: 3
  
  # Users and databases
  users:
    postgres:  # Admin user
    - superuser
    - createdb
    appuser:   # Application user
    - login
  
  databases:
    users: appuser  # Database 'users' owned by 'appuser'
  
  # PostgreSQL configuration
  postgresql:
    version: "15"
    parameters:
      max_connections: "200"
      shared_buffers: "256MB"
      effective_cache_size: "1GB"
      work_mem: "4MB"
  
  # Volume (uses EBS via StorageClass)
  volume:
    size: 10Gi
    storageClass: ebs-gp3
  
  # Resources per pod
  resources:
    requests:
      cpu: 100m
      memory: 256Mi
    limits:
      cpu: 500m
      memory: 512Mi
  
  # Connection pooler (PgBouncer)
  enableConnectionPooler: true
  connectionPooler:
    numberOfInstances: 2
    mode: "transaction"
    resources:
      requests:
        cpu: 100m
        memory: 128Mi
      limits:
        cpu: 300m
        memory: 256Mi
  
  # Patroni configuration (HA/Failover)
  patroni:
    ttl: 30
    loop_wait: 10
    retry_timeout: 10
    synchronous_mode: false
    synchronous_mode_strict: false
```

### Apply the manifest

```bash
kubectl apply -f postgres-cluster.yaml

# Watch cluster creation
kubectl get postgresql users-db-cluster -w

# Check pods
kubectl get pods -l cluster-name=users-db-cluster
```

**You'll see:**
```
NAME                          READY   STATUS    ROLE
users-db-cluster-0            1/1     Running   master    ← Primary (read/write)
users-db-cluster-1            1/1     Running   replica   ← Replica (read-only)
users-db-cluster-2            1/1     Running   replica   ← Replica (read-only)
```

## Services Created

```bash
kubectl get svc -l cluster-name=users-db-cluster
```

**Services:**
- `users-db-cluster` → Primary (read/write)
- `users-db-cluster-repl` → All replicas (read-only load balanced)
- `users-db-cluster-pooler` → PgBouncer connection pooler

## Connection Strings

### Write Operations (Primary)
```bash
# Service: users-db-cluster (points to primary)
postgres://appuser:password@users-db-cluster:5432/users
```

### Read Operations (Replicas)
```bash
# Service: users-db-cluster-repl (load balanced across replicas)
postgres://appuser:password@users-db-cluster-repl:5432/users
```

### Via Connection Pooler (Recommended)
```bash
# Service: users-db-cluster-pooler (PgBouncer)
postgres://appuser:password@users-db-cluster-pooler:5432/users
```

## Application Configuration

### Update users-api deployment

```yaml
env:
- name: POSTGRES_CONNECTION_URI
  value: "postgres://appuser:$(PASSWORD)@users-db-cluster-pooler:5432/users"
  # Or separate read/write:
  # WRITE: users-db-cluster:5432
  # READ:  users-db-cluster-repl:5432
```

## How Failover Works

### Scenario: Primary pod crashes

```
Before:
users-db-cluster-0 (master)   ← Crashes!
users-db-cluster-1 (replica)
users-db-cluster-2 (replica)

After (automatic, ~30 seconds):
users-db-cluster-0 (starting)
users-db-cluster-1 (master)    ← Promoted to primary
users-db-cluster-2 (replica)

When pod-0 comes back:
users-db-cluster-0 (replica)   ← Joins as replica
users-db-cluster-1 (master)
users-db-cluster-2 (replica)
```

**Downtime:** ~30 seconds (configurable via Patroni TTL)

## Scaling

### Scale up replicas
```bash
kubectl patch postgresql users-db-cluster \
  --type='json' \
  -p='[{"op": "replace", "path": "/spec/numberOfInstances", "value": 5}]'

# Or edit the manifest and reapply
```

### Scale down replicas
```bash
kubectl patch postgresql users-db-cluster \
  --type='json' \
  -p='[{"op": "replace", "path": "/spec/numberOfInstances", "value": 2}]'
```

## Storage Per Pod

Each pod gets its own EBS volume via StatefulSet:
```bash
kubectl get pvc -l cluster-name=users-db-cluster

NAME                               STATUS   VOLUME                                     CAPACITY
pgdata-users-db-cluster-0          Bound    pvc-xxx                                    10Gi
pgdata-users-db-cluster-1          Bound    pvc-yyy                                    10Gi
pgdata-users-db-cluster-2          Bound    pvc-zzz                                    10Gi
```

**Each replica has independent EBS storage** (not shared).

## Backup & Restore

### Configure S3 backups

```yaml
spec:
  # ... existing config ...
  
  # Enable WAL archiving to S3
  enableWalArchiving: true
  
  # S3 bucket for backups
  env:
  - name: WAL_S3_BUCKET
    value: "my-postgres-backups"
  - name: AWS_REGION
    value: "ap-southeast-2"
  
  # Backup schedule
  backup:
    schedule: "0 2 * * *"  # Daily at 2 AM
    retentionPolicy: "7d"
```

### Manual backup
```bash
# Execute pg_basebackup
kubectl exec users-db-cluster-0 -- \
  pg_basebackup -D /backup -F tar -z -P
```

## Monitoring

### Check replication lag
```bash
kubectl exec users-db-cluster-0 -- \
  psql -U postgres -c "SELECT * FROM pg_stat_replication;"
```

### Check cluster status
```bash
kubectl exec users-db-cluster-0 -- patronictl list
```

**Output:**
```
+ Cluster: users-db-cluster -----+----+-----------+
| Member              | Host      | Role    | State   | Lag in MB |
+---------------------+-----------+---------+---------+-----------+
| users-db-cluster-0  | 10.0.1.5  | Leader  | running | 0         |
| users-db-cluster-1  | 10.0.1.6  | Replica | running | 0         |
| users-db-cluster-2  | 10.0.1.7  | Replica | running | 0         |
+---------------------+-----------+---------+---------+-----------+
```

## Testing Failover

### Manually delete primary pod
```bash
# Identify current primary
kubectl get pods -l cluster-name=users-db-cluster \
  -o jsonpath='{.items[?(@.metadata.labels.spilo-role=="master")].metadata.name}'

# Delete primary (simulates crash)
kubectl delete pod users-db-cluster-0

# Watch failover (one replica becomes new primary)
watch kubectl get pods -l cluster-name=users-db-cluster \
  -o custom-columns=NAME:.metadata.name,ROLE:.metadata.labels.spilo-role
```

## Pros & Cons

### ✅ Pros
- Automatic failover (< 1 minute)
- Read scaling (replicas handle read queries)
- Connection pooling included (PgBouncer)
- Backup/restore to S3
- Production-ready HA setup
- GitOps friendly (declarative YAML)

### ⚠️ Cons
- More complex than single instance
- Higher cost (multiple pods + storage)
- Need to update app to use read replicas (optional)
- Operator adds another component to manage

## Cost Estimate (3 replicas)

**Compute (t3.medium nodes):**
- 3 PostgreSQL pods: 3 × 0.5 CPU, 512Mi RAM
- 2 PgBouncer pods: 2 × 0.3 CPU, 256Mi RAM

**Storage (EBS gp3):**
- 3 × 10Gi volumes = 30Gi × $0.096 = **$2.88/month**

**Total:** ~$3-5/month (plus EC2 node costs)

## Comparison with RDS

| Feature | Zalando Operator | Amazon RDS Multi-AZ |
|---------|------------------|---------------------|
| **Setup** | Self-managed | Fully managed |
| **Failover** | ~30 seconds | ~60-120 seconds |
| **Cost (3 instances)** | ~$5/month + nodes | ~$100/month |
| **Flexibility** | Full control | AWS-managed |
| **Backup** | Custom (S3) | Automatic snapshots |
| **Scaling** | Manual/HPA | Manual/API |

**RDS is easier but 20x more expensive.**

## Alternative Operators

### CloudNativePG (formerly EDB Operator)
```bash
helm repo add cnpg https://cloudnative-pg.github.io/charts
helm install cnpg cnpg/cloudnative-pg --namespace cnpg-system --create-namespace
```

### Crunchy PostgreSQL Operator
```bash
helm repo add crunchy https://charts.crunchydata.com
helm install pgo crunchy/pgo --namespace postgres-operator --create-namespace
```

## Quick Start Commands

```bash
# 1. Install operator
helm repo add postgres-operator-charts https://opensource.zalando.com/postgres-operator/charts/postgres-operator
helm install postgres-operator postgres-operator-charts/postgres-operator -n postgres-operator --create-namespace

# 2. Create cluster (see manifest above)
kubectl apply -f postgres-cluster.yaml

# 3. Wait for cluster
kubectl wait --for=condition=ready pod -l cluster-name=users-db-cluster --timeout=300s

# 4. Get password
kubectl get secret postgres.users-db-cluster.credentials.postgresql.acid.zalan.do \
  -o jsonpath='{.data.password}' | base64 --decode

# 5. Connect
kubectl exec -it users-db-cluster-0 -- psql -U postgres
```

## Resources

- [Zalando Operator Docs](https://postgres-operator.readthedocs.io/)
- [Patroni Documentation](https://patroni.readthedocs.io/)
- [PostgreSQL Replication](https://www.postgresql.org/docs/current/high-availability.html)
