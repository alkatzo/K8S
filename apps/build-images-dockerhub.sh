# Build and push images
cd /home/myuser/GitHub/K8S/master-slave
REPO_NAME="task-system"
REGISTRY="alkatzo"


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


