pipeline {
    agent any

    environment {
        DOCKER_IMAGE = 'imedjedli/achat-app'
        DOCKER_TAG   = "2.${BUILD_NUMBER}"
        TRIVY_CACHE  = '/Users/Shared/trivy-cache'
    }

    stages {
        // ============================================
        // 1. CHECKOUT
        // ============================================
        stage('Checkout') {
            steps {
                git branch: 'main',
                    url: 'https://github.com/imedjadli-dev/devops-formation'
            }
        }

        // ============================================
        // 2. BUMP VERSION
        // ============================================
        stage('Bump Version') {
            steps {
                // FIX: l'ancien code contenait "\\${BUILD_NUMBER}" -> le backslash
                // était conservé et injectait un caractère "\" littéral dans le
                // numéro de version (ex: "2.\42" au lieu de "2.42"), ce qui pouvait
                // faire échouer "versions:set". Utilisation de guillemets simples
                // pour laisser le shell (pas Groovy) faire l'interpolation.
                sh 'mvn versions:set -DnewVersion=2.${BUILD_NUMBER} -DgenerateBackupPoms=false'
            }
        }

        // ============================================
        // 3. ENVIRONMENT
        // ============================================
        stage('Environment') {
            steps {
                sh '''
                    echo "===== JAVA ====="
                    java -version

                    echo "===== MAVEN ====="
                    mvn -version
                '''
            }
        }

        // ============================================
        // 4. MAVEN CLEAN
        // ============================================
        stage('Maven Clean') {
            steps {
                sh 'mvn clean'
            }
        }

        // ============================================
        // 5. MAVEN COMPILE
        // ============================================
        stage('Maven Compile') {
            steps {
                sh 'mvn compile'
            }
        }

        // ============================================
        // 6. UNIT TESTS
        // ============================================
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

        // ============================================
        // 7. CODE COVERAGE
        // ============================================
        stage('Code Coverage') {
            steps {
                sh 'mvn verify'
            }
        }

        // ============================================
        // 8. SONARQUBE
        // ============================================
        // ============================================
        // 5. SONARQUBE ANALYSIS
        // ============================================
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



        // ============================================
        // 9. CHECK PATH
        // ============================================
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

        // ============================================
        // 10. GENERATE SETTINGS.XML
        // ============================================
        stage('Generate settings.xml') {
            steps {
                // FIX: identifiants Nexus en clair ("admin"/"nexusadmin").
                // Récupérés depuis les credentials Jenkins (ID: nexus-creds)
                // et injectés dans le settings.xml généré dynamiquement.
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

        // ============================================
        // 11. DEPLOY TO NEXUS
        // ============================================
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

        // ============================================
        // 12. MAVEN PACKAGE
        // ============================================
        stage('Maven Package') {
            steps {
                sh 'mvn package -DskipTests'
            }
        }

        // ============================================
        // 13. CHECK JAR
        // ============================================
        stage('Check JAR') {
            steps {
                sh 'ls -la target/*.jar'
            }
        }

        // ============================================
        // 14. DOCKER BUILD
        // ============================================
        stage('Docker Build') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'dockerhub-creds', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
                    sh '''
                        echo "=== Testing Network Connectivity ==="
                        curl -sS --max-time 10 https://auth.docker.io/token || echo "WARNING: Cannot reach auth.docker.io"

                        echo "=== Logging into Docker Hub ==="
                        echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin

                        echo "=== Building Docker Image ==="
                        docker build -t ${DOCKER_IMAGE}:${DOCKER_TAG} .
                    '''
                }
            }
        }

        // ============================================
        // 15. TRIVY SECURITY SCAN
        // ============================================
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

        // ============================================
        // 16. DOCKER PUSH
        // ============================================
        // FIX: il y avait DEUX stages nommés "Docker Push" à la suite,
        // le second refaisant exactement le login + tag + push du premier
        // (build inutilement plus long, confusion dans Blue Ocean).
        // Fusionnés en un seul stage avec le test de connectivité inclus.
     // ============================================
        // 16. DOCKER PUSH
        // ============================================
        stage('Docker Push') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'dockerhub-creds', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
                    retry(3) {
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

        // ============================================
                // 17. DEPLOY WITH ANSIBLE
                // ============================================
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
    }

     stage('Deploy') {
                environment {
                    NEXUS_URL = 'http://127.0.0.1:8081'
                }
                steps {
                    withCredentials([usernamePassword(credentialsId: 'nexus-creds', usernameVariable: 'NEXUS_USER', passwordVariable: 'NEXUS_PASS')]) {
                        sh '''
                            cd /Users/imedjadli/ansible-workshop/backend
                            /opt/homebrew/bin/ansible-playbook -i inventory.ini site.yml \
                              -e "app_env=prod" \
                              -e "build_number=${BUILD_NUMBER}" \
                              -e "nexus_url=${NEXUS_URL}" \
                              -e "zip_name=devops-formation-frontend-${BUILD_NUMBER}.zip"
                        '''
                    }
                }
            }

    // ================================================
    // PIPELINE POST ACTIONS
    // ================================================
    post {
        success {
            echo '================================='
            echo 'PIPELINE STATUS : SUCCESS'
            echo '================================='
        }

        failure {
            echo '================================='
            echo 'PIPELINE STATUS : FAILED'
            echo '================================='
        }

        always {
            echo '================================='
            echo 'PIPELINE TERMINE'
            echo '================================='
        }
    }
}
