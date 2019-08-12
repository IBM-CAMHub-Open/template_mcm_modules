variable "kubernetes_service" {
  description = "Type of the Kubernetes Service"
}

variable "icp_url" {
  description = "URL, including port, for ICP server hosting the MCM hub cluster"
}

variable "icp_admin_user" {
  description = "User name for connecting to the ICP server"
}

variable "icp_admin_password" {
  description = "Password for connecting to the ICP server"
}

variable "mcm_hub_endpoint" {
  description = "API endpoint of MCM hub cluster"
}

variable "remove_or_delete" {
  description = "When deployment is destroyed, 'remove' or 'delete' kubernetes cluster from MCM hub-cluster"
  default = "remove"
}

variable "cluster_name" {
  description = "Name of the Kubernetes Service cluster"
  default = ""
}

variable "cluster_config" {
  description = "kubeconfig details for Kubernetes Service cluster"
  default = ""
}

variable "cluster_certificate_authority" {
  description = "Certificate for authenticating with Kubernetes Service cluster"
  default = ""
}

variable "cluster_region" {
  description = "The region in which the EKS cluster is deployed"
  default = ""
}

variable "service_account_credentials" {
  description = "Credentials for service account"
  default = ""
}

variable "access_key_id" {
  description = "Access key ID for authorizing with cloud and/or cluster"
  default = ""
}

variable "secret_access_key" {
  description = "Password/secret key for authorizing with cloud and/or cluster"
  default = ""
}
