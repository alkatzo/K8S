#!/bin/bash
# Script to manually delete orphaned AWS resources

CLUSTER_NAME="users-eks-cluster"
REGION="ap-southeast-2"

echo "Deleting orphaned resources..."

# Delete CloudWatch Log Group if it exists
if aws logs describe-log-groups --log-group-name-prefix "/aws/eks/${CLUSTER_NAME}/cluster" --region ${REGION} 2>/dev/null | grep -q "logGroups"; then
    echo "Deleting CloudWatch Log Group..."
    aws logs delete-log-group --log-group-name "/aws/eks/${CLUSTER_NAME}/cluster" --region ${REGION}
    echo "CloudWatch Log Group deleted."
else
    echo "CloudWatch Log Group not found."
fi

# Delete SSH Key Pair if it exists
if aws ec2 describe-key-pairs --key-names "${CLUSTER_NAME}-worker-key" --region ${REGION} 2>/dev/null | grep -q "KeyPairs"; then
    echo "Deleting Key Pair..."
    aws ec2 delete-key-pair --key-name "${CLUSTER_NAME}-worker-key" --region ${REGION}
    echo "Key Pair deleted."
else
    echo "Key Pair not found."
fi

echo "Cleanup complete."
