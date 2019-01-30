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

resource "null_resource" "mkdir-boot-node" {
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
    provisioner "remote-exec" {
    inline = [
      "mkdir -p ~/ibm-mcm-${var.mcm_version}"
    ]
  }
}

resource "null_resource" "download_mcm_ppa_images" {
  depends_on = ["null_resource.mkdir-boot-node",]

  #count = "${ length(var.master_ipv4_address_list) > 0 ? length(var.master_ipv4_address_list) : 0}"
  connection {
    type = "ssh"
    user = "${var.vm_os_user}"
    password =  "${var.vm_os_password}"
    private_key = "${length(var.private_key) > 0 ? base64decode(var.private_key) : ""}"
    #host = "${var.master_ipv4_address_list[count.index]}"
    host = "${var.master_ipv4_address}"
    bastion_host        = "${var.bastion_host}"
    bastion_user        = "${var.bastion_user}"
    bastion_private_key = "${ length(var.bastion_private_key) > 0 ? base64decode(var.bastion_private_key) : var.bastion_private_key}"
    bastion_port        = "${var.bastion_port}"
    bastion_host_key    = "${var.bastion_host_key}"
    bastion_password    = "${var.bastion_password}"          
  }
  
  provisioner "file" {
    source = "${path.module}/scripts/download_mcm.sh"
    destination = "~/ibm-mcm-${var.mcm_version}/download_mcm.sh"
  }
  
  provisioner "remote-exec" {
    inline = [
      "chmod 755 ~/ibm-mcm-${var.mcm_version}/download_mcm.sh",
      "echo \"~/ibm-mcm-${var.mcm_version}/download_mcm.sh -i ${var.mcm_binary_url} -v ${var.mcm_version} ${local.download_user} ${local.download_user_password}\"",
      "bash -c '~/ibm-mcm-${var.mcm_version}/download_mcm.sh -i ${var.mcm_binary_url} -v ${var.mcm_version} ${local.download_user} ${local.download_user_password}'"
      # "tar -xf  ibm-mcm-${var.mcm_Version}.tar.gz -O | sudo docker load",
      # "docker run -v $(pwd):/data -e LICENSE=accept ibmcom/mcm-inception:${var.mcm_Version}-ee cp -r cluster /data",
      # "mkdir -p cluster/images; mv ibm-mcm-${var.mcm_Version}.tar.gz cluster/images/"
    ]
  }
}

resource "null_resource" "prep_mcm" {
  depends_on = ["null_resource.mkdir-boot-node", "null_resource.download_mcm_ppa_images"]

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
    bastion_private_key = "${ length(var.bastion_private_key) > 0 ? base64decode(var.bastion_private_key) : var.bastion_private_key}"
    bastion_port        = "${var.bastion_port}"
    bastion_host_key    = "${var.bastion_host_key}"
    bastion_password    = "${var.bastion_password}"          
  }
  provisioner "file" {
    source = "${path.module}/scripts/mcm_prereq.sh"
    destination = "~/ibm-mcm-${var.mcm_version}/mcm_prereq.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod 755 ~/ibm-mcm-${var.mcm_version}/mcm_prereq.sh",
      "echo ~/ibm-mcm-${var.mcm_version}/mcm_prereq.sh ${var.secret_name} ${var.cluster_name} ${var.icp_user} ${var.icp_user_password} ${var.master_ipv4_address} ${var.icp_version}",
      "bash -c '~/ibm-mcm-${var.mcm_version}/mcm_prereq.sh ${var.secret_name} ${var.cluster_name} ${var.icp_user} ${var.icp_user_password} ${var.master_ipv4_address} ${var.icp_version}'"
    ]
  }
}

resource "null_resource" "load_mcm_ppa_image" {
  depends_on = ["null_resource.mkdir-boot-node", "null_resource.prep_mcm"]

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
    bastion_private_key = "${ length(var.bastion_private_key) > 0 ? base64decode(var.bastion_private_key) : var.bastion_private_key}"
    bastion_port        = "${var.bastion_port}"
    bastion_host_key    = "${var.bastion_host_key}"
    bastion_password    = "${var.bastion_password}"          
  }
  provisioner "file" {
    source = "${path.module}/scripts/mcm_install.sh"
    destination = "~/ibm-mcm-${var.mcm_version}/mcm_install.sh"
  }

  provisioner "file" {
    source = "${path.module}/scripts/mcm_cleanup.sh"
    destination = "~/ibm-mcm-${var.mcm_version}/mcm_cleanup.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod 755 ~/ibm-mcm-${var.mcm_version}/mcm_install.sh",
      "echo ~/ibm-mcm-${var.mcm_version}/mcm_install.sh  -v ${var.mcm_version} -u ${var.icp_user} -p ${var.icp_user_password} -a ${var.mcm_binary_url} -c ${var.cluster_name} -m ${var.master_ipv4_address}",
      "bash -c '~/ibm-mcm-${var.mcm_version}/mcm_install.sh -v ${var.mcm_version} -u ${var.icp_user} -p ${var.icp_user_password} -a ${var.mcm_binary_url} -c ${var.cluster_name} -m ${var.master_ipv4_address}'"
    ]
  }

  provisioner "remote-exec" {
    when = "destroy"
    inline = [
      "chmod 755 ~/ibm-mcm-${var.mcm_version}/mcm_cleanup.sh",
      "echo ~/ibm-mcm-${var.mcm_version}/mcm_cleanup.sh ${var.secret_name} ${var.icp_user} ${var.icp_user_password} ${var.master_ipv4_address} ${var.icp_version} ${var.cluster_name}",
      "bash -c '~/ibm-mcm-${var.mcm_version}/mcm_cleanup.sh ${var.secret_name} ${var.icp_user} ${var.icp_user_password} ${var.master_ipv4_address} ${var.icp_version} ${var.cluster_name}'"
    ]
  }
}

resource "null_resource" "docker_install_finished" {
  depends_on = ["null_resource.load_mcm_ppa_image","null_resource.config_mcm_download_dependsOn","null_resource.download_mcm_ppa_images","null_resource.mkdir-boot-node"]
  provisioner "local-exec" {
    command = "echo 'Docker and mcm Images loaded, has been installed on Nodes'"
  }
}
