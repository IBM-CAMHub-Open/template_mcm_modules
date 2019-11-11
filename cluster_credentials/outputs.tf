output "credentials_jsonfile" {
  description = "JSON-formatted file containing the cluster name, endpoint, user and token information used to access the cluster"
  value       = "${local.credentials_file}"
}

output "credentials_generated" {
  description = "Indicates completion of module"
  value       = "${null_resource.credentials-generated.id}"
}