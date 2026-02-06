#!/usr/bin/env bash

cat << 'EOF'
🔍 Get ARM Image OCID for US East (Ashburn)

QUICK METHOD - Copy/Paste from OCI Console:

1. Open this link in your browser:
   https://cloud.oracle.com/compute/instances/create

2. At the top, verify region is: "US East (Ashburn)"
   (Change it if it shows a different region)

3. Click "Change Image" button

4. Select "Canonical Ubuntu"

5. Choose "Canonical-Ubuntu-22.04-Minimal-aarch64"

6. Copy the OCID shown (starts with: ocid1.image.oc1.iad.)

7. Paste it below and press Enter:
EOF

read -p "ARM Image OCID: " IMAGE_OCID

if [[ $IMAGE_OCID == ocid1.image.oc1.iad.* ]]; then
  echo ""
  echo "✅ Valid OCID format!"
  echo ""
  echo "Now updating terraform.tfvars..."

  # Update terraform.tfvars
  if [ -f terraform.tfvars ]; then
    # Check if the placeholder exists
    if grep -q "REPLACE_WITH_US_ASHBURN_IMAGE_OCID" terraform.tfvars; then
      sed -i.bak "s|REPLACE_WITH_US_ASHBURN_IMAGE_OCID|${IMAGE_OCID}|g" terraform.tfvars
      echo "✅ Updated terraform.tfvars"
      echo ""
      echo "You can now run:"
      echo "  tofu plan"
      echo "  tofu apply"
    else
      echo ""
      echo "⚠️  Couldn't find placeholder in terraform.tfvars"
      echo "Please manually update this line:"
      echo "  arm_image_ocid = \"${IMAGE_OCID}\""
    fi
  else
    echo "⚠️  terraform.tfvars not found"
    echo "Please create it and add:"
    echo "  arm_image_ocid = \"${IMAGE_OCID}\""
  fi
else
  echo ""
  echo "❌ Invalid OCID format. Should start with: ocid1.image.oc1.iad."
  echo "Please try again."
  exit 1
fi
EOF
