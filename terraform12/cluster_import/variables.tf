variable "dependsOn" {
  description = "Variable to force dependency between modules"
  default     = "true"
}

variable "mcm_url" {
  description = "URL, including port, for the IBM CP4MCM hub cluster"
}

variable "mcm_admin_user" {
  description = "User name for connecting to the IBM CP4MCM server"
}

variable "mcm_admin_password" {
  description = "Password for connecting to the IBM CP4MCM server"
}

variable "cluster_name" {
  description = "Name of the Kubernetes cluster"
  default     = ""
}

variable "cluster_namespace" {
  description = "Namespace on the hub cluster into which the target cluster will be imported"
  default     = ""
}

variable "cluster_endpoint" {
  description = "URL for the Kubernetes cluster endpoint"
  default     = ""
}

variable "cluster_user" {
  description = "Username for accessing the Kubernetes cluster"
  default     = ""
}

variable "cluster_token" {
  description = "Token for authenticating with the Kubernetes cluster"
  default     = ""
}

variable "cluster_credentials" {
  description = "JSON-formatted file containing the cluster name, endpoint, user and token information"
  default     = ""
}

variable "image_registry" {
  description = "URL for private docker registry from which klusterlet images will be pulled"
  default     = ""
}

variable "image_suffix" {
  description = "Suffix (e.g. platform type) to be appended to image name"
  default     = ""
}

variable "image_version" {
  description = "Version (tag) of the IBM CP4MCM image to be pulled"
  default     = ""
}

variable "docker_user" {
  description = "Username for authenticating with the private docker registry"
  default     = ""
}

variable "docker_password" {
  description = "Password for authenticating with the private docker registry"
  default     = ""
}

variable "work_directory" {
  description = "Path of the temporary directory where work files will be generated"
  default     = ""
}

