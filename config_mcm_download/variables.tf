variable "vm_os_password"       { type = "string"  description = "Operating System Password for the Operating System User to access virtual machine"}
variable "vm_os_user"           { type = "string"  description = "Operating System user for the Operating System User to access virtual machine"}
variable "boot_ipv4_address"  { type="string"      description = "Master Node IPv4 Address's"}
variable "private_key"          { type = "string"  description = "Private SSH key Details to the Virtual machine"}
variable "random"               { type = "string"  description = "Random String Generated"}
variable "dependsOn"            { default = "true" description = "Boolean for dependency"}
variable "mcm_binary_url"       { type = "string"  description = "IBM Cloud Private mcm Download Location (http|https|ftp|file)"}
variable "icp_user"             { type = "string"  description = "IBM Cloud Private admin user use to load ppa package"}
variable "icp_user_password"    { type = "string"  description = "IBM Cloud Private admin user password"}
variable "cluster_ca_name"      { type = "string"  description = "Kubernetes CA domain of the cluster , like mycluster.icp "}
variable "cluster_docker_registry_server_name" { type = "string"  description = "ICP internal registry server name (usually deployed on the boot server), used for loading the MCM docker images into "}
variable "cluster_name"         { type = "string"  description = "Kubernetes cluster name, like mycluster "}
variable "secret_name"          { type = "string"  description = "MCM Kubelet secret"}
variable "download_user"        { type = "string"  description = "Repository User Name (Optional)" }    
variable "download_user_password"  { type = "string" description = "Repository User Password (Optional)"}  
