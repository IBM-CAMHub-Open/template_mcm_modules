## Generate unique ID for temporary work directory on docker host
resource "random_string" "random-dir" {
  length  = 8
  special = false
}


## Set up local variables to be used
locals {
  work_dir             = "mcm${random_string.random-dir.result}"
  kubeconfig_data      = "${length(var.cluster_config) > 0 ? base64decode(var.cluster_config) : var.cluster_config}"
  certificate_data     = "${length(var.cluster_certificate_authority) > 0 ? base64decode(var.cluster_certificate_authority) : var.cluster_certificate_authority}"
  service_account_data = "${length(var.service_account_credentials) > 0 ? base64decode(var.service_account_credentials) : var.service_account_credentials}"
  destroy_action       = "${var.remove_or_delete}"
}


resource "null_resource" "manage-cluster" {
  provisioner "local-exec" {
    command = "chmod 755 ${path.module}/scripts/manage_cluster.sh && ${path.module}/scripts/manage_cluster.sh -a import -s ${var.kubernetes_service} -w ${local.work_dir}"
    environment {
      CLUSTER_CONFIG              = "${local.kubeconfig_data}"
      CLUSTER_NAME                = "${var.cluster_name}"
      ICP_URL                     = "${var.icp_url}"
      ICP_ADMIN_USER              = "${var.icp_admin_user}"
      ICP_ADMIN_PASSWORD          = "${var.icp_admin_password}"
      MCM_ENDPOINT                = "${var.mcm_hub_endpoint}"

      ## IKS
      CLUSTER_CA_CERTIFICATE      = "${local.certificate_data}"
      ## GKE
      SERVICE_ACCOUNT_CREDENTIALS = "${local.service_account_data}"
      ## EKS
      ACCESS_KEY_ID               = "${var.access_key_id}"
      SECRET_ACCESS_KEY           = "${var.secret_access_key}"
      CLUSTER_REGION              = "${var.cluster_region}"
    }
  }

  provisioner "local-exec" {
    when    = "destroy"
    command = "chmod 755 ${path.module}/scripts/manage_cluster.sh && ${path.module}/scripts/manage_cluster.sh -a ${local.destroy_action} -s ${var.kubernetes_service} -w ${local.work_dir}"
    environment {
      CLUSTER_CONFIG              = "${local.kubeconfig_data}"
      CLUSTER_NAME                = "${var.cluster_name}"
      ICP_URL                     = "${var.icp_url}"
      ICP_ADMIN_USER              = "${var.icp_admin_user}"
      ICP_ADMIN_PASSWORD          = "${var.icp_admin_password}"
      MCM_ENDPOINT                = "${var.mcm_hub_endpoint}"

      ## IKS
      CLUSTER_CA_CERTIFICATE      = "${local.certificate_data}"
      ## GKE
      SERVICE_ACCOUNT_CREDENTIALS = "${local.service_account_data}"
      ## EKS
      ACCESS_KEY_ID               = "${var.access_key_id}"
      SECRET_ACCESS_KEY           = "${var.secret_access_key}"
      CLUSTER_REGION              = "${var.cluster_region}"
    }
  }
}