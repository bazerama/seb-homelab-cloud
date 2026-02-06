# Oracle Cloud Infrastructure Variables
# These can be set via environment variables (TF_VAR_*) or terraform.tfvars

variable "tenancy_ocid" {
  description = "OCID of your tenancy. Get from OCI Console -> Profile -> Tenancy"
  type        = string
}

variable "user_ocid" {
  description = "OCID of the user. Get from OCI Console -> Profile -> User Settings"
  type        = string
}

variable "fingerprint" {
  description = "Fingerprint of the API key. Get when you upload API key to OCI"
  type        = string
}

variable "private_key_path" {
  description = "Path to your private API key file"
  type        = string
  default     = "~/.oci/oci_api_key.pem"
}

variable "region" {
  description = "OCI region (e.g., us-ashburn-1, eu-frankfurt-1)"
  type        = string
  default     = "us-ashburn-1"
}

variable "compartment_ocid" {
  description = "OCID of the compartment to create resources in (use tenancy OCID for root compartment)"
  type        = string
}

variable "availability_domain" {
  description = "Availability domain (e.g., 'ynwd:US-ASHBURN-AD-1')"
  type        = string
}

variable "ssh_public_key_path" {
  description = "Path to SSH public key for instance access"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "arm_image_ocid" {
  description = "OCID of the ARM-based Oracle Linux image for your region"
  type        = string
  # You'll need to find this for your region - see setup guide
}
