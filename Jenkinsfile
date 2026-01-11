pipeline {
  agent any

  environment {
    REGISTRY = "alkatzo/deployment"
    REGISTRY_CREDENTIALS = "dockerhub-credentials"
    IMAGE_TAG = "${BUILD_NUMBER}"
    COMPOSE_PROJECT_NAME = "task-system"
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

    stage('Build & Push images') {
      steps {
        script {
          docker.withRegistry('https://index.docker.io/v1/', REGISTRY_CREDENTIALS) {
            docker.build("${REGISTRY}:job-a.${IMAGE_TAG}",          'apps/job-a').push()
            docker.build("${REGISTRY}:job-b.${IMAGE_TAG}",          'apps/job-b').push()
            docker.build("${REGISTRY}:job-c.${IMAGE_TAG}",          'apps/job-c').push()
            docker.build("${REGISTRY}:task-executor.${IMAGE_TAG}",  'apps/task-executor-service').push()
            docker.build("${REGISTRY}:ui-service.${IMAGE_TAG}",     'apps/ui-service').push()
          }
        }
      }
    }

    stage('Deploy with docker-compose') {
      steps {
        sh '''
          set -e
          export REGISTRY=${REGISTRY}
          export IMAGE_TAG=${IMAGE_TAG}
          docker compose pull || true
          docker compose up -d
        '''
      }
    }
  }
}
