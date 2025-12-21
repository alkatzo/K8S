# Argo Workflows Examples

This file contains various Argo Workflow patterns you can use in your task system.

---
## 1. Basic Sequential Workflow (Current Implementation)

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  name: sequential-jobs
spec:
  entrypoint: main
  templates:
  - name: main
    steps:
    - - name: job-a
        template: run-job-a
    - - name: job-b
        template: run-job-b
    - - name: job-c
        template: run-job-c
  
  - name: run-job-a
    container:
      image: job-a:latest
      command: ["python", "app.py"]
```

---
## 2. Parallel Execution with Fan-Out/Fan-In

Run multiple jobs in parallel, then continue when all complete:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  name: parallel-jobs
spec:
  entrypoint: main
  templates:
  - name: main
    steps:
    # First job runs alone
    - - name: init-job
        template: run-job-a
    
    # Multiple jobs run in parallel (fan-out)
    - - name: process-job-1
        template: run-job-b
      - name: process-job-2
        template: run-job-b
      - name: process-job-3
        template: run-job-b
    
    # Final job runs after all parallel jobs complete (fan-in)
    - - name: finalize-job
        template: run-job-c
```

---
## 3. Conditional Execution

Run jobs based on previous step results:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  name: conditional-jobs
spec:
  entrypoint: main
  templates:
  - name: main
    steps:
    - - name: check-data
        template: run-job-a
    
    # Only run if job-a succeeded
    - - name: process-data
        template: run-job-b
        when: "{{steps.check-data.outputs.result}} == success"
    
    # Run job-c regardless
    - - name: cleanup
        template: run-job-c
```

---
## 4. Retry Strategy

Add retry logic to individual steps:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  name: retry-jobs
spec:
  entrypoint: main
  templates:
  - name: main
    steps:
    - - name: flaky-job
        template: run-with-retry
  
  - name: run-with-retry
    retryStrategy:
      limit: 3                    # Retry up to 3 times
      retryPolicy: "OnFailure"    # Only retry on failure
      backoff:
        duration: "10s"           # Wait 10s before retry
        factor: 2                 # Double wait time each retry
        maxDuration: "5m"         # Max wait time
    container:
      image: job-a:latest
      command: ["python", "app.py"]
```

---
## 5. DAG (Directed Acyclic Graph)

More complex dependencies:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  name: dag-jobs
spec:
  entrypoint: main
  templates:
  - name: main
    dag:
      tasks:
      - name: A
        template: run-job-a
      
      - name: B
        dependencies: [A]
        template: run-job-b
      
      - name: C
        dependencies: [A]
        template: run-job-c
      
      - name: D
        dependencies: [B, C]
        template: run-job-d
      
      # Visual representation:
      #     A
      #    / \
      #   B   C
      #    \ /
      #     D
```

---
## 6. WorkflowTemplate (Reusable)

Create reusable workflow templates:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: WorkflowTemplate
metadata:
  name: job-template
  namespace: task-system-master
spec:
  templates:
  - name: process-task
    inputs:
      parameters:
      - name: task-name
      - name: postgres-host
    container:
      image: job-a:latest
      env:
      - name: TASK_NAME
        value: "{{inputs.parameters.task-name}}"
      - name: POSTGRES_HOST
        value: "{{inputs.parameters.postgres-host}}"

---
# Use the template
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  name: use-template
spec:
  entrypoint: main
  templates:
  - name: main
    steps:
    - - name: job-1
        templateRef:
          name: job-template
          template: process-task
        arguments:
          parameters:
          - name: task-name
            value: "Task-A"
          - name: postgres-host
            value: "postgres-service"
```

---
## 7. CronWorkflow (Scheduled Workflows)

Run workflows on a schedule:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: CronWorkflow
metadata:
  name: scheduled-jobs
  namespace: task-system-master
spec:
  schedule: "0 2 * * *"  # Run at 2 AM daily
  timezone: "America/Los_Angeles"
  concurrencyPolicy: "Forbid"  # Don't run if previous workflow still running
  startingDeadlineSeconds: 0
  workflowSpec:
    entrypoint: main
    templates:
    - name: main
      steps:
      - - name: daily-job
          template: run-job-a
    
    - name: run-job-a
      container:
        image: job-a:latest
        command: ["python", "app.py"]
```

---
## 8. With Parameters (Dynamic Workflows)

Pass parameters to workflows:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  name: parameterized-workflow
spec:
  entrypoint: main
  arguments:
    parameters:
    - name: num-tasks
      value: "5"
    - name: postgres-host
      value: "postgres-service"
  
  templates:
  - name: main
    steps:
    - - name: generate-tasks
        template: task-generator
        arguments:
          parameters:
          - name: count
            value: "{{workflow.parameters.num-tasks}}"
  
  - name: task-generator
    inputs:
      parameters:
      - name: count
    container:
      image: job-a:latest
      env:
      - name: NUM_TASKS
        value: "{{inputs.parameters.count}}"
      - name: POSTGRES_HOST
        value: "{{workflow.parameters.postgres-host}}"
```

Submit with custom parameters:
```bash
argo submit workflow.yaml -p num-tasks=10 -p postgres-host="custom-db"
```

---
## 9. Output Artifacts

Share data between workflow steps:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  name: artifact-workflow
spec:
  entrypoint: main
  templates:
  - name: main
    steps:
    - - name: generate-data
        template: producer
    - - name: consume-data
        template: consumer
        arguments:
          artifacts:
          - name: data-file
            from: "{{steps.generate-data.outputs.artifacts.result}}"
  
  - name: producer
    container:
      image: job-a:latest
      command: ["sh", "-c"]
      args: ["echo 'hello world' > /tmp/result.txt"]
    outputs:
      artifacts:
      - name: result
        path: /tmp/result.txt
  
  - name: consumer
    inputs:
      artifacts:
      - name: data-file
        path: /tmp/input.txt
    container:
      image: job-b:latest
      command: ["cat", "/tmp/input.txt"]
```

---
## 10. Volumes and PVCs

Share persistent storage across steps:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  name: volume-workflow
spec:
  entrypoint: main
  volumeClaimTemplates:
  - metadata:
      name: workdir
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 1Gi
  
  templates:
  - name: main
    steps:
    - - name: write-data
        template: writer
    - - name: read-data
        template: reader
  
  - name: writer
    container:
      image: job-a:latest
      command: ["sh", "-c"]
      args: ["echo 'data' > /work/file.txt"]
      volumeMounts:
      - name: workdir
        mountPath: /work
  
  - name: reader
    container:
      image: job-b:latest
      command: ["cat", "/work/file.txt"]
      volumeMounts:
      - name: workdir
        mountPath: /work
```

---
## How to Use These Examples

1. **Copy the desired pattern** to a new file (e.g., `my-workflow.yaml`)
2. **Customize** the job images, commands, and parameters
3. **Submit** the workflow:
   ```bash
   argo submit -n task-system-master my-workflow.yaml --watch
   ```
4. **Monitor** execution:
   ```bash
   argo list -n task-system-master
   argo get <workflow-name> -n task-system-master
   argo logs <workflow-name> -n task-system-master
   ```

---
## Best Practices

1. **Use WorkflowTemplates** for reusable patterns
2. **Add retry strategies** for network-dependent operations
3. **Use DAG** for complex dependencies
4. **Implement proper error handling** with conditional steps
5. **Set resource limits** on all containers
6. **Use volumes** for sharing data between steps
7. **Add meaningful labels** for organization
8. **Use CronWorkflows** for scheduled tasks
9. **Test in development** namespace first
10. **Monitor workflows** via UI or CLI

---
## Resources

- [Official Examples](https://github.com/argoproj/argo-workflows/tree/master/examples)
- [Workflow Syntax](https://argoproj.github.io/argo-workflows/workflow-concepts/)
- [Fields Reference](https://argoproj.github.io/argo-workflows/fields/)
