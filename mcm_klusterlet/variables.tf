variable "kubernetes_service" {
  description = "Type of the Kubernetes Service"
}

variable "docker_host" {
  description = "Docker host IP"
}

variable "user_name" {
  description = "User name"
}

variable "private_key" {
  description = "Private ssh key"
}

variable "mcm_hub_endpoint" {
  description = "API endpoint of MCM hub cluster"
}

variable "mcm_hub_token" {
  description = "Authentication token for MCM hub cluster API endpoint"
}

variable "mcm_version" {
  description = "MCM klusterlet version"
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

variable "cluster_location" {
  description = "Location where Kubernetes Service cluster is deployed"
  default = ""
}

variable "cluster_project" {
  description = "Cloud project in which Kubernetes Service cluster is deployed"
  default = ""
}

variable "service_account_key" {
  description = "Key for service account with admin privileges to Kubernetes Service cluster"
  default = ""
}

variable "access_key_id" {
  description = "Key ID for gaining access to the cloud and Kubernetes Service cluster"
  default = ""
}

variable "access_key_secret" {
  description = "Key secret for gaining access to the cloud and Kubernetes Service cluster"
  default = ""
}