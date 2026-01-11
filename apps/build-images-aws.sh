# Build and push images
cd /home/myuser/GitHub/K8S/master-slave
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION="ap-southeast-2"
REPO_NAME="task-system"
REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

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

docker build -t ${REGISTRY}/${REPO_NAME}:task-executor-latest ./task-executor
docker push ${REGISTRY}/${REPO_NAME}:task-executor-latest

docker build -t ${REGISTRY}/${REPO_NAME}:ui-service-latest ./ui-service
docker push ${REGISTRY}/${REPO_NAME}:ui-service-latest
