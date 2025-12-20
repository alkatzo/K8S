Postgres for cluster (simple StatefulSet)
=========================================

What this provides
- A Kubernetes Secret `postgres-secret` holding DB name, user, and password (created from stringData in the manifest).
- A ClusterIP Service `postgres` for clients to connect at port 5432.
- A headless Service `postgres-headless` used by the StatefulSet.
- A StatefulSet `postgres` (1 replica) with a PersistentVolumeClaim template `postgres-data` (10Gi).

How to apply
1. (Optional) Edit `kubernetes/postgres.yaml` to set a different password, user or storageClassName.
2. Apply the manifest:

```powershell
kubectl apply -f kubernetes/postgres.yaml
```

What to expect
- A Secret, two Services and a StatefulSet will be created.
- The StatefulSet creates a PVC; the underlying PV will be provisioned by your cluster's storage class.

Check status:

```powershell
kubectl get pods,svc,pvc -l app=postgres
kubectl describe statefulset postgres
kubectl logs statefulset/postgres -c postgres
```

Connecting from `users-api`
- The `users-api` should use a connection string like:

  postgres://POSTGRES_USER:POSTGRES_PASSWORD@postgres:5432/POSTGRES_DB

- Example (matches the sample Secret in the manifest):

  postgres://postgres:password@postgres:5432/users

- The `kubernetes/users.yaml` in this repo was updated to use a sample `POSTGRES_CONNECTION_URI` that points to `postgres` service. Replace the placeholder with the correct secret or set a Kubernetes Secret/ConfigMap and mount it into the `users-api` deployment for production.

Notes and next steps
- For production, don't store credentials in plain YAML. Create a Kubernetes Secret beforehand (kubectl create secret generic ...) or use a secrets manager.
- Consider setting up a backup strategy and configuring resource requests/limits for your cluster size.
- If you want a HA Postgres setup, consider using Patroni, Stolon or a managed RDS instance instead.
