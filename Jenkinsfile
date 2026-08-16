pipeline {
    agent any

    environment {
        BASE_URL = 'http://localhost:30080'
        NAMESPACE = 'qa-lab'
        REGISTRY = 'localhost:5001'
        IMAGE_NAME = 'loan-service'
        IMAGE_TAG = '1.0'
        CLUSTER_IMAGE = 'k3d-qa-registry:5000/loan-service:1.0'
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
                sh """
                    echo "=== Building Docker Image ==="
                    docker build -t ${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG} .
                    docker push ${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}
                """
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
