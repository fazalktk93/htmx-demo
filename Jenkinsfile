pipeline {
    agent any
    
    environment {
        IMAGE_NAME = "htmx-demo"
        REGISTRY = "registry.digitalocean.com/kube-app-registry"
        DEPLOYMENT_FILE = "deployment.yaml"
        SECRET_FILE = "do-registry-secret.yaml"
        DO_CLUSTER = "k8s-htmx"
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

        stage('Login to DigitalOcean') {
            steps {
                withCredentials([string(credentialsId: 'DO_ACCESS_TOKEN', variable: 'DO_TOKEN')]) {
                    sh '''
                        export DIGITALOCEAN_ACCESS_TOKEN=$DO_TOKEN
                        doctl auth init --access-token $DO_TOKEN
                        doctl kubernetes cluster kubeconfig save $DO_CLUSTER
                    '''
                }
            }
        }

        stage('Tag and Push to DOCR') {
            steps {
                sh "docker tag ${IMAGE_NAME} ${REGISTRY}/${IMAGE_NAME}:latest"
                sh "docker push ${REGISTRY}/${IMAGE_NAME}:latest"
            }
        }

        stage('Create Kubernetes Secret') {
            steps {
                withCredentials([string(credentialsId: 'DO_ACCESS_TOKEN', variable: 'DO_TOKEN')]) {
                    sh '''
                        kubectl create secret docker-registry do-registry-secret \
                            --docker-server=registry.digitalocean.com \
                            --docker-username=unused \
                            --docker-password=$DO_TOKEN \
                            --docker-email=unused \
                            --dry-run=client -o yaml | kubectl apply -f -
                    '''
                }
            }
        }


        stage('Deploy to Kubernetes') {
            steps {
                withCredentials([file(credentialsId: 'KUBECONFIG_FILE', variable: 'KUBECONFIG')]) {
                    sh '''
                        export KUBECONFIG=/var/lib/jenkins/.kube/config
                        kubectl get nodes
                        kubectl apply -f deployment.yaml
                    '''
                }
            }
        }
    }
}