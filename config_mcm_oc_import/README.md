# Modules for IBM Multicloud Manager Klusterlet on OpenShift
Copyright IBM Corp. 2019, 2019 
This code is released under the Apache 2.0 License.

## Overview
 This terraform template module contains scripts that imports an existing OpenShift Cluster to a IBM Multicloud Manager Controller (Hub Cluster).

## Prerequisites
* An existing OpenShift cluster.
* An existing IBM Multicloud Manager Controller.
* A VM to execute import command to import OpenShift Cluster to IBM MCM Controller.

## Automation summary
The terraform template module performs the following activities:
* connects to the provided VM node and installs the kubectl, cloudctl and docker if not present 
* Sets up the kubernetes configuration for target OpenSift managed cluster and IBM MCM Controller
* runs the `cloudctl mc import` command to import the target OpenSift managed cluster to the IBM Multicloud Manager Controller

## Template variables
Template Variable Name                                        | Parameter description
------------------------------------------------------|------------------------------------------------------------------
import_launch_node_ip| IP address of the node to execute import of a OopenShift cluster to IBM MCM Controller. This can be a OpenShift installer master node.
vm_os_user | The user name to connect to the import launch node.
vm_os_password (optional)| Base64 encoded private SSH key to connect to the import launch node. Either the password or the private key should be provided.
vm_os_private_key (optional)| The user password to connect to the import launch node. Either the password or the private key should be provided.
admin_user| OpenShift administrator user name.
admin_pass| OpenShift administrator user password.
OCP_server_url| OpenShift server URL.
man_cluster_on_hub | Name that will be used to identify the managed cluster on the IBM MCM Controller.
rhsm_user | RedHat Subscription Manager user name for downloading OC CLI.
rhsm_password | RedHat Subscription Manager user password for downloading OC CLI.
mcm_controller_server_name | Server name of a IBM MCM Controller to register the managed OpenShift cluster.
mcm_controller_admin_user | IBM MCM Controller administrator user name.
mcm_controller_admin_user_password | IBM MCM Controller administrator password.
