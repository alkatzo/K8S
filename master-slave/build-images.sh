# Build and push images
cd /home/myuser/GitHub/K8S/master-slave
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION="ap-southeast-2"
REPO_NAME="task-system"
REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

# Login the ECR
aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin $(aws sts get-caller-identity --query Account --output text).dkr.ecr.${AWS_REGION}.amazonaws.com


# Create single ECR repository
aws ecr create-repository --repository-name ${REPO_NAME} --region ${AWS_REGION}

# Login to ECR
aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${REGISTRY}

# Build and push all images with different tags
docker build -t ${REGISTRY}/${REPO_NAME}:job-a-latest ./job-a
docker push ${REGISTRY}/${REPO_NAME}:job-a-latest

docker build -t ${REGISTRY}/${REPO_NAME}:job-b-latest ./job-b
docker push ${REGISTRY}/${REPO_NAME}:job-b-latest

docker build -t ${REGISTRY}/${REPO_NAME}:job-c-latest ./job-c
docker push ${REGISTRY}/${REPO_NAME}:job-c-latest

docker build -t ${REGISTRY}/${REPO_NAME}:task-executor-latest ./task-executor-service
docker push ${REGISTRY}/${REPO_NAME}:task-executor-latest

docker build -t ${REGISTRY}/${REPO_NAME}:ui-service-latest ./ui-service
docker push ${REGISTRY}/${REPO_NAME}:ui-service-latest


# Deploy
cd k8s/helm/

helm install task-system ./task-system \
  --set jobA.image.repository=${REGISTRY}/${REPO_NAME} \
  --set jobA.image.tag=job-a-latest \
  --set jobB.image.repository=${REGISTRY}/${REPO_NAME} \
  --set jobB.image.tag=job-b-latest \
  --set jobC.image.repository=${REGISTRY}/${REPO_NAME} \
  --set jobC.image.tag=job-c-latest \
  --set taskExecutor.image.repository=${REGISTRY}/${REPO_NAME} \
  --set taskExecutor.image.tag=task-executor-latest \
  --set postgresql.persistence.storageClass=ebs-gp3

# Monitor
watch kubectl get all -n task-system-master