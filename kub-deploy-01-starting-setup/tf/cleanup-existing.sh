#!/bin/bash
# Script to import existing resources before terraform apply

CLUSTER_NAME="users-eks-cluster"
REGION="ap-southeast-2"

echo "Checking for existing resources..."

# Import CloudWatch Log Group if it exists
if aws logs describe-log-groups --log-group-name-prefix "/aws/eks/${CLUSTER_NAME}/cluster" --region ${REGION} 2>/dev/null | grep -q "logGroups"; then
    echo "Found existing CloudWatch Log Group, importing..."
    terraform import 'module.eks.aws_cloudwatch_log_group.this[0]' "/aws/eks/${CLUSTER_NAME}/cluster" || true
fi

# Import SSH Key Pair if it exists
if aws ec2 describe-key-pairs --key-names "${CLUSTER_NAME}-worker-key" --region ${REGION} 2>/dev/null | grep -q "KeyPairs"; then
    echo "Found existing Key Pair, importing..."
    terraform import 'aws_key_pair.worker[0]' "${CLUSTER_NAME}-worker-key" || true
fi

echo "Import complete. You can now run terraform apply."
