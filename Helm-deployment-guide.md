# 🚀 Helm Deployment Guide for DevOps App Starter

This guide explains how to package, deploy, and expose the **DevOps App Starter** using **Helm** on Kubernetes.

---

## 📂 Project Structure for Helm

Inside your repo, create a `helm/` folder:

```
helm/
  devops-app/
    Chart.yaml
    values.yaml
    templates/
      deployment.yaml
      service.yaml
      ingress.yaml
```

### Example `Chart.yaml`

```yaml
apiVersion: v2
name: devops-app
version: 0.1.0
appVersion: "1.0"
description: A Helm chart for deploying the DevOps App Starter
```

### Example `values.yaml`

```yaml
replicaCount: 2

image:
  repository: ghcr.io/YOUR_GH_USERNAME/devops-app-starter
  tag: latest
  pullPolicy: IfNotPresent

service:
  type: ClusterIP
  port: 80

ingress:
  enabled: true
  className: nginx
  hosts:
    - host: devops.local
      paths:
        - path: /
          pathType: Prefix
  tls: []
```

### Example `templates/deployment.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Chart.Name }}
  labels:
    app: {{ .Chart.Name }}
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      app: {{ .Chart.Name }}
  template:
    metadata:
      labels:
        app: {{ .Chart.Name }}
    spec:
      containers:
      - name: api
        image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
        ports:
        - containerPort: 8080
        env:
        - name: APP_ENV
          value: "prod"
```

### Example `templates/service.yaml`

```yaml
apiVersion: v1
kind: Service
metadata:
  name: {{ .Chart.Name }}
  labels:
    app: {{ .Chart.Name }}
spec:
  type: {{ .Values.service.type }}
  ports:
    - port: {{ .Values.service.port }}
      targetPort: 8080
      protocol: TCP
      name: http
  selector:
    app: {{ .Chart.Name }}
```

### Example `templates/ingress.yaml`

```yaml
{{- if .Values.ingress.enabled }}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ .Chart.Name }}
  annotations:
    nginx.ingress.kubernetes.io/proxy-body-size: "1m"
spec:
  ingressClassName: {{ .Values.ingress.className }}
  rules:
    {{- range .Values.ingress.hosts }}
    - host: {{ .host }}
      http:
        paths:
          {{- range .paths }}
          - path: {{ .path }}
            pathType: {{ .pathType }}
            backend:
              service:
                name: {{ $.Chart.Name }}
                port:
                  number: {{ $.Values.service.port }}
          {{- end }}
    {{- end }}
  {{- if .Values.ingress.tls }}
  tls:
    {{- range .Values.ingress.tls }}
    - hosts:
        {{- range .hosts }}
        - {{ . }}
        {{- end }}
      secretName: {{ .secretName }}
    {{- end }}
  {{- end }}
{{- end }}
```

---

## ⚙️ Deploy with Helm

Package and install:

```powershell
helm upgrade --install devops-app ./helm/devops-app -n devops-app --create-namespace
```

Check status:

```powershell
kubectl -n devops-app get pods
kubectl -n devops-app get svc
```

---

## 🌐 Ingress Testing

### Local (Docker Desktop Kubernetes) with `devops.local`

1. Install ingress-nginx:

   ```powershell
   kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/cloud/deploy.yaml
   kubectl -n ingress-nginx get pods -w
   ```

2. Add host mapping (Admin PowerShell):

   ```powershell
   notepad C:\Windows\System32\drivers\etc\hosts
   ```

   Add:

   ```
   127.0.0.1 devops.local
   ```

3. Apply local ingress:

   ```powershell
   kubectl apply -f k8s/ingress.local.yaml
   kubectl -n devops-app get ingress
   ```

4. Test:

   * [http://devops.local/healthz](http://devops.local/healthz)
   * [http://devops.local/docs](http://devops.local/docs)

---

### AKS (Public IP with LoadBalancer)

1. Install ingress-nginx via Helm:

   ```powershell
   helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
   helm repo update

   helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx `
     --namespace ingress-nginx --create-namespace `
     --set controller.ingressClassResource.name=nginx `
     --set controller.ingressClass=nginx `
     --set controller.service.type=LoadBalancer
   ```

2. Get the external IP:

   ```powershell
   kubectl -n ingress-nginx get svc ingress-nginx-controller -w
   ```

3. Apply AKS ingress:

   ```powershell
   kubectl apply -f k8s/ingress.aks.yaml
   kubectl -n devops-app get ingress
   ```

4. Test using magic DNS (replace `<IP>` with the external IP):

   ```powershell
   curl http://<IP>.nip.io/healthz
   # Browser: http://<IP>.nip.io/docs
   ```

---

## 🔧 Handy Follow-ups

```powershell
# check logs
kubectl -n devops-app logs -l app=devops-app --tail=100 -f

# scale manually
kubectl -n devops-app scale deploy/devops-app --replicas=3

# autoscale (requires metrics-server)
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl -n devops-app autoscale deploy/devops-app --min=2 --max=5 --cpu-percent=70
```

---

✅ With Helm + Ingress, you can run the app both **locally (`devops.local`)** and on **AKS (via LoadBalancer IP)**.

---

## ✅ Testing the Ingress (Local & AKS)

### 🔹 Local (Docker Desktop Kubernetes) with `devops.local`

1. Install/verify ingress-nginx:

   ```powershell
   kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/cloud/deploy.yaml
   kubectl -n ingress-nginx get pods -w
   ```

   Wait until the controller pod shows `1/1 Running`.

2. Add host entry (Admin PowerShell):

   ```powershell
   notepad C:\Windows\System32\drivers\etc\hosts
   ```

   Add this line and save:

   ```
   127.0.0.1 devops.local
   ```

3. Apply local ingress:

   ```powershell
   kubectl apply -f k8s/ingress.local.yaml
   kubectl -n devops-app get ingress
   ```

4. Test in browser or curl:

   * [http://devops.local/healthz](http://devops.local/healthz)
   * [http://devops.local/docs](http://devops.local/docs)

---

### 🔹 AKS (Public IP with LoadBalancer)

1. Install ingress-nginx via Helm:

   ```powershell
   helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
   helm repo update

   helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx `
     --namespace ingress-nginx --create-namespace `
     --set controller.ingressClassResource.name=nginx `
     --set controller.ingressClass=nginx `
     --set controller.service.type=LoadBalancer
   ```

2. Get the external IP:

   ```powershell
   kubectl -n ingress-nginx get svc ingress-nginx-controller -w
   ```

   Wait until `EXTERNAL-IP` appears.

3. Apply AKS ingress:

   ```powershell
   kubectl apply -f k8s/ingress.aks.yaml
   kubectl -n devops-app get ingress
   ```

4. Test using magic DNS (replace `<IP>` with the external IP):

   ```powershell
   curl http://<IP>.nip.io/healthz
   # Browser:
   # http://<IP>.nip.io/docs
   ```

---

## 🔒 Optional TLS (HTTPS)

### 🧪 Local TLS (mkcert → devops.local)

Use **mkcert** to generate a locally trusted cert and attach it to your Ingress.

1. Install mkcert and trust the local CA (Admin PowerShell):

```powershell
choco install mkcert -y   # or: scoop install mkcert
mkcert -install
```

2. Create a cert for your host:

```powershell
mkcert devops.local
# Produces: devops.local.pem (cert), devops.local-key.pem (key)
```

3. Create a Kubernetes TLS secret in `devops-app` namespace:

```powershell
kubectl -n devops-app create secret tls devops-app-tls `
  --cert=devops.local.pem `
  --key=devops.local-key.pem
```

4. Enable TLS in **`k8s/ingress.local.yaml`**:

```yaml
spec:
  ingressClassName: nginx
  tls:
    - hosts: ["devops.local"]
      secretName: devops-app-tls
  rules:
    - host: devops.local
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

5. Apply and test:

```powershell
kubectl apply -f k8s/ingress.local.yaml
curl -k https://devops.local/healthz
# Browser: https://devops.local/docs (should be trusted if mkcert CA installed)
```

---

### ☁️ AKS TLS (cert-manager + Let’s Encrypt)

Use **cert-manager** to automatically provision valid certs for a real domain.

> Prereqs: a real DNS **A record** (e.g., `api.example.com`) pointing to your **ingress-nginx** `EXTERNAL-IP`.

1. Install cert-manager (CRDs included):

```powershell
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/latest/download/cert-manager.yaml
kubectl -n cert-manager get pods -w
```

2. Create a ClusterIssuer (Let’s Encrypt HTTP-01):

```yaml
# k8s/cert-manager-clusterissuer.yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    email: you@example.com
    server: https://acme-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: letsencrypt-prod-key
    solvers:
      - http01:
          ingress:
            class: nginx
```

Apply it:

```powershell
kubectl apply -f k8s/cert-manager-clusterissuer.yaml
```

3. Update **`k8s/ingress.aks.yaml`** to use your domain + TLS:

```yaml
spec:
  ingressClassName: nginx
  tls:
    - hosts: ["api.example.com"]
      secretName: devops-app-tls
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

4. Create a Certificate resource (cert-manager will fetch the cert):

```yaml
# k8s/certificate.yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: devops-app-cert
  namespace: devops-app
spec:
  secretName: devops-app-tls
  issuerRef:
    kind: ClusterIssuer
    name: letsencrypt-prod
  dnsNames:
    - api.example.com
```

Apply:

```powershell
kubectl apply -f k8s/certificate.yaml
```

5. Verify readiness and test:

```powershell
kubectl -n devops-app get certificate,order,challenge
# Once Ready:
curl https://api.example.com/healthz
```

> Tip: For staging (rate-limit friendly), use `https://acme-staging-v02.api.letsencrypt.org/directory` in the ClusterIssuer first, then switch to prod.
