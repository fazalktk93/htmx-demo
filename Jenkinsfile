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
                    def versionFile = env.VERSION_FILE  // Ensure this is set in Jenkins
                    sh 'git fetch --tags' // Fetch latest tags
                    
                    // Read and increment version
                    def currentVersion = sh(script: "cat ${versionFile}", returnStdout: true).trim()
                    def versionParts = currentVersion.tokenize('.')
                    versionParts[-1] = (versionParts[-1].toInteger() + 1).toString()
                    def newVersion = versionParts.join('.')

                    // Update version file and commit changes
                    sh """
                        echo ${newVersion} > ${versionFile}
                        git add ${versionFile}
                        git commit -m 'Bump version to ${newVersion}'
                    """

                    // Push changes using GitHub PAT stored in Jenkins credentials
                    withCredentials([string(credentialsId: 'github-push', variable: 'GIT_PAT')]) {
                        sh 'git push origin HEAD:main'
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
