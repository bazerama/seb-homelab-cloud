# Remote State Configuration
# Stores OpenTofu state in OCI Object Storage (S3-compatible API)
# This ensures state is shared between local development and GitHub Actions

terraform {
  backend "s3" {
    # OCI Object Storage S3-compatible endpoint
    endpoint                    = "https://sdhjr6nmxkui.compat.objectstorage.ap-sydney-1.oraclecloud.com"
    bucket                      = "terraform-state-homelab"
    key                         = "k3s-cluster/terraform.tfstate"
    region                      = "ap-sydney-1"
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    use_path_style              = true

    # Credentials are set via environment variables:
    # - AWS_ACCESS_KEY_ID (Customer Access Key from OCI)
    # - AWS_SECRET_ACCESS_KEY (Customer Secret Key from OCI)
  }
}
