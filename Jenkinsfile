pipeline {
    agent any

    environment {
        BASE_URL = 'http://localhost:30080'
        NAMESPACE = 'qa-lab'
        CLUSTER_IMAGE = "k3d-qa-registry:5000/loan-service:${BUILD_NUMBER}"
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
                    set -e

                    echo "=== Building Docker Image ==="

                    docker build \
                        -t k3d-qa-registry:5000/loan-service:${BUILD_NUMBER} \
                        .

                    echo "=== Pushing Docker Image ==="

                    docker push \
                        k3d-qa-registry:5000/loan-service:${BUILD_NUMBER}
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
                        set -e

                        echo "=== Kubernetes Cluster ==="
                        kubectl get nodes

                        echo "=== Applying Manifests ==="
                        kubectl apply -f k8s/

                        echo "=== Updating Deployment Image ==="
                        kubectl set image deployment/loan-service \
                            loan-service=$CLUSTER_IMAGE \
                            -n $NAMESPACE

                        echo "=== Kubernetes Resources ==="
                        kubectl get all -n $NAMESPACE
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
                            -n $NAMESPACE \
                            --timeout=120s

                        echo "=== Pods ==="
                        kubectl get pods -n $NAMESPACE -o wide

                        echo "=== Services ==="
                        kubectl get services -n $NAMESPACE
                    '''
                }
            }
        }

        stage('Run REST Assured Tests') {
            steps {
                sh """
                    echo "=== Running REST Assured Tests ==="
                    mvn test -pl tests -Dgroups=smoke -DBASE_URL=${BASE_URL}
                """
            }
        }
    }

    post {
        always {
            echo '=== Pipeline Finished ==='
            junit allowEmptyResults: true, testResults: '**/target/surefire-reports/*.xml'
        }
    }
}
