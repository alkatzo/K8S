#!/bin/bash
# Setup ECR access for Vagrant K8s cluster

set -e

AWS_REGION="ap-southeast-2"
AWS_ACCOUNT_ID="839918632884"
ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

echo "=== Installing AWS CLI on all nodes ==="
for node in master worker1 worker2; do
    echo "Installing on $node..."
    vagrant ssh $node -c '
        sudo apt-get update -qq
        sudo apt-get install -y unzip curl
        cd /tmp
        curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
        unzip -q awscliv2.zip
        sudo ./aws/install
        rm -rf aws awscliv2.zip
    '
done

echo ""
echo "=== Configuring AWS credentials ==="
echo "You need to provide AWS credentials with ECR access."
read -p "AWS Access Key ID: " AWS_ACCESS_KEY_ID
read -sp "AWS Secret Access Key: " AWS_SECRET_ACCESS_KEY
echo ""

for node in master worker1 worker2; do
    echo "Configuring $node..."
    vagrant ssh $node -c "
        mkdir -p ~/.aws
        cat > ~/.aws/credentials <<EOF
[default]
aws_access_key_id = $AWS_ACCESS_KEY_ID
aws_secret_access_key = $AWS_SECRET_ACCESS_KEY
EOF
        cat > ~/.aws/config <<EOF
[default]
region = $AWS_REGION
output = json
EOF
        chmod 600 ~/.aws/credentials
    "
done

echo ""
echo "=== Creating Kubernetes imagePullSecret ==="
vagrant ssh master -c "
    # Get ECR password
    ECR_PASSWORD=\$(aws ecr get-login-password --region $AWS_REGION)
    
    # Create secret in both namespaces
    for ns in task-system-master task-system-slave; do
        kubectl create secret docker-registry ecr-secret \
            --docker-server=$ECR_REGISTRY \
            --docker-username=AWS \
            --docker-password=\$ECR_PASSWORD \
            --namespace=\$ns \
            --dry-run=client -o yaml | kubectl apply -f -
        echo \"Secret created in \$ns\"
    done
"

echo ""
echo "=== Patching deployments to use imagePullSecret ==="
vagrant ssh master -c "
    for ns in task-system-master task-system-slave; do
        kubectl patch serviceaccount default -n \$ns -p '{\"imagePullSecrets\": [{\"name\": \"ecr-secret\"}]}'
        echo \"Patched default SA in \$ns\"
    done
"

echo ""
echo "=== Setup complete! ==="
echo "Note: ECR tokens expire after 12 hours. To refresh:"
echo "  vagrant ssh master"
echo "  ./refresh-ecr-token.sh"
