.PHONY: help init validate plan apply deploy destroy clean ssh-control ssh-worker-1 ssh-worker-2 kubeconfig status fmt version

# Use OpenTofu by default, fallback to Terraform if not available
TOFU := $(shell command -v tofu 2> /dev/null)
ifndef TOFU
	TOFU := $(shell command -v terraform 2> /dev/null)
	ifndef TOFU
		$(error "Neither OpenTofu nor Terraform found. Please install OpenTofu: https://opentofu.org/docs/intro/install/")
	endif
endif

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Using: $(TOFU)'
	@echo ''
	@echo 'Available targets:'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-20s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

version: ## Show OpenTofu/Terraform version
	@$(TOFU) version

init: ## Initialize OpenTofu
	$(TOFU) init

validate: init ## Validate configuration
	$(TOFU) validate

fmt: ## Format .tf files
	$(TOFU) fmt -recursive

plan: validate ## Show what will be deployed
	$(TOFU) plan

apply: validate ## Deploy the infrastructure (alias: deploy)
	$(TOFU) apply

deploy: apply ## Deploy the infrastructure

destroy: ## Destroy all infrastructure (WARNING: destructive!)
	@echo "⚠️  This will destroy all infrastructure!"
	@read -p "Are you sure? (yes/no): " confirm && [ "$$confirm" = "yes" ]
	$(TOFU) destroy

clean: ## Clean OpenTofu/Terraform files
	rm -rf .terraform .terraform.lock.hcl terraform.tfstate terraform.tfstate.backup

ssh-control: ## SSH into control plane node
	@PUBLIC_IP=$$($(TOFU) output -raw k3s_control_plane_public_ip 2>/dev/null) && \
	ssh opc@$$PUBLIC_IP

ssh-worker-1: ## SSH into worker 1
	@PUBLIC_IP=$$($(TOFU) output -json k3s_worker_public_ips 2>/dev/null | jq -r '.["k3s-worker-1"]') && \
	ssh opc@$$PUBLIC_IP

ssh-worker-2: ## SSH into worker 2
	@PUBLIC_IP=$$($(TOFU) output -json k3s_worker_public_ips 2>/dev/null | jq -r '.["k3s-worker-2"]') && \
	ssh opc@$$PUBLIC_IP

kubeconfig: ## Fetch kubeconfig from control plane
	@echo "Fetching kubeconfig from control plane..."
	@PUBLIC_IP=$$($(TOFU) output -raw k3s_control_plane_public_ip 2>/dev/null) && \
	ssh opc@$$PUBLIC_IP sudo cat /etc/rancher/k3s/k3s.yaml | \
	sed "s/127.0.0.1/$$PUBLIC_IP/g" > ~/.kube/oracle-k3s-config && \
	echo "✅ Kubeconfig saved to ~/.kube/oracle-k3s-config" && \
	echo "Run: export KUBECONFIG=~/.kube/oracle-k3s-config"

status: ## Show deployed resources
	@echo "📊 Deployed Resources:"
	@$(TOFU) output -json | jq -r 'to_entries[] | "\(.key): \(.value.value)"'

show: ## Show current state
	$(TOFU) show

