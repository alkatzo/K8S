# Argo Workflows Integration Guide

This guide explains how to use Argo Workflows instead of Kubernetes Jobs with init containers for job sequencing.

## Architecture Comparison

### Current Approach (Kubernetes Jobs + Init Containers)
```
job-a (runs) → job-b (waits via init container) → job-c (waits via init container)
```
- Uses `kubectl wait` in init containers
- Requires RBAC for job-executor service account
- Each job is independent

### Argo Workflows Approach
```
Workflow Controller → Step 1 (job-a) → Step 2 (job-b) → Step 3 (job-c)
```
- Centralized workflow orchestration
- Native sequential execution
- Built-in monitoring and retry logic

## Installation Steps

### 1. Install Argo Workflows in Your Cluster

```bash
# Create namespace
kubectl create namespace argo

# Install Argo Workflows
kubectl apply -n argo -f https://github.com/argoproj/argo-workflows/releases/download/v3.5.2/install.yaml

# Wait for Argo to be ready
kubectl wait --for=condition=ready pod -l app=workflow-controller -n argo --timeout=300s
```

**Or using Helm:**
```bash
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
helm install argo-workflows argo/argo-workflows -n argo --create-namespace
```

### 2. Install Argo CLI (Optional but Recommended)

**Linux:**
```bash
curl -sLO https://github.com/argoproj/argo-workflows/releases/download/v3.5.2/argo-linux-amd64.gz
gunzip argo-linux-amd64.gz
chmod +x argo-linux-amd64
sudo mv ./argo-linux-amd64 /usr/local/bin/argo
```

**macOS:**
```bash
brew install argo
```

### 3. Update values.yaml

Add Argo Workflows configuration to your `values.yaml`:

```yaml
# Argo Workflows configuration
argoWorkflow:
  enabled: false  # Set to true to use Argo instead of regular Jobs
  
# Disable regular jobs when using Argo
jobA:
  enabled: true  # Keep enabled if NOT using Argo
  # ... rest of config

jobB:
  enabled: true  # Keep enabled if NOT using Argo
  # ... rest of config

jobC:
  enabled: true  # Keep enabled if NOT using Argo
  # ... rest of config
```

### 4. Deploy with Argo Workflows

**Option A: Use Argo Workflows (disable regular jobs)**
```bash
helm upgrade --install task-system ./k8s/helm/task-system \
  --set argoWorkflow.enabled=true \
  --set jobA.enabled=false \
  --set jobB.enabled=false \
  --set jobC.enabled=false \
  --create-namespace
```

**Option B: Use regular Kubernetes Jobs (current approach)**
```bash
helm upgrade --install task-system ./k8s/helm/task-system \
  --set argoWorkflow.enabled=false \
  --set jobA.enabled=true \
  --set jobB.enabled=true \
  --set jobC.enabled=true \
  --create-namespace
```

## Using Argo Workflows

### Submit a Workflow

```bash
# Submit workflow and watch execution
argo submit -n task-system-master \
  k8s/helm/task-system/templates/workflow.yaml \
  --watch

# Submit without watching
argo submit -n task-system-master \
  k8s/helm/task-system/templates/workflow.yaml
```

### Monitor Workflows

```bash
# List all workflows
argo list -n task-system-master

# Get workflow details
argo get <workflow-name> -n task-system-master

# View workflow logs
argo logs <workflow-name> -n task-system-master

# Follow logs in real-time
argo logs <workflow-name> -n task-system-master -f

# View logs for specific step
argo logs <workflow-name> -n task-system-master run-job-a
```

### Manage Workflows

```bash
# Delete a workflow
argo delete <workflow-name> -n task-system-master

# Resubmit a workflow
argo resubmit <workflow-name> -n task-system-master

# Stop a running workflow
argo stop <workflow-name> -n task-system-master

# Retry a failed workflow
argo retry <workflow-name> -n task-system-master
```

## Access Argo UI

### Port Forward Method
```bash
kubectl -n argo port-forward deployment/argo-server 2746:2746
```
Then open: https://localhost:2746

### Create Ingress (Production)
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argo-workflows
  namespace: argo
spec:
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

## Workflow Features

### 1. Sequential Execution (Current Implementation)
```yaml
steps:
- - name: run-job-a
    template: job-a-template
- - name: run-job-b
    template: job-b-template
- - name: run-job-c
    template: job-c-template
```

### 2. Parallel Execution (Example)
```yaml
steps:
- - name: run-job-a
    template: job-a-template
- - name: run-job-b-1
    template: job-b-template
  - name: run-job-b-2
    template: job-b-template
  - name: run-job-b-3
    template: job-b-template
- - name: run-job-c
    template: job-c-template
```

### 3. Conditional Execution (Example)
```yaml
steps:
- - name: run-job-a
    template: job-a-template
- - name: run-job-b
    template: job-b-template
    when: "{{steps.run-job-a.outputs.result}} == success"
```

### 4. Retry Logic (Example)
```yaml
- name: job-a-template
  retryStrategy:
    limit: 3
    retryPolicy: "Always"
  container:
    image: job-a:latest
```

## Troubleshooting

### Check Argo Controller Logs
```bash
kubectl logs -n argo deployment/workflow-controller
```

### Check Argo Server Logs
```bash
kubectl logs -n argo deployment/argo-server
```

### Workflow Stuck/Failed
```bash
# Get detailed workflow info
argo get <workflow-name> -n task-system-master -o yaml

# Check pod events
kubectl describe pod -n task-system-master -l workflows.argoproj.io/workflow=<workflow-name>
```

### Permission Issues
Ensure the `argo-workflow` service account has proper RBAC permissions (defined in `argo-rbac.yaml`).

## Comparison: Current vs Argo

| Feature | Current (Jobs + InitContainers) | Argo Workflows |
|---------|--------------------------------|----------------|
| **Setup Complexity** | Simple | Medium |
| **Sequential Jobs** | ✅ Yes (with init containers) | ✅ Yes (native) |
| **Parallel Jobs** | ❌ Complex | ✅ Easy |
| **Retry Logic** | ⚠️ Job backoffLimit only | ✅ Per-step retry |
| **Monitoring** | ⚠️ kubectl/logs | ✅ UI + CLI |
| **Conditional Logic** | ❌ No | ✅ Yes |
| **DAG Support** | ❌ No | ✅ Yes |
| **Extra Infrastructure** | ❌ None | ⚠️ Argo controller |
| **Learning Curve** | Low | Medium |

## Recommendation

**Keep your current approach if:**
- ✅ Simple sequential execution (A→B→C)
- ✅ Team familiar with basic Kubernetes
- ✅ Minimal infrastructure preferred
- ✅ No need for advanced orchestration

**Switch to Argo Workflows if:**
- ✅ Complex workflows with multiple branches
- ✅ Need parallel execution
- ✅ Want workflow visualization
- ✅ Require advanced retry/conditional logic
- ✅ Planning to scale to more complex pipelines

## Next Steps

1. Install Argo Workflows in your cluster
2. Test the workflow in the master namespace
3. Verify job execution order
4. Access the Argo UI to visualize workflow
5. Decide whether to migrate based on your needs

## Resources

- [Argo Workflows Documentation](https://argoproj.github.io/argo-workflows/)
- [Workflow Examples](https://github.com/argoproj/argo-workflows/tree/master/examples)
- [Best Practices](https://argoproj.github.io/argo-workflows/workflow-concepts/)
