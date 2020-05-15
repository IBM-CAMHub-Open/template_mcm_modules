# MCM Klusterlet within public Kubernetes Service platform
Copyright IBM Corp. 2020, 2020
This code is released under the Apache 2.0 License.

## Overview
This terraform module generates the credentials (user name and token) used to access a Kubernetes cluster.
Supported Kubernetes cluster environments include:
* IBM Cloud Private (ICP)
* IBM Cloud Private with Openshift (OCP)
* IBM Cloud Kubernetes Service (IKS)
* Microsoft Azure Kubernetes Service (AKS)
* Google Cloud Kubernetes Engine (GKE)
* Amazon EC2 Kubernetes Service (EKS)

## Automation summary
The terraform module accepts cluster-specific information (e.g. kubeconfig file, username and password) used to access a Kubernetes cluster:
* Verifies the target cluster can be accessed via the given details
* Generates a set of credentials, including an authentication token, that may be used to access the cluster by 'down-stream' module(s) in a universal manner

## Template input parameters

| Parameter Name                  | Parameter Description | Required | Allowed Values |
| :---                            | :--- | :--- | :--- |
| cluster_type                    | Indicates the type of environment supporting the target Kubernetes cluster | true | icp, ocp, iks, aks, gke, eks |
| cluster_name                    | Name of the target cluster to be imported into the MCM hub cluster | true | |
| work_directory                  | Directory where work files can be generated | | |

For ICP clusters:
| Parameter Name                  | Parameter Description | Required | Allowed Values |
| :---                            | :--- | :--- | :--- |
| icp\_url                        | URL, including port, for the ICP server | true | |
| icp\_admin\_user                | User name for connecting to the ICP server | true | |
| icp\_admin\_password            | Password for connecting to the ICP server | true | |

For OCP clusters:
| Parameter Name                  | Parameter Description | Required | Allowed Values |
| :---                            | :--- | :--- | :--- |
| ocp\_url                        | URL, including port, for the OCP server | true | |
| ocp\_admin\_user                | User name for connecting to the OCP server | true | |
| ocp\_admin\_password            | Password for connecting to the OCP server | true | |

For Microsoft Azure Kubernetes Service (AKS) clusters:
| Parameter Name                  | Parameter Description | Required | Allowed Values |
| :---                            | :--- | :--- | :--- |
| cluster_config                  | kubectl configuration text, Base64 encoded | true | |

For Amazon EC2 Kubernetes Service (EKS) clusters:
| Parameter Name                  | Parameter Description | Required | Allowed Values |
| :---                            | :--- | :--- | :--- |
| cluster_config                  | kubectl configuration text, Base64 encoded | true | |
| cluster_region                  | Location (region / zone) where cluster is deployed in public cloud | true | |
| access\_key\_id                 | Key ID for gaining access to the cloud and Kubernetes Service | true | |
| secret\_access\_key             | Key secret for gaining access to the cloud and Kubernetes Service | true | |

For Google Kubernetes Engine (GKE) clusters:
| Parameter Name                  | Parameter Description | Required | Allowed Values |
| :---                            | :--- | :--- | :--- |
| cluster_config                  | kubectl configuration text, Base64 encoded | true | |
| service\_account\_credentials   | JSON-formatted key for admin service account associated with cluster, Base64 encoded | true | |

For IBM Cloud Kubernetes Service (IKS) clusters:
| Parameter Name                  | Parameter Description | Required | Allowed Values |
| :---                            | :--- | :--- | :--- |
| cluster_config                  | kubectl configuration text, Base64 encoded | true | |
| cluster\_certificate\_authority | Certificate for authenticating with cluster, Base64 encoded | true | |