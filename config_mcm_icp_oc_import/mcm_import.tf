resource "null_resource" "mkdir-mcm-scripts" {
  connection {
    type = "ssh"
    user = "${var.vm_os_user}"
    password =  "${var.vm_os_password}"
    private_key = "${length(var.vm_os_private_key) > 0 ? base64decode(var.vm_os_private_key) : ""}"
    host = "${var.import_launch_node_ip}"
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

resource "null_resource" "import_icp" {
  depends_on = ["null_resource.mkdir-mcm-scripts"]
  connection {
    type = "ssh"
    user = "${var.vm_os_user}"
    password =  "${var.vm_os_password}"
    private_key = "${length(var.vm_os_private_key) > 0 ? base64decode(var.vm_os_private_key) : ""}"
    host = "${var.import_launch_node_ip}"
    bastion_host        = "${var.bastion_host}"
    bastion_user        = "${var.bastion_user}"
    bastion_private_key = "${length(var.bastion_private_key) > 0 ? base64decode(var.bastion_private_key) : var.bastion_private_key}"
    bastion_port        = "${var.bastion_port}"
    bastion_host_key    = "${var.bastion_host_key}"
    bastion_password    = "${var.bastion_password}"          
  }
  
  provisioner "file" {
    source = "${path.module}/scripts/mcm_import_prereq.sh"
    destination = "/var/lib/registry/mcm_scripts/mcm_import_prereq.sh"
  }

  provisioner "file" {
    source = "${path.module}/scripts/mcm_import.sh"
    destination = "/var/lib/registry/mcm_scripts/mcm_import.sh"
  }
  
  provisioner "file" {
    source = "${path.module}/scripts/mcm_cleanup.sh"
    destination = "/var/lib/registry/mcm_scripts/mcm_cleanup.sh"
  }      

  provisioner "remote-exec" {
    inline = [    
      "chmod 755 /var/lib/registry/mcm_scripts/mcm_import_prereq.sh",
      "echo /var/lib/registry/mcm_scripts/mcm_import_prereq.sh -c ${var.cluster_name} -h ${var.icp_server_url}",
      #"bash -c '/var/lib/registry/mcm_scripts/mcm_import_prereq.sh -c ${var.cluster_name} -h ${var.icp_server_url} -kc ${var.cluster_config} -kk  ${var.cluster_certificate_authority}'",
      "bash -c '/var/lib/registry/mcm_scripts/mcm_import_prereq.sh -c ${var.cluster_name} -h ${var.icp_server_url}'",
      
      "chmod 755 /var/lib/registry/mcm_scripts/mcm_import.sh",
      "echo /var/lib/registry/mcm_scripts/mcm_import.sh -ocpu ${var.ocp_admin_user} -ru ${var.rhsm_user} -osu ${var.ocp_server_url} -rh ${var.cluster_docker_registry_server_name} -rp ${var.cluster_docker_registry_server_port} -ri ${var.cluster_docker_registry_server_ip} -cm ${var.cluster_name} -pa ${var.icp_dir} -hs ${var.mcm_controller_server_name} -hu ${var.mcm_controller_admin_user} -mch ${var.man_cluster_on_hub} -icpu ${var.icp_admin_user} -v ${var.icp_inception_image} -s ${var.icp_server_url}",
      #"bash -c '/var/lib/registry/mcm_scripts/mcm_import.sh -hs ${var.mcm_controller_server_name} -hp ${var.mcm_controller_admin_user_password} -hu ${var.mcm_controller_admin_user} -mch ${var.man_cluster_on_hub} -u ${var.admin_user} -ru ${var.rhsm_user} -rp ${var.rhsm_password} -kc ${var.cluster_config} -kk ${var.cluster_certificate_authority}'"
      "bash -c '/var/lib/registry/mcm_scripts/mcm_import.sh -a ${var.ocp_admin_user} -b ${var.rhsm_user} -c ${var.rhsm_password} -d ${var.ocp_server_url} -e ${var.ocp_admin_pass} -f ${var.cluster_docker_registry_server_ip} -g ${var.cluster_docker_registry_server_ca_crt} -h ${var.cluster_docker_registry_server_name} -i ${var.cluster_docker_registry_server_port} -j ${var.cluster_name} -k ${var.icp_dir} -l ${var.mcm_controller_server_name} -m ${var.mcm_controller_admin_user_password} -n ${var.mcm_controller_admin_user} -o ${var.man_cluster_on_hub} -p ${var.icp_admin_user} -q ${var.icp_admin_pass} -r ${var.icp_server_url} -s ${var.icp_inception_image}'"      
            
      #"echo /var/lib/registry/mcm_scripts/mcm_import.sh -hs ${var.mcm_controller_server_name} -hu ${var.mcm_controller_admin_user} -mch ${var.man_cluster_on_hub} -u ${var.admin_user} -ru ${var.rhsm_user} -mcc ${var.managed_cluster_cloud} -mcv ${var.managed_cluster_kube_vendor} -mce ${var.managed_cluster_environment} -mcr ${var.managed_cluster_region} -mcd ${var.managed_cluster_datacenter} -mco ${var.managed_cluster_owner}",
      #"bash -c '/var/lib/registry/mcm_scripts/mcm_import.sh -hs ${var.mcm_controller_server_name} -hp ${var.mcm_controller_admin_user_password} -hu ${var.mcm_controller_admin_user} -mch ${var.man_cluster_on_hub} -u ${var.admin_user} -ru ${var.rhsm_user} -rp ${var.rhsm_password} -mcc ${var.managed_cluster_cloud} -mcv ${var.managed_cluster_kube_vendor} -mce ${var.managed_cluster_environment} -mcr ${var.managed_cluster_region} -mcd ${var.managed_cluster_datacenter} -mco ${var.managed_cluster_owner} -kc ${var.cluster_config} -kk ${var.cluster_certificate_authority}'"
    ]
  }
  
  provisioner "remote-exec" {
    when = "destroy"
    inline = [  
      "chmod 755 /var/lib/registry/mcm_scripts/mcm_cleanup.sh",
      "echo /var/lib/registry/mcm_scripts/mcm_cleanup.sh -cm ${var.cluster_name} -hs ${var.mcm_controller_server_name} -hu ${var.mcm_controller_admin_user} -mch ${var.man_cluster_on_hub} -u ${var.icp_admin_user} -s ${var.icp_server_url} -pa ${var.icp_dir} ",
      "bash -c '/var/lib/registry/mcm_scripts/mcm_cleanup.sh -cm ${var.cluster_name} -hs ${var.mcm_controller_server_name} -hp ${var.mcm_controller_admin_user_password} -hu ${var.mcm_controller_admin_user} -mch ${var.man_cluster_on_hub} -u ${var.icp_admin_user} -pw ${var.icp_admin_pass} -s ${var.icp_server_url} -pa ${var.icp_dir}'"      
    ]
  }
}

resource "camc_scriptpackage" "get_cluster_import_yaml" {
 	depends_on = ["null_resource.import_icp"]	
  	program = ["sudo", "cat", "/var/lib/registry/mcm_scripts/cluster-import.yaml", "|", "base64", "-w0"]
  	on_create = true
  	remote_host = "${var.import_launch_node_ip}"
  	remote_user = "${var.vm_os_user}"
  	remote_password = "${var.vm_os_password}"
  	remote_key = "${length(var.vm_os_private_key) > 0 ? var.vm_os_private_key : ""}"
    bastion_host        = "${var.bastion_host}"
    bastion_user        = "${var.bastion_user}"
    bastion_private_key = "${var.bastion_private_key}"
    bastion_port        = "${var.bastion_port}"
    bastion_password    = "${var.bastion_password}"            	
}