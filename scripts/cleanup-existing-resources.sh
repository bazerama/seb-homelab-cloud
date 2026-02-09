#!/usr/bin/env bash

set -euo pipefail

echo "🔍 Checking for Existing OCI Resources"
echo "======================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if OCI CLI is configured
if ! command -v oci &> /dev/null; then
    echo -e "${RED}❌ OCI CLI not found${NC}"
    echo "Install it: brew install oci-cli"
    exit 1
fi

# Check configuration
if [ ! -f ~/.oci/config ]; then
    echo -e "${RED}❌ OCI CLI not configured${NC}"
    echo "Run: oci setup config"
    exit 1
fi

# Get compartment OCID from terraform.tfvars or environment
if [ -f terraform.tfvars ]; then
    # Extract value, strip quotes, and remove inline comments
    COMPARTMENT_OCID=$(grep "^compartment_ocid" terraform.tfvars | cut -d'=' -f2 | cut -d'#' -f1 | tr -d ' "')
elif [ -n "${TF_VAR_compartment_ocid:-}" ]; then
    COMPARTMENT_OCID="$TF_VAR_compartment_ocid"
else
    echo -e "${RED}❌ Cannot find compartment_ocid${NC}"
    echo "Set it in terraform.tfvars or as TF_VAR_compartment_ocid"
    exit 1
fi

echo -e "${GREEN}✓${NC} Using compartment: $COMPARTMENT_OCID"
echo ""

# ============================================================================
# Check VCNs
# ============================================================================
echo "📡 Checking VCNs..."
VCN_COUNT=$(oci network vcn list --compartment-id "$COMPARTMENT_OCID" --query 'data | length(@)' --raw-output 2>/dev/null || echo "0")

if [ "$VCN_COUNT" -gt 0 ]; then
    echo -e "${YELLOW}⚠️  Found $VCN_COUNT existing VCN(s)${NC}"
    echo ""
    echo "VCN Details:"
    oci network vcn list --compartment-id "$COMPARTMENT_OCID" \
        --query 'data[*].[id, "display-name", "lifecycle-state"]' \
        --output table 2>/dev/null || true
    echo ""

    if [ "$VCN_COUNT" -ge 2 ]; then
        echo -e "${RED}❌ VCN limit reached (2 max for free tier)${NC}"
        echo ""
        echo "To delete a VCN:"
        echo "1. Go to: https://cloud.oracle.com/networking/vcns"
        echo "2. Select the VCN you want to delete"
        echo "3. Click 'Terminate'"
        echo "4. Confirm termination"
        echo ""
        echo "Or use OCI CLI:"
        echo "  oci network vcn delete --vcn-id <VCN_OCID>"
    fi
else
    echo -e "${GREEN}✓${NC} No existing VCNs found"
fi
echo ""

# ============================================================================
# Check Budgets
# ============================================================================
echo "💰 Checking Budgets..."

# Get tenancy OCID (budgets are at tenancy level)
if [ -f terraform.tfvars ]; then
    # Extract value, strip quotes, and remove inline comments
    TENANCY_OCID=$(grep "^tenancy_ocid" terraform.tfvars | cut -d'=' -f2 | cut -d'#' -f1 | tr -d ' "')
elif [ -n "${TF_VAR_tenancy_ocid:-}" ]; then
    TENANCY_OCID="$TF_VAR_tenancy_ocid"
else
    TENANCY_OCID="$COMPARTMENT_OCID"  # Fallback if using tenancy as compartment
fi

BUDGET_COUNT=$(oci budgets budget list --compartment-id "$TENANCY_OCID" --query 'data | length(@)' --raw-output 2>/dev/null || echo "0")

if [ "$BUDGET_COUNT" -gt 0 ]; then
    echo -e "${YELLOW}⚠️  Found $BUDGET_COUNT existing budget(s)${NC}"
    echo ""
    echo "Budget Details:"
    oci budgets budget list --compartment-id "$TENANCY_OCID" \
        --query 'data[*].[id, "display-name", amount, "lifecycle-state"]' \
        --output table 2>/dev/null || true
    echo ""

    echo "Options:"
    echo "1. ${GREEN}Import existing budget into OpenTofu state:${NC}"
    echo "   tofu import oci_budget_budget.free_tier_protection <BUDGET_OCID>"
    echo ""
    echo "2. ${YELLOW}Delete existing budget (if you don't want to keep it):${NC}"
    echo "   oci budgets budget delete --budget-id <BUDGET_OCID>"
    echo ""
    echo "3. ${YELLOW}Rename your new budget in budgets.tf to avoid conflict${NC}"
else
    echo -e "${GREEN}✓${NC} No existing budgets found"
fi
echo ""

# ============================================================================
# Check Compute Instances
# ============================================================================
echo "🖥️  Checking Compute Instances..."
INSTANCE_COUNT=$(oci compute instance list --compartment-id "$COMPARTMENT_OCID" --query 'data | length(@)' --raw-output 2>/dev/null || echo "0")

if [ "$INSTANCE_COUNT" -gt 0 ]; then
    echo -e "${YELLOW}⚠️  Found $INSTANCE_COUNT existing instance(s)${NC}"
    echo ""
    echo "Instance Details:"
    oci compute instance list --compartment-id "$COMPARTMENT_OCID" \
        --query 'data[*].[id, "display-name", shape, "lifecycle-state"]' \
        --output table 2>/dev/null || true
    echo ""
else
    echo -e "${GREEN}✓${NC} No existing instances found"
fi
echo ""

# ============================================================================
# Summary
# ============================================================================
echo "======================================"
echo "📊 Summary"
echo "======================================"
echo "VCNs: $VCN_COUNT / 2 (free tier limit)"
echo "Budgets: $BUDGET_COUNT / 1 (free tier limit)"
echo "Instances: $INSTANCE_COUNT / 4 (free tier limit)"
echo ""

if [ "$VCN_COUNT" -ge 2 ] || [ "$BUDGET_COUNT" -ge 1 ]; then
    echo -e "${RED}❌ Action required before deployment:${NC}"
    [ "$VCN_COUNT" -ge 2 ] && echo "   - Clean up VCNs (limit reached)"
    [ "$BUDGET_COUNT" -ge 1 ] && echo "   - Import or delete existing budget"
    echo ""
    echo "See: docs/TROUBLESHOOTING.md for detailed steps"
    exit 1
else
    echo -e "${GREEN}✅ Ready to deploy!${NC}"
    exit 0
fi
