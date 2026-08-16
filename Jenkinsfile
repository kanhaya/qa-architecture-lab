pipeline {
    agent any

    stages {

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

        stage('Build Application') {
            steps {
                sh '''
                    echo "=== Building Application ==="
                    mvn clean package -DskipTests
                '''
            }
        }

        stage('Build Docker Image') {
            steps {
                sh '''
                    echo "=== Building Docker Image ==="

                    docker build \
                        -t qa-loan-service:${BUILD_NUMBER} \
                        .
                '''
            }
        }

        stage('Deploy to Kubernetes') {
            steps {
                withCredentials([
                    file(
                        credentialsId: 'k3d-kubeconfig',
                        variable: 'KUBECONFIG'
                    )
                ]) {
                    sh '''
                        echo "=== Kubernetes Cluster ==="
                        kubectl get nodes

                        echo "=== Deploying Application ==="

                        kubectl apply -f k8s/

                        echo "=== Kubernetes Resources ==="
                        kubectl get deployments
                        kubectl get pods
                        kubectl get services
                    '''
                }
            }
        }

        stage('Wait for Application') {
            steps {
                withCredentials([
                    file(
                        credentialsId: 'k3d-kubeconfig',
                        variable: 'KUBECONFIG'
                    )
                ]) {
                    sh '''
                        echo "=== Waiting for Deployment ==="

                        kubectl rollout status deployment/loan-service \
                            --timeout=120s

                        echo "=== Pods ==="
                        kubectl get pods -o wide

                        echo "=== Services ==="
                        kubectl get services
                    '''
                }
            }
        }

        stage('Run REST Assured Tests') {
            steps {
                sh '''
                    echo "=== Running REST Assured Tests ==="

                    mvn test
                '''
            }
        }
    }

    post {
        always {
            echo "=== Pipeline Finished ==="

            junit allowEmptyResults: true,
                  testResults: '**/target/surefire-reports/*.xml'
        }
    }
}