# ============================================================================
# Local Variables & Validation
# ============================================================================

locals {
  # K3s node configuration - STAYS WITHIN FREE TIER LIMITS
  # Total: 3 instances, 4 OCPUs, 24GB RAM (100% of free tier allocation)
  nodes = [
    {
      name       = "k3s-control-1"
      role       = "control-plane"
      ocpus      = 2
      memory_gb  = 12
      storage_gb = 50
    },
    {
      name       = "k3s-worker-1"
      role       = "worker"
      ocpus      = 1
      memory_gb  = 6
      storage_gb = 50
    },
    {
      name       = "k3s-worker-2"
      role       = "worker"
      ocpus      = 1
      memory_gb  = 6
      storage_gb = 50
    }
  ]

  # Calculate totals for validation
  total_ocpus     = sum([for node in local.nodes : node.ocpus])
  total_memory_gb = sum([for node in local.nodes : node.memory_gb])
  total_instances = length(local.nodes)
  total_storage   = sum([for node in local.nodes : node.storage_gb])

  # K3s configuration
  k3s_token = random_password.k3s_token.result

  # Common tags
  common_tags = {
    tier        = "always-free"
    cluster     = "k3s"
    environment = "homelab"
    managed-by  = "terraform"
  }
}

# Validation checks
resource "null_resource" "validate_free_tier" {
  lifecycle {
    precondition {
      condition     = local.total_ocpus <= 4
      error_message = "Total OCPUs (${local.total_ocpus}) exceeds Always-Free tier limit of 4."
    }
    precondition {
      condition     = local.total_memory_gb <= 24
      error_message = "Total memory (${local.total_memory_gb}GB) exceeds Always-Free tier limit of 24GB."
    }
    precondition {
      condition     = local.total_instances <= 4
      error_message = "Total instances (${local.total_instances}) exceeds practical limit of 4."
    }
    precondition {
      condition     = local.total_storage <= 200
      error_message = "Total storage (${local.total_storage}GB) exceeds Always-Free tier limit of 200GB."
    }
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "✅ Always-Free Tier Validation Passed:"
      echo "   Instances: ${local.total_instances}/4"
      echo "   OCPUs: ${local.total_ocpus}/4"
      echo "   Memory: ${local.total_memory_gb}GB/24GB"
      echo "   Storage: ${local.total_storage}GB/200GB"
    EOT
  }
}

# ============================================================================
# Random K3s Token
# ============================================================================

resource "random_password" "k3s_token" {
  length  = 32
  special = false
}

# ============================================================================
# Network Configuration
# ============================================================================

# Virtual Cloud Network (VCN)
resource "oci_core_vcn" "k3s_vcn" {
  compartment_id = var.compartment_ocid
  cidr_blocks    = ["10.0.0.0/16"]
  display_name   = "k3s-vcn"
  dns_label      = "k3svcn"

  freeform_tags = local.common_tags
}

# Internet Gateway
resource "oci_core_internet_gateway" "k3s_igw" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.k3s_vcn.id
  display_name   = "k3s-internet-gateway"
  enabled        = true

  freeform_tags = local.common_tags
}

# Route Table
resource "oci_core_route_table" "k3s_route_table" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.k3s_vcn.id
  display_name   = "k3s-route-table"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.k3s_igw.id
  }

  freeform_tags = local.common_tags
}

# Security List
resource "oci_core_security_list" "k3s_security_list" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.k3s_vcn.id
  display_name   = "k3s-security-list"

  # Egress - Allow all outbound
  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"
    stateless   = false
  }

  # Ingress - SSH
  ingress_security_rules {
    protocol    = "6" # TCP
    source      = "0.0.0.0/0"
    stateless   = false
    description = "SSH access"

    tcp_options {
      min = 22
      max = 22
    }
  }

  # Ingress - K8s API Server
  ingress_security_rules {
    protocol    = "6" # TCP
    source      = "0.0.0.0/0"
    stateless   = false
    description = "K8s API Server"

    tcp_options {
      min = 6443
      max = 6443
    }
  }

  # Ingress - HTTP
  ingress_security_rules {
    protocol    = "6" # TCP
    source      = "0.0.0.0/0"
    stateless   = false
    description = "HTTP"

    tcp_options {
      min = 80
      max = 80
    }
  }

  # Ingress - HTTPS
  ingress_security_rules {
    protocol    = "6" # TCP
    source      = "0.0.0.0/0"
    stateless   = false
    description = "HTTPS"

    tcp_options {
      min = 443
      max = 443
    }
  }

  # Ingress - Internal cluster communication
  ingress_security_rules {
    protocol    = "all"
    source      = "10.0.0.0/16"
    stateless   = false
    description = "Internal cluster communication"
  }

  freeform_tags = local.common_tags
}

# Subnet
resource "oci_core_subnet" "k3s_subnet" {
  compartment_id             = var.compartment_ocid
  vcn_id                     = oci_core_vcn.k3s_vcn.id
  cidr_block                 = "10.0.1.0/24"
  display_name               = "k3s-subnet"
  dns_label                  = "k3ssubnet"
  route_table_id             = oci_core_route_table.k3s_route_table.id
  security_list_ids          = [oci_core_security_list.k3s_security_list.id]
  prohibit_public_ip_on_vnic = false

  freeform_tags = local.common_tags
}

# ============================================================================
# Compute Instances (K3s Nodes)
# ============================================================================

# Control Plane Node (created first)
resource "oci_core_instance" "k3s_control_plane" {
  availability_domain = var.availability_domain
  compartment_id      = var.compartment_ocid
  display_name        = local.nodes[0].name
  shape               = "VM.Standard.A1.Flex" # Always-Free ARM shape

  shape_config {
    ocpus         = local.nodes[0].ocpus
    memory_in_gbs = local.nodes[0].memory_gb
  }

  source_details {
    source_type             = "image"
    source_id               = var.arm_image_ocid
    boot_volume_size_in_gbs = local.nodes[0].storage_gb
  }

  create_vnic_details {
    assign_public_ip = true
    subnet_id        = oci_core_subnet.k3s_subnet.id
    display_name     = "${local.nodes[0].name}-vnic"
  }

  metadata = {
    ssh_authorized_keys = file(var.ssh_public_key_path)
    user_data = base64encode(templatefile("${path.module}/cloud-init.tpl", {
      node_name        = local.nodes[0].name
      node_role        = local.nodes[0].role
      is_control_plane = true
      control_plane_ip = "" # Not needed for control plane
      k3s_token        = local.k3s_token
    }))
  }

  freeform_tags = merge(local.common_tags, {
    role = local.nodes[0].role
  })

  depends_on = [null_resource.validate_free_tier]
}

# Worker Nodes (created after control plane)
resource "oci_core_instance" "k3s_workers" {
  for_each = { for idx, node in slice(local.nodes, 1, length(local.nodes)) : node.name => node }

  availability_domain = var.availability_domain
  compartment_id      = var.compartment_ocid
  display_name        = each.value.name
  shape               = "VM.Standard.A1.Flex" # Always-Free ARM shape

  shape_config {
    ocpus         = each.value.ocpus
    memory_in_gbs = each.value.memory_gb
  }

  source_details {
    source_type             = "image"
    source_id               = var.arm_image_ocid
    boot_volume_size_in_gbs = each.value.storage_gb
  }

  create_vnic_details {
    assign_public_ip = true
    subnet_id        = oci_core_subnet.k3s_subnet.id
    display_name     = "${each.value.name}-vnic"
  }

  metadata = {
    ssh_authorized_keys = file(var.ssh_public_key_path)
    user_data = base64encode(templatefile("${path.module}/cloud-init.tpl", {
      node_name        = each.value.name
      node_role        = each.value.role
      is_control_plane = false
      control_plane_ip = oci_core_instance.k3s_control_plane.public_ip
      k3s_token        = local.k3s_token
    }))
  }

  freeform_tags = merge(local.common_tags, {
    role = each.value.role
  })

  depends_on = [
    null_resource.validate_free_tier,
    oci_core_instance.k3s_control_plane
  ]
}

# ============================================================================
# Outputs
# ============================================================================

output "validation_summary" {
  description = "Always-Free tier resource usage summary"
  value = {
    instances  = "${local.total_instances}/4"
    ocpus      = "${local.total_ocpus}/4"
    memory_gb  = "${local.total_memory_gb}/24"
    storage_gb = "${local.total_storage}/200"
    status     = "✅ Within Always-Free tier limits"
  }
}

output "k3s_control_plane_public_ip" {
  description = "Public IP of K3s control plane"
  value       = oci_core_instance.k3s_control_plane.public_ip
}

output "k3s_control_plane_private_ip" {
  description = "Private IP of K3s control plane"
  value       = oci_core_instance.k3s_control_plane.private_ip
}

output "k3s_worker_public_ips" {
  description = "Public IPs of K3s workers"
  value = {
    for name, instance in oci_core_instance.k3s_workers :
    name => instance.public_ip
  }
}

output "k3s_worker_private_ips" {
  description = "Private IPs of K3s workers"
  value = {
    for name, instance in oci_core_instance.k3s_workers :
    name => instance.private_ip
  }
}

output "all_nodes" {
  description = "All node details"
  value = merge(
    {
      (oci_core_instance.k3s_control_plane.display_name) = {
        public_ip  = oci_core_instance.k3s_control_plane.public_ip
        private_ip = oci_core_instance.k3s_control_plane.private_ip
        role       = "control-plane"
      }
    },
    {
      for name, instance in oci_core_instance.k3s_workers :
      name => {
        public_ip  = instance.public_ip
        private_ip = instance.private_ip
        role       = "worker"
      }
    }
  )
}

output "k3s_token" {
  description = "K3s cluster token (sensitive)"
  value       = local.k3s_token
  sensitive   = true
}

output "ssh_commands" {
  description = "SSH commands to access nodes"
  value = merge(
    {
      (oci_core_instance.k3s_control_plane.display_name) = "ssh opc@${oci_core_instance.k3s_control_plane.public_ip}"
    },
    {
      for name, instance in oci_core_instance.k3s_workers :
      name => "ssh opc@${instance.public_ip}"
    }
  )
}

output "kubeconfig_command" {
  description = "Command to fetch kubeconfig from control plane"
  value       = "ssh opc@${oci_core_instance.k3s_control_plane.public_ip} sudo cat /etc/rancher/k3s/k3s.yaml"
}
