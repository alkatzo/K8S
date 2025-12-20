# Argo Workflows Integration - Quick Reference

## What Was Added

1. **workflow.yaml** - Argo Workflow definition for sequential job execution
2. **argo-rbac.yaml** - RBAC permissions for Argo workflow execution
3. **values.yaml** - Added `argoWorkflow.enabled` configuration
4. **install-argo.sh** - Automated installation script
5. **ARGO_WORKFLOWS_GUIDE.md** - Complete documentation
6. **ARGO_EXAMPLES.md** - Various workflow patterns and examples

## Quick Start

### 1. Install Argo Workflows
```bash
cd /home/myuser/GitHub/K8S/master-slave
./install-argo.sh
```

### 2. Deploy with Argo Enabled
```bash
# Build images first (if needed)
./build-images.sh

# Deploy with Argo Workflows
helm upgrade --install task-system ./k8s/helm/task-system \
  --set argoWorkflow.enabled=true \
  --set jobA.enabled=false \
  --set jobB.enabled=false \
  --set jobC.enabled=false \
  --create-namespace
```

### 3. Submit Workflow
```bash
# Using Argo CLI
argo submit -n task-system-master \
  k8s/helm/task-system/templates/workflow.yaml --watch

# Or using kubectl
kubectl create -f k8s/helm/task-system/templates/workflow.yaml
```

### 4. Monitor Workflow
```bash
# List workflows
argo list -n task-system-master

# Get workflow details
argo get <workflow-name> -n task-system-master

# View logs
argo logs <workflow-name> -n task-system-master -f
```

### 5. Access Argo UI
```bash
kubectl -n argo port-forward deployment/argo-server 2746:2746
# Open: https://localhost:2746
```

## File Locations

```
master-slave/
├── install-argo.sh                          # Installation script
├── ARGO_WORKFLOWS_GUIDE.md                  # Complete guide
├── ARGO_EXAMPLES.md                         # Workflow patterns
├── k8s/
│   ├── argo-workflows-install.yaml          # Installation notes
│   └── helm/
│       └── task-system/
│           ├── values.yaml                  # Added argoWorkflow config
│           └── templates/
│               ├── workflow.yaml            # Argo Workflow definition
│               ├── argo-rbac.yaml           # RBAC for Argo
│               ├── job-a.yaml               # Regular job (keep for fallback)
│               ├── job-b.yaml               # Regular job (keep for fallback)
│               └── job-c.yaml               # Regular job (keep for fallback)
```

## Configuration Toggle

### Use Argo Workflows
```bash
helm upgrade --install task-system ./k8s/helm/task-system \
  --set argoWorkflow.enabled=true \
  --set jobA.enabled=false \
  --set jobB.enabled=false \
  --set jobC.enabled=false
```

### Use Regular Jobs (Current Approach)
```bash
helm upgrade --install task-system ./k8s/helm/task-system \
  --set argoWorkflow.enabled=false \
  --set jobA.enabled=true \
  --set jobB.enabled=true \
  --set jobC.enabled=true
```

## Key Commands

### Argo CLI
```bash
# Submit workflow
argo submit workflow.yaml -n namespace

# List workflows
argo list -n namespace

# Get workflow status
argo get workflow-name -n namespace

# View logs
argo logs workflow-name -n namespace

# Delete workflow
argo delete workflow-name -n namespace

# Resubmit workflow
argo resubmit workflow-name -n namespace

# Stop workflow
argo stop workflow-name -n namespace

# Watch workflow
argo watch workflow-name -n namespace
```

### Kubectl (Alternative)
```bash
# List workflows
kubectl get workflows -n namespace

# Describe workflow
kubectl describe workflow workflow-name -n namespace

# Get workflow YAML
kubectl get workflow workflow-name -n namespace -o yaml

# Delete workflow
kubectl delete workflow workflow-name -n namespace
```

## Comparison Table

| Aspect | Regular Jobs + InitContainers | Argo Workflows |
|--------|------------------------------|----------------|
| Setup | ✅ Simple | ⚠️ Requires Argo installation |
| Sequential Jobs | ✅ Yes | ✅ Yes |
| Parallel Jobs | ❌ Complex | ✅ Easy |
| Monitoring | ⚠️ kubectl/logs | ✅ UI + CLI |
| Retry Logic | ⚠️ Basic | ✅ Advanced |
| Conditional Logic | ❌ No | ✅ Yes |
| DAG Support | ❌ No | ✅ Yes |
| Visualization | ❌ No | ✅ Yes |
| Learning Curve | ✅ Low | ⚠️ Medium |

## When to Use What

### Stay with Regular Jobs If:
- Simple sequential execution (A→B→C)
- Team familiar with basic Kubernetes
- Minimal infrastructure preferred
- No plans for complex workflows

### Switch to Argo Workflows If:
- Need parallel execution
- Complex dependencies (DAG)
- Require workflow visualization
- Want advanced retry/conditional logic
- Planning to scale workflows

## Troubleshooting

### Argo Controller Issues
```bash
kubectl logs -n argo deployment/workflow-controller
kubectl describe pod -n argo -l app=workflow-controller
```

### Workflow Stuck
```bash
argo get workflow-name -n namespace -o yaml
kubectl describe pod -l workflows.argoproj.io/workflow=workflow-name -n namespace
```

### Permission Errors
Check RBAC: `kubectl get rolebinding -n namespace`

## Next Steps

1. ✅ Files created and ready to use
2. 📖 Read `ARGO_WORKFLOWS_GUIDE.md` for detailed documentation
3. 📖 Browse `ARGO_EXAMPLES.md` for workflow patterns
4. 🚀 Run `./install-argo.sh` to install Argo Workflows
5. 🧪 Test the workflow in your cluster
6. 🎯 Decide whether to adopt Argo based on your needs

## Resources

- [Argo Workflows Docs](https://argoproj.github.io/argo-workflows/)
- [GitHub Repository](https://github.com/argoproj/argo-workflows)
- [Examples](https://github.com/argoproj/argo-workflows/tree/master/examples)
- [Community](https://argoproj.github.io/community/)
