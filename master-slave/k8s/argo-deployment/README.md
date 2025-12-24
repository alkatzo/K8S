# Task System - Argo Workflows Deployment

A Helm-templated Kubernetes deployment for the task processing system using Argo Workflows for advanced orchestration.

## Architecture

This deployment uses Argo Workflows to orchestrate sequential job execution:

- **Master-Slave Replication**: Separate namespaces (`task-system-master` and `task-system-slave`) for workload isolation
- **PostgreSQL Databases**: One database per namespace for task storage
- **Argo Workflow Orchestration**: Native workflow controller manages job sequencing
- **Task Executor Service**: RESTful API for task management
- **UI Service**: Web interface for task monitoring

### Job Execution Flow

```
Argo Workflow Controller
  ↓
Step 1: Job A (creates tasks)
  ↓
Step 2: Job B (processes tasks) - waits for Step 1
  ↓
Step 3: Job C (finalizes tasks) - waits for Step 2
```

Jobs execute sequentially with Argo's native orchestration (~5s between jobs vs 20s with init containers).

## Prerequisites

- Kubernetes cluster v1.19+
- Helm v3.0+
- `kubectl` configured to access your cluster
- **Argo Workflows v3.7+** (installation instructions below)
- Container images pushed to a registry (Docker Hub, ECR, etc.)

## Installing Argo Workflows

### Option 1: Using kubectl (Quick)

```bash
# Create argo namespace
kubectl create namespace argo

# Install Argo Workflows
kubectl apply -n argo -f https://github.com/argoproj/argo-workflows/releases/download/v3.7.6/install.yaml

# Wait for Argo to be ready
kubectl wait --for=condition=ready pod -l app=workflow-controller -n argo --timeout=300s

# Verify installation
kubectl get pods -n argo
```

### Option 2: Using Helm

```bash
# Add Argo Helm repository
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

# Install Argo Workflows
helm install argo-workflows argo/argo-workflows \
  -n argo \
  --create-namespace

# Verify installation
kubectl get pods -n argo
```

### Install Argo CLI (Optional but Recommended)

**Linux:**
```bash
curl -sLO https://github.com/argoproj/argo-workflows/releases/download/v3.7.6/argo-linux-amd64.gz
gunzip argo-linux-amd64.gz
chmod +x argo-linux-amd64
sudo mv ./argo-linux-amd64 /usr/local/bin/argo

# Verify
argo version
```

**macOS:**
```bash
brew install argo

# Verify
argo version
```

**Windows:**
```powershell
# Download from GitHub releases
curl -LO https://github.com/argoproj/argo-workflows/releases/download/v3.7.6/argo-windows-amd64.gz
# Extract and add to PATH
```

## Installation

### Quick Start

**For AWS EKS:**
```bash
# From the repository root
cd k8s/argo-deployment

# Deploy to EKS with EBS storage (loads base + AWS overrides)
helm template task-system . -f values-argo.yaml -f values-aws.yaml | kubectl apply -f -
```

**For Local/Bare-Metal (Vagrant, kubeadm):**
```bash
# From the repository root
cd k8s/argo-deployment

# Deploy to local cluster (uses base values only)
helm template task-system . -f values-argo.yaml -f values-local.yaml | kubectl apply -f -
```

### Values Files Overview

- **`values-argo.yaml`** - Base values shared across all environments
- **`values-aws.yaml`** - AWS-specific overrides (ECR registry, ebs-gp3 storage)
- **`values-local.yaml`** - Local-specific overrides (currently empty, uses base defaults)

**Note:** Helm merges values files from left to right, so later files override earlier ones.

### Using Custom Image Registry

Edit the appropriate values file or override values:

```bash
# For AWS with custom registry
REGISTRY="$(aws sts get-caller-identity --query Account --output text).dkr.ecr.ap-southeast-2.amazonaws.com"
helm template task-system . -f values-argo.yaml -f values-aws.yaml \
  --set registry="${REGISTRY}" \
  --set repository=task-system | kubectl apply -f -

# For local with Docker Hub
helm template task-system . -f values-argo.yaml -f values-local.yaml \
  --set registry=docker.io \
  --set repository=myuser/task-system | kubectl apply -f -
```

### Install with Specific Image Tags

```bash
# AWS deployment with custom tags
helm template task-system . -f values-argo.yaml -f values-aws.yaml \
  --set images.jobA=v1.0 \
  --set images.jobB=v1.0 \
  --set images.jobC=v1.0 | kubectl apply -f -

# Local deployment with custom tags
helm template task-system . -f values-argo.yaml -f values-local.yaml \
  --set images.jobA=v1.0 \
  --set images.jobB=v1.0 \
  --set images.jobC=v1.0 | kubectl apply -f -
```

```bash
helm template task-system . -f values-argo.yaml \
  --set jobA.tag=v1.0 \
  --set jobB.tag=v1.0 \
  --set jobC.tag=v1.0 | kubectl apply -f -
```

## Configuration

### Key Configuration Options

Edit `values-argo.yaml`:

| Parameter | Description | Default |
|-----------|-------------|---------|
| `namespaces.master` | Master namespace name | `task-system-master` |
| `namespaces.slave` | Slave namespace name | `task-system-slave` |
| `image.registry` | Container registry | `alkatzo` |
| `image.repository` | Image repository | `task-system` |
| `jobA.tag` | Job A image tag | `job-a-latest` |
| `jobB.tag` | Job B image tag | `job-b-latest` |
| `jobC.tag` | Job C image tag | `job-c-latest` |
| `taskExecutor.tag` | Task Executor image tag | `task-executor-latest` |
| `postgresql.storageClass` | Storage class for PostgreSQL | `""` (default) |
| `postgresql.storageSize` | PostgreSQL storage size | `1Gi` |
| `postgresql.password` | PostgreSQL password | `postgres123` |

## Verifying Installation

```bash
# Check workflows
kubectl get workflows -n task-system-master
kubectl get workflows -n task-system-slave

# Watch workflow progress
kubectl get workflows -n task-system-master -w

# Check all resources
kubectl get all -n task-system-master
kubectl get all -n task-system-slave
```

## Managing Workflows

### Using Argo CLI

```bash
# List workflows
argo list -n task-system-master

# Get workflow details
argo get <workflow-name> -n task-system-master

# View logs
argo logs <workflow-name> -n task-system-master

# Follow logs in real-time
argo logs <workflow-name> -n task-system-master -f

# View specific step logs
argo logs <workflow-name> -n task-system-master run-job-a

# Delete workflow
argo delete <workflow-name> -n task-system-master

# Resubmit workflow
argo resubmit <workflow-name> -n task-system-master

# Stop running workflow
argo stop <workflow-name> -n task-system-master

# Retry failed workflow
argo retry <workflow-name> -n task-system-master
```

### Using kubectl

```bash
# Check workflow status
kubectl get workflows -n task-system-master
kubectl get workflows -n task-system-slave

# Describe workflow
kubectl describe workflow <workflow-name> -n task-system-master

# Get workflow YAML
kubectl get workflow <workflow-name> -n task-system-master -o yaml

# View all workflow logs
kubectl logs -l workflows.argoproj.io/workflow=<workflow-name> -n task-system-master

# Check all pods from the workflow
kubectl get pods -n task-system-master -l workflows.argoproj.io/workflow=<workflow-name>

# Delete workflow
kubectl delete workflow <workflow-name> -n task-system-master

# View specific pod logs
kubectl logs -n task-system-master <pod-name>
```

### Restarting Workflows Only

To restart workflows without affecting databases, services, or other resources:

```bash
# Method 1: Delete and reapply (only workflows recreated, existing resources unchanged)
kubectl delete workflow --all -n task-system-master
kubectl delete workflow --all -n task-system-slave
helm template task-system . -f values-argo.yaml | kubectl apply -f -

# Method 2: Resubmit existing workflow (creates new instance)
kubectl get workflow job-sequence-workflow -n task-system-master -o yaml | kubectl create -f -
kubectl get workflow job-sequence-workflow -n task-system-slave -o yaml | kubectl create -f -

# Method 3: Using Argo CLI (if installed)
argo resubmit job-sequence-workflow -n task-system-master
argo resubmit job-sequence-workflow -n task-system-slave
```

## Accessing Argo UI

### Port Forward Method

```bash
kubectl -n argo port-forward deployment/argo-server 2746:2746
```

Then open in browser: https://localhost:2746

### Using Ingress (Production)

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argo-workflows
  namespace: argo
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - argo.yourdomain.com
    secretName: argo-tls
  rules:
  - host: argo.yourdomain.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: argo-server
            port:
              number: 2746
```

## Upgrading

```bash
# Update values in values-argo.yaml, then reapply
helm template task-system . -f values-argo.yaml | kubectl apply -f -

# Or with inline value changes
helm template task-system . -f values-argo.yaml \
  --set jobA.tag=v2.0 | kubectl apply -f -
```

## Uninstallation

### Remove the Deployment

```bash
cd k8s/argo-deployment

# Delete all resources
helm template task-system . -f values-argo.yaml | kubectl delete -f -
```

### Delete Namespaces

```bash
# Delete both namespaces and all their resources
kubectl delete namespace task-system-master task-system-slave
```

### If Namespaces Stuck in Terminating State

```bash
# Force delete master namespace
kubectl get namespace task-system-master -o json | \
  Out-File -Encoding ASCII temp-ns.json
(Get-Content temp-ns.json | ConvertFrom-Json | ForEach-Object { 
  $_.spec = @{finalizers=@()}; $_ 
} | ConvertTo-Json -Depth 100 -Compress) | Out-File -Encoding ASCII temp-ns-fixed.json
kubectl replace --raw "/api/v1/namespaces/task-system-master/finalize" -f temp-ns-fixed.json
Remove-Item temp-ns.json, temp-ns-fixed.json

# Repeat for slave namespace
kubectl get namespace task-system-slave -o json | \
  Out-File -Encoding ASCII temp-ns.json
(Get-Content temp-ns.json | ConvertFrom-Json | ForEach-Object { 
  $_.spec = @{finalizers=@()}; $_ 
} | ConvertTo-Json -Depth 100 -Compress) | Out-File -Encoding ASCII temp-ns-fixed.json
kubectl replace --raw "/api/v1/namespaces/task-system-slave/finalize" -f temp-ns-fixed.json
Remove-Item temp-ns.json, temp-ns-fixed.json
```

### Uninstall Argo Workflows (Optional)

```bash
# If installed via kubectl
kubectl delete -n argo -f https://github.com/argoproj/argo-workflows/releases/download/v3.7.6/install.yaml
kubectl delete namespace argo

# If installed via Helm
helm uninstall argo-workflows -n argo
kubectl delete namespace argo
```

## Troubleshooting

### Workflow Not Starting

```bash
# Check Argo controller logs
kubectl logs -n argo deployment/workflow-controller

# Check workflow status
kubectl describe workflow <workflow-name> -n task-system-master
```

### Step Failing

```bash
# View step logs
argo logs <workflow-name> -n task-system-master <step-name>

# Check pod events
kubectl describe pod -n task-system-master -l workflows.argoproj.io/workflow=<workflow-name>
```

### Database Connection Issues

```bash
# Check PostgreSQL status
kubectl get pods -n task-system-master -l app=postgres
kubectl logs -n task-system-master postgres-0

# Test connection
kubectl exec -n task-system-master postgres-0 -- \
  psql -U postgres -d taskdb -c "SELECT 1;"
```

### Querying PostgreSQL Database

To check task data in the database after workflow execution:

```bash
# Query all tasks in master namespace
kubectl exec -n task-system-master postgres-0 -- \
  psql -U postgres -d taskdb -c "SELECT * FROM tasks;"

# Query all tasks in slave namespace
kubectl exec -n task-system-slave postgres-0 -- \
  psql -U postgres -d taskdb -c "SELECT * FROM tasks;"

# Query with formatted output
kubectl exec -n task-system-master postgres-0 -- \
  psql -U postgres -d taskdb -c "SELECT id, title, status, created_at FROM tasks ORDER BY id;"

# Count tasks by status
kubectl exec -n task-system-master postgres-0 -- \
  psql -U postgres -d taskdb -c "SELECT status, COUNT(*) FROM tasks GROUP BY status;"

# Get recent tasks
kubectl exec -n task-system-master postgres-0 -- \
  psql -U postgres -d taskdb -c "SELECT * FROM tasks ORDER BY created_at DESC LIMIT 10;"

# Interactive PostgreSQL session
kubectl exec -it -n task-system-master postgres-0 -- psql -U postgres -d taskdb

# Once in the interactive session, you can run:
# \dt                    -- List all tables
# \d tasks               -- Describe tasks table structure
# SELECT * FROM tasks;   -- Query tasks
# \q                     -- Quit
```

### Image Pull Errors

```bash
# Check pod status
kubectl describe pod <pod-name> -n task-system-master

# For private registries, create image pull secret
kubectl create secret docker-registry regcred \
  --docker-server=<registry-url> \
  --docker-username=<username> \
  --docker-password=<password> \
  -n task-system-master

# Add to values-argo.yaml
imagePullSecrets:
  - name: regcred
```

### Permission Issues

Ensure the `argo-workflow` service account has proper RBAC permissions. Check:

```bash
kubectl get serviceaccount -n task-system-master
kubectl get rolebinding -n task-system-master
```

## Development

### Preview Templates

```bash
# Render templates without applying
helm template task-system . -f values-argo.yaml
```

### Validate Workflow

```bash
# Check workflow syntax
argo lint templates/workflow.yaml
```

### Dry Run

```bash
# Test workflow without execution
argo submit templates/workflow.yaml -n task-system-master --dry-run
```

## Argo Workflows vs Helm Chart Comparison

### When to Use Argo Workflows (This Deployment)

**Pros:**
- ✅ **Native orchestration** - Built-in workflow controller, no init container hacks
- ✅ **Faster execution** - ~5s between jobs vs ~20s with kubectl wait
- ✅ **Rich UI** - Graphical workflow visualization and monitoring
- ✅ **Advanced features** - Parallel execution, DAGs, conditionals, retry logic
- ✅ **Better observability** - Centralized logs, workflow status tracking
- ✅ **Workflow resubmission** - Easy to retry or rerun workflows
- ✅ **Step-level control** - Pause, resume, or retry individual steps
- ✅ **Parameter passing** - Dynamic workflow configuration
- ✅ **Artifact management** - Built-in support for passing data between steps
- ✅ **Scalability** - Better for complex workflows with many dependencies

**Cons:**
- ❌ **Additional infrastructure** - Requires Argo Workflows installation (~3 pods)
- ❌ **Learning curve** - New concepts (workflows, templates, steps)
- ❌ **More complexity** - Additional layer of abstraction
- ❌ **Resource overhead** - Argo controller consumes cluster resources
- ❌ **Dependency** - External project with its own release cycle

**Best for:**
- Complex workflows with multiple branches or parallel execution
- Need for workflow visualization and monitoring
- Advanced retry logic and conditional execution
- DAG (Directed Acyclic Graph) workflows
- Teams familiar with workflow orchestration tools
- Production environments requiring robust orchestration

---

### When to Use Regular Helm Chart (k8s/helm/task-system)

**Pros:**
- ✅ **Simple** - No additional infrastructure required
- ✅ **Native Kubernetes** - Uses standard Jobs and init containers
- ✅ **No dependencies** - Just Kubernetes and Helm
- ✅ **Easy to understand** - Familiar Kubernetes concepts
- ✅ **Minimal overhead** - No workflow controller running
- ✅ **Lower learning curve** - Standard Kubernetes patterns
- ✅ **Self-contained** - Everything in one Helm chart

**Cons:**
- ❌ **Init container overhead** - ~20s between jobs for kubectl wait
- ❌ **No visualization** - Must use kubectl for monitoring
- ❌ **Limited orchestration** - Only sequential execution
- ❌ **Basic retry** - Only job-level backoffLimit
- ❌ **No conditionals** - Can't skip steps based on conditions
- ❌ **Manual resubmission** - Must delete and recreate jobs
- ❌ **Less flexible** - Hard to implement parallel or complex workflows
- ❌ **RBAC required** - Init containers need permissions for kubectl wait

**Best for:**
- Simple sequential execution (A→B→C)
- Small teams familiar with basic Kubernetes
- Minimal infrastructure preference
- Prototypes or development environments
- No need for advanced orchestration features
- Resource-constrained clusters

---

## Comparison Table

| Feature | Argo Workflows | Helm Chart (Jobs) |
|---------|----------------|-------------------|
| **Setup Complexity** | Medium (install Argo) | Simple (just Helm) |
| **Sequential Jobs** | ✅ Native | ✅ Init containers |
| **Parallel Jobs** | ✅ Easy | ❌ Complex |
| **Execution Speed** | ✅ Fast (~5s between) | ⚠️ Slower (~20s between) |
| **Visualization** | ✅ Web UI | ❌ kubectl only |
| **Retry Logic** | ✅ Per-step, advanced | ⚠️ Basic (backoffLimit) |
| **Conditional Logic** | ✅ Yes | ❌ No |
| **DAG Support** | ✅ Yes | ❌ No |
| **Workflow Resubmission** | ✅ Easy (argo resubmit) | ❌ Manual delete/create |
| **Monitoring** | ✅ UI + CLI | ⚠️ kubectl/logs |
| **Learning Curve** | ⚠️ Medium | ✅ Low |
| **Infrastructure** | ⚠️ Argo controller | ✅ None |
| **Resource Overhead** | ⚠️ ~3 pods + controller | ✅ Minimal |
| **Artifact Passing** | ✅ Built-in | ❌ Manual (volumes) |
| **Parameter Support** | ✅ Dynamic | ⚠️ Static (values.yaml) |

---

## Recommendation

**Choose Argo Workflows (this deployment) if:**
- You need workflow visualization and monitoring
- Planning complex workflows with parallel execution
- Want advanced retry and conditional logic
- Team comfortable learning new tools
- Production environment requiring robust orchestration
- Need to scale to more complex pipelines

**Choose Helm Chart (k8s/helm/task-system) if:**
- Simple A→B→C sequential execution is sufficient
- Prefer minimal infrastructure
- Team only knows basic Kubernetes
- Development or prototype environment
- Resource constraints in cluster
- Want fastest deployment with least dependencies

---

## Resources

- [Argo Workflows Documentation](https://argoproj.github.io/argo-workflows/)
- [Argo Workflows GitHub](https://github.com/argoproj/argo-workflows)
- [Workflow Examples](https://github.com/argoproj/argo-workflows/tree/master/examples)
- [Best Practices](https://argoproj.github.io/argo-workflows/workflow-concepts/)
- [Argo Community](https://argoproj.github.io/community/)

## Additional Documentation

- [ARGO_QUICKSTART.md](./ARGO_QUICKSTART.md) - Quick reference guide
- [ARGO_WORKFLOWS_GUIDE.md](./ARGO_WORKFLOWS_GUIDE.md) - Detailed integration guide
- [ARGO_EXAMPLES.md](./ARGO_EXAMPLES.md) - Workflow pattern examples
