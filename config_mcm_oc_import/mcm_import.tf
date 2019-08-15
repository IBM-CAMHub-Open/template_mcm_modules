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

resource "null_resource" "import_oc" {
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
      "echo /var/lib/registry/mcm_scripts/mcm_import_prereq.sh -ru ${var.rhsm_user} -rp ${var.rhsm_password} -hs ${var.mcm_controller_server_name}",
      #"bash -c '/var/lib/registry/mcm_scripts/mcm_import_prereq.sh -ru ${var.rhsm_user} -rp ${var.rhsm_password} -hs ${var.mcm_controller_server_name} -kc ${var.cluster_config} -kk  ${var.cluster_certificate_authority}'",
      "bash -c '/var/lib/registry/mcm_scripts/mcm_import_prereq.sh -ru ${var.rhsm_user} -rp ${var.rhsm_password} -hs ${var.mcm_controller_server_name}'",
      
      "chmod 755 /var/lib/registry/mcm_scripts/mcm_import.sh",
      "echo /var/lib/registry/mcm_scripts/mcm_import.sh -hs ${var.mcm_controller_server_name} -hu ${var.mcm_controller_admin_user} -mch ${var.man_cluster_on_hub} -u ${var.admin_user} -ru ${var.rhsm_user} -osu ${var.ocp_server_url}",
      #"bash -c '/var/lib/registry/mcm_scripts/mcm_import.sh -hs ${var.mcm_controller_server_name} -hp ${var.mcm_controller_admin_user_password} -hu ${var.mcm_controller_admin_user} -mch ${var.man_cluster_on_hub} -u ${var.admin_user} -ru ${var.rhsm_user} -rp ${var.rhsm_password} -kc ${var.cluster_config} -kk ${var.cluster_certificate_authority}'"
      "bash -c '/var/lib/registry/mcm_scripts/mcm_import.sh -hs ${var.mcm_controller_server_name} -hp ${var.mcm_controller_admin_user_password} -hu ${var.mcm_controller_admin_user} -mch ${var.man_cluster_on_hub} -u ${var.admin_user} -ru ${var.rhsm_user} -rp ${var.rhsm_password} -osu ${var.ocp_server_url} -p ${var.admin_pass}'"      
            
      #"echo /var/lib/registry/mcm_scripts/mcm_import.sh -hs ${var.mcm_controller_server_name} -hu ${var.mcm_controller_admin_user} -mch ${var.man_cluster_on_hub} -u ${var.admin_user} -ru ${var.rhsm_user} -mcc ${var.managed_cluster_cloud} -mcv ${var.managed_cluster_kube_vendor} -mce ${var.managed_cluster_environment} -mcr ${var.managed_cluster_region} -mcd ${var.managed_cluster_datacenter} -mco ${var.managed_cluster_owner}",
      #"bash -c '/var/lib/registry/mcm_scripts/mcm_import.sh -hs ${var.mcm_controller_server_name} -hp ${var.mcm_controller_admin_user_password} -hu ${var.mcm_controller_admin_user} -mch ${var.man_cluster_on_hub} -u ${var.admin_user} -ru ${var.rhsm_user} -rp ${var.rhsm_password} -mcc ${var.managed_cluster_cloud} -mcv ${var.managed_cluster_kube_vendor} -mce ${var.managed_cluster_environment} -mcr ${var.managed_cluster_region} -mcd ${var.managed_cluster_datacenter} -mco ${var.managed_cluster_owner} -kc ${var.cluster_config} -kk ${var.cluster_certificate_authority}'"
    ]
  }
  
  provisioner "remote-exec" {
    when = "destroy"
    inline = [  
      "chmod 755 /var/lib/registry/mcm_scripts/mcm_cleanup.sh",
      "echo /var/lib/registry/mcm_scripts/mcm_cleanup.sh -hs ${var.mcm_controller_server_name} -hu ${var.mcm_controller_admin_user} -mch ${var.man_cluster_on_hub} -ru ${var.rhsm_user} -u ${var.admin_user} -osu ${var.ocp_server_url}",
      #"bash -c '/var/lib/registry/mcm_scripts/mcm_cleanup.sh -hs ${var.mcm_controller_server_name} -hp ${var.mcm_controller_admin_user_password} -hu ${var.mcm_controller_admin_user} -mch ${var.man_cluster_on_hub} -ru ${var.rhsm_user} -rp ${var.rhsm_password} -kc ${var.cluster_config} -kk ${var.cluster_certificate_authority}'"
	  "bash -c '/var/lib/registry/mcm_scripts/mcm_cleanup.sh -hs ${var.mcm_controller_server_name} -hp ${var.mcm_controller_admin_user_password} -hu ${var.mcm_controller_admin_user} -mch ${var.man_cluster_on_hub} -ru ${var.rhsm_user} -rp ${var.rhsm_password} -osu ${var.ocp_server_url} -p ${var.admin_pass} -u ${var.admin_user}'"      
    ]
  }
}


