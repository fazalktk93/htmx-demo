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
        GITHUB_CREDENTIALS_ID = "github-push"   // GitHub PAT stored in Jenkins credentials
        SKIP_BUILD = "false" // Default value
        VERSION = ""
    }

    stages {

        stage('Check for Changes & Determine Version') {
            steps {
                script {
                    withCredentials([string(credentialsId: GITHUB_CREDENTIALS_ID, variable: 'GIT_PAT')]) {
                        sh '''
                        # Fetch latest changes and reset
                        git fetch origin main
                        git reset --hard origin/main
                        git fetch --tags

                        # Get latest commit and previous commit
                        LATEST_COMMIT=$(git rev-parse HEAD)
                        PREVIOUS_COMMIT=$(git rev-parse HEAD~1 2>/dev/null || echo "")

                        # Check for changes
                        if [ -n "$PREVIOUS_COMMIT" ] && git diff --quiet $PREVIOUS_COMMIT $LATEST_COMMIT; then
                            echo "No changes detected. Skipping build."
                            echo "SKIP_BUILD=true" > skip_build.env
                            exit 0
                        fi

                        # Get latest tag or fallback to 1.0.0
                        LATEST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "1.0.0")

                        # Bump patch version (1.0.0 -> 1.0.1)
                        NEW_VERSION=$(echo $LATEST_TAG | awk -F. '{$NF++; print}' OFS=.)

                        # Configure Git to use PAT for authentication
                        git config --global user.email "jenkins@yourdomain.com"
                        git config --global user.name "Jenkins CI"
                        git remote set-url origin https://${GIT_PAT}@github.com/fazalktk93/htmx-demo.git

                        # Create and push a new tag
                        git tag "$NEW_VERSION"
                        git push origin "$NEW_VERSION"

                        # Save version info
                        echo "VERSION=$NEW_VERSION" > version.env
                        echo "SKIP_BUILD=false" > skip_build.env
                        '''

                        // Load environment variables
                        def versionEnv = readFile('version.env').trim()
                        env.VERSION = versionEnv.split("=")[1]

                        def skipBuildEnv = readFile('skip_build.env').trim()
                        env.SKIP_BUILD = skipBuildEnv.split("=")[1]
                    }
                }
            }
        }

        stage('SonarQube Analysis') {
            when {
                expression { env.SKIP_BUILD == "false" }
            }
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

        stage('Build & Push Docker Image') {
            when {
                expression { env.SKIP_BUILD == "false" }
            }
            steps {
                sh '''
                    docker build -t ${IMAGE_NAME}:${VERSION} .
                    docker tag ${IMAGE_NAME}:${VERSION} ${REGISTRY}/${IMAGE_NAME}:${VERSION}
                    docker push ${REGISTRY}/${IMAGE_NAME}:${VERSION}
                '''
            }
        }

        stage('Deploy to Kubernetes') {
            when {
                expression { env.SKIP_BUILD == "false" }
            }
            steps {
                sh '''
                    sed -i "s|image: ${REGISTRY}/${IMAGE_NAME}:.*|image: ${REGISTRY}/${IMAGE_NAME}:${VERSION}|" ${DEPLOYMENT_FILE}
                    kubectl apply -f ${DEPLOYMENT_FILE}
                '''
            }
        }
    }
}