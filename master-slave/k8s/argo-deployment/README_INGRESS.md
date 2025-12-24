# Ingress Setup and UI Access Guide

This guide explains how to configure and access the UI services through the Kubernetes Ingress controller.

## How Kubernetes Ingress Works

### The Basic Concept

Ingress is a Kubernetes API object that manages external HTTP/HTTPS access to services inside your cluster. Think of it as a smart HTTP router sitting at the edge of your cluster.

**Without Ingress:**
```
Browser → Service 1 (LoadBalancer IP:80)
Browser → Service 2 (LoadBalancer IP:80)  
Browser → Service 3 (LoadBalancer IP:80)
```
You need multiple LoadBalancers (expensive, complex)

**With Ingress:**
```
Browser → Ingress (one IP:80) → routes to Service 1, 2, or 3
```
One entry point, intelligent routing

### Architecture Components

#### 1. **Ingress Resource** (Your Configuration)
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ui-ingress
spec:
  rules:
  - http:
      paths:
      - path: /master
        backend:
          service:
            name: ui-service
            port: 80
```

This is just a configuration object - it doesn't do anything by itself.

#### 2. **Ingress Controller** (The Implementation)
- A pod running in your cluster (e.g., nginx-ingress-controller)
- Watches for Ingress resources
- Configures itself to route traffic according to the rules
- Common controllers: Nginx, Traefik, HAProxy, Istio Gateway

#### 3. **The Traffic Flow**

```
1. Browser sends request: GET http://172.30.20.15:8080/master

2. Request hits port-forward → Ingress Controller Service (port 80)

3. Ingress Controller (nginx pod) receives request:
   - Looks at the path: /master
   - Checks Ingress rules
   - Finds match: path=/master → ui-service:80

4. Controller proxies request to: ui-service.task-system-master:80

5. Service routes to: ui-service pod (10.244.1.13:8080)

6. Pod responds with HTML

7. Response flows back through controller → port-forward → browser
```

### How This Setup Works

#### Component Breakdown

**1. Ingress Controller (nginx)**
```bash
kubectl get pods -n ingress-nginx
# ingress-nginx-controller-xxx - This is the actual reverse proxy
```

This pod runs nginx with dynamic configuration. When you create/update Ingress resources, the controller:
- Watches Kubernetes API
- Generates nginx configuration
- Reloads nginx

**2. Ingress Service**
```bash
kubectl get svc -n ingress-nginx
# ingress-nginx-controller - NodePort 30855
```

This exposes the controller pod so traffic can reach it from outside.

**3. Ingress Resource**
```bash
kubectl get ingress -n task-system-master
# ui-ingress - Defines routing rules
```

Rules say:
- `/master` → `ui-service` in `task-system-master`
- `/slave` → `ui-service-slave-proxy` → ExternalName → `ui-service` in `task-system-slave`

**4. Port Forward**
```bash
kubectl port-forward -n ingress-nginx svc/ingress-nginx-controller 8080:80
```

This creates a tunnel: `localhost:8080` → `ingress-nginx-controller service:80`

### Path-Based Routing

This deployment uses path-based routing:

```yaml
rules:
- http:
    paths:
    - path: /master
      backend:
        service:
          name: ui-service
          port: 80
    - path: /slave
      backend:
        service:
          name: ui-service-slave-proxy
          port: 80
```

**How it works:**
- Request to `/master/anything` → goes to `ui-service`
- Request to `/slave/anything` → goes to `ui-service-slave-proxy`
- The `rewrite-target: /` annotation strips the prefix, so the backend sees `/anything` instead of `/master/anything`

### Cross-Namespace Routing

The setup uses an ExternalName service to route from master namespace to slave namespace:

```yaml
# In task-system-master namespace
apiVersion: v1
kind: Service
metadata:
  name: ui-service-slave-proxy
spec:
  type: ExternalName
  externalName: ui-service.task-system-slave.svc.cluster.local
```

**What happens:**
1. Ingress in `task-system-master` routes `/slave` to `ui-service-slave-proxy`
2. `ui-service-slave-proxy` is an ExternalName service (just a DNS alias)
3. DNS resolves to: `ui-service.task-system-slave.svc.cluster.local`
4. Traffic reaches the actual `ui-service` in `task-system-slave` namespace

**Why this works:**
- Ingress resources are namespace-scoped
- Services normally can't reference other namespaces
- ExternalName bypasses this by using DNS

### Behind The Scenes: What nginx Does

When the Ingress is created, the controller generates nginx configuration similar to:

```nginx
server {
    listen 80;
    
    location /master {
        rewrite ^/master/?(.*)$ /$1 break;
        proxy_pass http://ui-service.task-system-master.svc.cluster.local:80;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
    
    location /slave {
        rewrite ^/slave/?(.*)$ /$1 break;
        proxy_pass http://ui-service.task-system-slave.svc.cluster.local:80;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

### The Complete Traffic Flow

```
Internet/Windows Browser
   ↓
WSL Port Forward (8080 → 80)
   ↓
Ingress Controller Service (nginx pod)
   ↓
[Ingress Rules: path-based routing]
   ↓
Service 1 (master)    Service 2 (slave via ExternalName)
   ↓                       ↓
Pod(s) in zone-a        Pod(s) in zone-b
```

This is why the port-forward method works perfectly from Windows - it creates a direct tunnel through WSL networking!

### Ingress vs Other Solutions

| Solution | Use Case | Complexity | Features |
|----------|----------|------------|----------|
| **NodePort** | Dev/testing | Low | Direct node access |
| **LoadBalancer** | Simple external access | Medium | One IP per service |
| **Ingress** | HTTP routing, multiple services | Medium | Path/host routing, SSL |
| **Service Mesh** (Istio) | Advanced traffic management | High | Full observability |

**Why Ingress:**
- ✅ One external IP for many services
- ✅ HTTP path/host routing
- ✅ SSL termination
- ✅ Advanced features (auth, rate limiting)
- ❌ HTTP/HTTPS only (no TCP/UDP)

## Architecture Overview

The deployment uses a unified Ingress resource to provide a single entry point for both UI services:

```
Browser → Ingress Controller → Master UI (task-system-master namespace)
                             └→ Slave UI (task-system-slave namespace)
```

- **Master UI**: Accessible at `/master` path
- **Slave UI**: Accessible at `/slave` path
- **Cross-namespace routing**: ExternalName service enables routing from master namespace to slave namespace

## Prerequisites

### 1. Enable Ingress Controller

#### For Minikube:
```bash
minikube addons enable ingress
```

#### For Bare-Metal Kubernetes:
```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/baremetal/deploy.yaml
```

### 2. Verify Ingress Controller

```bash
# Check Ingress controller pods
kubectl get pods -n ingress-nginx

# Check Ingress controller service
kubectl get svc -n ingress-nginx
```

Expected output:
```
NAME                       READY   STATUS    RESTARTS   AGE
ingress-nginx-controller-xxx   1/1     Running   0          5m
```

## Deployment

The Ingress resource is automatically deployed with the Helm template:

```bash
cd k8s/argo-deployment
helm template . -f values-argo.yaml | kubectl apply -f -
```

### Verify Ingress Deployment

```bash
kubectl get ingress -n task-system-master
```

Expected output:
```
NAME         CLASS   HOSTS   ADDRESS        PORTS   AGE
ui-ingress   nginx   *       192.168.49.2   80      5m
```

## Access Methods

### Method 1: Port Forward (Recommended for Development)

This method works reliably across all environments including WSL2/Windows setups.

#### Step 1: Start Port Forward

In a terminal, run:
```bash
kubectl port-forward -n ingress-nginx svc/ingress-nginx-controller 8080:80 --address 0.0.0.0
```

**Note**: Keep this terminal running. The `--address 0.0.0.0` flag allows access from other machines/Windows.

#### Step 2: Get Your IP Address

**On Linux/WSL:**
```bash
hostname -I | awk '{print $1}'
```

Example output: `172.30.20.15`

**On macOS:**
```bash
ipconfig getifaddr en0
```

#### Step 3: Access from Browser

- **Master UI**: `http://<YOUR_IP>:8080/master`
- **Slave UI**: `http://<YOUR_IP>:8080/slave`

**Example (WSL IP is 172.30.20.15):**
- Master: `http://172.30.20.15:8080/master`
- Slave: `http://172.30.20.15:8080/slave`

**From Windows browser**: Use the WSL IP address shown above.

**From Linux/WSL browser**: You can also use `http://localhost:8080/master`

---

### Method 2: Direct NodePort Access

If Ingress controller is using NodePort (default for minikube):

#### Step 1: Get NodePort

```bash
kubectl get svc -n ingress-nginx ingress-nginx-controller
```

Example output:
```
NAME                       TYPE       CLUSTER-IP       PORT(S)
ingress-nginx-controller   NodePort   10.102.184.121   80:30855/TCP,443:32243/TCP
```

Note the NodePort for port 80 (e.g., `30855`)

#### Step 2: Get Node IP

**For Minikube:**
```bash
minikube ip
```

**For Bare-Metal:**
```bash
kubectl get nodes -o wide
# Use any node's INTERNAL-IP or EXTERNAL-IP
```

#### Step 3: Access from Browser

- **Master UI**: `http://<NODE_IP>:<NODEPORT>/master`
- **Slave UI**: `http://<NODE_IP>:<NODEPORT>/slave`

**Example (minikube IP: 192.168.49.2, NodePort: 30855):**
- Master: `http://192.168.49.2:30855/master`
- Slave: `http://192.168.49.2:30855/slave`

**Note**: This may not work from Windows if the Node IP is not routable from Windows host.

---

### Method 3: Minikube Tunnel (Minikube Only)

Minikube tunnel exposes LoadBalancer services on localhost.

#### Step 1: Start Tunnel

In a separate terminal (requires sudo):
```bash
sudo minikube tunnel
```

**Note**: Keep this running.

#### Step 2: Access from Browser

- **Master UI**: `http://192.168.49.2/master`
- **Slave UI**: `http://192.168.49.2/slave`

**Limitation**: This typically only works from the Linux/WSL environment, not from Windows.

---

### Method 4: LoadBalancer with MetalLB (Production-like)

For bare-metal clusters with MetalLB configured:

#### Step 1: Enable MetalLB

```bash
# For minikube
minikube addons enable metallb
minikube addons configure metallb
# Enter IP range, e.g., 192.168.56.10-192.168.56.20
```

#### Step 2: Patch Ingress Service to LoadBalancer

```bash
kubectl patch svc ingress-nginx-controller -n ingress-nginx -p '{"spec":{"type":"LoadBalancer"}}'
```

#### Step 3: Get LoadBalancer IP

```bash
kubectl get svc -n ingress-nginx ingress-nginx-controller
```

Wait for `EXTERNAL-IP` to be assigned.

#### Step 4: Access from Browser

- **Master UI**: `http://<EXTERNAL_IP>/master`
- **Slave UI**: `http://<EXTERNAL_IP>/slave`

---

## Troubleshooting

### 404 Not Found

**Problem**: Getting 404 when accessing `/master` or `/slave`

**Solutions**:
1. Check if Ingress is deployed:
   ```bash
   kubectl get ingress -n task-system-master
   ```

2. Check Ingress rules:
   ```bash
   kubectl describe ingress ui-ingress -n task-system-master
   ```

3. Verify backend services are running:
   ```bash
   kubectl get pods -n task-system-master -l app=ui-service
   kubectl get pods -n task-system-slave -l app=ui-service
   ```

4. Check Ingress controller logs:
   ```bash
   kubectl logs -n ingress-nginx deploy/ingress-nginx-controller --tail=50
   ```

### Connection Refused / Timeout

**Problem**: Cannot connect to the IP:Port

**Solutions**:
1. Verify port-forward is running:
   ```bash
   ps aux | grep "port-forward" | grep -v grep
   ```

2. Check if the port is listening:
   ```bash
   netstat -tuln | grep 8080
   ```

3. For WSL/Windows: Ensure Windows Firewall allows the port:
   ```powershell
   # Run in Windows PowerShell as Administrator
   New-NetFirewallRule -DisplayName "Kubectl Port Forward" -Direction Inbound -LocalPort 8080 -Protocol TCP -Action Allow
   ```

4. Verify WSL IP is correct and accessible from Windows:
   ```bash
   # In WSL
   hostname -I
   
   # From Windows Command Prompt
   ping <WSL_IP>
   ```

### ExternalName Service Not Resolving

**Problem**: `/slave` route not working (cross-namespace routing)

**Solutions**:
1. Check ExternalName service:
   ```bash
   kubectl get svc ui-service-slave-proxy -n task-system-master
   ```

2. Verify slave UI service exists:
   ```bash
   kubectl get svc ui-service -n task-system-slave
   ```

3. Test DNS resolution from a pod:
   ```bash
   kubectl run -it --rm debug --image=nicolaka/netshoot --restart=Never -- nslookup ui-service.task-system-slave.svc.cluster.local
   ```

### Ingress Controller Not Starting

**Problem**: Ingress controller pod is not running

**Solutions**:
1. Check pod status:
   ```bash
   kubectl get pods -n ingress-nginx
   kubectl describe pod -n ingress-nginx -l app.kubernetes.io/component=controller
   ```

2. For minikube, try disabling and re-enabling:
   ```bash
   minikube addons disable ingress
   minikube addons enable ingress
   ```

3. Check if required ports are available (80, 443, 8443)

## Testing the Ingress

### Test from Command Line

```bash
# Get your IP
IP=$(hostname -I | awk '{print $1}')

# Test master UI
curl -s http://${IP}:8080/master | head -20

# Test slave UI
curl -s http://${IP}:8080/slave | head -20
```

### Test from Inside Cluster

```bash
# Test from Ingress controller itself
kubectl exec -n ingress-nginx deploy/ingress-nginx-controller -- curl -s http://localhost:80/master | head -10

# Test from a temporary pod
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- curl -s http://ui-service.task-system-master/
```

## Security Considerations

### Production Recommendations

1. **Add TLS/HTTPS**:
   ```yaml
   apiVersion: networking.k8s.io/v1
   kind: Ingress
   metadata:
     annotations:
       cert-manager.io/cluster-issuer: letsencrypt-prod
   spec:
     tls:
     - hosts:
       - task-system.yourdomain.com
       secretName: task-system-tls
   ```

2. **Add Authentication**:
   ```yaml
   annotations:
     nginx.ingress.kubernetes.io/auth-type: basic
     nginx.ingress.kubernetes.io/auth-secret: basic-auth
     nginx.ingress.kubernetes.io/auth-realm: 'Authentication Required'
   ```

3. **Rate Limiting**:
   ```yaml
   annotations:
     nginx.ingress.kubernetes.io/limit-rps: "10"
   ```

4. **IP Whitelisting**:
   ```yaml
   annotations:
     nginx.ingress.kubernetes.io/whitelist-source-range: "10.0.0.0/8,172.16.0.0/12"
   ```

## Quick Reference

| Method | Access URL | Requirements | Windows Compatible |
|--------|-----------|--------------|-------------------|
| Port Forward | `http://<IP>:8080/master` | kubectl | ✅ Yes |
| NodePort | `http://<NODE_IP>:<NODEPORT>/master` | Accessible node IP | ⚠️ Maybe |
| Minikube Tunnel | `http://192.168.49.2/master` | minikube, sudo | ❌ No |
| LoadBalancer | `http://<LB_IP>/master` | MetalLB or cloud LB | ✅ Yes |

**Recommended for WSL2/Windows**: Port Forward method (`kubectl port-forward --address 0.0.0.0`)
