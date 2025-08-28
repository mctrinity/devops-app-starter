# DevOps App Starter 🚀

A starter FastAPI + Docker + Kubernetes project, instrumented with Prometheus metrics, health checks, and Ingress.

---

## 🐳 Run locally with Docker

Build and run:

```powershell
docker build -t devops-app:local .
docker run -p 8080:8080 devops-app:local
```

Logs:

```
INFO:     Open your browser at: http://localhost:8080
```

### Endpoints

* [http://localhost:8080/healthz](http://localhost:8080/healthz) → health check
* [http://localhost:8080/hello?name=maki](http://localhost:8080/hello?name=maki) → sample endpoint
* [http://localhost:8080/docs](http://localhost:8080/docs) → Swagger UI
* [http://localhost:8080/metrics](http://localhost:8080/metrics) → Prometheus metrics

---

## ☸️ Run locally with Kubernetes (Docker Desktop)

1. **Enable Kubernetes** in Docker Desktop.
2. Apply manifests:

```powershell
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/configmap.yaml -f k8s/secret.yaml `
  -f k8s/serviceaccount.yaml -f k8s/role.yaml -f k8s/rolebinding.yaml `
  -f k8s/service.yaml -f k8s/deployment.yaml
```

Check status:

```powershell
kubectl -n devops-app get pods
kubectl -n devops-app get svc
```

---

## 🌐 Ingress

We provide **two Ingress manifests** depending on your environment:

* `k8s/ingress.local.yaml` → for local development with Docker Desktop / Minikube (host: `devops.local`).
* `k8s/ingress.aks.yaml` → for AKS deployments using a LoadBalancer external IP.

### Local (`devops.local`)

1. Install ingress-nginx:

```powershell
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/cloud/deploy.yaml
```

2. Wait until controller pod is `1/1 Running`:

```powershell
kubectl -n ingress-nginx get pods -w
```

3. Add host mapping (edit as Administrator):

**`C:\Windows\System32\drivers\etc\hosts`**

```
127.0.0.1 devops.local
```

4. Apply ingress:

```powershell
kubectl apply -f k8s/ingress.local.yaml
kubectl -n devops-app get ingress
```

5. Browse:

* [http://devops.local/healthz](http://devops.local/healthz)
* [http://devops.local/hello?name=maki](http://devops.local/hello?name=maki)
* [http://devops.local/docs](http://devops.local/docs)

### AKS (`LoadBalancer` external IP)

1. Deploy ingress:

```powershell
kubectl apply -f k8s/ingress.aks.yaml
```

2. Get external IP:

```powershell
kubectl -n ingress-nginx get svc ingress-nginx-controller
```

3. Browse:

* http\://<EXTERNAL-IP>/docs

---

## 📦 Build & Push to GitHub Container Registry (GHCR)

1. **Login** (replace with your username + token):

```powershell
echo YOUR_PAT | docker login ghcr.io -u YOUR_GH_USERNAME --password-stdin
```

2. **Tag and push**:

```powershell
docker tag devops-app:local ghcr.io/YOUR_GH_USERNAME/devops-app-starter:latest
docker push ghcr.io/YOUR_GH_USERNAME/devops-app-starter:latest
```

Check image:

```powershell
docker images ghcr.io/YOUR_GH_USERNAME/devops-app-starter
```

---

## 🔄 CI/CD with GitHub Actions → AKS

* **ci.yaml** builds & pushes to GHCR on every commit.
* **deploy-aks.yaml** connects to AKS and updates your deployment with the new image.

### Secrets required

* `AZURE_CLIENT_ID`
* `AZURE_TENANT_ID`
* `AZURE_SUBSCRIPTION_ID`
* `AKS_RESOURCE_GROUP`
* `AKS_CLUSTER_NAME`

See `.github/workflows/deploy-aks.yaml` for details.

---

## 🛠 Useful commands

```powershell
# check rollout
kubectl -n devops-app rollout status deployment/devops-app

# update image manually
kubectl -n devops-app set image deployment/devops-app api=ghcr.io/USER/devops-app-starter:TAG

# logs
kubectl -n devops-app logs -l app=devops-app --tail=100 -f
```

---

## ✅ Summary

* Local dev: **[http://localhost:8080](http://localhost:8080)**
* K8s + Ingress: **[http://devops.local](http://devops.local)**
* AKS Ingress: **http\://<EXTERNAL-IP>**
* Metrics: **/metrics**
* CI/CD: Build → GHCR → Deploy (AKS)

This repo is a full local-to-cloud DevOps starter kit. 🎉
