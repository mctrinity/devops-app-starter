# DevOps App Starter (FastAPI + Docker + Kubernetes)

A minimal, production-minded template with:

* **Backend**: FastAPI (Python) + Uvicorn
* **Container**: Multi-stage Dockerfile + `.dockerignore`
* **Kubernetes**: Namespace, ConfigMap, Secret (example), Deployment, Service, Ingress (class-agnostic), HPA, and ServiceAccount + RBAC (optional)
* **CI (optional)**: GitHub Actions to build/push image and apply K8s manifests
* **Local tooling**: Makefile and `docker-compose.yaml` for quick start

> Rename `example-` files and replace `CHANGEME_…` placeholders before shipping.

---

## Project Structure

```
.devcontainer/             # (optional) devcontainer config
.github/workflows/
  ci.yaml                  # CI: build, push, apply manifests (optional)
app/
  __init__.py
  main.py                  # FastAPI entrypoint
  api.py                   # Routes
  settings.py              # Config parsing
  instrumentation.py       # Prometheus / health
  requirements.txt
k8s/
  namespace.yaml
  configmap.yaml
  secret.example.yaml      # copy to secret.yaml and fill Base64 values
  serviceaccount.yaml
  role.yaml
  rolebinding.yaml
  deployment.yaml
  service.yaml
  ingress.yaml
  hpa.yaml
Dockerfile
.dockerignore
Makefile
README.md                  # This doc content adapted
docker-compose.yaml        # Local dev
```

---

## Backend: FastAPI

**app/requirements.txt**

```
fastapi==0.115.0
uvicorn[standard]==0.30.6
pydantic-settings==2.4.0
prometheus-client==0.20.0
```

**app/settings.py**

```python
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    app_name: str = "devops-app"
    env: str = "local"
    log_level: str = "INFO"
    port: int = 8080
    # Example of secrets / config
    db_url: str | None = None

    class Config:
        env_prefix = "APP_"  # e.g., APP_ENV=prod
        extra = "ignore"

settings = Settings()
```

**app/instrumentation.py**

```python
from prometheus_client import Counter, Histogram
from time import perf_counter

REQUESTS = Counter("http_requests_total", "Total HTTP requests", ["method", "endpoint", "status"])
LATENCY = Histogram("http_request_duration_seconds", "Request latency", ["method", "endpoint"])

class TrackRequest:
    def __init__(self, method: str, endpoint: str):
        self.method = method
        self.endpoint = endpoint
        self.start = perf_counter()

    def done(self, status: int):
        REQUESTS.labels(self.method, self.endpoint, str(status)).inc()
        LATENCY.labels(self.method, self.endpoint).observe(perf_counter() - self.start)
```

**app/api.py**

```python
from fastapi import APIRouter, Response

router = APIRouter()

@router.get("/")
async def root():
    return {
        "app": "devops-app",
        "endpoints": ["/healthz", "/hello?name=YOU", "/metrics", "/docs"]
    }

@router.get("/favicon.ico")
async def favicon():
    # No favicon yet; avoid noisy 404s
    return Response(status_code=204)

@router.get("/healthz")
async def healthz():
    return {"status": "ok"}

@router.get("/hello")
async def hello(name: str = "world"):
    return {"message": f"Hello, {name}!"}
```

**app/main.py**

```python
import os
import logging
from fastapi import FastAPI, Request, Response
from fastapi.middleware.cors import CORSMiddleware
from prometheus_client import generate_latest, CONTENT_TYPE_LATEST
from .api import router
from .settings import settings
from .instrumentation import TrackRequest

app = FastAPI(title=settings.app_name)

# CORS — adjust origins as needed
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000", "http://127.0.0.1:3000"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(router)

@app.middleware("http")
async def metrics_middleware(request: Request, call_next):
    tracker = TrackRequest(request.method, request.url.path)
    response = await call_next(request)
    tracker.done(response.status_code)
    return response

@app.get("/metrics")
async def metrics():
    data = generate_latest()
    return Response(content=data, media_type=CONTENT_TYPE_LATEST)

# Friendly startup log to show a connectable URL from Docker
@app.on_event("startup")
async def show_clickable_url():
    display_host = os.getenv("DISPLAY_HOST", "localhost")
    logging.getLogger("uvicorn.error").info(
        f"Open your browser at: http://{display_host}:{settings.port}"
    )

if __name__ == "__main__":
    import uvicorn
    # Keep 0.0.0.0 for Docker; this is correct for container networking
    uvicorn.run("app.main:app", host="0.0.0.0", port=settings.port, reload=True)
```

---

## Containerization

**.dockerignore**

```
__pycache__
*.pyc
*.pyo
*.pyd
*.swp
.env
.venv
.git
.github
.devcontainer
k8s
README.md
```

**Dockerfile** (multi-stage, tiny runtime)

```dockerfile
# syntax=docker/dockerfile:1.7

FROM python:3.12-slim AS base
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# ===== builder =====
FROM base AS builder
WORKDIR /w
COPY app/requirements.txt ./
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --upgrade pip && pip wheel --no-cache-dir --no-deps -r requirements.txt -w /wheels

# ===== runtime =====
FROM base AS runtime
WORKDIR /app
ENV PORT=8080 \
    APP_ENV=prod \
    APP_LOG_LEVEL=INFO

# Install runtime deps only
COPY --from=builder /wheels /wheels
RUN pip install --no-cache-dir /wheels/* && rm -rf /wheels

# Copy code last (better layer caching)
COPY app/ ./app/
EXPOSE 8080

# App user (non-root)
RUN useradd -r -u 10001 appuser && chown -R appuser:appuser /app
USER appuser

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8080"]
```

---

## Kubernetes Manifests (`k8s/`)

> Replace `your-registry.io/your-org/devops-app:TAG` and domain names.

**namespace.yaml**

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: devops-app
```

**configmap.yaml**

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: devops-app-config
  namespace: devops-app
data:
  APP_ENV: "prod"
  APP_LOG_LEVEL: "INFO"
```

**secret.example.yaml**

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: devops-app-secret
  namespace: devops-app
stringData:
  # Put plain values here while developing; CI should convert to base64 data
  DB_URL: "postgresql://user:pass@db:5432/app"
```

**serviceaccount.yaml**

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: devops-app-sa
  namespace: devops-app
```

**role.yaml**

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: devops-app-role
  namespace: devops-app
rules:
- apiGroups: [""]
  resources: ["pods", "configmaps", "secrets"]
  verbs: ["get", "list"]
```

**rolebinding.yaml**

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: devops-app-rb
  namespace: devops-app
subjects:
- kind: ServiceAccount
  name: devops-app-sa
  namespace: devops-app
roleRef:
  kind: Role
  name: devops-app-role
  apiGroup: rbac.authorization.k8s.io
```

**deployment.yaml**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: devops-app
  namespace: devops-app
  labels:
    app: devops-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: devops-app
  template:
    metadata:
      labels:
        app: devops-app
    spec:
      serviceAccountName: devops-app-sa
      containers:
      - name: api
        image: your-registry.io/your-org/devops-app:CHANGEME_TAG
        imagePullPolicy: IfNotPresent
        ports:
        - name: http
          containerPort: 8080
        env:
        - name: APP_ENV
          valueFrom:
            configMapKeyRef:
              name: devops-app-config
              key: APP_ENV
        - name: APP_LOG_LEVEL
          valueFrom:
            configMapKeyRef:
              name: devops-app-config
              key: APP_LOG_LEVEL
        - name: APP_PORT
          value: "8080"
        - name: DB_URL
          valueFrom:
            secretKeyRef:
              name: devops-app-secret
              key: DB_URL
        readinessProbe:
          httpGet:
            path: /healthz
            port: http
          initialDelaySeconds: 3
          periodSeconds: 5
        livenessProbe:
          httpGet:
            path: /healthz
            port: http
          initialDelaySeconds: 10
          periodSeconds: 10
        resources:
          requests:
            cpu: "100m"
            memory: "128Mi"
          limits:
            cpu: "500m"
            memory: "512Mi"
```

**service.yaml**

```yaml
apiVersion: v1
kind: Service
metadata:
  name: devops-app
  namespace: devops-app
spec:
  type: ClusterIP
  selector:
    app: devops-app
  ports:
  - name: http
    port: 80
    targetPort: 8080
```

**ingress.yaml** (class-agnostic)

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: devops-app
  namespace: devops-app
  annotations:
    kubernetes.io/ingress.class: "nginx"
    nginx.ingress.kubernetes.io/proxy-body-size: "1m"
    nginx.ingress.kubernetes.io/proxy-read-timeout: "30"
    nginx.ingress.kubernetes.io/limit-rps: "20"
spec:
  rules:
  - host: api.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: devops-app
            port:
              number: 80
```

**hpa.yaml**

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: devops-app
  namespace: devops-app
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: devops-app
  minReplicas: 2
  maxReplicas: 6
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 60
```

---

## Local Dev

**docker-compose.yaml**

```yaml
version: "3.9"
services:
  api:
    build: .
    ports:
      - "8080:8080"
    environment:
      APP_ENV: local
      APP_LOG_LEVEL: DEBUG
```

**Makefile**

```
IMAGE?=your-registry.io/your-org/devops-app
TAG?=$(shell git rev-parse --short HEAD)
NAMESPACE?=devops-app

.PHONY: build push deploy logs port-forward

build:
	docker build -t $(IMAGE):$(TAG) .

push:
	docker push $(IMAGE):$(TAG)

e2e-run:
	curl -s http://localhost:8080/healthz | jq .

deploy:
	kubectl apply -f k8s/namespace.yaml
	sed "s|CHANGEME_TAG|$(TAG)|" k8s/deployment.yaml | kubectl apply -f -
	kubectl apply -f k8s/configmap.yaml -f k8s/service.yaml -f k8s/ingress.yaml -f k8s/hpa.yaml -f k8s/serviceaccount.yaml -f k8s/role.yaml -f k8s/rolebinding.yaml

logs:
	kubectl -n $(NAMESPACE) logs -l app=devops-app -f --max-log-requests=5

port-forward:
	kubectl -n $(NAMESPACE) port-forward svc/devops-app 8080:80
```

---

## GitHub Actions (optional)

**.github/workflows/ci.yaml**

```yaml
name: CI

on:
  push:
    branches: [ main ]
  pull_request:

jobs:
  build-push-deploy:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      id-token: write
    steps:
      - uses: actions/checkout@v4
      - uses: docker/setup-buildx-action@v3
      - uses: docker/login-action@v3
        with:
          registry: ${{ secrets.REGISTRY_HOST }}
          username: ${{ secrets.REGISTRY_USER }}
          password: ${{ secrets.REGISTRY_PASSWORD }}
      - name: Build & Push
        uses: docker/build-push-action@v5
        with:
          push: true
          tags: ${{ secrets.REGISTRY_HOST }}/${{ secrets.ORG }}/devops-app:${{ github.sha }}
      - name: Set Kubeconfig
        run: |
          mkdir -p ~/.kube
          echo "${KUBECONFIG_DATA}" | base64 -d > ~/.kube/config
        env:
          KUBECONFIG_DATA: ${{ secrets.KUBECONFIG_B64 }}
      - name: Deploy
        run: |
          kubectl apply -f k8s/namespace.yaml
          sed "s|CHANGEME_TAG|${GITHUB_SHA}|" k8s/deployment.yaml | kubectl apply -f -
          kubectl apply -f k8s/configmap.yaml -f k8s/service.yaml -f k8s/ingress.yaml -f k8s/hpa.yaml -f k8s/serviceaccount.yaml -f k8s/role.yaml -f k8s/rolebinding.yaml
```

---

## Quick Start

1. **Build & run locally**

   ```bash
   make build && docker run -p 8080:8080 your-registry.io/your-org/devops-app:$(git rev-parse --short HEAD)
   # or
   docker compose up --build
   ```
2. **Test endpoints**

   ```bash
   curl http://localhost:8080/healthz
   curl http://localhost:8080/hello?name=you
   curl http://localhost:8080/metrics  # Prometheus format
   ```
3. **Deploy to K8s**

   ```bash
   kubectl apply -f k8s/namespace.yaml
   kubectl apply -f k8s/configmap.yaml -f k8s/secret.yaml -f k8s/serviceaccount.yaml -f k8s/role.yaml -f k8s/rolebinding.yaml -f k8s/service.yaml -f k8s/ingress.yaml -f k8s/hpa.yaml
   # inject your tag
   TAG=$(git rev-parse --short HEAD)
   sed "s|CHANGEME_TAG|$TAG|" k8s/deployment.yaml | kubectl apply -f -
   ```

---

## Notes & Next Steps

* Add persistent storage and a real DB (e.g., Postgres via StatefulSet) when needed.
* Wire logs to ELK/Cloud Logging; ship metrics to Prometheus + Grafana.
* Replace Ingress annotations with your ingress-controller’s specifics (ALB, Nginx, Traefik).
* Consider PodDisruptionBudget, PodSecurity, and NetworkPolicy for hardened production.
* Swap or extend FastAPI with your preferred stack if needed; manifests remain valid.
