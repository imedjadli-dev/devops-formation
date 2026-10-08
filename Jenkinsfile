pipeline {
    agent any

    environment {
        DOCKER_IMAGE = 'imedjedli/achat-app'
        DOCKER_TAG   = "2.${BUILD_NUMBER}"
        TRIVY_CACHE  = '/Users/Shared/trivy-cache'

        // Kubernetes (minikube)
        K8S_NAMESPACE  = 'devops'
        K8S_DEPLOYMENT = 'spring-backend'
        K8S_DIR        = 'k8s'
    }

    stages {

        // Checkout
        stage('Checkout') {
            steps {
                git branch: 'main',
                    url: 'https://github.com/imedjadli-dev/devops-formation'
            }
        }

        // Bump version
        stage('Bump Version') {
            steps {
                sh 'mvn versions:set -DnewVersion=2.${BUILD_NUMBER} -DgenerateBackupPoms=false'
            }
        }

        // Maven clean + compile
        stage('Maven Clean & Compile') {
            steps {
                sh 'mvn clean compile'
            }
        }

        // Unit tests
        stage('Unit Tests') {
            steps {
                sh 'mvn test'
            }
            post {
                always {
                    junit '**/target/surefire-reports/*.xml'
                }
            }
        }

        // Code coverage
        stage('Code Coverage') {
            steps {
                sh 'mvn verify'
            }
        }

        // SonarQube analysis
        stage('SonarQube Analysis') {
            steps {
                withCredentials([string(credentialsId: 'sonar-token', variable: 'SONAR_TOKEN')]) {
                    sh '''
                        mvn org.sonarsource.scanner.maven:sonar-maven-plugin:5.7.0.6970:sonar \
                            -Dsonar.host.url=http://127.0.0.1:9000 \
                            -Dsonar.token=${SONAR_TOKEN}
                    '''
                }
            }
        }

        // Check path
        stage('Check Path') {
            steps {
                sh '''
                    echo "===== PATH ====="
                    pwd

                    echo "===== FILES ====="
                    ls -la

                    echo "===== SETTINGS.XML ====="
                    find . -name "settings.xml" -type f
                '''
            }
        }

        // Generate settings.xml
        stage('Generate settings.xml') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'nexus-creds', usernameVariable: 'NEXUS_USER', passwordVariable: 'NEXUS_PASS')]) {
                    writeFile file: 'settings.xml', text: """<settings>
                        <servers>
                            <server>
                                <id>deploymentRepo</id>
                                <username>${NEXUS_USER}</username>
                                <password>${NEXUS_PASS}</password>
                            </server>
                        </servers>
                    </settings>
                    """
                }
            }
        }

        // Deploy to Nexus
        stage('Deploy to Nexus') {
            steps {
                sh '''
                    mvn deploy \
                        -DskipTests \
                        -s settings.xml \
                        -DaltDeploymentRepository=deploymentRepo::default::http://127.0.0.1:8081/repository/maven-releases/
                '''
            }
        }

        // Maven package
        stage('Maven Package') {
            steps {
                sh 'mvn package -DskipTests'
            }
        }

        // Check jar
        stage('Check JAR') {
            steps {
                sh 'ls -la target/*.jar'
            }
        }

        // Docker build
        stage('Docker Build') {
            steps {
                sh 'docker build -t ${DOCKER_IMAGE}:${DOCKER_TAG} .'
            }
        }

        // Trivy security scan
        stage('Trivy Security Scan') {
            steps {
                sh '''
                    trivy image \
                        --cache-dir ${TRIVY_CACHE} \
                        --scanners vuln \
                        --skip-db-update \
                        --skip-java-db-update \
                        --severity HIGH,CRITICAL \
                        --timeout 15m \
                        ${DOCKER_IMAGE}:${DOCKER_TAG}
                '''
            }
        }



        // Docker push
        stage('Docker Push') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'dockerhub-creds', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
                    retry(5) {
                        sh '''
                            echo "=== Logging into Docker Hub ==="
                            echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin

                            echo "=== Pushing Docker Image ==="
                            docker push ${DOCKER_IMAGE}:${DOCKER_TAG}
                        '''
                    }
                }
            }
        }

        // Docker Compose
     // Docker Compose
        stage('Docker Compose') {
            steps {
                sh '''
                    rm -rf prometheus.yml/ 2>/dev/null || true
                    docker compose down --remove-orphans || true
                    docker compose up -d --build
                    docker compose ps
                '''
            }
        }

        // Deploy with Ansible
        stage('Deploy with Ansible') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'nexus-creds', usernameVariable: 'NEXUS_USER', passwordVariable: 'NEXUS_PASS')]) {
                    dir('/Users/imedjadli/ansible-workshop') {
                        sh '''
                            export PATH=/opt/homebrew/bin:$PATH
                            ansible-playbook site.yml --tags backend -e "backend_version=2.${BUILD_NUMBER}"
                        '''
                    }
                }
            }
        }

        // Deploy to Kubernetes (minikube)
        stage('Deploy to Kubernetes') {
            steps {
                sh '''
                    export PATH=/opt/homebrew/bin:/usr/local/bin:$PATH

                    echo "===== K8S CONTEXT ====="
                    kubectl config current-context
                    kubectl get nodes

                    echo "===== APPLY MANIFESTS ====="
                    kubectl apply -f ${K8S_DIR}/spring-config.yaml
                    kubectl apply -f ${K8S_DIR}/spring-service.yaml
                    sed "s|IMAGE_PLACEHOLDER|${DOCKER_IMAGE}:${DOCKER_TAG}|" ${K8S_DIR}/spring-deployment.yaml | kubectl apply -f -

                    echo "===== ROLLOUT STATUS ====="
                    kubectl rollout status deployment/${K8S_DEPLOYMENT} -n ${K8S_NAMESPACE} --timeout=180s

                    echo "===== RESOURCES ====="
                    kubectl get pods,svc -n ${K8S_NAMESPACE}
                '''
            }
        }

        // Prometheus check
        stage('Prometheus') {
            steps {
                sh '''
                    echo "===== PROMETHEUS HEALTH ====="
                    curl -sf http://127.0.0.1:9090/-/healthy

                    echo "===== PROMETHEUS READY ====="
                    curl -sf http://127.0.0.1:9090/-/ready

                    echo "===== TARGETS ====="
                    curl -sf http://127.0.0.1:9090/api/v1/targets | grep -o '"health":"[a-z]*"'
                '''
            }
        }

        // Grafana check
        stage('Grafana') {
            steps {
                sh '''
                    echo "===== GRAFANA HEALTH ====="
                    for i in $(seq 1 20); do
                        if curl -sf http://127.0.0.1:3000/api/health; then
                            echo ""
                            echo "Grafana OK"
                            exit 0
                        fi
                        echo "Grafana pas encore prêt ($i/20)..."
                        sleep 3
                    done
                    echo "Grafana non disponible"
                    exit 1
                '''
            }
        }
    }

    post {
        success {
            echo 'PIPELINE STATUS : SUCCESS'
        }
        failure {
            echo 'PIPELINE STATUS : FAILED'
        }
        always {
            echo 'PIPELINE TERMINE'
        }
    }
}