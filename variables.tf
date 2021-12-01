# ---------------------------------------------------------------------------------------------------------------------
# AD Settings. By default uses AD1 
# ---------------------------------------------------------------------------------------------------------------------
variable "availability_domain" {
  default = "1"
}

# ---------------------------------------------------------------------------------------------------------------------
# SSH Keys - Put this to top level because they are required
# ---------------------------------------------------------------------------------------------------------------------
variable "ssh_provided_public_key" {
  default = ""
}


# ---------------------------------------------------------------------------------------------------------------------
# Network Settings
# --------------------------------------------------------------------------------------------------------------------- 

# If you want to use an existing VCN set useExistingVcn = "true" and configure OCID(s) of myVcn, OKESubnet and edgeSubnet

variable "useExistingVcn" {
  default = "false"
}

variable "myVcn" {
  default = " "
}
variable "OKESubnet" {
  default = " "
}
variable "edgeSubnet" {
  default = " "
}

variable "custom_cidrs" { 
  default = "false"
}

variable "VCN_CIDR" {
  default = "10.0.0.0/16"
}

variable "edge_cidr" {
  default = "10.0.1.0/24"
}

variable "private_cidr" {
  default =  "10.0.2.0/24"
}

variable "vcn_dns_label" {
  default = "kubeflowvcn"
}

variable "service_port" {
  default = "8080"
}

variable "public_edge_node" {
  default = true 
}

# ---------------------------------------------------------------------------------------------------------------------
# OKE Settings
# ---------------------------------------------------------------------------------------------------------------------

variable "create_new_oke_cluster" {
  default = "true"
}

variable "existing_oke_cluster_id" {
  default = " "
}

variable "cluster_name" {
  default = "kubeflow-cluster"
}

variable "kubernetes_version" {
  default = "v1.20.11"
}

variable "kubeflow_node_pool_name" {
  default = "Kubeflow-Node-Pool"
}

variable "kubeflow_node_pool_shape" {
  default = "VM.Standard2.2"
}

variable "kubeflow_node_pool_size" {
  default = 1
}

variable "kubeflow_namespace" {
  default = "kubeflow"
}

variable "kube_label" {
  default = "kubeflow"
}

variable "cluster_options_add_ons_is_kubernetes_dashboard_enabled" {
  default = "false"
}

variable "cluster_options_admission_controller_options_is_pod_security_policy_enabled" {
  default = "false"
}

variable "cluster_endpoint_config_is_public_ip_enabled" {
  default = "false" 
}

variable "endpoint_subnet_id" {
  default = " "
}

variable "customize_kubeflow" {
  default = "false"
}


variable "kubeflow_password" {
  default = "Kubeflow54321"
}

# ---------------------------------------------------------------------------------------------------------------------
# Bastion VM Settings
# ---------------------------------------------------------------------------------------------------------------------


variable "bastion_name" {
  default = "bastion"
}

variable "bastion_shape" {
  default = "VM.Standard2.1"
}

# ---------------------------------------------------------------------------------------------------------------------
# Environmental variables
# You probably want to define these as environmental variables.
# Instructions on that are here: https://github.com/oracle/oci-quickstart-prerequisites
# ---------------------------------------------------------------------------------------------------------------------

variable "compartment_ocid" {}

# Required by the OCI Provider

variable "tenancy_ocid" {}
variable "region" {}

# Dictionary Locals
locals {
  compute_flexible_shapes = [
    "VM.Standard.E3.Flex",
    "VM.Standard.E4.Flex",
    "VM.Optimized3.Flex"
  ]
}

variable "node_pool_node_shape_config_ocpus" {
  default     = "4" # Only used if flex shape is selected
  description = "You can customize the number of OCPUs to a flexible shape"
}
variable "node_pool_node_shape_config_memory_in_gbs" {
  default     = "64" # Only used if flex shape is selected
  description = "You can customize the amount of memory allocated to a flexible shape"
}

variable "bastion_shape_config_ocpus"  {
  default     = "1" # Only used if flex shape is selected
  description = "You can customize the number of OCPUs to a flexible shape"
  
}
variable "bastion_shape_config_memory_in_gbs" {
  default     = "8" # Only used if flex shape is selected
  description = "You can customize the amount of memory allocated to a flexible shape"

}

variable "is_node_pool_shape" {
  default     = "1" # Only used if flex shape is selected
  description = "Default is to use E3 Flex"

}
