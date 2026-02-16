pipeline {
    agent any

    environment {
        SCANNER_HOME = tool 'sonar-scanner'
        SONAR_CREDENTIALS_ID = 'Sonar-token'
        SONARQUBE_URL = 'http://192.168.8.14:9000'
        DOCKER_IMAGE = 'abdoulie/wave-image'
        DOCKER_TAG = 'latest'
        DOCKER_CREDENTIALS = 'docker-hub-credentials'
    }

    stages {

        stage('Checkout') {
            steps {
                echo '🔄 Clonage du code depuis le dépôt Git'
                checkout scm
            }
        }

        stage('Trivy FS Scan') {
            steps {
                echo '🔍 Analyse des fichiers de l\'application avec Trivy (filesystem)'
                sh 'trivy fs . > trivyfs.txt || true'
            }
        }

        stage('Build Docker Image') {
            steps {
                echo '🛠️ Construction de l\'image Docker'
                sh '''
                    docker build -t $DOCKER_IMAGE:$DOCKER_TAG .
                '''
            }
        }

        stage('Push Docker Image to Docker Hub') {
            steps {
                echo '📤 Push de l\'image Docker vers Docker Hub'
                withCredentials([usernamePassword(
                    credentialsId: DOCKER_CREDENTIALS,
                    passwordVariable: 'DOCKER_PASSWORD',
                    usernameVariable: 'DOCKER_USERNAME'
                )]) {
                    sh '''
                        docker login -u $DOCKER_USERNAME -p $DOCKER_PASSWORD
                        docker tag $DOCKER_IMAGE:$DOCKER_TAG docker.io/$DOCKER_USERNAME/wave-image:$DOCKER_TAG
                        docker push docker.io/$DOCKER_USERNAME/wave-image:$DOCKER_TAG
                    '''
                }
            }
        }

        stage('SonarQube Analysis') {
            steps {
                echo '📊 Analyse statique du code avec SonarQube'
                withSonarQubeEnv('sonarqube') {
                    sh '''
                        $SCANNER_HOME/bin/sonar-scanner \
                        -Dsonar.projectKey=wave-project \
                        -Dsonar.host.url=$SONARQUBE_URL \
                        -Dsonar.login=$SONARQUBE_TOKEN  \
                        -Dsonar.exclusions=k8s/**/*
                    '''
                }
            }
        }

        stage('Trivy Docker Image Scan') {
            steps {
                echo '🔐 Analyse de sécurité de l\'image Docker avec Trivy'
                sh '''
                    trivy image --no-progress --exit-code 1 --severity HIGH,CRITICAL $DOCKER_IMAGE:$DOCKER_TAG || true
                '''
            }
        }

        stage('Deploy to Kubernetes') {
            steps {
                echo '🚀 Déploiement de l\'application dans Kubernetes (MicroK8s)'
                script {
                    sh '/snap/bin/microk8s.kubectl apply -f k8s/wave-env.yml'
                    sh '/snap/bin/microk8s.kubectl apply -f k8s/wave-nginx-config.yml'
                    sh '/snap/bin/microk8s.kubectl apply -f k8s/pvc.yml'
                    sh '/snap/bin/microk8s.kubectl apply -f k8s/deployment.yml'
                    sh '/snap/bin/microk8s.kubectl apply -f k8s/service.yml'
                }
            }
        }
    }
}
