# Modules for IBM Multicloud Manager Klusterlet on IBM Cloud Private
Copyright IBM Corp. 2019, 2019 \
This code is released under the Apache 2.0 License.

## Overview
 This terraform template module contains scripts that imports an existing IBM Cloud Private cluster to a IBM Multicloud Manager Controller (Hub Cluster).

## Prerequisites
* An existing IBM Cloud Private cluster.
* An existing IBM Multicloud Manager Controller.
* A VM to execute import command to import ICP to IBM MCM Controller.

## Automation summary
The terraform template module performs the following activities:
* connects to the provided VM node and installs the kubectl, cloudctl and docker if not present 
* Sets up the kubernetes configuration for target ICP managed cluster and IBM MCM Controller
* runs the `cloudctl mc import` command to import the target ICP managed cluster to the IBM Multicloud Manager Hub

## Template variables
Template Variable Name                                        | Parameter description
------------------------------------------------------|------------------------------------------------------------------
import_launch_node_ip| IP address of the node to execute import of a ICP cluster to IBM MCM Controller. This can be ICP boot node.
vm_os_user | The user name to connect to the import launch node.
vm_os_password (optional)| Base64 encoded private SSH key to connect to the import launch node. Either the password or the private key should be provided.
vm_os_private_key (optional)| The user password to connect to the import launch node. Either the password or the private key should be provided.
cluster_name| IBM Cloud Private Cluster Name on managed cluster.
admin_user| Managed ICP cluster administrator user name.
admin_user_password| Managed ICP administrator password.
icp_server_url | ICP server URL for managed cluster.
icp_inception_image | Name of the bootstrap installation image on managed cluster. Default is ibmcom/icp-inception-amd64:3.2.0-ee.
icp_dir | Provide ICP Install Directory of managed cluster if the import launch node is boot or boot master node. If this value is not provided, config.yaml file used for installation would not be updated.
man_cluster_on_hub  | Name that will be used to identify the managed ICP cluster on target IBM MCM Controller. If not provided a name would be generated based on cluster name.
cluster_config | Base64 encoded Kubernetes config details for managed cluster
cluster_certificate_authority (optional) | Base64 encoded ertificate for authenticating with managed cluster
mcm_controllerserver_name | Server name of a IBM MCM Controller to register the managed OpenShift cluster.
mcm_controlleradmin_user | IBM MCM Controller administrator user name.
mcm_controlleradmin_user_password | IBM MCM Controller administrator password.
cluster_docker_registry_server_name | ICP Docker registry server name
cluster_docker_registry_server_ip | ICP Docker registry server IP
cluster_docker_registry_server_port | ICP Docker registry server port
cluster_docker_registry_server_ca_crt | Base64 encoded ICP Docker registry server CA certificate

