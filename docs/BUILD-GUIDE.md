# QA Architecture Lab — Complete Build & CI/CD Playbook

**Jenkins · Docker · k3d · Kubernetes · REST Assured · SonarQube**

| | |
|---|---|
| **Repository** | [github.com/kanhaya/qa-architecture-lab](https://github.com/kanhaya/qa-architecture-lab) |
| **Pipeline** | `qa-k3d-pipeline` @ http://localhost:8080 |
| **Audience** | Senior SDETs & QA Architects |
| **Status** | End-to-end pipeline verified ✅ |

---

This document is a step-by-step record of **what was built**, **why each decision was made**, **what was achieved**, and **how to reproduce the full stack** from scratch.

> **PDF version:** Run `./scripts/generate-playbook-pdf.sh` to regenerate `docs/QA-Architecture-Lab-Playbook.pdf`

---

## Table of Contents

1. [Overall Goal](#1-overall-goal)
2. [What We Achieved](#2-what-we-achieved)
3. [End-to-End Architecture](#3-end-to-end-architecture)
4. [Phase 1 — Loan Service (Spring Boot)](#4-phase-1--loan-service-spring-boot)
5. [Phase 2 — Unit Tests](#5-phase-2--unit-tests)
6. [Phase 3 — Docker Containerization](#6-phase-3--docker-containerization)
7. [Phase 4 — Kubernetes (k3d) Deployment](#7-phase-4--kubernetes-k3d-deployment)
8. [Phase 5 — API Automation (REST Assured)](#8-phase-5--api-automation-rest-assured)
9. [Phase 6 — Deployment Scripts](#9-phase-6--deployment-scripts)
10. [Phase 7 — Jenkins CI/CD Pipeline](#10-phase-7--jenkins-cicd-pipeline)
11. [Port Map Reference](#11-port-map-reference)
12. [Problems Solved & Lessons Learned](#12-problems-solved--lessons-learned)
13. [Diagnostic Command Sheet](#13-diagnostic-command-sheet)
14. [Verification Checklist](#14-verification-checklist)
15. [How to Explain This Like a Pro](#15-how-to-explain-this-like-a-pro)
16. [Reproduce Everything From Scratch](#16-reproduce-everything-from-scratch)
17. [Verify a Successful Build](#17-verify-a-successful-build)
18. [Production Maturity Path](#18-production-maturity-path)

---

## 1. Overall Goal

Build a **production-style QA Architecture Lab** that demonstrates the full lifecycle of a cloud-native microservice:

| Layer | Purpose |
|-------|---------|
| Application | A real REST API (Loan Service) that SDETs can test |
| Unit tests | Fast feedback on business logic |
| Docker | Package the app as a portable container image |
| Kubernetes (k3d) | Run 3 replicas with health probes and a NodePort service |
| API automation | REST Assured smoke/functional/negative/regression suites |
| CI/CD (Jenkins) | Quality gate (tests + JaCoCo + Checkstyle + SpotBugs + OpenAPI + SonarQube wait) → image → deploy → smoke tests |

**Target audience:** Senior SDETs and QA Architects learning how modern teams ship and validate microservices.

**Repository:** [github.com/kanhaya/qa-architecture-lab](https://github.com/kanhaya/qa-architecture-lab)

---

## 2. What We Achieved

By the end of this lab you have:

- ✅ A working **Loan Management REST API** with CRUD operations
- ✅ **Unit and component tests** (`@WebMvcTest`) plus **OpenAPI contract tests** (in-process HTTP, no cluster)
- ✅ **Static analysis** (Checkstyle, SpotBugs) bound to Maven `verify`
- ✅ **JaCoCo** line coverage ≥ 80% on `loan-service` (boilerplate excluded) bound to `verify`
- ✅ **SonarQube Community** (local Docker) with custom New Code quality gate and `sonar.qualitygate.wait=true`
- ✅ A **multi-stage Dockerfile** with a built-in health check
- ✅ **Kubernetes manifests** (namespace, configmap, deployment, service)
- ✅ A **k3d cluster** with an embedded Docker registry and NodePort access
- ✅ **REST Assured API tests** (smoke, functional, negative, regression)
- ✅ **Shell scripts** for cluster setup, deploy, validate, and dashboard
- ✅ A **Jenkins pipeline** with a **Quality Gate + SonarQube wait before `docker build`**, then push, deploy, and cluster smoke tests (`main` only)
- ✅ A **successful end-to-end build** from GitHub → Jenkins → k3d → passing tests

---

## 3. End-to-End Architecture

```
┌──────────────────────┐
│       GitHub         │
│  qa-architecture-lab │
└──────────┬───────────┘
           │  git checkout
           ▼
┌──────────────────────────────────────────┐
│              Jenkins (Docker)            │
│  Port 8080  │  Maven  │  Docker CLI       │
│             │  kubectl                     │
└──────────┬───────────────────────────────┘
           │
     ┌─────┴─────┐
     │           │
 mvn verify    docker build
 (Quality Gate)     │
     │              ▼
     │   ┌──────────────────────┐
     │   │   k3d Registry       │
     │   │ k3d-qa-registry:5000 │
     │   │ (push via :5001)     │
     │   └──────────┬───────────┘
     │              │
     │         docker push
     │              │
     │              ▼
     │   ┌──────────────────────┐
     │   │   k3d Cluster        │
     │   │   qa-cluster         │
     │   │   (k3s / Kubernetes) │
     │   └──────────┬───────────┘
     │              │
     │         kubectl set image
     │              │
     │              ▼
     │   ┌──────────────────────┐
     │   │  Deployment          │
     │   │  loan-service (x3)   │
     │   └──────────┬───────────┘
     │              │
     │    Pod-1  Pod-2  Pod-3
     │              │
     │              ▼
     │   ┌──────────────────────┐
     │   │  Service (NodePort)  │
     │   │  :30080 → :8080      │
     │   └──────────┬───────────┘
     │              │
     └──────────────┤
                    │
              REST Assured
              smoke tests
                    │
                    ▼
             JUnit / Surefire
             Jenkins Report
```

### Application internal architecture

```
HTTP Request
    │
    ▼
LoanController  →  LoanService  →  LoanRepository  →  InMemoryLoanRepository
                                                          (ConcurrentHashMap)
```

---

## 4. Phase 1 — Loan Service (Spring Boot)

### What we built

A Maven multi-module project with a `loan-service` module:

```
loan-service/
├── src/main/java/com/qa/loanservice/
│   ├── controller/     LoanController.java
│   ├── service/        LoanService.java
│   ├── repository/     InMemoryLoanRepository.java
│   ├── model/          Loan, LoanStatus, DTOs
│   └── exception/      GlobalExceptionHandler, LoanNotFoundException
└── src/main/resources/
    ├── application.yml              (local — port 8081)
    ├── application-docker.yml       (Docker — port 8080)
    └── application-kubernetes.yml   (k8s — port 8080)
```

### API endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/loans` | List all loans |
| GET | `/api/loans/{id}` | Get loan by ID |
| POST | `/api/loans` | Create loan (status: PENDING) |
| PUT | `/api/loans/{id}/status` | Update loan status |
| DELETE | `/api/loans/{id}` | Delete loan |
| GET | `/actuator/health` | Health check (used by k8s probes) |
| GET | `/actuator/info` | Application info |

### Seeded test data

| ID | Customer | Amount | Status |
|----|----------|--------|--------|
| 101 | Rahul | 500,000 | APPROVED |
| 102 | Amit | 300,000 | PENDING |

### Why port 8081 locally?

Jenkins runs on **port 8080**. To avoid conflicts during local development, the app defaults to **8081** on the host:

```yaml
# application.yml
server:
  port: ${SERVER_PORT:8081}
```

Inside Docker and Kubernetes containers the app still listens on **8080**.

### How to run locally

```bash
cd loan-service
mvn spring-boot:run

curl http://localhost:8081/actuator/health
curl http://localhost:8081/api/loans
```

---

## 5. Phase 2 — Unit Tests

### What we built

JUnit 5 + Mockito tests inside `loan-service/src/test/`:

| Test class | What it covers |
|------------|----------------|
| `LoanServiceTest` | Business logic, create/update/delete |
| `InMemoryLoanRepositoryTest` | Data storage, seeded data |
| `LoanControllerTest` | HTTP layer with MockMvc |
| `GlobalExceptionHandlerTest` | Error responses (400, 404) |
| `LoanApiContractTest` | OpenAPI contract via REST Assured on `RANDOM_PORT` |

### Why separate from API tests?

Unit, MockMvc, and contract tests run **without Kubernetes** — `mvn -pl loan-service verify` is the Jenkins Quality Gate. Phase 5 REST Assured (`tests` module) still needs a deployed service.

### How to run

```bash
mvn test -pl loan-service
# Full Quality Gate (tests + JaCoCo 80% + Checkstyle + SpotBugs + OpenAPI contract):
mvn -pl loan-service -am verify
```

---

## 6. Phase 3 — Docker Containerization

### What we built

A **multi-stage Dockerfile** at the project root:

| Stage | Base image | Purpose |
|-------|-----------|---------|
| Build | `eclipse-temurin:21-jdk-alpine` | Compile with Maven |
| Runtime | `eclipse-temurin:21-jre-alpine` | Run JAR as non-root user |

Key design choices:

- **Non-root user** (`appuser`) for security
- **curl** installed for Docker `HEALTHCHECK`
- **Health check** hits `/actuator/health` every 30s
- Container listens on **port 8080** (`APP_ENV=docker` profile)

### Why multi-stage?

Keeps the final image small (~200 MB vs ~600 MB with JDK) and follows production best practices.

### How to build and run

```bash
mvn clean package -pl loan-service -am -DskipTests
docker build -t loan-service:1.0 .
docker run -p 8081:8080 -e APP_ENV=docker loan-service:1.0

curl http://localhost:8081/actuator/health
```

---

## 7. Phase 4 — Kubernetes (k3d) Deployment

### What is k3d?

**k3d** runs a lightweight Kubernetes cluster (k3s) inside Docker containers on your local machine. It is ideal for learning and CI/CD labs without needing a cloud account.

### What we built

Kubernetes manifests in `k8s/`:

| File | Purpose |
|------|---------|
| `namespace.yaml` | Isolates resources in `qa-lab` namespace |
| `configmap.yaml` | Sets `APP_ENV=kubernetes`, `SERVER_PORT=8080` |
| `deployment.yaml` | 3 replicas, health probes, resource limits |
| `service.yaml` | NodePort 30080 → pod port 8080 |

### Cluster setup script

`scripts/setup-k3d-cluster.sh` creates:

| Component | Value |
|-----------|-------|
| Cluster name | `qa-lab` (default) or `qa-cluster` (your setup) |
| Registry (host) | `localhost:5001` |
| Registry (in-cluster) | `k3d-qa-registry:5000` |
| NodePort | `30080` |
| Namespace | `qa-lab` |

### Why two registry URLs?

k3d exposes **one physical registry** under two names:

```
Your Mac / Docker daemon          Kubernetes pods
        │                                │
   localhost:5001  ──same registry──  k3d-qa-registry:5000
   (docker push)                     (image pull)
```

### Deployment highlights

```yaml
# deployment.yaml
replicas: 3
readinessProbe: GET /actuator/health (port 8080)
livenessProbe:  GET /actuator/health (port 8080)
image: k3d-qa-registry:5000/loan-service:1.0
```

### How to deploy manually

```bash
./scripts/setup-k3d-cluster.sh

docker build -t localhost:5001/loan-service:1.0 .
docker push localhost:5001/loan-service:1.0

kubectl apply -f k8s/
kubectl set image deployment/loan-service \
  loan-service=k3d-qa-registry:5000/loan-service:1.0 -n qa-lab

kubectl get pods -n qa-lab
curl http://localhost:30080/actuator/health
curl http://localhost:30080/api/loans
```

---

## 8. Phase 5 — API Automation (REST Assured)

### What we built

A separate Maven module `tests/` with REST Assured + JUnit 5:

```
tests/src/test/java/com/qa/tests/
├── base/         BaseApiTest.java
├── clients/      LoanClient.java
├── models/       LoanResponse.java
├── utils/        TestConfig.java, TestDataFactory.java
└── tests/
    ├── smoke/        SmokeTests.java       @Tag("smoke")
    ├── functional/   FunctionalTests.java  @Tag("functional")
    ├── negative/     NegativeTests.java    @Tag("negative")
    └── regression/   RegressionSuite.java  (all tags)
```

### Test URL auto-detection

`TestConfig.java` probes these URLs in order:

1. `http://localhost:8081` — local Spring Boot
2. `http://localhost:30080` — Kubernetes NodePort
3. Falls back to `8081` if nothing responds

It validates the response contains `"status":"UP"` so Jenkins on port 8080 is never mistaken for the Loan Service.

### How to run

```bash
# Against local app
export BASE_URL=http://localhost:8081
mvn test -pl tests -Dgroups=smoke

# Against Kubernetes
export BASE_URL=http://localhost:30080
mvn test -pl tests -Dgroups=smoke
```

---

## 9. Phase 6 — Scripts Reference (Detailed)

The `scripts/` directory contains automation for cluster setup, deployment, validation, dashboard access, Jenkins integration, and documentation. Each script is **idempotent** where possible (safe to re-run).

### Scripts overview map

```
scripts/
├── up.sh                           ← Start Docker, k3d, Jenkins, SonarQube, dashboard
├── down.sh                         ← Stop the lab and reclaim this project's Docker disk
├── setup-k3d-cluster.sh            ← Create cluster + registry (used by up.sh)
├── setup-sonarqube.sh              ← Start SonarQube + quality gate (used by up.sh)
├── deploy-and-test.sh              ← Local workflow: build → deploy → smoke
├── validate-deployment.sh          ← Health/replica checks (used by deploy-and-test)
├── open-dashboard.sh               ← Dashboard port-forward (background)
├── setup-jenkins-k3d-network.sh    ← Connect Jenkins to k3d Docker network
├── setup-jenkins-sonar-network.sh  ← Connect Jenkins to SonarQube network
├── configure-jenkins-kubeconfig.sh ← Runtime kubeconfig (used by Jenkinsfile)
├── export-jenkins-kubeconfig.sh    ← Export kubeconfig for manual debugging
├── prune-loan-images.sh            ← Keep last N loan-service tags (used by Jenkins)
└── generate-playbook-pdf.sh        ← Regenerate this playbook as PDF
```

---

### 9.1 `setup-k3d-cluster.sh` — Create k3d cluster and registry

**Purpose:** One-time (or repeatable) foundation for the entire lab. Creates a local Kubernetes cluster with an embedded Docker registry and applies all `k8s/` manifests.

**Why needed:** Without this, there is no cluster to deploy to and no registry for Kubernetes to pull images from. This is the **first script** you run when setting up the lab.

**What it does step by step:**

1. Checks `k3d` is installed
2. If cluster exists → skips creation, ensures NodePort `30080` is mapped
3. If cluster does not exist → creates cluster with:
   - Embedded registry at `localhost:5001` (in-cluster: `k3d-qa-registry:5000`)
   - NodePort mapping `30080:30080` for the Loan Service
   - 2 agent nodes (worker capacity)
4. Runs `kubectl apply -f k8s/` (namespace, configmap, deployment, service)

**When to use:**

```bash
./scripts/setup-k3d-cluster.sh
```

**Environment variables:**

| Variable | Default | Description |
|----------|---------|-------------|
| `K3D_CLUSTER` | `qa-cluster` | k3d cluster name (matches Jenkinsfile) |
| `REGISTRY_NAME` | `qa-registry` | Registry name (becomes `k3d-qa-registry`) |
| `REGISTRY_HOST_PORT` | `5001` | Host port for `docker push` |
| `NODE_PORT` | `30080` | NodePort exposed on host |
| `AGENTS` | `2` | Number of k3d agent nodes |

**Output when successful:**

```
Registry (host push):  localhost:5001
Registry (in-cluster): k3d-qa-registry:5000
Service URL:           http://localhost:30080
Namespace:             qa-lab
```

---

### 9.2 `deploy-and-test.sh` — Full build, deploy, and test pipeline

**Purpose:** The **main orchestration script** — replicates locally what Jenkins does in CI. Builds the app, pushes the Docker image, deploys to Kubernetes, validates, and runs smoke tests.

**Why needed:** Provides a single command to verify the entire stack works without Jenkins. Useful for local development and debugging before pushing to CI.

**What it does step by step:**

| Step | Action | Why |
|------|--------|-----|
| 1 | `mvnw clean package -pl loan-service -DskipTests` | Compile JAR without API tests (no server needed) |
| 2 | `docker build` | Package app into container image |
| 3 | `docker push localhost:5001/...` | Push to k3d registry so Kubernetes can pull |
| 4 | `kubectl apply -f k8s/` + `kubectl set image` | Deploy/update with correct image tag |
| 5 | `kubectl rollout status` | Wait until all pods are ready |
| 6 | `validate-deployment.sh` | Verify replicas, pods, health endpoint |
| 7 | `mvnw test -pl tests -Dgroups=smoke` | Run REST Assured smoke tests |

**When to use:**

```bash
./scripts/deploy-and-test.sh

# Custom image tag:
IMAGE_TAG=2.0 ./scripts/deploy-and-test.sh
```

**Environment variables:**

| Variable | Default | Description |
|----------|---------|-------------|
| `NAMESPACE` | `qa-lab` | Kubernetes namespace |
| `DEPLOYMENT` | `loan-service` | Deployment name |
| `BASE_URL` | `http://localhost:30080` | API test target URL |
| `TIMEOUT` | `180` | Rollout and health timeout (seconds) |
| `K3D_CLUSTER` | `qa-cluster` | k3d cluster name |
| `REGISTRY` | `localhost:5001` | Host registry for push |
| `IMAGE_NAME` | `loan-service` | Docker image name |
| `IMAGE_TAG` | `1.0` | Docker image tag |

---

### 9.3 `validate-deployment.sh` — Post-deploy health and replica checks

**Purpose:** Gatekeeper script that confirms the deployment is **actually healthy** before running API tests. Called by `deploy-and-test.sh` and usable standalone.

**Why needed:** `kubectl rollout status` only confirms the rollout completed — it does not verify the health endpoint responds or all replicas are truly ready. This script adds that safety layer.

**What it checks:**

1. Deployment exists in namespace
2. `readyReplicas == desiredReplicas` (expects 3)
3. All pods are in `Running` state
4. All pods pass `Ready` condition
5. Service exists
6. Polls `GET /actuator/health` until `"status":"UP"` or timeout

**When to use:**

```bash
export BASE_URL=http://localhost:30080
./scripts/validate-deployment.sh
```

**Fails fast with clear errors** — prints pod status on failure for quick diagnosis.

---

### 9.4 `up.sh` — Start the complete lab

**Purpose:** One command for Docker, k3d (`qa-cluster`), Kubernetes Dashboard, Jenkins, SonarQube, and the Docker networks Jenkins needs.

**When to use:**

```bash
./scripts/up.sh
# Then in Jenkins: save SONAR_TOKEN and Build Now on main
```

Skip pieces with `SKIP_JENKINS=1`, `SKIP_SONAR=1`, or `SKIP_DASHBOARD=1`.

---

### 9.5 `down.sh` — Stop the lab and reclaim disk

**Purpose:** Tears down this project's stack only. It does **not** run `docker system prune -a` (that would delete unrelated images).

**What it does:**

1. Stops dashboard port-forward
2. Deletes k3d clusters `qa-cluster` and `qa-lab` (registry included)
3. `docker compose down -v` for SonarQube
4. Removes the Jenkins container (keeps `jenkins_home` unless `--purge`)
5. Removes `loan-service` / k3d registry tags, dangling images, unused lab volumes
6. `--purge` also removes Sonar/Jenkins/k3s images and `jenkins_home`

```bash
./scripts/down.sh
./scripts/down.sh --purge
```

---

### 9.6 `open-dashboard.sh` — Open dashboard (background)

**Purpose:** Starts port-forward in the **background** and prints the URL + token. Dashboard install is part of `up.sh`.

**Why needed:** When the dashboard is already installed and you just need to reconnect or get a fresh token.

**When to use:**

```bash
./scripts/open-dashboard.sh
# Dashboard at https://localhost:8443
```

---

### 9.7 `setup-jenkins-k3d-network.sh` — Connect Jenkins to k3d network

**Purpose:** Connects the Jenkins Docker container to the k3d cluster's Docker network so Jenkins can resolve `k3d-qa-registry`, reach the Kubernetes API, and hit the Loan Service NodePort.

**Why needed:** By default Jenkins runs on the `bridge` network and cannot resolve k3d hostnames (`k3d-qa-registry`, `k3d-qa-cluster-server-0`). Without this, registry checks, kubectl, and API tests fail inside Jenkins.

**What it does:**

1. Verifies Jenkins container exists
2. Verifies k3d network exists (`k3d-qa-cluster` or `k3d-<cluster-name>`)
3. Runs `docker network connect k3d-qa-cluster jenkins` (idempotent)

**When to use (one-time after starting Jenkins):**

```bash
JENKINS_CONTAINER=jenkins ./scripts/setup-jenkins-k3d-network.sh
```

**After running, Jenkins can reach:**

| Target | URL |
|--------|-----|
| Registry | `k3d-qa-registry:5000` |
| Loan Service | `http://k3d-qa-cluster-server-0:30080` |
| Kubernetes API | `https://k3d-qa-cluster-serverlb:6443` |

---

### 9.8 `configure-jenkins-kubeconfig.sh` — Generate kubeconfig at runtime

**Purpose:** Creates a valid kubeconfig **inside the Jenkins container** for `kubectl` commands. Used by the Jenkinsfile in Deploy and Wait stages.

**Why needed:** The host kubeconfig (`~/.kube/config`) uses `https://0.0.0.0:<port>` which fails inside Jenkins with TLS errors. This script fetches a fresh config from k3d and rewrites the API server to the Docker-network address.

**What it does:**

1. Runs `k3d kubeconfig get qa-cluster` via the k3d Docker image + Docker socket
2. Rewrites API server to `https://k3d-qa-cluster-serverlb:6443`
3. Sets `KUBECONFIG` environment variable to a temp file
4. Must be **sourced** (not executed) so `KUBECONFIG` persists in the shell

**Used in Jenkinsfile as:**

```bash
#!/usr/bin/env bash
source scripts/configure-jenkins-kubeconfig.sh
kubectl get nodes
```

**Environment variables:**

| Variable | Default | Description |
|----------|---------|-------------|
| `K3D_CLUSTER` | `qa-cluster` | Cluster name |
| `KUBE_SERVER` | `https://k3d-qa-cluster-serverlb:6443` | API server URL |
| `K3D_IMAGE` | `ghcr.io/k3d-io/k3d:5.8.3` | k3d Docker image |

---

### 9.9 `export-jenkins-kubeconfig.sh` — Export kubeconfig for manual use

**Purpose:** Generates a Jenkins-compatible kubeconfig file on your **Mac** for manual debugging or optional Jenkins credential upload.

**Why needed:** When you want to run `kubectl` from your Mac with the same API server URL Jenkins uses, or upload a pre-built kubeconfig to Jenkins credentials.

**When to use:**

```bash
./scripts/export-jenkins-kubeconfig.sh jenkins-kubeconfig.yaml
# Optional: upload to Jenkins → Manage Credentials → Secret file → ID: k3d-kubeconfig
```

> **Note:** The current Jenkinsfile generates kubeconfig at runtime and does **not** require this credential. This script is for manual debugging only.

---

### 9.10 `generate-playbook-pdf.sh` — Regenerate the PDF playbook

**Purpose:** Converts `docs/BUILD-GUIDE.md` into a styled PDF using `md-to-pdf`.

**When to use:**

```bash
./scripts/generate-playbook-pdf.sh
# Output: docs/QA-Architecture-Lab-Playbook.pdf
```

---

### Scripts vs Jenkins pipeline — who does what?

| Task | Local script | Jenkins pipeline |
|------|-------------|-----------------|
| Create cluster | `setup-k3d-cluster.sh` | Manual one-time setup |
| Build JAR | `deploy-and-test.sh` | `mvn clean package -DskipTests` |
| Docker build/push | `deploy-and-test.sh` | Build Docker Image stage |
| kubectl deploy | `deploy-and-test.sh` | Deploy to Kubernetes stage |
| Wait for rollout | `deploy-and-test.sh` | Wait for Application stage |
| Validate health | `validate-deployment.sh` | (implicit in wait + tests) |
| API smoke tests | `deploy-and-test.sh` | Run REST Assured Tests stage |
| Connect Jenkins network | `setup-jenkins-k3d-network.sh` | Manual one-time setup |
| Kubeconfig for kubectl | `configure-jenkins-kubeconfig.sh` | Sourced in pipeline stages |

### One-command workflows

```bash
# First-time / full lab
./scripts/up.sh

# Stop lab and reclaim this project's Docker disk
./scripts/down.sh

# Deploy and test locally (no Jenkins)
./scripts/deploy-and-test.sh

# Regenerate PDF playbook
./scripts/generate-playbook-pdf.sh
```

---

## 10. Phase 7 — Jenkins CI/CD Pipeline

### Jenkins setup

Jenkins runs as a **Docker container** with:

- Port **8080** exposed (UI at http://localhost:8080)
- Docker socket mounted (`-v /var/run/docker.sock:/var/run/docker.sock`)
- Connected to the **k3d Docker network** (`k3d-qa-cluster`)

```bash
# One-time: connect Jenkins to k3d network
JENKINS_CONTAINER=jenkins ./scripts/setup-jenkins-k3d-network.sh
```

### Pipeline job

- **Job name:** `qa-k3d-pipeline`
- **URL:** http://localhost:8080/job/qa-k3d-pipeline/
- **Source:** GitHub repo `kanhaya/qa-architecture-lab` (branch `main`)
- **Definition:** `Jenkinsfile` in repo root

### Pipeline stages (in order)

| # | Stage | What it does | Why |
|---|-------|-------------|-----|
| 1 | **Checkout** | Pulls code from GitHub | Always start from latest commit |
| 2 | **Verify Environment** | Checks docker, kubectl, mvn, registry, k3d API | Fail fast if infrastructure is broken |
| 3 | **Quality Gate** | `mvn -pl loan-service -am clean verify` | Unit tests, `@WebMvcTest`, OpenAPI contract (`RANDOM_PORT` — **not** k3d / `localhost:30080`), JaCoCo ≥ 80% line coverage, Checkstyle, and SpotBugs. Failure stops the pipeline; no image is built. |
| 4 | **SonarQube** | `mvn sonar:sonar -Dsonar.qualitygate.wait=true` | Imports JaCoCo XML, waits for quality gate `qa-lab-new-code`. Spike/experiment branches set wait to `false`. |
| 5 | **Build Docker Image** | `docker build` + `docker push` | Package app, push to k3d registry (`main` only) |
| 6 | **Deploy to Kubernetes** | `kubectl apply` + `kubectl set image` | Roll out new image to 3 pods (`main` only) |
| 7 | **Wait for Application** | `kubectl rollout status` | Ensure pods are healthy before testing |
| 8 | **Run REST Assured Tests** | `mvn test -pl tests -Dgroups=smoke` | Validate deployed API automatically (`main` only) |

The Quality Gate is the pre-image check: JaCoCo, Checkstyle, SpotBugs, JUnit (`loan-service`), and OpenAPI contract tests against an in-process Spring Boot server (`RANDOM_PORT`). SonarQube then blocks on `qa-lab-new-code` (`sonar.qualitygate.wait=true`). Cluster smoke tests (`tests` module) still run only after deploy on `main`.

Community Edition does not decorate GitHub PR lines or compute a PR diff as New Code. Conditions apply to the project's **New Code Period** (previous version). Jenkins job status plus http://localhost:9000 are the review signals. Install SonarLint Connected Mode against that URL and project key `com.qa:qa-architecture-lab` to catch most issues in the IDE.

**Sonar one-time setup:** `./scripts/setup-sonarqube.sh` then store the printed token as Jenkins secret text credential `SONAR_TOKEN`. From Jenkins the server is `http://sonarqube:9000` on Docker network `qa-lab-sonar`.

**Spec:** [`loan-service/src/main/resources/openapi/loan-service.yaml`](../loan-service/src/main/resources/openapi/loan-service.yaml). If a field or status code drifts from the spec, `verify` fails and Jenkins never builds an image.

The Dockerfile still uses `mvn ... -DskipTests` **inside the image build**. That is packaging of the same source Jenkins already verified — not a substitute for the Quality Gate.

### Image tagging strategy

Each build tags the image with the Jenkins `BUILD_NUMBER`:

```
Build:   k3d-qa-registry:5000/loan-service:27
Push:    localhost:5001/loan-service:27        (same registry, host port)
Deploy:  kubectl set image … loan-service:27
```

### Key environment variables in Jenkinsfile

```groovy
REGISTRY      = 'k3d-qa-registry:5000'    // in-cluster image name
HOST_REGISTRY = 'localhost:5001'          // docker push target
BASE_URL      = 'http://k3d-qa-cluster-server-0:30080'  // API tests from Jenkins
NAMESPACE     = 'qa-lab'
K3D_CLUSTER   = 'qa-cluster'
SONAR_HOST_URL = 'http://sonarqube:9000'  // from Jenkins on network qa-lab-sonar
```

### Kubeconfig inside Jenkins

The pipeline generates kubeconfig at runtime via `scripts/configure-jenkins-kubeconfig.sh`:

1. Runs `k3d kubeconfig get qa-cluster` using the k3d Docker image
2. Rewrites API server to `https://k3d-qa-cluster-serverlb:6443`
3. Uses embedded TLS certificates (no manual credential upload needed)

Shell steps use `#!/usr/bin/env bash` because Jenkins defaults to `/bin/sh` (dash) which does not support `source`.

---

## 11. Port Map Reference

| Service | Port | Who uses it |
|---------|------|-------------|
| Jenkins UI | **8080** | You (browser) — **not** the Loan Service |
| Loan Service (local dev) | **8081** | `mvn spring-boot:run` on your Mac |
| Loan Service (container/k8s) | **8080** | Inside Docker pod |
| Loan Service (k8s NodePort) | **30080** | You + Jenkins API tests from Mac |
| k3d registry (host push) | **5001** | `docker push` from Jenkins/host |
| k3d registry (in-cluster) | **5000** | Kubernetes image pull |
| Kubernetes Dashboard | **8443** | https://localhost:8443 |
| SonarQube | **9000** | http://localhost:9000 (Jenkins uses http://sonarqube:9000) |
| k3d API server (from Jenkins) | **6443** | `kubectl` inside Jenkins container |

### Quick health checks

```bash
# Loan Service on Kubernetes
curl http://localhost:30080/actuator/health

# Loan Service local dev
curl http://localhost:8081/actuator/health

# k3d registry
curl http://localhost:5001/v2/_catalog

# Jenkins (should NOT be used for API tests)
curl http://localhost:8080/

# SonarQube
curl http://localhost:9000/api/system/status
```

---

## 12. Problems Solved & Lessons Learned

### Problem 1: Port 8080 conflict (Jenkins vs Loan Service)

**Symptom:** API tests returned `403 Forbidden` with `X-Jenkins` headers.

**Cause:** Tests pointed at `localhost:8080` which is Jenkins, not the Loan Service.

**Fix:** Local app uses port **8081**; Kubernetes tests use **30080**; Jenkins pipeline uses `k3d-qa-cluster-server-0:30080`.

---

### Problem 2: `k3d-qa-registry:5000` — no such host

**Symptom:** `docker push k3d-qa-registry:5000` failed with DNS lookup error.

**Cause:** That hostname only exists on the k3d Docker network, not on the host where the Docker daemon runs.

**Fix:** Tag image as `k3d-qa-registry:5000/...` but push via `localhost:5001` (same physical registry).

---

### Problem 3: kubeconfig TLS error inside Jenkins

**Symptom:** `x509: certificate signed by unknown authority`

**Cause:** Host kubeconfig uses `https://0.0.0.0:<port>` and/or file-path certificates that don't exist inside Jenkins.

**Fix:** Generate kubeconfig at runtime with `configure-jenkins-kubeconfig.sh`, pointing API server to `k3d-qa-cluster-serverlb:6443`.

---

### Problem 4: `source: not found` in Jenkins

**Symptom:** `source: not found` when running kubeconfig script.

**Cause:** Jenkins `sh` step uses `/bin/sh` (dash), not bash.

**Fix:** Add `#!/usr/bin/env bash` as the first line of shell blocks that use `source`.

---

### Problem 5: Cluster name mismatch

**Symptom:** Wrong hostnames in pipeline (`k3d-qa-lab` vs actual `qa-cluster`).

**Fix:** Aligned `K3D_CLUSTER`, `K3D_NETWORK`, `BASE_URL`, and `KUBE_SERVER` to match actual cluster name `qa-cluster`.

### Problem 6: `mvn: not found` in Jenkins

**Symptom:** Pipeline fails at Maven stage with `mvn: not found`.

**Cause:** Jenkins container does not have Maven installed or not in PATH.

**Fix:** Install Maven inside Jenkins (or use a custom Jenkins image). Verify with `docker exec jenkins mvn --version`.

---

### Problem 7: `kubectl: not found` in Jenkins

**Symptom:** Deploy stage fails — kubectl command not found.

**Cause:** Base Jenkins image does not include kubectl.

**Fix:** Install kubectl in the Jenkins container. Verify with `docker exec jenkins kubectl version --client`.

---

### Problem 8: Namespace `qa-lab` not found

**Symptom:** `kubectl apply` fails — namespace does not exist.

**Cause:** Namespaced resources applied before namespace exists (race when applying all manifests at once).

**Fix:** Apply `k8s/namespace.yaml` first, or use `kubectl apply -f k8s/` which creates namespace before other resources. Re-run apply if race occurs.

---

### Problem 9: REST Assured `Connection refused`

**Symptom:** Tests fail with connection refused before deploy completes.

**Cause:** Functional tests ran during `mvn clean test` before the API was deployed.

**Fix:** Jenkins **Quality Gate** (`mvn -pl loan-service -am verify`) runs unit/component/contract tests before the image. REST Assured in `tests` still runs only after deploy and rollout.

**Key lesson:** Maven proves the code. Kubernetes runs the image. REST Assured (`tests`) validates the **running** system.

---

### Problem 10: `HTTP response to HTTPS client` (ImagePullBackOff)

**Symptom:** Pods stuck in `ImagePullBackOff`; events show `http: server gave HTTP response to HTTPS client`.

**Cause:** Registry serves plain HTTP but containerd tries HTTPS.

**Fix:** Create registry as part of k3d cluster setup:

```bash
k3d registry create qa-registry --port 5001
k3d cluster create qa-cluster --registry-use k3d-qa-registry:5000
```

**Diagnostic:** `kubectl describe pod <pod-name> -n qa-lab` — read the Events section.

---

### Problem 11: Image tag mismatch

**Symptom:** Kubernetes pulls `loan-service:1.0` but Jenkins built `loan-service:27`.

**Cause:** Deployment manifest has a static tag; pipeline builds with `${BUILD_NUMBER}`.

**Fix:** `kubectl set image deployment/loan-service loan-service=k3d-qa-registry:5000/loan-service:${BUILD_NUMBER} -n qa-lab`

**Diagnostic:**

```bash
kubectl get pod -n qa-lab -o jsonpath='{.items[0].spec.containers[0].image}'
```

---

### Problem 12: Registry `localhost:5001` timeout from Jenkins

**Symptom:** `curl localhost:5001` fails inside Jenkins container.

**Cause:** Inside Jenkins, `localhost` means the Jenkins container itself — not the Mac host.

**Fix:** For HTTP checks from Jenkins, use `k3d-qa-registry:5000`. For `docker push` via socket, use `localhost:5001` (Docker daemon on host).

---

## 13. Diagnostic Command Sheet

When something fails, identify **which layer** failed, then run diagnostics for that layer only.

### Layer 1 — Docker / Jenkins

```bash
docker ps
docker inspect jenkins
docker logs jenkins --tail 50
docker exec jenkins docker --version
docker exec jenkins mvn --version
docker exec jenkins kubectl version --client
```

### Layer 2 — Network / Registry

```bash
docker network inspect k3d-qa-cluster
docker exec jenkins getent hosts k3d-qa-registry
docker exec jenkins curl -sf http://k3d-qa-registry:5000/v2/_catalog
curl -sf http://localhost:5001/v2/_catalog
curl -sf http://localhost:5001/v2/loan-service/tags/list
```

### Layer 3 — Kubernetes

```bash
kubectl get nodes
kubectl get ns
kubectl get all -n qa-lab
kubectl get pods -n qa-lab -o wide
kubectl describe pod <pod-name> -n qa-lab    # Most valuable for image failures
kubectl logs <pod-name> -n qa-lab
kubectl rollout status deployment/loan-service -n qa-lab
kubectl get svc loan-service -n qa-lab
```

### Professional debugging pattern

```
Failure
  ↓
Identify the layer (build / registry / k8s / tests)
  ↓
Run the most direct diagnostic command
  ↓
Validate the hypothesis
  ↓
Change one thing
  ↓
Re-run pipeline
  ↓
Verify the next layer
```

---

## 14. Verification Checklist

Use this checklist every time you rebuild or debug the lab.

| # | Check | Command | Expected result |
|---|-------|---------|-----------------|
| 1 | Git repository | `git remote -v` | Points to `qa-architecture-lab` |
| 2 | Jenkins SCM | Build #N console | Checkout succeeds |
| 3 | Maven | `mvn --version` in Jenkins | Maven 3.9+ |
| 4 | Docker | `docker --version` in Jenkins | Docker 20+ |
| 5 | kubectl | `kubectl get nodes` | Node Ready |
| 6 | k3d API | `source scripts/configure-jenkins-kubeconfig.sh && kubectl get nodes` | Cluster reachable |
| 7 | Registry DNS | `docker exec jenkins getent hosts k3d-qa-registry` | Returns IP |
| 8 | Registry API | `curl http://k3d-qa-registry:5000/v2/_catalog` from Jenkins | JSON catalog |
| 9 | Quality Gate | Jenkins **Quality Gate** stage | `mvn verify` green (unit, contract, JaCoCo ≥ 80%, Checkstyle, SpotBugs) |
| 9b | SonarQube | Jenkins **SonarQube** stage + http://localhost:9000 | Quality gate `qa-lab-new-code` green (`wait=true` except spike/experiment) |
| 10 | Image push | `curl localhost:5001/v2/loan-service/tags/list` | Contains build tag |
| 11 | Namespace | `kubectl get ns qa-lab` | Exists |
| 12 | Deployment | `kubectl rollout status deployment/loan-service -n qa-lab` | Successfully rolled out |
| 13 | Pods | `kubectl get pods -n qa-lab` | 3/3 Ready |
| 14 | Service | `kubectl get svc -n qa-lab` | NodePort 30080 |
| 15 | Health | `curl http://localhost:30080/actuator/health` | `{"status":"UP"}` |
| 16 | API | `curl http://localhost:30080/api/loans` | JSON with loans 101, 102 |
| 17 | REST Assured | Jenkins test stage | Smoke tests PASS |
| 18 | Reports | Jenkins build page | Surefire/JUnit results visible |

---

## 15. How to Explain This Like a Pro

### 15.1 Sixty-second interview answer

> "I built a local CI/CD environment where Jenkins runs in Docker and orchestrates the full test-deployment lifecycle. After checkout, a Quality Gate runs `mvn verify` on loan-service: unit tests, MockMvc, OpenAPI contract tests on a random port, JaCoCo coverage, Checkstyle, and SpotBugs. SonarQube then analyzes the same module with `sonar.qualitygate.wait=true` so a failed New Code gate never reaches `docker build`. Only on `main` does Jenkins build and push a Docker image tagged with the build number to a local k3d registry. Kubernetes deploys that image with three replicas. The pipeline waits for rollout, then runs REST Assured smoke tests against the live NodePort. I separated in-process quality (no cluster) from black-box API tests (need a deployed service)."

### 15.2 Common interview questions

**Q: Do you run tests before the image?**

> Yes. The Quality Gate is `mvn -pl loan-service -am verify`. That covers unit tests, `@WebMvcTest`, OpenAPI contract tests on `RANDOM_PORT`, JaCoCo ≥ 80% line coverage, Checkstyle, and SpotBugs. SonarQube then runs with `sonar.qualitygate.wait=true`. A failure never reaches `docker build`. Cluster REST Assured in the `tests` module still runs only after deploy on `main`, because those tests need a live URL.

**Q: Why skip tests inside the Dockerfile?**

> Jenkins already verified the same source. The Docker `mvn ... -DskipTests` step is packaging, not a second test run. Contract and unit tests do not belong in the image build.

**Q: Why Kubernetes Service?**

> Pods are ephemeral — their IPs change. The Service provides a stable network endpoint and load-balances traffic across ready pods.

**Q: Why a registry?**

> The Docker image Jenkins builds must be available to the Kubernetes runtime. The registry is the contract between image creation and cluster deployment.

**Q: Why build-number tags?**

> They make deployments traceable. I can identify exactly which Jenkins build produced the image running in Kubernetes. It avoids ambiguity from a mutable `latest` tag.

**Q: How did you debug ImagePullBackOff?**

> I used `kubectl describe pod` and read the Events section. The event showed `HTTP response to HTTPS client`, which identified a registry protocol mismatch — not an application failure. I then verified registry reachability and reconfigured k3d registry integration.

**Q: Why port 8081 locally but 30080 in Kubernetes?**

> Jenkins occupies port 8080 on my Mac. Local dev uses 8081 to avoid conflict. In Kubernetes, the Service exposes the app on NodePort 30080 while pods listen on 8080 internally.

---

## 16. Reproduce Everything From Scratch

### Prerequisites

```bash
# Install on macOS
brew install java maven docker k3d kubectl
```

### Step 1 — Clone the repo

```bash
git clone https://github.com/kanhaya/qa-architecture-lab.git
cd qa-architecture-lab
```

### Step 2 — Run the Quality Gate

```bash
mvn -pl loan-service -am verify
```

### Step 2b — Start SonarQube and bind Jenkins

```bash
./scripts/setup-sonarqube.sh
# Add Jenkins credential SONAR_TOKEN (secret text) from the script output
# If Jenkins already exists: JENKINS_CONTAINER=jenkins ./scripts/setup-jenkins-sonar-network.sh
```

### Step 3 — Run locally

```bash
cd loan-service && mvn spring-boot:run
# In another terminal:
curl http://localhost:8081/api/loans
```

### Step 4 — Create k3d cluster

```bash
./scripts/setup-k3d-cluster.sh
# Or if using qa-cluster name:
K3D_CLUSTER=qa-cluster k3d cluster create qa-cluster \
  --registry-create qa-registry:0.0.0.0:5001 \
  --port 30080:30080@server:0
kubectl apply -f k8s/
```

### Step 5 — Deploy to Kubernetes

```bash
./scripts/deploy-and-test.sh
```

### Step 6 — Start Jenkins

```bash
docker run -d \
  --name jenkins \
  -p 8080:8080 -p 50000:50000 \
  -v jenkins_home:/var/jenkins_home \
  -v /var/run/docker.sock:/var/run/docker.sock \
  jenkins/jenkins:lts

# Connect to k3d network
JENKINS_CONTAINER=jenkins ./scripts/setup-jenkins-k3d-network.sh

# Connect to SonarQube network (after ./scripts/setup-sonarqube.sh)
JENKINS_CONTAINER=jenkins ./scripts/setup-jenkins-sonar-network.sh
```

Install Maven, Docker CLI, and kubectl inside Jenkins (or use a custom Jenkins image).

### Step 7 — Create Jenkins pipeline job

1. Open http://localhost:8080
2. New Item → Pipeline → name: `qa-k3d-pipeline`
3. Pipeline → Definition: **Pipeline script from SCM**
4. SCM: Git → URL: `https://github.com/kanhaya/qa-architecture-lab.git`
5. Branch: `main` → Script Path: `Jenkinsfile`
6. Add credential **SONAR_TOKEN** (secret text) from `./scripts/setup-sonarqube.sh`
7. Save → **Build Now**

### Step 8 — Verify successful build

See [Section 17](#17-verify-a-successful-build).

---

## 17. Verify a Successful Build

### In Jenkins

1. Open http://localhost:8080/job/qa-k3d-pipeline/
2. Latest build should show **green** (Success)
3. Check stages: all 7 stages completed
4. Console output should end with smoke tests passing

### On your Mac

```bash
# Pods running (3 replicas)
kubectl get pods -n qa-lab

# Service reachable
curl http://localhost:30080/actuator/health
# Expected: {"status":"UP"}

curl http://localhost:30080/api/loans
# Expected: JSON array with loans 101 and 102

# Image in registry
curl http://localhost:5001/v2/_catalog
# Expected: {"repositories":["loan-service"]}
```

### Expected pod output

```
NAME                            READY   STATUS    RESTARTS   AGE
loan-service-xxxxxxxxxx-xxxxx   1/1     Running   0          2m
loan-service-xxxxxxxxxx-xxxxx   1/1     Running   0          2m
loan-service-xxxxxxxxxx-xxxxx   1/1     Running   0          2m
```

---

## 18. Production Maturity Path

The local lab is intentionally simple. The same architecture evolves into a production-grade platform:

| Local lab | Production evolution |
|-----------|---------------------|
| k3d local registry | GHCR, ECR, GCR, or enterprise registry with TLS |
| Build-number tags | Immutable image digests for provenance |
| Single Jenkins pipeline | Separate PR CI, build, publish, and deploy jobs; GitHub PR decoration (SonarQube Developer Edition or SonarCloud) |
| In-process Quality Gate (JaCoCo, Checkstyle, SpotBugs, OpenAPI) plus local SonarQube Community wait | Commercial PR-diff New Code, SAST/SCA beyond Sonar, container scanning |
| Cluster smoke tests after deploy | Smoke → functional → regression → perf/security stages |
| Static k8s YAML | Helm or Kustomize per environment |
| Manual cluster | Ephemeral namespaces per PR/build |
| No observability | Prometheus, Grafana, centralized logs |

### Maturity ladder

```
Local learning lab
      ↓
Quality Gate (unit, contract, static analysis)
      ↓
Container registry
      ↓
Kubernetes deployment
      ↓
Cluster smoke / API tests
      ↓
Deeper security (SAST, SCA, container scan)
      ↓
Ephemeral test environments
      ↓
Promotion across environments (dev → QA → prod)
      ↓
Observability + automated diagnosis
```

### Final takeaway

The most reusable lesson is the **dependency chain**:

```
source → quality gate (JaCoCo + Sonar wait) → container image → registry → Kubernetes workload → Service → cluster smoke
```

When a pipeline fails, locate the broken link in that chain and inspect that layer directly.

---

## Summary

| Phase | Built | Achieved |
|-------|-------|----------|
| 1 — Spring Boot | REST API + actuator | Runnable microservice |
| 2 — Unit tests | JUnit/Mockito + OpenAPI contract | Fast CI feedback without a cluster |
| 3 — Docker | Multi-stage image | Portable, health-checked container |
| 4 — Kubernetes | k3d + manifests | 3 replicas, NodePort, probes |
| 5 — API tests | REST Assured suites | Automated API validation on the cluster |
| 6 — Scripts | deploy-and-test.sh etc. | One-command operations |
| 7 — Jenkins | Quality Gate + Sonar wait → image → deploy → smoke | Bad commits never produce an image |

**Overall goal achieved:** A complete, hands-on QA Architecture Lab demonstrating how a real team builds, containers, deploys to Kubernetes, and validates a microservice — with Jenkins automating the entire flow.

---

## Next Steps (Roadmap)

| Phase | Description |
|-------|-------------|
| Resilience testing | Pod failure, scaling, rollback scenarios |
| Helm | Templatize Kubernetes manifests |
| Argo CD | GitOps-based deployment |
| Observability | Prometheus, Grafana, OpenTelemetry |

See [README.md](../README.md) for command reference and troubleshooting.
