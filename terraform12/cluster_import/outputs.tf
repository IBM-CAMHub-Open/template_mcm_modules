output "cluster_imported" {
  description = "Indicates completion of module"
  value       = null_resource.import-cluster.id
}

output "cluster_removed" {
  description = "Indicates completion of module"
  value       = null_resource.remove-cluster.id
}

