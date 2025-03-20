pipeline {
    agent any
    
    environment {
        IMAGE_NAME = "htmx-demo"
        REGISTRY = "registry.digitalocean.com/kube-app-registry"
        DEPLOYMENT_FILE = "deployment.yaml"
        SECRET_FILE = "do-registry-secret.yaml"
        DO_CLUSTER = "k8s-htmx"
        SONAR_HOST_URL = "http://147.182.253.185:9000"
        SONAR_PROJECT_KEY = "htmx-project"
        VERSION_FILE = "version.txt"
        GITHUB_CREDENTIALS_ID = "github-push"
    }

    stages {

        stage('Update Version') {
            steps {
                script {
                    withCredentials([string(credentialsId: GITHUB_CREDENTIALS_ID, variable: 'GIT_PAT')]) {
                        sh '''
                        VERSION=$(cat "${VERSION_FILE}" || echo "1.0")
                        NEW_VERSION=$(echo $VERSION | awk -F. '{$NF++; print}' OFS=.)

                        echo "$NEW_VERSION" > "${VERSION_FILE}"

                        git config user.email "fazalktk93@gmail.com"
                        git config user.name "fazalktk93"

                        git add "${VERSION_FILE}"
                        git commit -m "Bump version to $NEW_VERSION"
                        git push https://${GIT_PAT}@github.com/fazalktk93/htmx-demo.git HEAD:main
                        '''
                    }
                }
            }
        }

        stage('SonarQube Analysis') {
            steps {
                withSonarQubeEnv('SonarQube') {
                    withCredentials([string(credentialsId: 'SONAR_TOKEN', variable: 'SONAR_TOKEN')]) {
                        sh '''
                            mvn clean verify sonar:sonar \
                            -Dsonar.projectKey=${SONAR_PROJECT_KEY} \
                            -Dsonar.host.url=${SONAR_HOST_URL} \
                            -Dsonar.token=${SONAR_TOKEN} \
                            -DskipTests
                        '''
                    }
                }
            }
        }

        stage('SonarQube Quality Gate') {
            steps {
                script {
                    echo "Waiting 60 seconds before checking Quality Gate..."
                    sleep(time: 20, unit: 'SECONDS') // Wait for SonarQube to process

                    def qg = waitForQualityGate()
                    echo "SonarQube Quality Gate Status: ${qg.status}"

                    if (qg.status != 'OK') {
                        error "Pipeline failed due to Quality Gate failure: ${qg.status}"
                    }
                }
            }
        }

        stage('Build JAR') {
            steps {
                sh 'mvn clean package -DskipTests'
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

        stage('Build & Push Docker Image') {
            when {
                changeset "src/**/*.java"
            }
            steps {
                sh '''
                    docker build -t ${IMAGE_NAME} .
                    docker tag ${IMAGE_NAME} ${REGISTRY}/${IMAGE_NAME}:latest
                    docker push ${REGISTRY}/${IMAGE_NAME}:latest
                '''
            }
        }
        stage('Setup Kubernetes Secret') {
              steps {
                    script {
                        def secretExists = sh(script: "kubectl get secret do-registry-secret --namespace=default", returnStatus: true) == 0

                           if (!secretExists) {
                            sh '''
                              kubectl create secret docker-registry do-registry-secret \
                              --docker-server=registry.digitalocean.com \
                              --docker-username=${DOCR_USERNAME} \
                              --docker-password=${DOCR_ACCESS_TOKEN} \
                              --namespace=default
                            '''
                    } else {
                            echo "Secret 'do-registry-secret' already exists. Skipping creation."
            }
        }
    }
}

        stage('Deploy to Kubernetes') {
            steps {
                sh '''
                    kubectl get nodes
                    kubectl apply -f $DEPLOYMENT_FILE
                '''
            }
        }
    }
}
