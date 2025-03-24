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
                    sh 'git fetch origin main'
                    sh 'git reset --hard origin/main'
                    
                    def previousVersion = sh(script: "git show HEAD~1:version.txt || echo '0.0'", returnStdout: true).trim()
                    def newVersion = sh(script: "cat version.txt", returnStdout: true).trim()
                    
                    echo "Previous Version: ${previousVersion}"
                    echo "New Version: ${newVersion}"
                    
                    def parseVersion = { version ->
                        def parts = version.tokenize('.').collect { it as int }
                        return parts.size() > 1 ? parts[0] * 100 + parts[1] : parts[0] * 100
                    }
                    
                    def prevVerNum = parseVersion(previousVersion)
                    def newVerNum = parseVersion(newVersion)
                    
                    if (newVerNum > prevVerNum) {
                        echo "Version upgrade detected. Proceeding with the pipeline."
                        env.VERSION_CHANGED = "true"
                    } else {
                        echo "No version upgrade detected (or version downgrade). Skipping pipeline."
                        env.VERSION_CHANGED = "false"
                        currentBuild.result = 'SUCCESS'
                        return
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
                        doctl registry login
                        doctl kubernetes cluster kubeconfig save $DO_CLUSTER
                    '''
                }
            }
        }

        stage('Read Version') {
            when { environment name: 'VERSION_CHANGED', value: 'true' }
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
            when {
                environment name: 'VERSION_CHANGED', value: 'true'
            }
            steps {
                script {
                    def secretExists = sh(
                        script: "kubectl get secret do-registry-secret --namespace=default --output=jsonpath='{.metadata.name}' || echo 'notfound'",
                        returnStdout: true
                    ).trim()

                    if (secretExists == 'do-registry-secret') {
                        echo "✅ Secret 'do-registry-secret' already exists. Skipping creation."
                        return  // Exit early, no new key will be created
                    } else {
                        error "❌ Secret 'do-registry-secret' is missing. Please create it manually before running this pipeline."
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

        stage('Show Application URL') {
            when { environment name: 'VERSION_CHANGED', value: 'true' }
            steps {
                script {
                    def serviceType = sh(script: "kubectl get svc htmx-demo-service -o=jsonpath='{.spec.type}'", returnStdout: true).trim()
                    
                    if (serviceType == "LoadBalancer") {
                        def appUrl = sh(script: "kubectl get svc htmx-demo-service -o=jsonpath='{.status.loadBalancer.ingress[0].ip}'", returnStdout: true).trim()
                        echo "✅ Application is accessible at: http://${appUrl}"
                    } else if (serviceType == "NodePort") {
                        def nodePort = sh(script: "kubectl get svc htmx-demo-service -o=jsonpath='{.spec.ports[0].nodePort}'", returnStdout: true).trim()
                        def nodeIP = sh(script: "kubectl get nodes -o=jsonpath='{.items[0].status.addresses[0].address}'", returnStdout: true).trim()
                        echo "✅ Application is accessible at: http://${nodeIP}:${nodePort}"
                    } else {
                        echo "⚠️ Could not determine application URL. Check service type."
                    }
                }
            }
        }
    }
}
