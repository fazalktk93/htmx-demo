pipeline {
    agent any
    
    environment {
        IMAGE_NAME = "htmx-demo"
        CONTAINER_NAME = "htmx-container"
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
    }
}
