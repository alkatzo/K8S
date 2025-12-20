#!/bin/bash
# Script to deploy PostgreSQL HA cluster with Zalando Operator

set -e

echo "=================================================="
echo "PostgreSQL HA Cluster Setup"
echo "=================================================="
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Configuration
OPERATOR_NAMESPACE="postgres-operator"
APP_NAMESPACE="default"
CLUSTER_NAME="users-db-cluster"

# Step 1: Install Zalando PostgreSQL Operator
echo -e "${YELLOW}Step 1: Installing Zalando PostgreSQL Operator...${NC}"

helm repo add postgres-operator-charts https://opensource.zalando.com/postgres-operator/charts/postgres-operator 2>/dev/null || true
helm repo update

if helm list -n $OPERATOR_NAMESPACE | grep -q "postgres-operator"; then
    echo "Operator already installed"
else
    helm install postgres-operator postgres-operator-charts/postgres-operator \
        --namespace $OPERATOR_NAMESPACE \
        --create-namespace \
        --set configKubernetes.enable_pod_antiaffinity=true
fi

echo -e "${GREEN}✓ Operator installed${NC}"

# Step 2: Wait for operator to be ready
echo ""
echo -e "${YELLOW}Step 2: Waiting for operator to be ready...${NC}"
kubectl wait --for=condition=ready pod \
    -l app.kubernetes.io/name=postgres-operator \
    -n $OPERATOR_NAMESPACE \
    --timeout=300s

echo -e "${GREEN}✓ Operator is ready${NC}"

# Step 3: Deploy PostgreSQL cluster
echo ""
echo -e "${YELLOW}Step 3: Deploying PostgreSQL HA cluster...${NC}"
kubectl apply -f kubernetes/postgres-cluster-ha.yaml -n $APP_NAMESPACE

echo "Waiting for cluster to be created..."
sleep 10

# Step 4: Wait for cluster to be ready
echo ""
echo -e "${YELLOW}Step 4: Waiting for cluster pods to be ready...${NC}"
for i in 0 1 2; do
    echo "Waiting for pod ${CLUSTER_NAME}-${i}..."
    kubectl wait --for=condition=ready pod/${CLUSTER_NAME}-${i} \
        -n $APP_NAMESPACE \
        --timeout=300s || true
done

echo -e "${GREEN}✓ Cluster is ready${NC}"

# Step 5: Display cluster info
echo ""
echo "=================================================="
echo -e "${GREEN}Cluster Information${NC}"
echo "=================================================="

echo ""
echo "Pods:"
kubectl get pods -l cluster-name=$CLUSTER_NAME -n $APP_NAMESPACE \
    -o custom-columns=NAME:.metadata.name,ROLE:.metadata.labels.spilo-role,STATUS:.status.phase

echo ""
echo "Services:"
kubectl get svc -l cluster-name=$CLUSTER_NAME -n $APP_NAMESPACE

echo ""
echo "PVCs:"
kubectl get pvc -l cluster-name=$CLUSTER_NAME -n $APP_NAMESPACE

echo ""
echo "=================================================="
echo -e "${GREEN}Connection Information${NC}"
echo "=================================================="

# Get password
PASSWORD=$(kubectl get secret postgres.${CLUSTER_NAME}.credentials.postgresql.acid.zalan.do \
    -n $APP_NAMESPACE \
    -o jsonpath='{.data.password}' 2>/dev/null | base64 --decode || echo "N/A")

echo ""
echo "Primary (Read/Write):"
echo "  Host: ${CLUSTER_NAME}.${APP_NAMESPACE}.svc.cluster.local"
echo "  Port: 5432"
echo "  Database: users"
echo "  Username: appuser"
echo "  Password: ${PASSWORD}"
echo ""
echo "Connection String:"
echo "  postgres://appuser:${PASSWORD}@${CLUSTER_NAME}:5432/users"

echo ""
echo "Replicas (Read-Only):"
echo "  Host: ${CLUSTER_NAME}-repl.${APP_NAMESPACE}.svc.cluster.local"
echo "  Port: 5432"
echo ""
echo "Connection String:"
echo "  postgres://appuser:${PASSWORD}@${CLUSTER_NAME}-repl:5432/users"

if kubectl get svc ${CLUSTER_NAME}-pooler -n $APP_NAMESPACE &>/dev/null; then
    echo ""
    echo "Connection Pooler (Recommended):"
    echo "  Host: ${CLUSTER_NAME}-pooler.${APP_NAMESPACE}.svc.cluster.local"
    echo "  Port: 5432"
    echo ""
    echo "Connection String:"
    echo "  postgres://appuser:${PASSWORD}@${CLUSTER_NAME}-pooler:5432/users"
fi

echo ""
echo "=================================================="
echo -e "${GREEN}Testing${NC}"
echo "=================================================="
echo ""
echo "Connect to primary:"
echo "  kubectl exec -it ${CLUSTER_NAME}-0 -n $APP_NAMESPACE -- psql -U postgres"
echo ""
echo "Check replication status:"
echo "  kubectl exec ${CLUSTER_NAME}-0 -n $APP_NAMESPACE -- psql -U postgres -c 'SELECT * FROM pg_stat_replication;'"
echo ""
echo "Check cluster status:"
echo "  kubectl exec ${CLUSTER_NAME}-0 -n $APP_NAMESPACE -- patronictl list"
echo ""
echo "Test failover (delete primary pod):"
echo "  kubectl delete pod ${CLUSTER_NAME}-0 -n $APP_NAMESPACE"
echo ""

echo "=================================================="
echo -e "${GREEN}Setup Complete!${NC}"
echo "=================================================="
