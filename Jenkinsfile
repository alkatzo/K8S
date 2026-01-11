pipeline {
  agent any

  environment {
    REGISTRY_CREDENTIALS = "dockerhub-credentials"
    IMAGE_TAG = "${BUILD_NUMBER}"
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
          env.REGISTRY = reg ?: 'alkatzo/deployment'
          def tag = envProps.get('IMAGE_TAG', '').trim()
          env.IMAGE_TAG = tag ?: env.IMAGE_TAG
          def proj = envProps.get('COMPOSE_PROJECT_NAME', '').trim()
          env.COMPOSE_PROJECT_NAME = proj ?: 'tasks'
          // Add more variables as needed from .env
        }
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
          export IMAGE_TAG=${IMAGE_TAG}
          docker compose pull || true
          docker compose up -d
        '''
      }
    }
  }
}
