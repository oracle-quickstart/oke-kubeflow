module "network" { 
  source = "./modules/network"
  tenancy_ocid = var.tenancy_ocid
  compartment_ocid = var.compartment_ocid
  region = var.region
  useExistingVcn = var.useExistingVcn
  VCN_CIDR = var.VCN_CIDR
  edge_cidr = var.edge_cidr
  private_cidr = var.private_cidr
  vcn_dns_label  = var.vcn_dns_label
  service_port = var.service_port
  custom_vcn = [var.myVcn]
  OKESubnet = var.OKESubnet
  edgeSubnet = var.edgeSubnet
  myVcn = var.myVcn
}

module "oke" {
  source = "./modules/oke"
  create_new_oke_cluster = var.create_new_oke_cluster
  existing_oke_cluster_id = var.existing_oke_cluster_id
  tenancy_ocid = var.tenancy_ocid
  compartment_ocid = var.compartment_ocid
  cluster_name = var.cluster_name
  kubernetes_version = var.kubernetes_version
  kubeflow_node_pool_name = var.kubeflow_node_pool_name
  kubeflow_node_pool_shape = var.kubeflow_node_pool_shape
  kubeflow_node_pool_size = var.kubeflow_node_pool_size
  cluster_options_add_ons_is_kubernetes_dashboard_enabled =  var.cluster_options_add_ons_is_kubernetes_dashboard_enabled
  cluster_options_admission_controller_options_is_pod_security_policy_enabled = var.cluster_options_admission_controller_options_is_pod_security_policy_enabled
  image_id = data.oci_core_images.oraclelinux7.images.0.id
  vcn_id = var.useExistingVcn ? var.myVcn : module.network.vcn-id
  subnet_id = var.useExistingVcn ? var.OKESubnet : module.network.private-id
  lb_subnet_id = module.network.edge-id
  ssh_public_key = var.ssh_provided_public_key
  cluster_endpoint_config_is_public_ip_enabled = var.cluster_endpoint_config_is_public_ip_enabled
  endpoint_subnet_id = var.cluster_endpoint_config_is_public_ip_enabled ? module.network.edge-id : module.network.private-id
  node_pool_node_shape_config_memory_in_gbs = var.flex_gbs
  node_pool_node_shape_config_ocpus = var.flex_ocpu
  is_flex_shape = contains(["VM.Standard.E3.Flex", "VM.Standard.E4.Flex", "VM.Optimized3.Flex", "VM.Standard.A1.Flex"], var.kubeflow_node_pool_shape)
}

module "bastion" {
  depends_on = [module.oke, module.network]
  source = "./modules/bastion"
  user_data = base64encode(file("userdata/cloudinit.sh"))
  compartment_ocid = var.compartment_ocid
  availability_domain = var.availability_domain
  image_id = data.oci_core_images.oraclelinux7.images.0.id 
  instance_shape   = var.bastion_shape
  instance_name = var.bastion_name
  subnet_id =  var.useExistingVcn ? var.edgeSubnet : local.bastion_subnet
  ssh_public_key = var.ssh_provided_public_key
  public_edge_node = var.public_edge_node
  oke_cluster_id = var.create_new_oke_cluster ? module.oke.cluster_id : var.existing_oke_cluster_id
  nodepool_id = module.oke.nodepool_id
  tenancy_ocid = var.tenancy_ocid
  namespace = var.kubeflow_namespace
  kube_label = var.kube_label
  bastion_flex_gbs = var.bastion_flex_gbs
  bastion_flex_ocpus = var.bastion_flex_ocpus
  is_flex_shape = contains(["VM.Standard.E3.Flex", "VM.Standard.E4.Flex", "VM.Optimized3.Flex", "VM.Standard.A1.Flex"], var.bastion_shape)
  kubeflow_login_ocid = var.kubeflow_login_ocid
  kubeflow_password_ocid = var.kubeflow_password_ocid
}

