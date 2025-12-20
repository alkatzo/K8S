#!/bin/bash
set -e

echo "=================================================="
echo "Argo Workflows Installation Script"
echo "=================================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}Error: kubectl is not installed${NC}"
    exit 1
fi

echo -e "${GREEN}✓ kubectl is installed${NC}"

# Step 1: Create Argo namespace
echo ""
echo "Step 1: Creating Argo namespace..."
kubectl create namespace argo --dry-run=client -o yaml | kubectl apply -f -
echo -e "${GREEN}✓ Namespace 'argo' created/verified${NC}"

# Step 2: Install Argo Workflows
echo ""
echo "Step 2: Installing Argo Workflows..."
ARGO_VERSION="v3.5.2"
kubectl apply -n argo -f https://github.com/argoproj/argo-workflows/releases/download/${ARGO_VERSION}/install.yaml
echo -e "${GREEN}✓ Argo Workflows installed${NC}"

# Step 3: Wait for Argo to be ready
echo ""
echo "Step 3: Waiting for Argo Workflows to be ready (this may take a minute)..."
kubectl wait --for=condition=ready pod -l app=workflow-controller -n argo --timeout=300s
kubectl wait --for=condition=ready pod -l app=argo-server -n argo --timeout=300s
echo -e "${GREEN}✓ Argo Workflows is ready${NC}"

# Step 4: Check installation
echo ""
echo "Step 4: Verifying installation..."
kubectl get pods -n argo
echo ""
kubectl get svc -n argo

# Step 5: Instructions
echo ""
echo "=================================================="
echo -e "${GREEN}Argo Workflows installed successfully!${NC}"
echo "=================================================="
echo ""
echo "Next steps:"
echo ""
echo "1. Access Argo UI:"
echo "   kubectl -n argo port-forward deployment/argo-server 2746:2746"
echo "   Then open: https://localhost:2746"
echo ""
echo "2. Install Argo CLI (optional):"
echo "   # Linux:"
echo "   curl -sLO https://github.com/argoproj/argo-workflows/releases/download/${ARGO_VERSION}/argo-linux-amd64.gz"
echo "   gunzip argo-linux-amd64.gz"
echo "   chmod +x argo-linux-amd64"
echo "   sudo mv ./argo-linux-amd64 /usr/local/bin/argo"
echo ""
echo "   # macOS:"
echo "   brew install argo"
echo ""
echo "3. Deploy task-system with Argo enabled:"
echo "   helm upgrade --install task-system ./k8s/helm/task-system \\"
echo "     --set argoWorkflow.enabled=true \\"
echo "     --set jobA.enabled=false \\"
echo "     --set jobB.enabled=false \\"
echo "     --set jobC.enabled=false \\"
echo "     --create-namespace"
echo ""
echo "4. Submit a workflow:"
echo "   argo submit -n task-system-master <workflow-file> --watch"
echo ""
echo "For more details, see: ARGO_WORKFLOWS_GUIDE.md"
echo ""
