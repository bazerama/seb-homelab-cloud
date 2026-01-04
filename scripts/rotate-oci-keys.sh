#!/usr/bin/env bash

# Script to rotate OCI API keys safely
# Usage: ./rotate-oci-keys.sh

set -euo pipefail

echo "🔐 OCI API Key Rotation Script"
echo "=============================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Paths
OCI_DIR="$HOME/.oci"
OLD_KEY="$OCI_DIR/oci_api_key.pem"
NEW_KEY="$OCI_DIR/oci_api_key_new.pem"
OLD_PUB="$OCI_DIR/oci_api_key_public.pem"
NEW_PUB="$OCI_DIR/oci_api_key_public_new.pem"
BACKUP_DIR="$OCI_DIR/backup_$(date +%Y%m%d_%H%M%S)"

echo -e "${YELLOW}⚠️  This script will:${NC}"
echo "   1. Generate a new OCI API key pair"
echo "   2. Show you the new public key to upload to OCI"
echo "   3. Get the new fingerprint"
echo "   4. Help you update terraform.tfvars"
echo ""
read -p "Continue? (yes/no): " -r REPLY
echo ""
if [[ ! $REPLY =~ ^[Yy]es$ ]]; then
    echo "Aborted."
    exit 1
fi

# Step 1: Backup existing keys
echo "📦 Step 1: Backing up existing keys..."
if [ -f "$OLD_KEY" ]; then
    mkdir -p "$BACKUP_DIR"
    cp "$OLD_KEY" "$BACKUP_DIR/"
    cp "$OLD_PUB" "$BACKUP_DIR/" 2>/dev/null || true
    echo -e "${GREEN}✅ Backed up to: $BACKUP_DIR${NC}"
else
    echo -e "${YELLOW}⚠️  No existing key found at $OLD_KEY${NC}"
fi
echo ""

# Step 2: Generate new key pair
echo "🔑 Step 2: Generating new API key pair..."
openssl genrsa -out "$NEW_KEY" 2048 2>/dev/null
chmod 600 "$NEW_KEY"
openssl rsa -pubout -in "$NEW_KEY" -out "$NEW_PUB" 2>/dev/null
echo -e "${GREEN}✅ Generated new key pair${NC}"
echo ""

# Step 3: Show public key
echo "📋 Step 3: New PUBLIC KEY (copy this):"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
cat "$NEW_PUB"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${YELLOW}Action Required:${NC}"
echo "1. Go to: https://cloud.oracle.com/"
echo "2. Click: Profile → User Settings → API Keys"
echo "3. Click: Add API Key"
echo "4. Select: Paste Public Key"
echo "5. Paste the key above"
echo "6. Click: Add"
echo ""
read -p "Press ENTER after you've added the key in OCI Console..." -r
echo ""

# Step 4: Get fingerprint
echo "🔍 Step 4: New FINGERPRINT:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
NEW_FINGERPRINT=$(openssl rsa -pubout -outform DER -in "$NEW_KEY" 2>/dev/null | openssl md5 -c | cut -d= -f2 | tr -d ' ')
echo "$NEW_FINGERPRINT"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Step 5: Update terraform.tfvars
echo "📝 Step 5: Update terraform.tfvars"
TFVARS_FILE="$(dirname "$0")/../terraform.tfvars"

if [ -f "$TFVARS_FILE" ]; then
    echo "Found terraform.tfvars at: $TFVARS_FILE"
    echo ""
    
    # Backup tfvars
    cp "$TFVARS_FILE" "$TFVARS_FILE.backup_$(date +%Y%m%d_%H%M%S)"
    
    # Try to update fingerprint
    if grep -q "^fingerprint" "$TFVARS_FILE"; then
        OLD_FINGERPRINT=$(grep "^fingerprint" "$TFVARS_FILE" | cut -d= -f2 | tr -d ' "')
        echo "Old fingerprint: $OLD_FINGERPRINT"
        echo "New fingerprint: $NEW_FINGERPRINT"
        echo ""
        
        # Update in-place
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS
            sed -i '' "s/fingerprint.*=.*/fingerprint        = \"$NEW_FINGERPRINT\"/" "$TFVARS_FILE"
        else
            # Linux
            sed -i "s/fingerprint.*=.*/fingerprint        = \"$NEW_FINGERPRINT\"/" "$TFVARS_FILE"
        fi
        
        echo -e "${GREEN}✅ Updated terraform.tfvars with new fingerprint${NC}"
    else
        echo -e "${YELLOW}⚠️  Could not find fingerprint line in terraform.tfvars${NC}"
        echo "Please manually update it with: $NEW_FINGERPRINT"
    fi
else
    echo -e "${YELLOW}⚠️  terraform.tfvars not found${NC}"
    echo "Please manually create it and add: fingerprint = \"$NEW_FINGERPRINT\""
fi
echo ""

# Step 6: Test new credentials
echo "🧪 Step 6: Test new credentials"
echo ""
read -p "Do you want to test with 'tofu plan' now? (yes/no): " -r TEST_REPLY
echo ""

if [[ $TEST_REPLY =~ ^[Yy]es$ ]]; then
    # Temporarily move new key to active location
    mv "$NEW_KEY" "$OCI_DIR/oci_api_key_new_test.pem"
    mv "$NEW_PUB" "$OCI_DIR/oci_api_key_public_new_test.pem"
    mv "$OLD_KEY" "$OCI_DIR/oci_api_key_old.pem" 2>/dev/null || true
    mv "$OLD_PUB" "$OCI_DIR/oci_api_key_public_old.pem" 2>/dev/null || true
    mv "$OCI_DIR/oci_api_key_new_test.pem" "$OLD_KEY"
    mv "$OCI_DIR/oci_api_key_public_new_test.pem" "$OLD_PUB"
    
    cd "$(dirname "$0")/.."
    
    echo "Testing with 'tofu plan'..."
    echo ""
    
    # Run tofu plan and capture exit code
    if tofu plan -detailed-exitcode >/dev/null 2>&1; then
        PLAN_EXIT=$?
    else
        PLAN_EXIT=$?
    fi
    
    # Exit codes: 0 = no changes, 1 = error, 2 = changes pending
    # Both 0 and 2 are success (2 just means there are changes to apply)
    if [ $PLAN_EXIT -eq 0 ] || [ $PLAN_EXIT -eq 2 ]; then
        echo -e "${GREEN}✅ New credentials work!${NC}"
        echo ""
        echo "Running plan again to show output:"
        echo ""
        tofu plan -no-color | head -30
        echo ""
        echo "Next steps:"
        echo "1. Go to OCI Console → User Settings → API Keys"
        echo "2. Delete the OLD API key (the one you backed up)"
        echo "3. Keep only the new key"
        echo ""
        echo "Old key backed up at: $BACKUP_DIR"
    else
        echo ""
        echo -e "${RED}❌ Test failed! Rolling back...${NC}"
        
        # Rollback
        mv "$OLD_KEY" "$NEW_KEY"
        mv "$OLD_PUB" "$NEW_PUB"
        mv "$OCI_DIR/oci_api_key_old.pem" "$OLD_KEY" 2>/dev/null || true
        mv "$OCI_DIR/oci_api_key_public_old.pem" "$OLD_PUB" 2>/dev/null || true
        
        echo "Restored old keys. Please check:"
        echo "1. Did you upload the public key correctly in OCI?"
        echo "2. Did you wait a few seconds for OCI to process it?"
        echo "3. Is the fingerprint correct in terraform.tfvars?"
        exit 1
    fi
else
    echo "Skipping test. To manually test later:"
    echo "1. Move new key to active location:"
    echo "   mv $NEW_KEY $OLD_KEY"
    echo "   mv $NEW_PUB $OLD_PUB"
    echo "2. Run: tofu plan"
fi
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}🎉 Key Rotation Complete!${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Summary:"
echo "  ✅ New key pair generated"
echo "  ✅ Public key uploaded to OCI (by you)"
echo "  ✅ terraform.tfvars updated"
echo "  ✅ Old keys backed up to: $BACKUP_DIR"
echo ""
echo "⚠️  Remember to DELETE the old API key from OCI Console!"
echo ""

