# Task System Helm Chart

A Helm chart for deploying a master-slave task processing system with sequential job execution using Kubernetes Jobs and init containers.

## Architecture

This chart deploys a task processing system with:

- **Master-Slave Replication**: Separate namespaces (`task-system-master` and `task-system-slave`) for workload isolation
- **PostgreSQL Databases**: One database per namespace for task storage
- **Sequential Job Execution**: Jobs A → B → C execute in order using init containers with `kubectl wait`
- **Task Executor Service**: RESTful API for task management
- **UI Service**: Web interface for task monitoring

### Job Execution Flow

```
Job A (creates tasks) 
  ↓
Job B (waits for Job A completion via init container)
  ↓
Job C (waits for Job B completion via init container)
```

Each job uses an init container that waits for the previous job to complete before starting.

## Prerequisites

- Kubernetes cluster v1.19+
- Helm v3.0+
- `kubectl` configured to access your cluster
- Container images pushed to a registry (Docker Hub, ECR, etc.)

## Installation

### Quick Start

```bash
# From the repository root
cd k8s/helm

# Install with default values
helm install task-system ./task-system --create-namespace

# Or specify custom values
helm install task-system ./task-system \
  --set jobA.image.repository=myregistry/task-system \
  --set jobA.image.tag=job-a-latest \
  --set jobB.image.repository=myregistry/task-system \
  --set jobB.image.tag=job-b-latest \
  --set jobC.image.repository=myregistry/task-system \
  --set jobC.image.tag=job-c-latest \
  --create-namespace
```

### Using a Custom Values File

```bash
# Create your custom values
cat > my-values.yaml <<EOF
jobA:
  image:
    repository: 123456789012.dkr.ecr.us-east-1.amazonaws.com/task-system
    tag: job-a-v1.0
    
jobB:
  image:
    repository: 123456789012.dkr.ecr.us-east-1.amazonaws.com/task-system
    tag: job-b-v1.0
    
jobC:
  image:
    repository: 123456789012.dkr.ecr.us-east-1.amazonaws.com/task-system
    tag: job-c-v1.0

postgresql:
  persistence:
    storageClass: "gp3"
    size: 10Gi
EOF

# Install with custom values
helm install task-system ./task-system -f my-values.yaml --create-namespace
```

## Configuration

### Key Configuration Options

| Parameter | Description | Default |
|-----------|-------------|---------|
| `replication.enabled` | Enable master-slave replication | `true` |
| `replication.namespaces.master` | Master namespace name | `task-system-master` |
| `replication.namespaces.slave` | Slave namespace name | `task-system-slave` |
| `postgresql.enabled` | Deploy PostgreSQL | `true` |
| `postgresql.auth.password` | PostgreSQL password | `postgres123` |
| `postgresql.persistence.enabled` | Enable persistent storage | `true` |
| `postgresql.persistence.size` | Storage size | `1Gi` |
| `jobA.enabled` | Enable Job A | `true` |
| `jobA.image.repository` | Job A image repository | `job-a` |
| `jobA.image.tag` | Job A image tag | `latest` |
| `jobB.enabled` | Enable Job B | `true` |
| `jobC.enabled` | Enable Job C | `true` |
| `taskExecutor.enabled` | Enable Task Executor service | `true` |
| `uiService.enabled` | Enable UI service | `true` |

See `values.yaml` for complete configuration options.

## Upgrading

```bash
# Upgrade with new values
helm upgrade task-system ./task-system \
  --set jobA.image.tag=job-a-v2.0 \
  --reuse-values

# Or upgrade with new values file
helm upgrade task-system ./task-system -f my-values.yaml
```

## Uninstallation

### Remove the Release

```bash
# Uninstall the Helm release
helm uninstall task-system
```

### Delete Namespaces (Optional)

The namespaces will remain with their resources. To completely remove everything:

```bash
# Delete both namespaces and all their resources
kubectl delete namespace task-system-master task-system-slave

# If namespaces get stuck in Terminating state, force delete:
kubectl get namespace task-system-master -o json | \
  jq '.spec.finalizers = []' > temp-ns.json
kubectl replace --raw "/api/v1/namespaces/task-system-master/finalize" -f temp-ns.json
rm temp-ns.json
```

### Clean Up Persistent Volumes (if needed)

```bash
# List PVs that might remain
kubectl get pv

# Delete specific PVs if using Retain policy
kubectl delete pv <pv-name>
```

## Verifying Installation

```bash
# Check Helm release status
helm status task-system

# List all resources in master namespace
kubectl get all -n task-system-master

# Check job execution order
kubectl get jobs -n task-system-master -w

# View job logs
kubectl logs -n task-system-master job/job-a-<hash>
kubectl logs -n task-system-master job/job-b-<hash>
kubectl logs -n task-system-master job/job-c-<hash>

# Check database
kubectl exec -n task-system-master postgres-0 -- \
  psql -U postgres -d taskdb -c "SELECT * FROM tasks;"
```

## Troubleshooting

### Jobs Not Starting

Check if previous job completed:
```bash
kubectl get jobs -n task-system-master
kubectl describe job <job-name> -n task-system-master
```

### Init Container Waiting

Init containers wait for previous jobs to complete. Check the previous job:
```bash
kubectl logs -n task-system-master <pod-name> -c wait-for-job-a
```

### Database Connection Issues

Check PostgreSQL status:
```bash
kubectl get pods -n task-system-master -l app=postgres
kubectl logs -n task-system-master postgres-0
```

### Image Pull Errors

Ensure images exist in your registry:
```bash
kubectl describe pod <pod-name> -n task-system-master
```

For private registries, create an image pull secret:
```bash
kubectl create secret docker-registry regcred \
  --docker-server=<registry-url> \
  --docker-username=<username> \
  --docker-password=<password> \
  -n task-system-master
```

Then add to `values.yaml`:
```yaml
imagePullSecrets:
  - name: regcred
```

## Alternative: Argo Workflows

For more advanced workflow orchestration, see the Argo Workflows deployment in `k8s/argo-deployment/`:

- **k8s/helm/task-system/** (this chart) - Uses Kubernetes Jobs with init containers
- **k8s/argo-deployment/** - Uses Argo Workflows for orchestration

Choose based on your requirements:
- **Use this Helm chart** for simple, straightforward deployments
- **Use Argo deployment** for complex workflows, parallel execution, or advanced orchestration

See `k8s/argo-deployment/ARGO_WORKFLOWS_GUIDE.md` for details.

## Development

### Template Rendering

Preview rendered templates without installing:
```bash
helm template task-system ./task-system
```

### Dry Run

Test installation without actually deploying:
```bash
helm install task-system ./task-system --dry-run --debug
```

### Linting

Validate chart structure:
```bash
helm lint ./task-system
```

## License

See repository root for license information.
