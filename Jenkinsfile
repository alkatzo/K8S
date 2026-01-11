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
          def segmentPattern = ~/^[a-zA-Z0-9]+((\.|_|__|-+)[a-zA-Z0-9]+)*$/
          def isValidRepo = { String repo ->
            if (!repo) return false
            def parts = repo.split('/')
            return parts.every { it ==~ segmentPattern }
          }
          def reg = envProps.get('REGISTRY', '').trim()
          def tag = envProps.get('IMAGE_TAG', '').trim()
          def proj = envProps.get('COMPOSE_PROJECT_NAME', '').trim()
          echo "Read from .env: REGISTRY='${reg}', IMAGE_TAG='${tag}', COMPOSE_PROJECT_NAME='${proj}'"
          env.REGISTRY = isValidRepo(reg) ? reg : 'alkatzo/deployment'
          env.IMAGE_TAG = (tag && tag ==~ segmentPattern) ? tag : env.IMAGE_TAG
          env.COMPOSE_PROJECT_NAME = proj ?: 'tasks'
          echo "Using REGISTRY=${env.REGISTRY}, IMAGE_TAG=${env.IMAGE_TAG}, COMPOSE_PROJECT_NAME=${env.COMPOSE_PROJECT_NAME}"
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
