## Set up local variables to be used
locals {
  kubeconfig_file  = "${var.work_directory}/target_cluster_kubeconfig.yaml"
  certificate_file = "${var.work_directory}/target_cluster_certificate.pem"
  credentials_file = "${var.work_directory}/cluster_credentials.json"
}

resource "local_file" "create_kubeconfig_file" {
  count    = length(var.cluster_config) > 0 ? 1 : 0
  content  = base64decode(var.cluster_config)
  filename = local.kubeconfig_file
}

resource "local_file" "create_certificate_file" {
  count    = length(var.cluster_certificate_authority) > 0 ? 1 : 0
  content  = var.cluster_certificate_authority
  filename = local.certificate_file
}

resource "null_resource" "generate-credentials" {
  ## Token included in the credentials can expire;
  ## Trigger new resource to ensure credentials are generated during each plan/apply
  triggers = {
    trigger_time = timestamp()
  }

  provisioner "local-exec" {
    command = "chmod 755 ${path.module}/scripts/get_cluster_credentials.sh && ${path.module}/scripts/get_cluster_credentials.sh -cn ${var.cluster_name} -ct ${var.cluster_type} -wd ${var.work_directory} -cf ${local.credentials_file}"
    environment = {
      ## AKS, EKS, GKE, IKS, ROKS
      CLUSTER_CONFIG_FILE = local.kubeconfig_file
      ## IKS
      CLUSTER_CA_CERTIFICATE_FILE = local.certificate_file
      ## GKE
      SERVICE_ACCOUNT_CREDENTIALS = var.service_account_credentials
      ## EKS
      ACCESS_KEY_ID     = var.access_key_id
      SECRET_ACCESS_KEY = var.secret_access_key
      CLUSTER_REGION    = var.cluster_region
      ## ICP
      ICP_URL            = var.icp_url
      ICP_ADMIN_USER     = var.icp_admin_user
      ICP_ADMIN_PASSWORD = var.icp_admin_password
      ## OCP
      OCP_URL            = var.ocp_url
      OCP_OAUTH_URL      = var.ocp_oauth_url
      OCP_ADMIN_USER     = var.ocp_admin_user
      OCP_ADMIN_PASSWORD = var.ocp_admin_password
    }
  }
}

## Log generated credentials
resource "null_resource" "credentials-generated" {
  depends_on = [null_resource.generate-credentials]
  triggers = {
    trigger_time = timestamp()
  }
  provisioner "local-exec" {
    command = "cat ${local.credentials_file} | sed -e 's/token\":.*/token\": *****/'"
  }
}

