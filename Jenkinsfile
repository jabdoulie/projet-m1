/*
 * ===========================================
 * JENKINSFILE - Pipeline CI/CD pour Wave App
 * ===========================================
 * 
 * CREDENTIALS A CONFIGURER DANS JENKINS (Manage Jenkins > Credentials):
 * 
 * 1. docker-hub-credentials (Username with password)
 *    - Username: votre username Docker Hub
 *    - Password: votre password ou token Docker Hub
 * 
 * 2. github-credentials (Username with password)
 *    - Username: votre username GitHub
 *    - Password: Personal Access Token GitHub (avec droits repo)
 * 
 * 3. sonarqube-url (Secret text)
 *    - Secret: URL de SonarQube (ex: http://IP_JENKINS:9000)
 * 
 * 4. docker-image-name (Secret text)
 *    - Secret: nom de l'image Docker (ex: abdoulie/wave-image)
 * 
 * 5. git-repo-url (Secret text)
 *    - Secret: URL du repo GitHub (ex: github.com/username/projet-m1)
 * 
 * OUTILS A CONFIGURER (Manage Jenkins > Tools):
 * - sonar-scanner : SonarQube Scanner
 * 
 * CONFIGURATION SONARQUBE (Manage Jenkins > System):
 * - Ajouter un serveur SonarQube nommé "sonarqube"
 */

pipeline {
    agent any

    environment {
        SCANNER_HOME = tool 'sonar-scanner'
        DOCKER_TAG = "${BUILD_NUMBER}"
        APP_DIR = 'wave-app'
    }

    stages {

        stage('Checkout') {
            steps {
                echo 'Clonage du code depuis le dépôt Git'
                checkout scm
            }
        }

        stage('Install Dependencies') {
            steps {
                echo 'Installation des dépendances PHP'
                dir("${APP_DIR}") {
                    sh '''
                        docker run --rm -v $(pwd):/app -w /app composer:latest \
                            composer install --no-interaction --prefer-dist --optimize-autoloader
                    '''
                }
            }
        }

        stage('Unit Tests') {
            steps {
                echo 'Exécution des tests unitaires (Pest/PHPUnit)'
                dir("${APP_DIR}") {
                    sh '''
                        docker run --rm -v $(pwd):/app -w /app php:8.2-cli bash -c "
                            # Copier le fichier .env.example si .env n'existe pas
                            [ ! -f .env ] && cp .env.example .env || true
                            
                            # Créer le dossier pour les rapports
                            mkdir -p storage/test-results
                            
                            # Exécuter les tests avec Pest et générer le rapport JUnit
                            ./vendor/bin/pest --ci --colors=always --log-junit storage/test-results/junit.xml
                        "
                    '''
                }
            }
            post {
                always {
                    junit allowEmptyResults: true, testResults: "${APP_DIR}/storage/test-results/*.xml"
                }
            }
        }

        stage('Trivy FS Scan') {
            steps {
                echo 'Analyse des fichiers avec Trivy (filesystem)'
                sh 'trivy fs . --format table -o trivyfs-report.txt || true'
                archiveArtifacts artifacts: 'trivyfs-report.txt', allowEmptyArchive: true
            }
        }

        stage('SonarQube Analysis') {
            steps {
                echo 'Analyse statique du code avec SonarQube'
                withCredentials([string(credentialsId: 'sonarqube-url', variable: 'SONARQUBE_URL')]) {
                    withSonarQubeEnv('sonarqube') {
                        sh '''
                            $SCANNER_HOME/bin/sonar-scanner \
                            -Dsonar.projectKey=wave-project \
                            -Dsonar.projectName="Wave Application" \
                            -Dsonar.sources=${APP_DIR} \
                            -Dsonar.host.url=$SONARQUBE_URL \
                            -Dsonar.exclusions=**/k8s/**/*,**/vendor/**/*,**/node_modules/**/*,**/infra/**/*
                        '''
                    }
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                echo 'Construction de l\'image Docker'
                withCredentials([string(credentialsId: 'docker-image-name', variable: 'DOCKER_IMAGE')]) {
                    dir("${APP_DIR}") {
                        sh '''
                            docker build -t $DOCKER_IMAGE:$DOCKER_TAG .
                            docker tag $DOCKER_IMAGE:$DOCKER_TAG $DOCKER_IMAGE:latest
                        '''
                    }
                }
            }
        }

        stage('Trivy Docker Image Scan') {
            steps {
                echo 'Analyse de sécurité de l\'image Docker avec Trivy'
                withCredentials([string(credentialsId: 'docker-image-name', variable: 'DOCKER_IMAGE')]) {
                    sh '''
                        trivy image --format table -o trivy-image-report.txt $DOCKER_IMAGE:$DOCKER_TAG || true
                    '''
                }
                archiveArtifacts artifacts: 'trivy-image-report.txt', allowEmptyArchive: true
            }
        }

        stage('Push Docker Image to Docker Hub') {
            steps {
                echo 'Push de l\'image Docker vers Docker Hub'
                withCredentials([
                    usernamePassword(credentialsId: 'docker-hub-credentials', usernameVariable: 'DOCKER_USERNAME', passwordVariable: 'DOCKER_PASSWORD'),
                    string(credentialsId: 'docker-image-name', variable: 'DOCKER_IMAGE')
                ]) {
                    sh '''
                        echo $DOCKER_PASSWORD | docker login -u $DOCKER_USERNAME --password-stdin
                        docker push $DOCKER_IMAGE:$DOCKER_TAG
                        docker push $DOCKER_IMAGE:latest
                    '''
                }
            }
        }

        stage('Update K8s Manifests') {
            steps {
                echo 'Mise à jour des manifestes K8s avec le nouveau tag'
                withCredentials([
                    usernamePassword(credentialsId: 'github-credentials', usernameVariable: 'GIT_USERNAME', passwordVariable: 'GIT_PASSWORD'),
                    string(credentialsId: 'docker-image-name', variable: 'DOCKER_IMAGE'),
                    string(credentialsId: 'git-repo-url', variable: 'GIT_REPO_URL')
                ]) {
                    sh '''
                        # Mettre à jour le tag de l'image dans deployment.yml
                        sed -i "s|image: ${DOCKER_IMAGE}:.*|image: ${DOCKER_IMAGE}:${DOCKER_TAG}|g" ${APP_DIR}/k8s/deployment.yml
                        
                        # Configurer Git
                        git config user.email "jenkins@wave.local"
                        git config user.name "Jenkins CI"
                        
                        # Commit et push les changements
                        git add ${APP_DIR}/k8s/deployment.yml
                        git commit -m "ci: update image tag to ${DOCKER_TAG} [skip ci]" || echo "No changes to commit"
                        git push https://${GIT_USERNAME}:${GIT_PASSWORD}@${GIT_REPO_URL} HEAD:main || echo "Push failed or no changes"
                    '''
                }
            }
        }

        stage('Trigger FluxCD Reconciliation') {
            steps {
                echo 'FluxCD va automatiquement détecter les changements et déployer'
                echo 'Le déploiement est géré par FluxCD (GitOps)'
                sh '''
                    echo "================================================"
                    echo "FluxCD surveille le repo Git et va automatiquement:"
                    echo "  1. Détecter le nouveau commit"
                    echo "  2. Appliquer les manifestes K8s mis à jour"
                    echo "  3. Déployer la nouvelle version de l'application"
                    echo "================================================"
                '''
            }
        }

        // stage('Run Pipeline') {
        //     steps {
        //         script {
        //             fullPipeline(
        //                 appDir: "${APP_DIR}",
        //                 dockerTag: "${DOCKER_TAG}",
        //                 projectKey: "wave-project",
        //                 projectName: "Wave Application"
        //             )
        //         }
        //     }
        // }
    }

    post {
        always {
            echo 'Nettoyage des images Docker locales'
            withCredentials([string(credentialsId: 'docker-image-name', variable: 'DOCKER_IMAGE')]) {
                sh '''
                    docker rmi $DOCKER_IMAGE:$DOCKER_TAG || true
                    docker image prune -f || true
                '''
            }
        }
        success {
            echo 'Pipeline terminé avec succès !'
        }
        failure {
            echo 'Le pipeline a échoué. Vérifiez les logs.'
        }
    }
}
