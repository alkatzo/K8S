pipeline {
  agent {
    docker {
      image 'docker:dind'
      args '-v /var/run/docker.sock:/var/run/docker.sock'
    }
  }

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
          def tag = envProps.get('IMAGE_TAG', '').trim()
          def proj = envProps.get('COMPOSE_PROJECT_NAME', '').trim()
          env.REGISTRY = reg
          env.IMAGE_TAG = tag
          env.COMPOSE_PROJECT_NAME = proj
          echo "Using REGISTRY=${env.REGISTRY}, IMAGE_TAG=${env.IMAGE_TAG}, COMPOSE_PROJECT_NAME=${env.COMPOSE_PROJECT_NAME}"
          // Add more variables as needed from .env
        }
      }
    }

    stage('Build & Push images') {
      steps {
        script {
          docker.withRegistry('https://index.docker.io/v1/', REGISTRY_CREDENTIALS) {
            parallel(
              'Build job-a': {
                docker.build("${REGISTRY}:job-a.${IMAGE_TAG}", 'apps/job-a').push()
              },
              'Build job-b': {
                docker.build("${REGISTRY}:job-b.${IMAGE_TAG}", 'apps/job-b').push()
              },
              'Build job-c': {
                docker.build("${REGISTRY}:job-c.${IMAGE_TAG}", 'apps/job-c').push()
              },
              'Build task-executor': {
                docker.build("${REGISTRY}:task-executor.${IMAGE_TAG}", 'apps/task-executor-service').push()
              },
              'Build ui-service': {
                docker.build("${REGISTRY}:ui-service.${IMAGE_TAG}", 'apps/ui-service').push()
              }
            )
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
          docker compose up -d --remove-orphans
        '''
      }
    }
  }
}
