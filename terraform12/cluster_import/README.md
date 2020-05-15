# Import Kubernetes cluster into MCM hub-cluster
Copyright IBM Corp. 2020, 2020
This code is released under the Apache 2.0 License.

## Overview
This terraform template imports an existing Kubernetes cluster into a v3.2.1 MCM hub-cluster.
Supported Kubernetes cluster environments include:
* IBM Cloud Private (ICP)
* IBM Cloud Private with Openshift (OCP)
* IBM Cloud Kubernetes Service (IKS)
* Microsoft Azure Kubernetes Service (AKS)
* Google Cloud Kubernetes Engine (GKE)
* Amazon EC2 Kubernetes Service (EKS)

## Prerequisites
* Tiller should not be installed within the Kubernetes cluster

## Automation summary
The terraform template performs the following activities to import the specified Kubernetes cluster into the MCM hub-cluster:
* Authenticates with the ICP server hosting the MCM hub-cluster
* Uses the given Kubernetes cluster details to configure the import process
* Runs the import commands supported by the MCM hub-cluster

## Template input parameters

| Parameter Name                  | Parameter Description | Required |
| :---                            | :--- | :--- |
| mcm\_url                        | URL, including port, for the MCM hub-cluster | true |
| mcm\_admin\_user                | User name for connecting to the MCM hub-cluster | true |
| mcm\_admin\_password            | Password for authenticating with the MCM hub-cluster | true |
| cluster_name                    | Name of the target cluster to be imported into the MCM hub cluster | true |
| cluster_endpoint                | URL for the target Kubernetes cluster endpoint | true |
| cluster_user                    | Username for accessing the target Kubernetes cluster | true |
| cluster_token                   | Token for authenticating with the target Kubernetes cluster | true |
| cluster_namespace               | Namespace in the hub cluster into which the target cluster will be imported; Defaults to cluster name | |
| image_registry                  | URL for private docker registry from which klusterlet images will be pulled | |
| image_suffix                    | Suffix (e.g. platform type) to be appended to image name | |
| image_version                   | Version (tag) of the MCM image to be pulled | |
| docker_user                     | Username for authenticating with the private docker registry | |
| docker_password                 | Password for authenticating with the private docker registry | |
