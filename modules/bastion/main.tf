resource "oci_core_instance" "bastion" {
  availability_domain = var.availability_domain
  compartment_id      = var.compartment_ocid
  shape               = var.instance_shape
  display_name        = var.instance_name

  source_details {
    source_id   = var.image_id
    source_type = "image"
  }

  create_vnic_details {
    subnet_id        = var.subnet_id
    assign_public_ip = var.public_edge_node
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data = var.user_data
  }

  dynamic "shape_config" {
    for_each = local.flex_shape
      content {
        memory_in_gbs = shape_config.value.memory_in_gbs
        ocpus = shape_config.value.ocpus
      }
  }

  extended_metadata = {
    oke_cluster_id = var.oke_cluster_id
    nodepool_id = var.nodepool_id
    tenancy_ocid = var.tenancy_ocid
    namespace = var.namespace
    kube_label = var.kube_label
    kubeflow_login_ocid = var.kubeflow_login_ocid
    kubeflow_password_ocid = var.kubeflow_password_ocid
  }
}

