#!/bin/bash
# Deploy task-system with Argo Workflows

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "📦 Deploying task-system with Argo Workflows..."

# Generate and apply manifests
helm template task-system "$SCRIPT_DIR" -f "$SCRIPT_DIR/values-argo.yaml" | kubectl apply -f -

echo ""
echo "✅ Deployment complete!"
echo ""
echo "📊 Check status:"
echo "  kubectl get workflows -n task-system-master"
echo "  kubectl get workflows -n task-system-slave"
echo ""
echo "📝 View logs:"
echo "  argo logs job-sequence-workflow -n task-system-master"
echo ""
echo "🗄️  Check database:"
echo "  kubectl exec -n task-system-master postgres-0 -- psql -U postgres -d taskdb -c 'SELECT * FROM tasks;'"
