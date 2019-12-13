variable "cluster_type" {
  description = "Type of the Kubernetes cluster to be targeted (e.g. icp, ocp, iks, aks, gke, eks)"
}

variable "icp_url" {
  description = "URL, including port, for ICP server"
  default = ""
}

variable "icp_admin_user" {
  description = "User name for connecting to the ICP server"
  default = ""
}

variable "icp_admin_password" {
  description = "Password for connecting to the ICP server"
  default = ""
}

variable "cluster_name" {
  description = "Name of the Kubernetes cluster"
  default = ""
}

variable "cluster_config" {
  description = "kubeconfig file contents (Base64 encoded) for Kubernetes cluster"
  default = ""
}

variable "cluster_certificate_authority" {
  description = "Certificate for authenticating with Kubernetes cluster"
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

variable "ocp_url" {
  description = "URL, including port, for OCP server"
  default = ""
}

variable "ocp_oauth_url" {
  description = "URL, including port, for OCP OAUTH server"
  default = ""
}

variable "ocp_admin_user" {
  description = "User name for connecting to the OCP server"
  default = ""
}

variable "ocp_admin_password" {
  description = "Password for connecting to the OCP server"
  default = ""
}

variable "work_directory" {
  description = "Path of the temporary directory where work files will be generated"
  default = ""
}