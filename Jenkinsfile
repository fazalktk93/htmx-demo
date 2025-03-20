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
        GITHUB_CREDENTIALS_ID = "github-push"
        SKIP_BUILD = "false" // Default value
        VERSION = ""
    }

    stages {

        stage('Check for Changes & Determine Version') {
            steps {
                script {
                    withCredentials([string(credentialsId: GITHUB_CREDENTIALS_ID, variable: 'GIT_PAT')]) {
                        sh '''
                        # Fetch the latest Git changes
                        git fetch origin main
                        git reset --hard origin/main
                        git fetch --tags

                        # Get the latest Git commit hash
                        LATEST_COMMIT=$(git rev-parse HEAD)
                        PREVIOUS_COMMIT=$(git rev-parse HEAD~1 2>/dev/null || echo "")

                        # Check if there are any new changes
                        if [ -n "$PREVIOUS_COMMIT" ] && git diff --quiet $PREVIOUS_COMMIT $LATEST_COMMIT; then
                            echo "No changes detected. Skipping build."
                            echo "SKIP_BUILD=true" > skip_build.env
                            exit 0
                        fi

                        # Get the latest Git tag (fallback to 1.0.0 if no tag exists)
                        LATEST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "1.0.0")

                        # Bump the patch version (e.g., 1.0.0 → 1.0.1)
                        NEW_VERSION=$(echo $LATEST_TAG | awk -F. '{$NF++; print}' OFS=.)

                        # Create a new tag for the updated version
                        git tag "$NEW_VERSION"
                        git push origin "$NEW_VERSION"

                        # Store the new version in an environment file
                        echo "VERSION=$NEW_VERSION" > version.env
                        echo "SKIP_BUILD=false" > skip_build.env
                        '''

                        // Load version and SKIP_BUILD flag into the pipeline environment
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