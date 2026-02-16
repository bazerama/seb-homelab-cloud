.PHONY: help init validate plan apply deploy destroy clean ssh-control ssh-worker-1 ssh-worker-2 kubeconfig status fmt version setup install-brew install-oci configure-oci configure-backend find-resources

# Load S3 backend credentials from .env (written by scripts/setup-remote-state.sh)
# Clear work/corporate AWS settings that conflict with OCI S3 compatibility
unexport AWS_PROFILE
unexport AWS_CA_BUNDLE
ifneq (,$(wildcard .env))
    -include .env
    export AWS_ACCESS_KEY_ID
    export AWS_SECRET_ACCESS_KEY
endif

# Use OpenTofu by default, fallback to Terraform if not available
TOFU := $(shell command -v tofu 2> /dev/null)
ifndef TOFU
	TOFU := $(shell command -v terraform 2> /dev/null)
endif

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@if [ -n "$(TOFU)" ]; then \
		echo 'Using: $(TOFU)'; \
	else \
		echo 'Note: OpenTofu/Terraform not found — run "make setup" to get started'; \
	fi
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

# --- Setup targets ----------------------------------------------------------------

setup: ## Full guided setup: brew, OCI CLI, config, and resource discovery
	@$(MAKE) install-brew
	@$(MAKE) install-oci
	@$(MAKE) configure-oci
	@$(MAKE) find-resources || ( \
		echo ""; \
		echo "Resource discovery failed — this is usually an authentication issue."; \
		read -p "Re-run OCI configuration with fresh credentials? (y/N): " retry; \
		case "$$retry" in \
			[yY]*) $(MAKE) configure-oci && $(MAKE) find-resources ;; \
			*) echo "Run 'make configure-oci' and then 'make find-resources' when ready."; exit 1 ;; \
		esac \
	)
	@$(MAKE) configure-backend
	@echo ""
	@echo "=============================================="
	@echo "🎉 Setup complete! Running plan..."
	@echo "=============================================="
	@echo ""
	@$(MAKE) plan

install-brew: ## Install Homebrew (if not already installed)
	@if command -v brew >/dev/null 2>&1; then \
		echo "✅ Homebrew already installed: $$(brew --version | head -1)"; \
	else \
		echo "📦 Homebrew is a package manager for macOS used to install dependencies."; \
		echo ""; \
		echo "Installing Homebrew..."; \
		echo ""; \
		/bin/bash -c "$$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; \
	fi

install-oci: ## Install OCI CLI via Homebrew
	@if command -v oci >/dev/null 2>&1; then \
		echo "✅ OCI CLI already installed: $$(oci --version 2>&1)"; \
	else \
		echo "📦 Installing OCI CLI and tools via Homebrew..."; \
		echo ""; \
		brew install oci-cli dotenv-linter; \
		echo ""; \
		echo "✅ OCI CLI installed: $$(oci --version 2>&1)"; \
	fi

configure-oci: ## Configure OCI CLI with API key pair
	@if [ -f ~/.oci/config ]; then \
		echo "⚠️  OCI config already exists at ~/.oci/config"; \
		read -p "Overwrite? (y/N): " overwrite; \
		case "$$overwrite" in [yY]*) ;; *) echo "Skipping OCI configuration."; exit 0 ;; esac; \
	fi; \
	echo ""; \
	echo "🔧 OCI CLI Configuration"; \
	echo "========================"; \
	echo ""; \
	echo "You'll need two OCIDs from the Oracle Cloud Console."; \
	echo ""; \
	echo "📌 User OCID"; \
	echo "   OCI Console → Profile icon (top-right) → User settings → copy OCID"; \
	echo ""; \
	read -p "Paste your User OCID: " user_ocid; \
	if [ -z "$$user_ocid" ]; then echo "Error: User OCID is required."; exit 1; fi; \
	echo ""; \
	echo "📌 Tenancy OCID"; \
	echo "   OCI Console → Profile icon (top-right) → Tenancy: <name> → copy OCID"; \
	echo ""; \
	read -p "Paste your Tenancy OCID: " tenancy_ocid; \
	if [ -z "$$tenancy_ocid" ]; then echo "Error: Tenancy OCID is required."; exit 1; fi; \
	echo ""; \
	echo "📌 Region (common options):"; \
	echo "   ap-sydney-1      (Sydney)"; \
	echo "   ap-melbourne-1   (Melbourne)"; \
	echo "   us-ashburn-1     (Ashburn)"; \
	echo "   us-phoenix-1     (Phoenix)"; \
	echo "   eu-frankfurt-1   (Frankfurt)"; \
	echo ""; \
	read -p "Enter your region [ap-sydney-1]: " region; \
	region=$${region:-ap-sydney-1}; \
	echo ""; \
	echo "🔑 Generating API key pair..."; \
	mkdir -p ~/.oci; \
	openssl genrsa -out ~/.oci/oci_api_key.pem 2048 2>/dev/null; \
	chmod 600 ~/.oci/oci_api_key.pem; \
	openssl rsa -pubout -in ~/.oci/oci_api_key.pem -out ~/.oci/oci_api_key_public.pem 2>/dev/null; \
	fingerprint=$$(openssl rsa -pubout -outform DER -in ~/.oci/oci_api_key.pem 2>/dev/null | openssl md5 -c | awk '{print $$2}'); \
	echo "✅ Key pair generated in ~/.oci/"; \
	echo ""; \
	printf '[DEFAULT]\nuser=%s\nfingerprint=%s\ntenancy=%s\nregion=%s\nkey_file=~/.oci/oci_api_key.pem\n' \
		"$$user_ocid" "$$fingerprint" "$$tenancy_ocid" "$$region" > ~/.oci/config; \
	chmod 600 ~/.oci/config; \
	echo "✅ Config written to ~/.oci/config"; \
	echo ""; \
	echo "=============================================="; \
	echo "📋 Upload this public key to OCI Console:"; \
	echo "=============================================="; \
	echo ""; \
	cat ~/.oci/oci_api_key_public.pem; \
	echo ""; \
	echo "Steps:"; \
	echo "  1. Go to OCI Console → Profile icon → User settings"; \
	echo "  2. Under Resources, click 'API Keys'"; \
	echo "  3. Click 'Add API Key' → 'Paste Public Key'"; \
	echo "  4. Paste the key above and click 'Add'"; \
	echo ""; \
	read -p "Press Enter once you've uploaded the key to continue..." _

configure-backend: ## Configure S3 backend credentials for OCI Object Storage
	@if [ -f .env ] && grep -q AWS_ACCESS_KEY_ID .env 2>/dev/null; then \
		echo "✅ Backend credentials already configured in .env"; \
	else \
		./scripts/setup-remote-state.sh; \
	fi

find-resources: ## Discover OCI resources and generate terraform.tfvars
	@./scripts/util/find-oci-resources.sh
