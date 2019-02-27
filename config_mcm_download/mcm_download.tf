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

resource "null_resource" "mkdir-mcm-scripts" {
  depends_on = ["null_resource.config_mcm_download_dependsOn"]
  connection {
    type = "ssh"
    user = "${var.vm_os_user}"
    password =  "${var.vm_os_password}"
    private_key = "${length(var.private_key) > 0 ? base64decode(var.private_key) : ""}"
    host = "${var.boot_ipv4_address}"
    bastion_host        = "${var.bastion_host}"
    bastion_user        = "${var.bastion_user}"
    bastion_private_key = "${length(var.bastion_private_key) > 0 ? base64decode(var.bastion_private_key) : var.bastion_private_key}"
    bastion_port        = "${var.bastion_port}"
    bastion_host_key    = "${var.bastion_host_key}"
    bastion_password    = "${var.bastion_password}"          
  }
    provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p /var/lib/registry/mcm_scripts",
      "sudo chown $(whoami) /var/lib/registry/mcm_scripts"
    ]
  }
}

resource "null_resource" "load_mcm_ppa_image" {
  depends_on = ["null_resource.config_mcm_download_dependsOn", "null_resource.mkdir-mcm-scripts"]
  connection {
    type = "ssh"
    user = "${var.vm_os_user}"
    password =  "${var.vm_os_password}"
    private_key = "${length(var.private_key) > 0 ? base64decode(var.private_key) : ""}"
    host = "${var.boot_ipv4_address}"
    bastion_host        = "${var.bastion_host}"
    bastion_user        = "${var.bastion_user}"
    bastion_private_key = "${length(var.bastion_private_key) > 0 ? base64decode(var.bastion_private_key) : var.bastion_private_key}"
    bastion_port        = "${var.bastion_port}"
    bastion_host_key    = "${var.bastion_host_key}"
    bastion_password    = "${var.bastion_password}"          
  }

  provisioner "file" {
    source = "${path.module}/scripts/download_mcm.sh"
    destination = "/var/lib/registry/mcm_scripts/download_mcm.sh"
  }

  provisioner "file" {
    source = "${path.module}/scripts/mcm_prereq.sh"
    destination = "/var/lib/registry/mcm_scripts/mcm_prereq.sh"
  }

  provisioner "file" {
    source = "${path.module}/scripts/mcm_install.sh"
    destination = "/var/lib/registry/mcm_scripts/mcm_install.sh"
  }

  provisioner "file" {
    source = "${path.module}/scripts/mcm_namespace.json"
    destination = "/var/lib/registry/mcm_scripts/mcm_namespace.json"
  }

  provisioner "file" {
    when = "destroy"  
    source = "${path.module}/scripts/mcm_cleanup.sh"
    destination = "/var/lib/registry/mcm_scripts/mcm_cleanup.sh"
  }
  
  
    provisioner "remote-exec" {
    inline = [
    
      "sudo mkdir -p /var/lib/registry/mcm_scripts/${var.random}",
      "sudo chown $(whoami) /var/lib/registry/mcm_scripts/${var.random}",      
      
      "chmod 755 /var/lib/registry/mcm_scripts/download_mcm.sh",
      "echo \"/var/lib/registry/mcm_scripts/download_mcm.sh -i ${var.mcm_binary_url} -t /var/lib/registry/mcm_scripts/${var.random} ${local.download_user} ${local.download_user_password}\"",
      "bash -c '/var/lib/registry/mcm_scripts/download_mcm.sh -i ${var.mcm_binary_url} -t /var/lib/registry/mcm_scripts/${var.random} ${local.download_user} ${local.download_user_password}'",

      "chmod 755 /var/lib/registry/mcm_scripts/mcm_prereq.sh",
      "echo /var/lib/registry/mcm_scripts/mcm_prereq.sh ${var.secret_name} ${var.cluster_ca_name} ${var.cluster_name} ${var.icp_user} ${var.icp_user_password}",
      "bash -c '/var/lib/registry/mcm_scripts/mcm_prereq.sh ${var.secret_name} ${var.cluster_ca_name} ${var.cluster_name} ${var.icp_user} ${var.icp_user_password}'",

      "chmod 755 /var/lib/registry/mcm_scripts/mcm_install.sh",
      "echo /var/lib/registry/mcm_scripts/mcm_install.sh  -u ${var.icp_user} -t /var/lib/registry/mcm_scripts/${var.random} -p ${var.icp_user_password} -a ${var.mcm_binary_url} -c ${var.cluster_ca_name} -n ${var.cluster_name} -r ${var.cluster_docker_registry_server_name}",
      "bash -c '/var/lib/registry/mcm_scripts/mcm_install.sh -u ${var.icp_user} -t /var/lib/registry/mcm_scripts/${var.random} -p ${var.icp_user_password} -a ${var.mcm_binary_url} -c ${var.cluster_ca_name} -n ${var.cluster_name} -r ${var.cluster_docker_registry_server_name}'"
    ]
  }
  
  provisioner "remote-exec" {
    when = "destroy"
    inline = [
      "sudo rm -rf /var/lib/registry/mcm_scripts/${var.random}/",   
      "chmod 755 /var/lib/registry/mcm_scripts/mcm_cleanup.sh",
       "echo /var/lib/registry/mcm_scripts/mcm_cleanup.sh ${var.secret_name} ${var.icp_user} ${var.icp_user_password} ${var.cluster_ca_name} ${var.cluster_name}",
      "bash -c '/var/lib/registry/mcm_scripts/mcm_cleanup.sh ${var.secret_name} ${var.icp_user} ${var.icp_user_password} ${var.cluster_ca_name} ${var.cluster_name}'"
    ]
  }
} 

resource "null_resource" "docker_install_finished" {
  depends_on = ["null_resource.load_mcm_ppa_image","null_resource.config_mcm_download_dependsOn", "null_resource.mkdir-mcm-scripts"]
  provisioner "local-exec" {
    command = "echo 'Docker and mcm Images loaded, has been installed on Nodes'"
  }
}
