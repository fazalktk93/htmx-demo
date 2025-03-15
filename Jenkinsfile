pipeline {
    agent any
    
    environment {
        IMAGE_NAME = "htmx-demo"
        CONTAINER_NAME = "htmx-container"
        REGISTRY = "registry.digitalocean.com/kube-app-registry"
    }

    stages {
        stage('Clone Repository') {
            steps {
                git branch: 'main', url: 'https://github.com/emad-hussain/htmx-demo.git'
            }
        }

        stage('Build Docker Image') {
            steps {
                sh 'docker build -t $IMAGE_NAME .'
            }
        }

        stage('Run Container') {
            steps {
                sh 'docker stop $CONTAINER_NAME || true'
                sh 'docker rm $CONTAINER_NAME || true'
                sh 'docker run -d -p 8090:8080 --name $CONTAINER_NAME $IMAGE_NAME'
            }
        }
        stage('Login to DOCR') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'DOCR_CREDENTIALS', usernameVariable: 'DOCR_USER', passwordVariable: 'DOCR_PASS')]) {
                    sh """
                        echo \$DOCR_PASS | docker login ${REGISTRY} -u \$DOCR_USER --password-stdin
                    """
                }
            }
        }

        stage('Tag and Push to DOCR') {
            steps {
                sh "docker tag ${IMAGE_NAME} ${REGISTRY}/${IMAGE_NAME}"
                sh "docker push ${REGISTRY}/${IMAGE_NAME}"
            }
        }
    }
}
