resource "null_resource" "wait-for-prerequisite" {
  ## Trigger renewal of resource to allow for changes in prerequisite module
  triggers {
    trigger_time = "${timestamp()}"
  }
  provisioner "local-exec" {
    ## Use the 'dependsOn var, set within prerequisite module, to force dependency to work.
    command = "echo Completed prerequisite ${var.dependsOn}"
  }
}

resource "null_resource" "manage-cluster" {

  depends_on = ["null_resource.wait-for-prerequisite"]

  provisioner "local-exec" {
    command = "chmod 755 ${path.module}/scripts/manage_target_cluster.sh && ${path.module}/scripts/manage_target_cluster.sh -ac import -wd ${var.work_directory}"
    environment {
      ## Required
      CLUSTER_NAME                = "${var.cluster_name}"
      HUB_URL                     = "${var.mcm_url}"
      HUB_ADMIN_USER              = "${var.mcm_admin_user}"
      HUB_ADMIN_PASSWORD          = "${var.mcm_admin_password}"

      ## Cluster details
      CLUSTER_NAMESPACE           = "${var.cluster_namespace}"
      CLUSTER_ENDPOINT            = "${var.cluster_endpoint}"
      CLUSTER_USER                = "${var.cluster_user}"
      CLUSTER_TOKEN               = "${var.cluster_token}"
      CLUSTER_CREDENTIALS         = "${var.cluster_credentials}"

      ## Private docker registry
      IMAGE_REGISTRY              = "${var.image_registry}"
      IMAGE_SUFFIX                = "${var.image_suffix}"
      IMAGE_VERSION               = "${var.image_version}"
      DOCKER_USER                 = "${var.docker_user}"
      DOCKER_PASSWORD             = "${var.docker_password}"
    }
  }
  
  provisioner "local-exec" {
    when    = "destroy"
    command = "chmod 755 ${path.module}/scripts/manage_target_cluster.sh && ${path.module}/scripts/manage_target_cluster.sh -ac remove -wd ${var.work_directory}"
    environment {
      ## Required
      CLUSTER_NAME                = "${var.cluster_name}"
      CLUSTER_NAMESPACE           = "${var.cluster_namespace}"	    
      HUB_URL                     = "${var.mcm_url}"
      HUB_ADMIN_USER              = "${var.mcm_admin_user}"
      HUB_ADMIN_PASSWORD          = "${var.mcm_admin_password}"
    }
  }
}
