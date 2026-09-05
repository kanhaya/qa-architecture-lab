pipeline {
    agent any

    environment {
        // In-cluster registry name (same registry the k3d cluster pulls from)
        REGISTRY = 'k3d-qa-registry:5000'
        IMAGE_NAME = 'loan-service'
        CLUSTER_IMAGE = "${REGISTRY}/${IMAGE_NAME}:${BUILD_NUMBER}"
        KEEP_IMAGES = '3'

        // Host-mapped registry port (Docker daemon pushes via host port mapping)
        HOST_REGISTRY = 'localhost:5001'

        // k3d cluster: qa-cluster (Jenkins is on network k3d-qa-cluster)
        K3D_CLUSTER = 'qa-cluster'
        K3D_NETWORK = 'k3d-qa-cluster'
        KUBE_CONTEXT = 'k3d-qa-cluster'
        KUBE_SERVER = 'https://k3d-qa-cluster-serverlb:6443'
        K3D_IMAGE = 'ghcr.io/k3d-io/k3d:5.8.3'
        BASE_URL = 'http://k3d-qa-cluster-server-0:30080'
        NAMESPACE = 'qa-lab'

        SONAR_HOST_URL = 'http://sonarqube:9000'
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Verify Environment') {
            steps {
                sh '''#!/usr/bin/env bash
set -e

                    echo "=== Docker ==="
                    docker --version

                    echo "=== Kubernetes ==="
                    kubectl version --client

                    echo "=== Maven ==="
                    mvn --version

                    echo "=== k3d Registry ==="
                    curl -sf http://${REGISTRY}/v2/_catalog || \
                        echo "WARNING: registry not reachable at ${REGISTRY}"

                    echo "=== SonarQube ==="
                    curl -sf ${SONAR_HOST_URL}/api/system/status || \
                        echo "WARNING: SonarQube not reachable at ${SONAR_HOST_URL}"

                    echo "=== k3d API ==="
                    chmod +x scripts/configure-jenkins-kubeconfig.sh
                    source scripts/configure-jenkins-kubeconfig.sh
                    kubectl get nodes
                '''
            }
        }

        stage('Quality Gate') {
            steps {
                sh '''
                    echo "=== Quality Gate: unit, component, contract, JaCoCo, static analysis ==="
                    mvn -pl loan-service -am clean verify
                '''
            }
        }

        stage('SonarQube') {
            steps {
                script {
                    def branch = env.BRANCH_NAME ?: env.GIT_BRANCH ?: 'main'
                    def waitForGate = !(branch.contains('spike/') || branch.contains('experiment/'))
                    echo "Branch=${branch} sonar.qualitygate.wait=${waitForGate}"
                    withCredentials([string(credentialsId: 'SONAR_TOKEN', variable: 'SONAR_TOKEN')]) {
                        sh """
                            mvn -pl loan-service -am sonar:sonar \\
                                -Dsonar.host.url=${SONAR_HOST_URL} \\
                                -Dsonar.token=\${SONAR_TOKEN} \\
                                -Dsonar.qualitygate.wait=${waitForGate} \\
                                -Dsonar.projectVersion=${BUILD_NUMBER}
                        """
                    }
                }
            }
        }

        stage('Build Docker Image') {
            when {
                expression {
                    def b = env.BRANCH_NAME ?: env.GIT_BRANCH ?: 'main'
                    return b == 'main' || b.endsWith('/main')
                }
            }
            steps {
                sh '''
                    set -e

                    docker build \
                        -t ${HOST_REGISTRY}/${IMAGE_NAME}:${BUILD_NUMBER} \
                        .

                    docker push \
                        ${HOST_REGISTRY}/${IMAGE_NAME}:${BUILD_NUMBER}
                '''
            }
        }

        stage('Deploy to Kubernetes') {
            when {
                expression {
                    def b = env.BRANCH_NAME ?: env.GIT_BRANCH ?: 'main'
                    return b == 'main' || b.endsWith('/main')
                }
            }
            steps {
                sh '''#!/usr/bin/env bash
set -e
                    source scripts/configure-jenkins-kubeconfig.sh

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

        stage('Wait for Application') {
            when {
                expression {
                    def b = env.BRANCH_NAME ?: env.GIT_BRANCH ?: 'main'
                    return b == 'main' || b.endsWith('/main')
                }
            }
            steps {
                sh '''#!/usr/bin/env bash
set -e
                    source scripts/configure-jenkins-kubeconfig.sh

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

        stage('Run REST Assured Tests') {
            when {
                expression {
                    def b = env.BRANCH_NAME ?: env.GIT_BRANCH ?: 'main'
                    return b == 'main' || b.endsWith('/main')
                }
            }
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
            archiveArtifacts allowEmptyArchive: true, artifacts: 'loan-service/target/site/jacoco/**'
            sh '''#!/usr/bin/env bash
                    if ! command -v docker >/dev/null 2>&1; then
                      echo "Skipping image prune: docker CLI not in this agent"
                      exit 0
                    fi
                    chmod +x scripts/prune-loan-images.sh
                    echo "=== Pruning old ${IMAGE_NAME} images (keep last ${KEEP_IMAGES}) ==="
                    KEEP_IMAGES="${KEEP_IMAGES}" IMAGE_NAME="${IMAGE_NAME}" BUILD_NUMBER="${BUILD_NUMBER}" \
                        ./scripts/prune-loan-images.sh
                '''
        }
        failure {
            echo 'Pipeline failed. Check console output above for the first error.'
        }
    }
}
