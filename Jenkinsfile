pipeline {
    agent any

    environment {
        IMAGE_NAME = "htmx-demo"
        REGISTRY = "registry.digitalocean.com/kube-app-registry"
        DO_CLUSTER = "k8s-htmx"
        SONAR_HOST_URL = "http://147.182.253.185:9000"
        SONAR_PROJECT_KEY = "htmx-demo"
        VERSION_FILE = "version.txt"
        DEPLOYMENT_FILE = "deployment.yaml"
    }

    stages {
        stage('Check Version Change') {
            steps {
                script {
                    // Reset to latest main branch
                    sh 'git fetch origin main'
                    sh 'git reset --hard origin/main'

                    // Get versions
                    def previousVersion = sh(script: "git show HEAD~1:version.txt || echo '0.0'", returnStdout: true).trim()
                    def newVersion = sh(script: "cat version.txt", returnStdout: true).trim()
                    
                    // Version comparison logic
                    def versionChanged = "false"
                    if (previousVersion != newVersion) {
                        def (prevMajor, prevMinor) = previousVersion.tokenize('.').collect { it as int }
                        def (newMajor, newMinor) = newVersion.tokenize('.').collect { it as int }
                        
                        if (newMajor > prevMajor || (newMajor == prevMajor && newMinor > prevMinor)) {
                            versionChanged = "true"
                            env.NEW_VERSION = newVersion
                        }
                    }

                    env.VERSION_CHANGED = versionChanged
                    
                    if (env.VERSION_CHANGED == "false") {
                        echo "No valid version upgrade detected. Current: ${newVersion}, Previous: ${previousVersion}"
                        currentBuild.result = 'SUCCESS'
                        return
                    }
                    
                    echo "Version upgrade validated: ${previousVersion} → ${newVersion}"
                }
            }
        }


        stage('Run Unit & Integration test') {

            when { environment name: 'VERSION_CHANGED', value: 'true' }
            steps {
                sh '''
                    export SPRING_PROFILES_ACTIVE=test 
                    mvn clean test
                '''
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
            when {
                environment name: 'VERSION_CHANGED', value: 'true'
            }
            steps {
                script {
                    withCredentials([string(credentialsId: 'DO_ACCESS_TOKEN', variable: 'DO_TOKEN')]) {
                        def doctlAuthCheck = sh(
                            script: "doctl auth list | grep -q 'Valid' && echo 'AUTH_EXISTS' || echo 'NO_AUTH'",
                            returnStdout: true
                        ).trim()

                        if (doctlAuthCheck == "NO_AUTH") {
                            echo "🔑 No valid authentication found, initializing DigitalOcean auth..."
                            sh "doctl auth init --access-token $DO_TOKEN"
                        } else {
                            echo "✅ Already authenticated with DigitalOcean. Skipping auth init."
                        }

                        sh "doctl kubernetes cluster kubeconfig save $DO_CLUSTER"
                    }
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
                    doctl registry login
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
                        script: "kubectl get secret do-registry-secret --namespace=default --ignore-not-found",
                        returnStdout: true
                    ).trim()

                    if (secretExists == "") {
                        echo "Creating Kubernetes secret 'do-registry-secret'..."
                        withCredentials([string(credentialsId: 'DOCR_ACCESS_TOKEN', variable: 'DOCR_ACCESS_TOKEN'),
                                        string(credentialsId: 'DOCR_USERNAME', variable: 'DOCR_USERNAME')]) {
                            sh '''
                                kubectl create secret docker-registry do-registry-secret \
                                --docker-server=registry.digitalocean.com \
                                --docker-username=${DOCR_USERNAME} \
                                --docker-password=${DOCR_ACCESS_TOKEN} \
                                --namespace=default
                            '''
                        }
                    } else {
                        echo "Secret 'do-registry-secret' already exists. Skipping creation."
                    }
                }
            }
        }

        stage('Deploy to Kubernetes') {
            when { environment name: 'VERSION_CHANGED', value: 'true' }
            steps {
                sh '''
                    sed -i "s|image: REGISTRY/IMAGE_NAME:NEW_VERSION|image: ${REGISTRY}/${IMAGE_NAME}:${NEW_VERSION}|" ${DEPLOYMENT_FILE}
                    kubectl apply -f ${DEPLOYMENT_FILE}
                '''
            }
        }

        stage('Show Application URL') {
            steps {
                script {
                    if (env.VERSION_CHANGED == "true") {
                        echo "Waiting for LoadBalancer IP..."
                        sleep(time: 30, unit: 'SECONDS') // Wait for the IP to be assigned
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
}
  
