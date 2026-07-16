pipeline {
    agent any
    tools {
        nodejs 'nodejs'
    }
    environment {
        SONAR_PROJECT_KEY  = 'sonar-cicd'
        SONAR_SCANNER_HOME = tool 'SonarQubeScanner'
        ECR_REPO           = 'ecs-freetier-repo'
        IMAGE_TAG          = 'latest'
        ECR_REGISTRY       = '203510516855.dkr.ecr.us-east-1.amazonaws.com'
        FULL_IMAGE         = "${ECR_REGISTRY}/${ECR_REPO}:${IMAGE_TAG}"
    }
    stages {
        stage('GitHub') {
            steps {
                git branch: 'jenkins-sonarqube-trivy-ecs-alb',
                    credentialsId: 'jenkins',
                    url: 'https://github.com/pk-cloudy/praveenkankatala.git'
            }
        }
        stage('Unit Test') {
            steps {
                bat 'npm install'
                bat 'npm test'
            }
        }

        stage('Docker Image') {
            steps {
                script {
                    docker.build("${FULL_IMAGE}")
                }
            }
        }
        stage('Login to ECR') {
            steps {
                bat 'aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin %ECR_REGISTRY%'
            }
        }
        stage('Push Image to ECR') {
            steps {
                script {
                    docker.image("${FULL_IMAGE}").push()
                }
            }
        }
    }
    post {
        always {
            archiveArtifacts artifacts: 'trivy-report.txt', allowEmptyArchive: true
        }
    }
}
