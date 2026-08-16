# Loan Service — QA Architecture Lab

A production-style **Loan Management microservice** built for hands-on learning by Senior SDETs and QA Architects. The project demonstrates the full lifecycle of a cloud-native service: local development, containerization, Kubernetes deployment, API automation, and deployment validation.

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
├── Dockerfile
└── pom.xml                # Maven parent POM
```

## Prerequisites

- Java 21
- Maven 3.9+
- Docker
- k3d (for local Kubernetes)
- kubectl

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
- Embedded registry at `localhost:5001` (in-cluster: `k3d-qa-registry:5000`)
- NodePort mapping for the service at `http://localhost:30080`
- Namespace `qa-lab` and all manifests applied

### Manual deploy

```bash
docker build -t localhost:5001/loan-service:1.0 .
docker push localhost:5001/loan-service:1.0
kubectl apply -f k8s/
kubectl set image deployment/loan-service \
  loan-service=k3d-qa-registry:5000/loan-service:1.0 -n qa-lab
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

### Start the full lab (k3d + Dashboard)

```bash
./scripts/start-lab.sh
./scripts/deploy-and-test.sh
```

## Kubernetes Dashboard

Install and open the dashboard to inspect pods, services, and rollouts visually:

```bash
./scripts/setup-k8s-dashboard.sh
```

Or start port-forward in the background:

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
| Loan Service API | http://localhost:30080/api/loans |
| Health check | http://localhost:30080/actuator/health |
| Local dev (Spring Boot) | http://localhost:8081 |

## External CI/CD (Jenkins)

Jenkins typically runs on **port 8080**, so the Loan Service defaults to **8081** locally to avoid conflicts.

Use the included `Jenkinsfile` pipeline, or run the deploy script manually:

```bash
./scripts/deploy-and-test.sh
```

The pipeline runs unit tests, deploys to k3d/Kubernetes, and executes smoke tests against `http://localhost:30080`.

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
| `K3D_CLUSTER` | `qa-lab` |
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

Ensure the deployment image uses `k3d-qa-registry:5000/loan-service:<tag>` (in-cluster registry port is 5000).

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
| 2 — Unit Tests | Done | Service, repository, controller tests |
| 3 — Docker | Done | Multi-stage Dockerfile with health check |
| 4 — Kubernetes | Done | k3d deployment with 3 replicas |
| 5 — API Automation | Done | REST Assured test framework |
| 6 — Deployment Validation | Done | Post-deploy validation scripts |
| 7 — Resilience Testing | Planned | Pod failure, scaling, rollback |
| 8 — CI/CD | Planned | External Jenkins or GitHub Actions |
| 9 — Helm | Planned | Helm chart templating |
| 10 — Argo CD | Planned | GitOps deployment |
| 11 — Observability | Planned | Prometheus, Grafana, OpenTelemetry |

## License

This project is for educational purposes.
