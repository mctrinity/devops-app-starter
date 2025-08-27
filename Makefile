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