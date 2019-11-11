output "cluster_import_yaml"{
  value = "${camc_scriptpackage.get_cluster_import_yaml.result["stdout"]}"
} 