#!/usr/bin/env bash

# Script to check and cleanup OCI VCNs
# Helps resolve "vcn-count limit exceeded" errors

set -euo pipefail

echo "🔍 OCI VCN Cleanup Helper"
echo "========================="
echo ""

# Check if OCI CLI is installed
if ! command -v oci &> /dev/null; then
    echo "❌ OCI CLI is not installed"
    echo "Install it: brew install oci-cli"
    echo "Then run: oci setup config"
    exit 1
fi

# Get compartment OCID from terraform.tfvars or prompt
if [ -f "terraform.tfvars" ]; then
    COMPARTMENT_OCID=$(grep "^compartment_ocid" terraform.tfvars | cut -d'=' -f2 | cut -d'#' -f1 | tr -d ' "' | xargs || true)
fi

if [ -z "${COMPARTMENT_OCID:-}" ]; then
    echo "Enter your compartment OCID:"
    read -r COMPARTMENT_OCID
fi

echo "📋 Listing all VCNs in your compartment..."
echo ""

# List all VCNs
VCN_LIST=$(oci network vcn list --compartment-id "$COMPARTMENT_OCID" 2>&1)

if echo "$VCN_LIST" | grep -q "ServiceError"; then
    echo "❌ Error connecting to OCI"
    echo "$VCN_LIST"
    echo ""
    echo "Make sure you've run: oci setup config"
    exit 1
fi

# Parse and display VCNs
VCN_COUNT=$(echo "$VCN_LIST" | jq '.data | length')

if [ "$VCN_COUNT" -eq 0 ]; then
    echo "✅ No VCNs found. You should be able to create a new one."
    echo ""
    echo "If you're still seeing the limit error, wait a few minutes for OCI to sync."
    exit 0
fi

echo "Found $VCN_COUNT VCN(s):"
echo ""

# Display VCNs in a nice format
echo "$VCN_LIST" | jq -r '.data[] | "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\nName: \(.["display-name"])\nOCID: \(.id)\nCIDR: \(.["cidr-block"] // .["cidr-blocks"][0])\nState: \(.["lifecycle-state"])\n"'

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check free tier VCN limit
echo "📊 OCI Free Tier VCN Limit: 2 VCNs"
echo "   Current VCNs: $VCN_COUNT"
echo ""

if [ "$VCN_COUNT" -ge 2 ]; then
    echo "⚠️  You've reached the free tier VCN limit!"
    echo ""
    echo "To proceed with your K3s deployment, you need to:"
    echo "1. Delete an existing VCN (if unused)"
    echo "2. Or use an existing VCN for your K3s cluster"
    echo ""

    # Offer to delete VCNs
    echo "Would you like to delete a VCN? (yes/no)"
    read -r DELETE_CONFIRM

    if [[ $DELETE_CONFIRM =~ ^[Yy]es$ ]]; then
        echo ""
        echo "Enter the OCID of the VCN to delete:"
        read -r VCN_TO_DELETE

        echo ""
        echo "⚠️  WARNING: This will attempt to delete the VCN and all its resources."
        echo "This includes subnets, route tables, security lists, gateways, etc."
        echo ""
        echo "VCN to delete: $VCN_TO_DELETE"
        echo ""
        echo "Are you SURE? Type 'DELETE' to confirm:"
        read -r FINAL_CONFIRM

        if [ "$FINAL_CONFIRM" = "DELETE" ]; then
            echo ""
            echo "🗑️  Attempting to delete VCN..."
            echo ""

            # Try to delete (this might fail if resources still exist)
            if oci network vcn delete --vcn-id "$VCN_TO_DELETE" --force --wait-for-state TERMINATED; then
                echo ""
                echo "✅ VCN deleted successfully!"
                echo ""
                echo "Wait a few minutes, then run: tofu plan"
            else
                echo ""
                echo "❌ Failed to delete VCN"
                echo ""
                echo "The VCN might have dependent resources. Delete them manually:"
                echo "1. Go to: https://cloud.oracle.com/networking/vcns"
                echo "2. Find the VCN: ${VCN_TO_DELETE:0:50}..."
                echo "3. Delete all resources inside it (subnets, route tables, etc.)"
                echo "4. Then delete the VCN"
                echo ""
                echo "Or use the OCI Console's 'Terminate VCN' wizard which"
                echo "automatically cleans up dependent resources."
            fi
        else
            echo "❌ Deletion cancelled"
        fi
    fi
else
    echo "✅ You have capacity to create $(( 2 - VCN_COUNT )) more VCN(s)"
    echo ""
    echo "If you're still seeing the limit error:"
    echo "1. Wait a few minutes for OCI to sync"
    echo "2. Check the OCI Console: https://cloud.oracle.com/networking/vcns"
    echo "3. Make sure you're in the correct region (ap-sydney-1)"
fi

echo ""
echo "💡 Tip: You can also reuse an existing VCN by importing it:"
echo "   tofu import oci_core_vcn.k3s_vcn <vcn-ocid>"
