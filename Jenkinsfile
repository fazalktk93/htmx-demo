pipeline {
    agent any
    
    parameters {
        string(name: 'IMAGE_NAME', description: 'Docker Image Name')
        string(name: 'REGISTRY', description: 'Docker Registry')
        string(name: 'DO_CLUSTER', description: 'DigitalOcean Kubernetes Cluster')
        string(name: 'SONAR_HOST_URL', description: 'SonarQube Host URL')
        string(name: 'SONAR_PROJECT_KEY', description: 'SonarQube Project Key')
    }

    environment {
        IMAGE_NAME = "${params.IMAGE_NAME}"
        REGISTRY = "${params.REGISTRY}"
        DO_CLUSTER = "${params.DO_CLUSTER}"
        SONAR_HOST_URL = "${params.SONAR_HOST_URL}"
        SONAR_PROJECT_KEY = "${params.SONAR_PROJECT_KEY}"
        VERSION_FILE = "version.txt"
        DEPLOYMENT_FILE = "deployment.yaml"
    }

    stages {

        stage('Check Version Change') {
            steps {
                script {
                    // Fetch latest changes and reset
                    sh 'git fetch origin main'
                    sh 'git reset --hard origin/main'

                    // Check if version.txt has changed
                    def changeDetected = sh(script: '''
                        if git diff --quiet HEAD~1 HEAD -- "version.txt"; then
                            echo "false"
                        else
                            echo "true"
                        fi
                    ''', returnStdout: true).trim()

                    env.VERSION_CHANGED = changeDetected
                    echo "VERSION_CHANGED set to: ${env.VERSION_CHANGED}"

                    if (env.VERSION_CHANGED == "false") {
                        echo "No changes detected in version.txt. Skipping pipeline."
                        currentBuild.result = 'SUCCESS'
                        return  // Exit gracefully without failure
                    }
                }
            }
        }

        stage('SonarQube Analysis') {
            when { environment name: 'VERSION_CHANGED', value: 'true' }
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
            when { environment name: 'VERSION_CHANGED', value: 'true' }
            steps {
                script {
                    echo "Waiting 20 seconds before checking Quality Gate..."
                    sleep(time: 20, unit: 'SECONDS')

                    def qg = waitForQualityGate()
                    echo "SonarQube Quality Gate Status: ${qg.status}"

                    if (qg.status != 'OK') {
                        error "Pipeline failed due to Quality Gate failure: ${qg.status}"
                    }
                }
            }
        }

        stage('Build JAR') {
            when { environment name: 'VERSION_CHANGED', value: 'true' }
            steps {
                sh 'mvn clean package -DskipTests'
            }
        }

        stage('Login to DigitalOcean') {
            when { environment name: 'VERSION_CHANGED', value: 'true' }
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

        stage('Read Version') {
            steps {
                script {
                    def NEW_VERSION = sh(script: "cat version.txt", returnStdout: true).trim()
                    env.NEW_VERSION = NEW_VERSION
                    echo "Version extracted: ${NEW_VERSION}"
                }
            }
        }

        stage('Build & Push Docker Image') {
            when { environment name: 'VERSION_CHANGED', value: 'true' }
            steps {
                sh '''
                    docker build -t ${IMAGE_NAME} .
                    docker tag ${IMAGE_NAME} ${REGISTRY}/${IMAGE_NAME}:${NEW_VERSION}
                    docker push ${REGISTRY}/${IMAGE_NAME}:${NEW_VERSION}
                '''
            }
        }

        stage('Setup Kubernetes Secret') {
            when { environment name: 'VERSION_CHANGED', value: 'true' }
            steps {
                script {
                    def secretExists = sh(
                        script: "kubectl get secret do-registry-secret --namespace=default || echo 'notfound'",
                        returnStdout: true
                    ).trim()

                    if (secretExists.contains('do-registry-secret')) {
                        echo "Secret 'do-registry-secret' already exists. Skipping creation."
                    } else {
                        echo "Creating Kubernetes secret 'do-registry-secret'..."
                        withCredentials([string(credentialsId: 'DOCR_ACCESS_TOKEN', variable: 'DOCR_PASSWORD')]) {
                            sh '''
                                kubectl create secret docker-registry do-registry-secret \
                                --docker-server=registry.digitalocean.com \
                                --docker-username=${DOCR_USERNAME} \
                                --docker-password=${DOCR_PASSWORD} \
                                --namespace=default
                            '''
                        }
                    }
                }
            }
        }

        stage('Deploy to Kubernetes') {
            when { environment name: 'VERSION_CHANGED', value: 'true' }
            steps {
                sh '''
                    kubectl get nodes
                    kubectl apply -f $DEPLOYMENT_FILE
                '''
            }
        }
    }
}
