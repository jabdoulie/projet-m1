def call(Map config = [:]) {

    def appDir = config.appDir ?: '.'
    def dockerTag = config.dockerTag ?: 'latest'

    stage('Trivy FS Scan') {
        echo 'Analyse des fichiers avec Trivy (filesystem)'
        sh 'trivy fs . --format table -o trivyfs-report.txt || true'
        archiveArtifacts artifacts: 'trivyfs-report.txt', allowEmptyArchive: true
    }

    stage('SonarQube Analysis') {
        echo 'Analyse statique du code avec SonarQube'
        withCredentials([string(credentialsId: 'sonarqube-url', variable: 'SONARQUBE_URL')]) {
            withSonarQubeEnv('sonarqube') {
                sh """
                    \$SCANNER_HOME/bin/sonar-scanner \
                    -Dsonar.projectKey=${config.projectKey ?: 'wave-project'} \
                    -Dsonar.projectName="${config.projectName ?: 'Wave Application'}" \
                    -Dsonar.sources=${appDir} \
                    -Dsonar.host.url=\$SONARQUBE_URL \
                    -Dsonar.exclusions=**/k8s/**/*,**/vendor/**/*,**/node_modules/**/*,**/infra/**/*
                """
            }
        }
    }

    stage('Build Docker Image') {
        echo 'Construction de l\'image Docker'
        withCredentials([string(credentialsId: 'docker-image-name', variable: 'DOCKER_IMAGE')]) {
            dir(appDir) {
                sh """
                    docker build -t \$DOCKER_IMAGE:${dockerTag} .
                    docker tag \$DOCKER_IMAGE:${dockerTag} \$DOCKER_IMAGE:latest
                """
            }
        }
    }

    stage('Trivy Docker Image Scan') {
        echo 'Analyse de sécurité de l\'image Docker avec Trivy'
        withCredentials([string(credentialsId: 'docker-image-name', variable: 'DOCKER_IMAGE')]) {
            sh """
                trivy image --format table -o trivy-image-report.txt \$DOCKER_IMAGE:${dockerTag} || true
            """
        }
        archiveArtifacts artifacts: 'trivy-image-report.txt', allowEmptyArchive: true
    }

    stage('Push Docker Image to Docker Hub') {
        echo 'Push de l\'image Docker vers Docker Hub'
        withCredentials([
            usernamePassword(credentialsId: 'docker-hub-credentials', usernameVariable: 'DOCKER_USERNAME', passwordVariable: 'DOCKER_PASSWORD'),
            string(credentialsId: 'docker-image-name', variable: 'DOCKER_IMAGE')
        ]) {
            sh """
                echo \$DOCKER_PASSWORD | docker login -u \$DOCKER_USERNAME --password-stdin
                docker push \$DOCKER_IMAGE:${dockerTag}
                docker push \$DOCKER_IMAGE:latest
            """
        }
    }

    stage('Update K8s Manifests') {
        echo 'Mise à jour des manifestes K8s'
        withCredentials([
            usernamePassword(credentialsId: 'github-credentials', usernameVariable: 'GIT_USERNAME', passwordVariable: 'GIT_PASSWORD'),
            string(credentialsId: 'docker-image-name', variable: 'DOCKER_IMAGE'),
            string(credentialsId: 'git-repo-url', variable: 'GIT_REPO_URL')
        ]) {
            sh """
                sed -i "s|image: \${DOCKER_IMAGE}:.*|image: \${DOCKER_IMAGE}:${dockerTag}|g" ${appDir}/k8s/deployment.yml

                git config user.email "jenkins@wave.local"
                git config user.name "Jenkins CI"

                git add ${appDir}/k8s/deployment.yml
                git commit -m "ci: update image tag to ${dockerTag} [skip ci]" || echo "No changes"
                git push https://\${GIT_USERNAME}:\${GIT_PASSWORD}@\${GIT_REPO_URL} HEAD:main || echo "Push failed"
            """
        }
    }

    stage('Trigger FluxCD Reconciliation') {
        echo 'Déploiement via FluxCD (GitOps)'
        sh '''
            echo "FluxCD va détecter et déployer automatiquement"
        '''
    }
}