# Kubernetes Deployment Makefile

# Configuration
REGISTRY ?= ghcr.io/speedscale/microsvc
IMAGE_TAG ?= latest
NAMESPACE ?= banking-app
KUSTOMIZE_DIR ?= base

# Deployment targets
.PHONY: deploy undeploy redeploy status
deploy: update-images
	@echo "Deploying banking application to Kubernetes..."
	kubectl apply -k $(KUSTOMIZE_DIR)/

undeploy:
	@echo "Removing banking application from Kubernetes..."
	kubectl delete -k $(KUSTOMIZE_DIR)/ || true

redeploy: undeploy deploy

status:
	@echo "Checking deployment status..."
	kubectl get all -n $(NAMESPACE)
	@echo "\nPod status:"
	kubectl get pods -n $(NAMESPACE) -o wide
	@echo "\nService endpoints:"
	kubectl get svc -n $(NAMESPACE)

# Image management
.PHONY: update-images restore-local-images
update-images:
	@echo "Updating Kubernetes manifests with registry: $(REGISTRY) and tag: $(IMAGE_TAG)"
	@sed -i.bak "s|image: .*user-service:.*|image: $(REGISTRY)/user-service:$(IMAGE_TAG)|g" $(KUSTOMIZE_DIR)/deployments/user-service-deployment.yaml
	@sed -i.bak "s|image: .*accounts-service:.*|image: $(REGISTRY)/accounts-service:$(IMAGE_TAG)|g" $(KUSTOMIZE_DIR)/deployments/accounts-service-deployment.yaml
	@sed -i.bak "s|image: .*transactions-service:.*|image: $(REGISTRY)/transactions-service:$(IMAGE_TAG)|g" $(KUSTOMIZE_DIR)/deployments/transactions-service-deployment.yaml
	@sed -i.bak "s|image: .*api-gateway:.*|image: $(REGISTRY)/api-gateway:$(IMAGE_TAG)|g" $(KUSTOMIZE_DIR)/deployments/api-gateway-deployment.yaml
	@sed -i.bak "s|imagePullPolicy: Never|imagePullPolicy: Always|g" $(KUSTOMIZE_DIR)/deployments/*-deployment.yaml
	@rm -f $(KUSTOMIZE_DIR)/deployments/*.bak
	@echo "Successfully updated all Kubernetes manifests"

restore-local-images:
	@echo "Restoring local image references for minikube testing..."
	@sed -i.bak "s|image: $(REGISTRY)/user-service:.*|image: banking-user-service:latest|g" $(KUSTOMIZE_DIR)/deployments/user-service-deployment.yaml
	@sed -i.bak "s|image: $(REGISTRY)/accounts-service:.*|image: banking-accounts-service:latest|g" $(KUSTOMIZE_DIR)/deployments/accounts-service-deployment.yaml
	@sed -i.bak "s|image: $(REGISTRY)/transactions-service:.*|image: banking-transactions-service:latest|g" $(KUSTOMIZE_DIR)/deployments/transactions-service-deployment.yaml
	@sed -i.bak "s|image: $(REGISTRY)/api-gateway:.*|image: banking-api-gateway:latest|g" $(KUSTOMIZE_DIR)/deployments/api-gateway-deployment.yaml
	@sed -i.bak "s|imagePullPolicy: Always|imagePullPolicy: Never|g" $(KUSTOMIZE_DIR)/deployments/*-deployment.yaml
	@rm -f $(KUSTOMIZE_DIR)/deployments/*.bak
	@echo "Successfully restored local image references"

# Testing and debugging
.PHONY: logs port-forward test-deployment
logs:
	@echo "Fetching logs from all services..."
	kubectl logs -n $(NAMESPACE) -l app.kubernetes.io/name=banking-app --tail=100 -f

port-forward:
	@echo "Port forwarding API Gateway to localhost:8080..."
	kubectl port-forward -n $(NAMESPACE) service/api-gateway 8080:8080

test-deployment:
	@echo "Testing deployment with E2E test client..."
	kubectl apply -f testing/test-client-job.yaml
	@echo "Waiting for test job to complete..."
	kubectl wait --for=condition=complete job/banking-e2e-test -n $(NAMESPACE) --timeout=300s
	kubectl logs -n $(NAMESPACE) job/banking-e2e-test
	kubectl delete job/banking-e2e-test -n $(NAMESPACE)

# Minikube specific targets
.PHONY: minikube-deploy minikube-setup minikube-cleanup
minikube-setup:
	@echo "Setting up minikube environment..."
	minikube start --driver=docker
	minikube addons enable ingress
	eval $$(minikube docker-env)

minikube-deploy: restore-local-images deploy
	@echo "Deploying to minikube with local images..."

minikube-cleanup:
	@echo "Cleaning up minikube..."
	kubectl delete -k $(KUSTOMIZE_DIR)/ || true
	minikube delete

# Help
.PHONY: help
help:
	@echo "Kubernetes Deployment Commands:"
	@echo ""
	@echo "Deployment:"
	@echo "  deploy             - Deploy application to Kubernetes"
	@echo "  undeploy           - Remove application from Kubernetes"
	@echo "  redeploy           - Remove and redeploy application"
	@echo "  status             - Check deployment status"
	@echo ""
	@echo "Image Management:"
	@echo "  update-images      - Update manifests to use registry images"
	@echo "  restore-local-images - Restore local image references for minikube"
	@echo ""
	@echo "Testing & Debugging:"
	@echo "  logs               - Fetch logs from all services"
	@echo "  port-forward       - Port forward API Gateway to localhost:8080"
	@echo "  test-deployment    - Run E2E test against deployment"
	@echo ""
	@echo "Minikube:"
	@echo "  minikube-setup     - Setup minikube environment"
	@echo "  minikube-deploy    - Deploy to minikube with local images"
	@echo "  minikube-cleanup   - Clean up minikube"
	@echo ""
	@echo "Environment Variables:"
	@echo "  REGISTRY           - Docker registry (default: ghcr.io/speedscale/microsvc)"
	@echo "  IMAGE_TAG          - Docker image tag (default: latest)"
	@echo "  NAMESPACE          - Kubernetes namespace (default: banking-app)"