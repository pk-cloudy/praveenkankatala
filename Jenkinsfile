pipeline {
	agent any
	tools {
		nodejs 'NodeJS'
	}
	environment {
		SONAR_PROJECT_KEY = 'sonar-cicd'
		SONAR_SCANNER_HOME = tool 'SonarQubeScanner'
		JOB_NAME_NOW = 'cicd02'
		ECR_REPO = 'test'
		IMAGE_TAG = 'latest'
		ECR_REGISTRY = '203510516855.dkr.ecr.us-east-1.amazonaws.com'
	}
	stages {
		stage('GitHub'){
			steps {
				git branch: 'jenkins-sonarqube-trivy-ecs-alb', credentialsId: 'jenkins', url: 'https://github.com/pk-cloudy/praveenkankatala.git'
			}
		}
		stage('Unit Test'){
			steps {
				sh 'npm test'
				sh 'npm install'		
			}
		}
		stage('SonarQube Analysis'){
			steps {
				withCredentials([string(credentialsId: 'sonar-cicd', variable: 'SONAR_TOKEN')]) {
    					
					withSonarQubeEnv('SonarQube') {
    						sh """
						${SONAR_SCANNER_HOME}/bin/sonar-scanner \
						-Dsonar.projectKey=${SONAR_PROJECT_KEY} \
						-Dsonar.sources=. \
						-Dsonar.host.url=http://localhost:9000 \
						-Dsonar.login=${SONAR_TOKEN}
						"""
					}
				}
			}
		}
		stage('Docker Image'){
			steps {
				script {
					docker.build("${ECR_REGISTRY}/${ECR_REPO}:${IMAGE_TAG}")
				}
			}
		}
		stage('Trivy Scan'){
			steps {
				sh 'trivy --severity HIGH,CRITICAL --no-progress --format table -o trivy-report.html image ${JOB_NAME_NOW}:latest'
			}
		}
		stage('Login to ECR'){
			steps {
				sh """
				aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 203510516855.dkr.ecr.us-east-1.amazonaws.com
				"""
			}
		}
		stage('Push Image to ECR'){
			steps {
				script {
				docker.image("${ECR_REGISTRY}/${ECR_REPO}:${IMAGE_TAG}").push()
				}
			}
		}
	}
}
