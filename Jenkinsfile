pipeline {
    agent any

    environment {
        SERVER_PORT = '8081'
        BASE_URL = 'http://localhost:30080'
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Verify Environment') {
            steps {
                sh '''
                    echo "=== Docker ==="
                    docker --version

                    echo "=== Kubernetes ==="
                    kubectl version --client

                    echo "=== Maven ==="
                    ./mvnw --version
                '''
            }
        }

        stage('Unit Tests') {
            steps {
                sh '''
                    ./mvnw clean test -pl loan-service
                '''
            }
        }

        stage('Deploy and API Tests') {
            steps {
                withCredentials([
                    file(
                        credentialsId: 'k3d-kubeconfig',
                        variable: 'KUBECONFIG'
                    )
                ]) {
                    sh '''
                        kubectl get nodes
                        chmod +x scripts/*.sh
                        ./scripts/deploy-and-test.sh
                    '''
                }
            }
        }
    }
}
