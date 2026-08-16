pipeline {
    agent any

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
                    mvn --version
                '''
            }
        }

        stage('Maven Build & Test') {
            steps {
                sh '''
                    mvn clean test
                '''
            }
        }

        stage('Verify Kubernetes') {
            steps {
                withCredentials([
                    file(
                        credentialsId: 'k3d-kubeconfig',
                        variable: 'KUBECONFIG'
                    )
                ]) {
                    sh '''
                        kubectl get nodes
                        kubectl get pods -A
                    '''
                }
            }
        }
    }
}
