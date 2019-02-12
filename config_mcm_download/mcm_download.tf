locals {
   download_user    = "${var.download_user != "" ? "-u ${var.download_user}" : ""}"
   download_user_password    = "${var.download_user_password != "" ? "-p ${var.download_user_password}" : ""}"
}

resource "null_resource" "config_mcm_download_dependsOn" {
  provisioner "local-exec" {
# Hack to force dependencies to work correctly. Must use the dependsOn var somewhere in the code for dependencies to work. Contain value which comes from previous module.
	  command = "echo The dependsOn output for Config MCM Download is ${var.dependsOn}"
  }
}

resource "null_resource" "load_mcm_ppa_image" {
  depends_on = ["null_resource.config_mcm_download_dependsOn"]
  #count = "${length(var.master_ipv4_address_list)}"
  connection {
    type = "ssh"
    user = "${var.vm_os_user}"
    password =  "${var.vm_os_password}"
    private_key = "${length(var.private_key) > 0 ? base64decode(var.private_key) : ""}"
    #host = "${var.master_ipv4_address_list[count.index]}"
    host = "${var.master_ipv4_address}"
    bastion_host        = "${var.bastion_host}"
    bastion_user        = "${var.bastion_user}"
    bastion_private_key = "${length(var.bastion_private_key) > 0 ? base64decode(var.bastion_private_key) : var.bastion_private_key}"
    bastion_port        = "${var.bastion_port}"
    bastion_host_key    = "${var.bastion_host_key}"
    bastion_password    = "${var.bastion_password}"          
  }

  provisioner "file" {
    source = "${path.module}/scripts/download_mcm.sh"
    destination = "/tmp/download_mcm.sh"
  }

  provisioner "file" {
    source = "${path.module}/scripts/mcm_prereq.sh"
    destination = "/tmp/mcm_prereq.sh"
  }

  provisioner "file" {
    source = "${path.module}/scripts/mcm_install.sh"
    destination = "/tmp/mcm_install.sh"
  }

  provisioner "file" {
    when = "destroy"  
    source = "${path.module}/scripts/mcm_cleanup.sh"
    destination = "/tmp/mcm_cleanup.sh"
  }
  
  
    provisioner "remote-exec" {
    inline = [
    
      "mkdir -p /tmp/${var.random}",
      
      "chmod 755 /tmp/download_mcm.sh",
      "echo \"/tmp/download_mcm.sh -i ${var.mcm_binary_url} -t /tmp/${var.random} ${local.download_user} ${local.download_user_password}\"",
      "bash -c '/tmp/download_mcm.sh -i ${var.mcm_binary_url} -t /tmp/${var.random} ${local.download_user} ${local.download_user_password}'",

      "chmod 755 /tmp/mcm_prereq.sh",
      "echo /tmp/mcm_prereq.sh ${var.secret_name} ${var.cluster_ca_name} ${var.cluster_name} ${var.icp_user} ${var.icp_user_password}",
      "bash -c '/tmp/mcm_prereq.sh ${var.secret_name} ${var.cluster_ca_name} ${var.cluster_name} ${var.icp_user} ${var.icp_user_password}'",

      "chmod 755 /tmp/mcm_install.sh",
      "echo /tmp/mcm_install.sh  -u ${var.icp_user} -t /tmp/${var.random} -p ${var.icp_user_password} -a ${var.mcm_binary_url} -c ${var.cluster_ca_name} -n ${var.cluster_name}",
      "bash -c '/tmp/mcm_install.sh -u ${var.icp_user} -t /tmp/${var.random} -p ${var.icp_user_password} -a ${var.mcm_binary_url} -c ${var.cluster_ca_name} -n ${var.cluster_name}'"      
    ]
  }
  
  provisioner "remote-exec" {
    when = "destroy"
    inline = [
      "rm -rf /tmp/${var.random}/",   
      "chmod 755 /tmp/mcm_cleanup.sh",
      "echo /tmp/mcm_cleanup.sh ${var.secret_name} ${var.icp_user} ${var.icp_user_password} ${var.master_ipv4_address} ${var.cluster_name}",
      "bash -c '/tmp/mcm_cleanup.sh ${var.secret_name} ${var.icp_user} ${var.icp_user_password} ${var.master_ipv4_address} ${var.cluster_name}'"
    ]
  }
} 

resource "null_resource" "docker_install_finished" {
  depends_on = ["null_resource.load_mcm_ppa_image","null_resource.config_mcm_download_dependsOn"]
  provisioner "local-exec" {
    command = "echo 'Docker and mcm Images loaded, has been installed on Nodes'"
  }
}
