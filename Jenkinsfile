pipeline {
  agent { label 'k8s-agent-alex-default' }

  parameters {
    booleanParam(name: 'DEPLOY', defaultValue: false, description: 'Deploy after build')
  }

  environment {
    REGISTRY_CREDENTIALS = "dockerhub-credentials"
    IMAGE_TAG = "${BRANCH_NAME}-${BUILD_NUMBER}"
  }

  options {
    timestamps()
  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
      }
    }

    stage('Load Environment Variables') {
      steps {
        script {
          def envProps = readProperties file: '.env'
          def reg = envProps.get('REGISTRY', '').trim()
          def tag = envProps.get('IMAGE_TAG', '').trim()
          def proj = envProps.get('COMPOSE_PROJECT_NAME', '').trim()
          env.REGISTRY = reg
          env.IMAGE_TAG = tag ?: "${env.BRANCH_NAME.replace('/', '-')}-${env.BUILD_NUMBER}"
          env.COMPOSE_PROJECT_NAME = proj
          echo "Using REGISTRY=${env.REGISTRY}, IMAGE_TAG=${env.IMAGE_TAG}, COMPOSE_PROJECT_NAME=${env.COMPOSE_PROJECT_NAME}"
          // Add more variables as needed from .env
        }
      }
    }

    stage('Build & Push images') {
      steps {
        script {
          container('kaniko') {
             withCredentials([usernamePassword(
               credentialsId: REGISTRY_CREDENTIALS,
               usernameVariable: 'DOCKER_USER',
               passwordVariable: 'DOCKER_PASS'
             )]) {
               sh '''
                 set -e
                 set -x
                 echo "WORKSPACE=$WORKSPACE"
                 echo "Setting up Docker config for Kaniko"
                 mkdir -p /kaniko/.docker
                 AUTH=$(echo -n "${DOCKER_USER}:${DOCKER_PASS}" | base64)
                 echo "Auth length: ${#AUTH}"
                 cat > /kaniko/.docker/config.json <<EOF
                 {
                   "auths": {
                     "https://index.docker.io/v1/": {
                       "auth": "$AUTH"
                     }
                   }
                 }
                 EOF
                 echo "Docker config created"
               '''
 
               echo "Building and pushing ui-service to ${REGISTRY}:ui-service.${IMAGE_TAG}"
               sh '''
                 set -e
                 set -x
                 echo "Checking context for ui-service"
                 ls -la "${WORKSPACE}/apps/ui-service" || echo "Context not found"
                 echo "Contents of context:"
                 ls -la "${WORKSPACE}/apps/ui-service/" || echo "Failed to list"
                 echo "Dockerfile exists:"
                 cat "${WORKSPACE}/apps/ui-service/Dockerfile" || echo "Dockerfile not found"
                 echo "Running Kaniko for ui-service"
                 /kaniko/executor \
                   --context="${WORKSPACE}/apps/ui-service" \
                   --dockerfile="${WORKSPACE}/apps/ui-service/Dockerfile" \
                   --destination="${REGISTRY}:ui-service.${IMAGE_TAG}" \
                   --snapshotMode=redo \
                   --verbosity=debug
                 echo "Finished pushing ui-service"
               '''
             }
          }
        }
      }
    }

    // stage('Build & Push images') {
    //   agent any
    //   steps {
    //     script {
    //       docker.withRegistry('https://index.docker.io/v1/', REGISTRY_CREDENTIALS) {
    //         parallel(
    //           'Build job-a': {
    //             docker.build("${REGISTRY}:job-a.${IMAGE_TAG}", 'apps/job-a').push()
    //           },
    //           'Build job-b': {
    //             docker.build("${REGISTRY}:job-b.${IMAGE_TAG}", 'apps/job-b').push()
    //           },
    //           'Build job-c': {
    //             docker.build("${REGISTRY}:job-c.${IMAGE_TAG}", 'apps/job-c').push()
    //           },
    //           'Build task-executor': {
    //             docker.build("${REGISTRY}:task-executor.${IMAGE_TAG}", 'apps/task-executor-service').push()
    //           },
    //           'Build ui-service': {
    //             docker.build("${REGISTRY}:ui-service.${IMAGE_TAG}", 'apps/ui-service').push()
    //           }
    //         )
    //       }
    //     }
    //   }
    // }

    stage('Deploy with docker-compose') {
      agent any
      when {
        anyOf {
          branch 'main'
          expression { params.DEPLOY }
        }
      }
      steps {
        sh '''
          set -e
          export IMAGE_TAG=${IMAGE_TAG}
          docker compose pull || true
          docker compose up -d --remove-orphans
        '''
      }
    }
  }
}
