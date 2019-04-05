# MCM Klusterlet within public Kubernetes Service platform
Copyright IBM Corp. 2019, 2019 \
This code is released under the Apache 2.0 License.

## Overview
This terraform template deploys the IBM Multicloud Manager Klusterlet v3.1.2 into an existing kubernetes cluster managed within a public Kubernetes Service. \
Supported Kubernetes Services include:
* IBM Cloud Kubernetes Service (IKS)
* Microsoft Azure Kubernetes Service (AKS)
* Google Cloud Kubernetes Engine (GKE)
* Amazon EC2 Kubernetes Service (EKS)

## Prerequisites
* The user must provide the IP address (or hostname), a login name and a SSH private key for connecting to a remote host
* The remote host must be capable of running docker commands, which will be used to deploy the MCM Klusterlet into the kubernetes cluster
* The user, identified by the given login credentials, should have 'sudo' permissions on the remote host
* In addition to docker, the remote host must be capable of executing zip and unzip commands

## Automation summary
The terraform template performs the following activities to install the MCM klusterlet into the specified kubernetes cluster:
* connects to the specified remote (docker) host and pulls the MCM inception container image from the docker repository
* uses the given kubernetes cluster details to configure the installation process
* runs, via docker, the MCM inception container to install the MCM klusterlet and register the clusterlet with the MCM hub-cluster

## Template input parameters

| Parameter Name                  | Parameter Description | Required | Allowed Values |
| :---                            | :--- | :--- | :--- |
| kubernetes_service              | Indicates the type of public kubernetes service | true | iks, aks, gke, eks |
| docker_host                     | Docker host IP address or hostname | true | |
| user_name                       | Login name for connecting to the docker host | true | |
| private_key                     | Private SSH key for connecting to the docker host, Base64 encoded | true | |
| mcm\_hub\_endpoint              | The Kubernetes API endpoint of the IBM Multicloud Manager hub-cluster | true | |
| mcm\_hub\_token                 | The authentication token for the Kubernetes API endpoint of the IBM Multicloud Manager hub-cluster | true | |
| mcm\_version                    | Version of MCM klusterlet to be installed | true | 3.1.2-ce |
| cluster_name                    | Name of the deployed cluster within the kubernetes service | true | |
| cluster_config                  | kubectl configuration text, Base64 encoded | IKS, AKS | |
| cluster\_certificate\_authority | Certificate for authenticating with cluster, Base64 encoded | IKS | |
| cluster_location                | Location (region / zone) where cluster is deployed in public cloud | AKS, GKE | |
| cluster_project                 | Project to which the cluster is associated within the cloud account | GKE | |
| service\_account\_key           | JSON-formatted key for admin service account associated with cluster, Base64 encoded | GKE | |
| access\_key\_id                 | Key ID for gaining access to the cloud and Kubernetes Service | EKS | |
| access\_key\_secret             | Key secret for gaining access to the cloud and Kubernetes Service | EKS | |
