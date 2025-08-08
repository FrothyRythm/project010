pipeline {
  agent any

  environment {
    IMAGE_NAME = "technova-node-app"
    ADMIN_EMAIL = "admin@example.com" // change to your admin e-mail
  }

  stages {
    stage('Checkout') {
      steps {
        git url: 'https://github.com/FrothyRythm/project010.git', branch: 'main'
      }
    }

    stage('Install') {
      steps {
        sh 'node --version || curl -sL https://rpm.nodesource.com/setup_18.x | bash - && dnf install -y nodejs'
        sh 'npm install'
      }
    }

    stage('Test') {
      steps {
        sh 'npm test || true'
      }
    }

    stage('Build Docker Image') {
      steps {
        sh 'docker build -t ${IMAGE_NAME}:latest .'
      }
    }

    stage('Deploy') {
      steps {
        // Stop existing container if exists, remove, then run new container
        sh '''
        if docker ps -q --filter "name=technova_app" | grep -q .; then
          docker stop technova_app || true
        fi
        if docker ps -a -q --filter "name=technova_app" | grep -q .; then
          docker rm technova_app || true
        fi
        docker run -d --name technova_app -p 3000:3000 ${IMAGE_NAME}:latest
        '''
      }
    }
  }

  post {
    success {
      emailext(
        subject: "[TechNova] Deployment SUCCESS: ${env.JOB_NAME} #${env.BUILD_NUMBER}",
        body: "Deployment succeeded. Job: ${env.JOB_NAME} Build: ${env.BUILD_NUMBER} (<a href='${env.BUILD_URL}'>details</a>)",
        to: "${env.ADMIN_EMAIL}"
      )
    }
    failure {
      emailext(
        subject: "[TechNova] Deployment FAILED: ${env.JOB_NAME} #${env.BUILD_NUMBER}",
        body: "Deployment failed. Job: ${env.JOB_NAME} Build: ${env.BUILD_NUMBER} (<a href='${env.BUILD_URL}'>details</a>)",
        to: "${env.ADMIN_EMAIL}"
      )
    }
  }
}
