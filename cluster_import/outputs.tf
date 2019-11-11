output "cluster_managed" {
  description = "Indicates completion of module"
  value       = "${null_resource.manage-cluster.id}"
}