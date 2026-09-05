# Loan Service — QA Architecture Lab

A production-style **Loan Management microservice** built for hands-on learning by Senior SDETs and QA Architects. The project demonstrates the full lifecycle of a cloud-native service: local development, containerization, Kubernetes deployment, API automation, and deployment validation.

> **Full walkthrough:** See [docs/BUILD-GUIDE.md](docs/BUILD-GUIDE.md) for the complete step-by-step guide.  
> **PDF playbook:** [docs/QA-Architecture-Lab-Playbook.pdf](docs/QA-Architecture-Lab-Playbook.pdf) — regenerate with `./scripts/generate-playbook-pdf.sh`

## Architecture

```
Controller → Service → Repository → In-memory storage (ConcurrentHashMap)
```

```text
qa-architecture-lab/
├── loan-service/          # Spring Boot application
├── tests/                 # REST Assured API automation (separate module)
├── k8s/                   # Kubernetes manifests
├── scripts/               # Setup, deployment, and validation scripts
├── docker-compose.sonarqube.yml
├── Dockerfile
├── Jenkinsfile
└── pom.xml                # Maven parent POM
```

## Prerequisites

- Java 21
- Maven 3.9+
- Docker
- k3d (for local Kubernetes)
- kubectl

## Start the full lab

One command starts Docker (if needed), the k3d cluster Jenkins expects (`qa-cluster`), SonarQube, Jenkins, and the Docker networks:

```bash
./scripts/up.sh
```

Then open http://localhost:8080, add credential `SONAR_TOKEN` from the script output, and **Build Now** on `qa-k3d-pipeline` (`main`).

Skip pieces with `SKIP_JENKINS=1`, `SKIP_SONAR=1`, or `SKIP_DASHBOARD=1`.

Stop everything and reclaim this lab's Docker disk (loan-service images, Sonar volumes, k3d cluster — not unrelated images on your machine):

```bash
./scripts/down.sh
```

Remove Sonar/Jenkins/k3s images and Jenkins home as well:

```bash
./scripts/down.sh --purge
```

## API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/loans` | List all loans |
| GET | `/api/loans/{id}` | Get loan by ID |
| POST | `/api/loans` | Create a loan (status: PENDING) |
| PUT | `/api/loans/{id}/status` | Update loan status |
| DELETE | `/api/loans/{id}` | Delete a loan |
| GET | `/actuator/health` | Health check |
| GET | `/actuator/info` | Application info |

### Seeded Data

| ID | Customer | Amount | Status |
|----|----------|--------|--------|
| 101 | Rahul | 500,000 | APPROVED |
| 102 | Amit | 300,000 | PENDING |

## Run Locally

```bash
cd loan-service
mvn spring-boot:run
```

Verify:

```bash
curl http://localhost:8081/actuator/health
curl http://localhost:8081/api/loans
```

### Configuration

Environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `SERVER_PORT` | `8081` | HTTP port (8081 avoids conflict with Jenkins on 8080) |
| `APP_ENV` | `local` | Environment profile (`local`, `test`, `docker`, `kubernetes`) |

## Run Unit Tests

```bash
mvn test -pl loan-service
```

In-process quality gate (unit/contract tests, **JaCoCo ≥ 80% line coverage**, Checkstyle, SpotBugs):

```bash
mvn -pl loan-service -am verify
```

JaCoCo HTML report: `loan-service/target/site/jacoco/index.html`. Coverage excludes Spring Boot entrypoints, `config` packages, and generated/mapper/migration paths so boilerplate cannot fail the gate.

## Run with Docker

```bash
mvn clean package -pl loan-service -am -DskipTests
docker build -t loan-service:1.0 .
docker run -p 8081:8080 -e APP_ENV=docker loan-service:1.0
```

Verify:

```bash
curl http://localhost:8081/actuator/health
curl http://localhost:8081/api/loans
```

## Deploy to Kubernetes (k3d)

### Quick setup

```bash
./scripts/setup-k3d-cluster.sh
```

This creates a k3d cluster with:
- Embedded registry at `localhost:5001` (in-cluster: `qa-registry:5000`)
- NodePort mapping for the service at `http://localhost:30080`
- Namespace `qa-lab` and all manifests applied

### Manual deploy

```bash
docker build -t localhost:5001/loan-service:1.0 .
docker push localhost:5001/loan-service:1.0
kubectl apply -f k8s/
kubectl set image deployment/loan-service \
  loan-service=qa-registry:5000/loan-service:1.0 -n qa-lab
```

Or use the all-in-one script:

```bash
./scripts/deploy-and-test.sh
```

### Verify

```bash
kubectl -n qa-lab get pods
kubectl -n qa-lab get deployment
kubectl -n qa-lab get service
curl http://localhost:30080/actuator/health
curl http://localhost:30080/api/loans
```

## Kubernetes Dashboard

`./scripts/up.sh` installs the dashboard. To reconnect the port-forward later:

```bash
./scripts/open-dashboard.sh
```

- URL: **https://localhost:8443**
- Auth: paste the token printed by the script
- Navigate to namespace **qa-lab** to see the loan-service deployment

## Local UI Port Map

| UI | URL |
|----|-----|
| Kubernetes Dashboard | https://localhost:8443 |
| SonarQube | http://localhost:9000 |
| Loan Service API | http://localhost:30080/api/loans |
| Health check | http://localhost:30080/actuator/health |
| Local dev (Spring Boot) | http://localhost:8081 |

## External CI/CD (Jenkins)

Jenkins runs in a **Docker container** with access to the Docker socket, Maven, and `kubectl`. The pipeline in `Jenkinsfile` implements this flow:

```
GitHub → Jenkins (Docker) → Quality Gate (mvn verify + JaCoCo)
    → SonarQube (sonar.qualitygate.wait=true)
    → docker build → k3d Registry (qa-registry:5000) → k3d Cluster
    → kubectl set image → 3 replicas → REST Assured smoke → JUnit report
```

### One-time setup

Preferred — bring everything up:

```bash
./scripts/up.sh
```

Or step by step:

1. Create the k3d cluster and registry:

```bash
K3D_CLUSTER=qa-cluster REGISTRY_NAME=qa-registry ./scripts/setup-k3d-cluster.sh
```

2. Connect Jenkins to the k3d Docker network:

```bash
JENKINS_CONTAINER=jenkins ./scripts/setup-jenkins-k3d-network.sh
```

3. Kubeconfig is generated automatically in the pipeline via `scripts/configure-jenkins-kubeconfig.sh` (no Jenkins credential required).

   Optional — export a kubeconfig manually for local debugging:

```bash
./scripts/export-jenkins-kubeconfig.sh jenkins-kubeconfig.yaml
```

### SonarQube quality gate (local Docker)

Community Edition SonarQube runs beside Jenkins. It **fails the pipeline** when the custom New Code gate is red (`sonar.qualitygate.wait=true`). It does **not** post GitHub PR line comments (that needs Developer Edition or SonarCloud). Use the Jenkins job status plus http://localhost:9000 for issue detail.

One-time:

```bash
./scripts/setup-sonarqube.sh
```

That starts `docker-compose.sonarqube.yml`, waits until Sonar is `UP`, sets the admin password (`SONAR_ADMIN_PASSWORD`, default `QALabAdmin!9000`), creates project `com.qa:qa-architecture-lab`, attaches quality gate `qa-lab-new-code`, prints a token, and connects Jenkins to network `qa-lab-sonar` when the `jenkins` container exists.

Jenkins credential:

| Field | Value |
|-------|--------|
| Kind | Secret text |
| ID | `SONAR_TOKEN` |
| Secret | token printed by `setup-sonarqube.sh` |

If Jenkins was started later:

```bash
JENKINS_CONTAINER=jenkins ./scripts/setup-jenkins-sonar-network.sh
```

Local scan after `verify`:

```bash
mvn -pl loan-service -am sonar:sonar -Dsonar.token=<token>
```

New Code conditions on `qa-lab-new-code`: coverage ≥ 80%, duplicated lines ≤ 3%, new vulnerabilities = 0, new blocker/critical issues = 0, security hotspots reviewed = 100%, reliability/security/maintainability ratings = A. The New Code Period is **previous version** (Jenkins sets `-Dsonar.projectVersion=$BUILD_NUMBER` on each analysis).

Branch behavior in `Jenkinsfile`:

| Branch | Maven verify + JaCoCo | Sonar wait | Deploy + smoke |
|--------|------------------------|------------|----------------|
| `main` | Yes | `true` | Yes |
| feature | Yes | `true` | No |
| `spike/**`, `experiment/**` | Yes | `false` | No |

### Shift-left (SonarLint)

Install SonarLint / SonarQube for IDE in IntelliJ or VS Code and bind **Connected Mode** to `http://localhost:9000` with project key `com.qa:qa-architecture-lab`. Most issues then show while typing, before CI.

### Registry naming

| Context | Registry URL | Why |
|---------|--------------|-----|
| **Image tag / cluster pull** | `qa-registry:5000` | In-cluster DNS name used by Kubernetes (HTTP, injected by k3d) |
| **docker push from Jenkins** | `localhost:5001` | Host-mapped port to the **same** k3d registry |

The pipeline sets the deployment image to `qa-registry:5000/loan-service:<build>` and pushes via `localhost:5001` because the Docker daemon reaches the registry through the host port mapping.

### Service URL for tests

From Jenkins on the `k3d-qa-cluster` network, API tests use:

```
http://k3d-qa-cluster-server-0:30080
```

Jenkins on port **8080** does not conflict with the Loan Service — tests hit the Kubernetes NodePort, not Jenkins.

## Run API Tests

The `tests/` module is a separate Maven project using REST Assured and JUnit 5. Tests run against a **running** deployment.

### Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `BASE_URL` | auto-detected | Service URL (e.g. `http://localhost:8081` or `http://localhost:30080`) |
| `env` | `local` | Target environment (`local`, `docker`, `kubernetes`) |

```bash
# Ensure the application is running first
export BASE_URL=http://localhost:8081

# Smoke tests
mvn test -pl tests -Dgroups=smoke

# Functional tests
mvn test -pl tests -Dgroups=functional

# Negative tests
mvn test -pl tests -Dgroups=negative

# Full regression (all tests)
mvn test -pl tests

# Kubernetes environment
mvn test -pl tests -Denv=kubernetes -DBASE_URL=http://localhost:30080
```

### Test Suites

| Suite | Tag | Coverage |
|-------|-----|----------|
| Smoke | `smoke` | Health, get loans, get by ID, create loan |
| Functional | `functional` | Full CRUD lifecycle |
| Negative | `negative` | Validation errors, 404s, malformed JSON |
| Regression | (all) | All API tests |

## Deployment Validation

Validate a Kubernetes deployment before running smoke tests:

```bash
export BASE_URL=http://localhost:30080
./scripts/validate-deployment.sh
```

Full deploy-and-test orchestration:

```bash
./scripts/deploy-and-test.sh
```

Configurable environment variables for scripts:

| Variable | Default |
|----------|---------|
| `NAMESPACE` | `qa-lab` |
| `DEPLOYMENT` | `loan-service` |
| `BASE_URL` | `http://localhost:30080` |
| `TIMEOUT` | `180` |
| `K3D_CLUSTER` | `qa-cluster` |
| `REGISTRY` | `localhost:5001` |

## Troubleshooting

### Port 8081 already in use

Another process may be bound to port 8081. Options:

```bash
# Use a different port
SERVER_PORT=8082 mvn spring-boot:run

# Point tests at the correct URL
BASE_URL=http://localhost:8082 mvn test -pl tests -Dgroups=smoke
```

### Jenkins on port 8080

If Jenkins is running locally on `http://localhost:8080`, do **not** point API tests at port 8080 — you will hit Jenkins instead of the Loan Service. Use port `8081` for local dev or `30080` for Kubernetes.

The test framework auto-detects a healthy endpoint on common localhost variants when `BASE_URL` is not set.

### k3d pods stuck in ImagePullBackOff

Push the image to the k3d registry:

```bash
docker build -t localhost:5001/loan-service:1.0 .
docker push localhost:5001/loan-service:1.0
```

Ensure the deployment image uses `qa-registry:5000/loan-service:<tag>` (in-cluster registry port is 5000).

### Pods not becoming Ready

```bash
kubectl -n qa-lab describe pod <pod-name>
kubectl -n qa-lab logs <pod-name>
```

### Deployment not rolling out

```bash
kubectl -n qa-lab rollout status deployment/loan-service
kubectl -n qa-lab get events --sort-by='.lastTimestamp'
```

### API tests failing with connection errors

1. Confirm the application is running: `curl $BASE_URL/actuator/health`
2. Set `BASE_URL` explicitly if auto-detection fails
3. For Kubernetes, use `BASE_URL=http://localhost:30080` (NodePort)

## Roadmap

| Phase | Status | Description |
|-------|--------|-------------|
| 1 — Spring Boot API | Done | REST API with in-memory storage |
| 2 — Unit Tests | Done | Service, repository, controller, OpenAPI contract |
| 3 — Docker | Done | Multi-stage Dockerfile with health check |
| 4 — Kubernetes | Done | k3d deployment with 3 replicas |
| 5 — API Automation | Done | REST Assured test framework |
| 6 — Deployment Validation | Done | Post-deploy validation scripts |
| 7 — Resilience Testing | Planned | Pod failure, scaling, rollback |
| 8 — CI/CD | Done | Jenkins Quality Gate (JaCoCo + Sonar wait) → image → deploy → smoke |
| 9 — Helm | Planned | Helm chart templating |
| 10 — Argo CD | Planned | GitOps deployment |
| 11 — Observability | Planned | Prometheus, Grafana, OpenTelemetry |

## License

This project is for educational purposes.
