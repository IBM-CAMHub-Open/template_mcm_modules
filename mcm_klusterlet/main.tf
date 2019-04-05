## Generate unique ID for temporary work directory on docker host
resource "random_string" "random-dir" {
  length  = 8
  special = false
}


## Set up local variables to be used
locals {
  work_dir = "/tmp/mcm${random_string.random-dir.result}"
  kubeconfig_data  = "${length(var.cluster_config) > 0 ? base64decode(var.cluster_config) : var.cluster_config}"
  certificate_data = "${length(var.cluster_certificate_authority) > 0 ? base64decode(var.cluster_certificate_authority) : var.cluster_certificate_authority}"
  account_key = "${length(var.service_account_key) > 0 ? base64decode(var.service_account_key) : var.service_account_key}"
  mcm_version = "${var.mcm_version}"
}


resource "null_resource" "manage-klusterlet" {
  connection {
    type        = "ssh"
    host        = "${var.docker_host}"
    user        = "${var.user_name}"
    private_key = "${length(var.private_key) > 0 ? base64decode(var.private_key) : var.private_key}"
    bastion_host        = "${var.bastion_host}"
    bastion_user        = "${var.bastion_user}"
    bastion_private_key = "${ length(var.bastion_private_key) > 0 ? base64decode(var.bastion_private_key) : var.bastion_private_key}"
    bastion_port        = "${var.bastion_port}"
    bastion_host_key    = "${var.bastion_host_key}"
    bastion_password    = "${var.bastion_password}" 
  }

  provisioner "remote-exec" {
    inline = [
      "mkdir -p ${local.work_dir}"
    ]
  } 
  provisioner "remote-exec" {
    when   = "destroy"
    inline = [
      "mkdir -p ${local.work_dir}"
    ]
  } 

  provisioner "file" {
    source      = "${path.module}/scripts/manage_klusterlet.sh"
    destination = "${local.work_dir}/installKlusterlet.sh"
  }
  provisioner "file" {
    when        = "destroy"
    source      = "${path.module}/scripts/manage_klusterlet.sh"
    destination = "${local.work_dir}/uninstallKlusterlet.sh"
  }


  provisioner "file" {
    destination = "${local.work_dir}/details.txt"
    content     = <<EOF
<KUBECONFIG>
${local.kubeconfig_data}
</KUBECONFIG>
<MCMENDPOINT>
${var.mcm_hub_endpoint}
</MCMENDPOINT>
<MCMTOKEN>
${var.mcm_hub_token}
</MCMTOKEN>
<CACERTIFICATE>
${local.certificate_data}
</CACERTIFICATE>
<LOCATION>
${var.cluster_location}
</LOCATION>
<PROJECT>
${var.cluster_project}
</PROJECT>
<ACCOUNTKEY>
${local.account_key}
</ACCOUNTKEY>
<CREDENTIALS>
${var.access_key_id};${var.access_key_secret}
</CREDENTIALS>
EOF
  }
  
  provisioner "file" {
    when        = "destroy"
    destination = "${local.work_dir}/details.txt"
    content     = <<EOF
<KUBECONFIG>
${local.kubeconfig_data}
</KUBECONFIG>
<MCMENDPOINT>
${var.mcm_hub_endpoint}
</MCMENDPOINT>
<MCMTOKEN>
${var.mcm_hub_token}
</MCMTOKEN>
<CACERTIFICATE>
${local.certificate_data}
</CACERTIFICATE>
<LOCATION>
${var.cluster_location}
</LOCATION>
<PROJECT>
${var.cluster_project}
</PROJECT>
<ACCOUNTKEY>
${local.account_key}
</ACCOUNTKEY>
<CREDENTIALS>
${var.access_key_id};${var.access_key_secret}
</CREDENTIALS>
EOF
  }


  provisioner "remote-exec" {
    inline = [
      "set -e",
      "sudo chmod 755 ${local.work_dir}/installKlusterlet.sh",
      "sudo ${local.work_dir}/installKlusterlet.sh -a install -m ${local.mcm_version} -s ${var.kubernetes_service} -w ${local.work_dir} -c ${var.cluster_name}",
      "sudo rm -rf ${local.work_dir}"
    ]
  }

  provisioner "remote-exec" {
    when   = "destroy"
    inline = [
      "set -e",
      "chmod 755 ${local.work_dir}/uninstallKlusterlet.sh",
      "sudo ${local.work_dir}/uninstallKlusterlet.sh -a uninstall -m ${local.mcm_version} -s ${var.kubernetes_service} -w ${local.work_dir} -c ${var.cluster_name}",
      "sudo rm -rf ${local.work_dir}"
    ]
  }
}
