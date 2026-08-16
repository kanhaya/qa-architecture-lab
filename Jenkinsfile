pipeline {
    agent any

    environment {
        // In-cluster registry name (same registry the k3d cluster pulls from)
        REGISTRY = 'k3d-qa-registry:5000'
        IMAGE_NAME = 'loan-service'
        CLUSTER_IMAGE = "${REGISTRY}/${IMAGE_NAME}:${BUILD_NUMBER}"

        // Host-mapped registry port (Docker daemon pushes via host port mapping)
        HOST_REGISTRY = 'localhost:5001'

        // k3d cluster: qa-cluster (Jenkins is on network k3d-qa-cluster)
        K3D_CLUSTER = 'qa-cluster'
        K3D_NETWORK = 'k3d-qa-cluster'
        KUBE_CONTEXT = 'k3d-qa-cluster'
        KUBE_SERVER = 'https://k3d-qa-cluster-serverlb:6443'
        BASE_URL = 'http://k3d-qa-cluster-server-0:30080'
        NAMESPACE = 'qa-lab'
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

                    echo "=== k3d Registry ==="
                    curl -sf http://${REGISTRY}/v2/_catalog || \
                        echo "WARNING: registry not reachable at ${REGISTRY}"
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

                    # Tag with in-cluster registry name (k3d-qa-registry:5000)
                    docker build \
                        -t ${REGISTRY}/${IMAGE_NAME}:${BUILD_NUMBER} \
                        .

                    # Push via host-mapped port (same physical k3d registry)
                    docker tag \
                        ${REGISTRY}/${IMAGE_NAME}:${BUILD_NUMBER} \
                        ${HOST_REGISTRY}/${IMAGE_NAME}:${BUILD_NUMBER}

                    docker push \
                        ${HOST_REGISTRY}/${IMAGE_NAME}:${BUILD_NUMBER}
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

                        configure_kubeconfig() {
                            local kubeconfig
                            kubeconfig=$(mktemp)
                            cp "${KUBECONFIG}" "${kubeconfig}"
                            export KUBECONFIG="${kubeconfig}"
                            kubectl config set-cluster "${KUBE_CONTEXT}" \
                                --server="${KUBE_SERVER}"
                            kubectl config use-context "${KUBE_CONTEXT}"
                        }

                        configure_kubeconfig

                        echo "=== Kubernetes Cluster ==="
                        kubectl get nodes

                        echo "=== Applying Manifests ==="
                        kubectl apply -f k8s/

                        echo "=== Updating Deployment Image ==="
                        kubectl set image deployment/loan-service \
                            loan-service=${CLUSTER_IMAGE} \
                            -n ${NAMESPACE}

                        echo "=== Kubernetes Resources ==="
                        kubectl get all -n ${NAMESPACE}
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
                        configure_kubeconfig() {
                            local kubeconfig
                            kubeconfig=$(mktemp)
                            cp "${KUBECONFIG}" "${kubeconfig}"
                            export KUBECONFIG="${kubeconfig}"
                            kubectl config set-cluster "${KUBE_CONTEXT}" \
                                --server="${KUBE_SERVER}"
                            kubectl config use-context "${KUBE_CONTEXT}"
                        }

                        configure_kubeconfig

                        echo "=== Waiting for Deployment ==="
                        kubectl rollout status deployment/loan-service \
                            -n ${NAMESPACE} \
                            --timeout=120s

                        echo "=== Pods ==="
                        kubectl get pods -n ${NAMESPACE} -o wide

                        echo "=== Services ==="
                        kubectl get services -n ${NAMESPACE}
                    '''
                }
            }
        }

        stage('Run REST Assured Tests') {
            steps {
                sh """
                    echo "=== Running REST Assured Tests against ${BASE_URL} ==="
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
        failure {
            echo 'Pipeline failed. Check console output above for the first error.'
        }
    }
}
