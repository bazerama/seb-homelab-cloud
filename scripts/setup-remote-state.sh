#!/usr/bin/env bash

set -euo pipefail

echo "🔧 OCI Remote State Setup"
echo "========================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if OCI CLI is configured
if ! command -v oci &> /dev/null; then
    echo -e "${RED}❌ OCI CLI not found${NC}"
    echo "Install it: brew install oci-cli"
    exit 1
fi

if [ ! -f ~/.oci/config ]; then
    echo -e "${RED}❌ OCI CLI not configured${NC}"
    echo "Run: oci setup config"
    exit 1
fi

echo -e "${GREEN}✓${NC} OCI CLI configured"
echo ""

# Get required values from terraform.tfvars
if [ ! -f terraform.tfvars ]; then
    echo -e "${RED}❌ terraform.tfvars not found${NC}"
    exit 1
fi

COMPARTMENT_OCID=$(grep "^compartment_ocid" terraform.tfvars | cut -d'=' -f2 | cut -d'#' -f1 | tr -d ' "')
USER_OCID=$(grep "^user_ocid" terraform.tfvars | cut -d'=' -f2 | cut -d'#' -f1 | tr -d ' "')
REGION=$(grep "^region" terraform.tfvars | cut -d'=' -f2 | cut -d'#' -f1 | tr -d ' "')

echo -e "${BLUE}Configuration:${NC}"
echo "  Region: $REGION"
echo "  User: $USER_OCID"
echo ""

# Step 1: Get OCI Namespace
echo "📦 Step 1: Getting OCI Namespace..."
NAMESPACE=$(oci os ns get --query 'data' --raw-output)
echo -e "${GREEN}✓${NC} Namespace: $NAMESPACE"
echo ""

# Step 2: Create Object Storage Bucket
echo "🪣 Step 2: Creating Object Storage Bucket..."
BUCKET_NAME="terraform-state-homelab"

# Check if bucket already exists
if oci os bucket get --name "$BUCKET_NAME" --namespace-name "$NAMESPACE" &>/dev/null; then
    echo -e "${YELLOW}⚠️  Bucket '$BUCKET_NAME' already exists${NC}"
    echo "   Using existing bucket..."
else
    oci os bucket create \
        --compartment-id "$COMPARTMENT_OCID" \
        --name "$BUCKET_NAME" \
        --versioning "Enabled" \
        --public-access-type "NoPublicAccess" \
        >/dev/null

    echo -e "${GREEN}✓${NC} Bucket '$BUCKET_NAME' created with versioning enabled"
fi
echo ""

# Step 3: Create S3-Compatible Access Keys
echo "🔑 Step 3: Creating S3-Compatible Access Keys..."

# Check for existing keys
EXISTING_KEYS=$(oci iam customer-secret-key list --user-id "$USER_OCID" --query 'data[*]."display-name"' --output json)

if echo "$EXISTING_KEYS" | grep -q "terraform-state-access"; then
    echo -e "${YELLOW}⚠️  Customer secret key 'terraform-state-access' already exists${NC}"
    echo ""
    echo -e "${YELLOW}Options:${NC}"
    echo "  1. Use existing key (you'll need to find the secret manually)"
    echo "  2. Create new key with different name"
    echo "  3. Delete old key and create new one"
    echo ""
    read -p "Enter choice (1/2/3): " choice

    case $choice in
        1)
            echo ""
            echo -e "${BLUE}📝 You'll need to use your existing AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY${NC}"
            echo "   If you don't have them, choose option 3 to create new keys"
            echo ""
            ACCESS_KEY_ID=""
            SECRET_KEY=""
            ;;
        2)
            KEY_NAME="terraform-state-access-$(date +%Y%m%d)"
            echo ""
            echo "Creating key: $KEY_NAME"
            KEY_JSON=$(oci iam customer-secret-key create \
                --user-id "$USER_OCID" \
                --display-name "$KEY_NAME" \
                --query 'data' --output json)

            ACCESS_KEY_ID=$(echo "$KEY_JSON" | jq -r '.id')
            SECRET_KEY=$(echo "$KEY_JSON" | jq -r '.key')
            echo -e "${GREEN}✓${NC} New key created: $KEY_NAME"
            ;;
        3)
            # Get ID of old key
            OLD_KEY_ID=$(oci iam customer-secret-key list \
                --user-id "$USER_OCID" \
                --query 'data[?\"display-name\"==`terraform-state-access`].id | [0]' \
                --raw-output)

            if [ -n "$OLD_KEY_ID" ] && [ "$OLD_KEY_ID" != "null" ]; then
                oci iam customer-secret-key delete \
                    --user-id "$USER_OCID" \
                    --customer-secret-key-id "$OLD_KEY_ID" \
                    --force
                echo -e "${GREEN}✓${NC} Old key deleted"
            fi

            echo "Creating new key..."
            KEY_JSON=$(oci iam customer-secret-key create \
                --user-id "$USER_OCID" \
                --display-name "terraform-state-access" \
                --query 'data' --output json)

            ACCESS_KEY_ID=$(echo "$KEY_JSON" | jq -r '.id')
            SECRET_KEY=$(echo "$KEY_JSON" | jq -r '.key')
            echo -e "${GREEN}✓${NC} New key created"
            ;;
        *)
            echo -e "${RED}Invalid choice${NC}"
            exit 1
            ;;
    esac
else
    # No existing key, create new one
    KEY_JSON=$(oci iam customer-secret-key create \
        --user-id "$USER_OCID" \
        --display-name "terraform-state-access" \
        --query 'data' --output json)

    ACCESS_KEY_ID=$(echo "$KEY_JSON" | jq -r '.id')
    SECRET_KEY=$(echo "$KEY_JSON" | jq -r '.key')
    echo -e "${GREEN}✓${NC} Customer secret key created"
fi
echo ""

# Step 4: Update backend.tf
echo "📝 Step 4: Updating backend.tf..."

# Create the backend config
cat > backend.tf << EOF
# Remote State Configuration
# Stores OpenTofu state in OCI Object Storage (S3-compatible API)
# This ensures state is shared between local development and GitHub Actions

terraform {
  backend "s3" {
    # OCI Object Storage S3-compatible endpoint
    endpoint                    = "https://${NAMESPACE}.compat.objectstorage.${REGION}.oraclecloud.com"
    bucket                      = "${BUCKET_NAME}"
    key                         = "k3s-cluster/terraform.tfstate"
    region                      = "${REGION}"
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    use_path_style              = true

    # Credentials are set via environment variables:
    # - AWS_ACCESS_KEY_ID (Customer Access Key from OCI)
    # - AWS_SECRET_ACCESS_KEY (Customer Secret Key from OCI)
  }
}
EOF

echo -e "${GREEN}✓${NC} backend.tf updated with your namespace"
echo ""

# Step 5: Create .envrc file (if credentials were generated)
if [ -n "${ACCESS_KEY_ID:-}" ] && [ -n "${SECRET_KEY:-}" ]; then
    echo "🔐 Step 5: Creating .envrc file..."

    cat > .envrc << EOF
# S3-compatible credentials for OCI Object Storage remote state
# Generated by setup-remote-state.sh on $(date)
export AWS_ACCESS_KEY_ID="${ACCESS_KEY_ID}"
export AWS_SECRET_ACCESS_KEY="${SECRET_KEY}"
EOF

    chmod 600 .envrc
    echo -e "${GREEN}✓${NC} .envrc created (add to .gitignore)"
    echo ""
fi

# Step 6: Update .gitignore
echo "📄 Step 6: Updating .gitignore..."
if ! grep -q "^\.envrc$" .gitignore 2>/dev/null; then
    echo ".envrc" >> .gitignore
    echo -e "${GREEN}✓${NC} Added .envrc to .gitignore"
else
    echo -e "${YELLOW}⚠️  .envrc already in .gitignore${NC}"
fi
echo ""

# Summary
echo "======================================"
echo -e "${GREEN}✅ Remote State Setup Complete!${NC}"
echo "======================================"
echo ""

if [ -n "${ACCESS_KEY_ID:-}" ] && [ -n "${SECRET_KEY:-}" ]; then
    echo -e "${BLUE}📋 Your S3 Credentials:${NC}"
    echo ""
    echo "AWS_ACCESS_KEY_ID:"
    echo "  $ACCESS_KEY_ID"
    echo ""
    echo "AWS_SECRET_ACCESS_KEY:"
    echo "  $SECRET_KEY"
    echo ""
    echo -e "${YELLOW}⚠️  SAVE THESE! You won't be able to see the secret again.${NC}"
    echo ""
fi

echo -e "${BLUE}📦 Backend Configuration:${NC}"
echo "  Endpoint: ${NAMESPACE}.compat.objectstorage.${REGION}.oraclecloud.com"
echo "  Bucket: ${BUCKET_NAME}"
echo "  Key: k3s-cluster/terraform.tfstate"
echo ""

echo -e "${BLUE}🚀 Next Steps:${NC}"
echo ""
if [ -n "${ACCESS_KEY_ID:-}" ]; then
    echo "1. Load environment variables:"
    echo -e "   ${GREEN}source .envrc${NC}"
    echo ""
fi

echo "2. Migrate existing state to remote backend:"
echo -e "   ${GREEN}tofu init -migrate-state${NC}"
echo ""

echo "3. Verify migration:"
echo -e "   ${GREEN}tofu state list${NC}"
echo ""

echo "4. Set GitHub secrets:"
echo -e "   ${GREEN}gh secret set AWS_ACCESS_KEY_ID --body \"$ACCESS_KEY_ID\"${NC}"
echo -e "   ${GREEN}gh secret set AWS_SECRET_ACCESS_KEY --body \"$SECRET_KEY\"${NC}"
echo -e "   ${GREEN}gh secret set TF_BACKEND_NAMESPACE --body \"$NAMESPACE\"${NC}"
echo ""

echo "5. Commit and push:"
echo -e "   ${GREEN}git add backend.tf .gitignore${NC}"
echo -e "   ${GREEN}git commit -m \"feat(state): configure OCI Object Storage remote state\"${NC}"
echo ""

echo -e "${GREEN}🎉 Your state will now be safely stored in OCI Object Storage!${NC}"
