data "oci_identity_availability_domains" "ads" {
  compartment_id = var.compartment_ocid
}
data "template_file" "ad_names" {
  template = "${lookup(data.oci_identity_availability_domains.ads.availability_domains[(length(data.oci_identity_availability_domains.ads.availability_domains)-1)], "name")}"
}
