#!/bin/bash
#
#Licensed Materials - Property of IBM
#5737-E67
#(C) Copyright IBM Corporation 2019 All Rights Reserved.
#US Government Users Restricted Rights - Use, duplication or
#disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
#
set -e
systemArch=$(arch)

# Get script parameters
while test $# -gt 0; do
  [[ $1 =~ ^-c|--cluster ]] && { PARAM_CLUSTER="${2}"; shift 2; continue; };
  [[ $1 =~ ^-h|--icpsrvrurl ]] && { PARAM_ICP_SRVR_URL="${2}"; shift 2; continue; };
  #[[ $1 =~ ^-kc|--kubeconfig ]] && { CLUSTER_CONFIG="${2}"; shift 2; continue; };
  #[[ $1 =~ ^-kk|--kubecacert ]] && { CLUSTER_CA_CERT="${2}"; shift 2; continue; };  	
  break;
done

if [ -z "$PARAM_CLUSTER" ]; then
	echo "Managed ICP cluster name is required but missing. Failed to register ICP to hub cluster."
	exit 1
fi

if [ -z "$PARAM_ICP_SRVR_URL" ]; then
	echo "Server URL of managed ICP is missing.Failed to register ICP to hub cluster."
	exit 1
fi

#if [ -z "$CLUSTER_CONFIG" ]; then
#	echo "Kubernetes config of managed ICP is missing. Provide base64 encoded configuration value and re-deploy. Failed to register ICP to hub cluster."
#	exit 1
#fi

#if [ -z "$CLUSTER_CA_CERT" ]; then
#	echo "Kubernetes CA certificate is missing. Will connect without CA certificate."
#fi

if ! which kubectl; then
	echo "install kubectl from ${PARAM_ICP_SRVR_URL}"
	curl -kLo kubectl-linux-${systemArch} ${PARAM_ICP_SRVR_URL}/api/cli/kubectl-linux-amd64	
	chmod +x ./kubectl-linux-${systemArch}	
	sudo mv ./kubectl-linux-${systemArch} /usr/local/bin/kubectl
fi

if ! which cloudctl; then
	echo "install cloudctl from ${PARAM_CLUSTER_CONSOLE_HOST}"
	curl -kLo "cloudctl-linux-${systemArch}" ${PARAM_ICP_SRVR_URL}/api/cli/cloudctl-linux-amd64	
	chmod +x "./cloudctl-linux-${systemArch}"
	sudo mv "./cloudctl-linux-${systemArch}" /usr/local/bin/cloudctl
fi

if ! which docker; then
	echo "install docker CE"
	curl -fsSL https://get.docker.com/ | sudo sh
fi

#echo "Set up managed ICP kube cluster context from kubeconfig data object"
#KUBECONFIG_FILE=/var/lib/registry/mcm_scripts/managedconfig
#echo ${CLUSTER_CONFIG} | base64 -d > ${KUBECONFIG_FILE}
#export KUBECONFIG=${KUBECONFIG_FILE}
#if [[ ! -z "$CLUSTER_CA_CERT" ]]; then
#	CERT_LOC=$(sudo grep "certificate-authority:" ${KUBECONFIG_FILE} | cut -d':' -f2 | cut -d' ' -f2)
#	if [[ ! -z "$CERT_LOC" ]]; then
#		echo "${CLUSTER_CA_CERT}" | base64 -d > ./${CERT_LOC}
#	fi
#fi
	
#echo "Verify if the kubeconfig ${KUBECONFIG} is valid"
#set +e
#err=$(mktemp)
#sudo KUBECONFIG=${KUBECONFIG_FILE} kubectl get nodes 2>$err
#RESULT=$(echo $?)
#kubeerr=$(< $err)
#rm $err
#if [ $RESULT -eq 1 ]; then
#	echo "Unable to connect to ICP cluster. Kubeconfig validation failed: ${kubeerr} . Verify if the value for Managed Cluster Kubernetes Configuration is valid."
#	unset KUBECONFIG
#	exit 1	
#fi
#if [[ ! -z $kubeerr ]]; then
#	echo "Unable to connect to ICP cluster. Kubeconfig validation failed: ${kubeerr} . Verify if the value for Managed Cluster Kubernetes Configuration is valid."
#	unset KUBECONFIG
#	exit 1	
#fi
#echo "kubeconfig ${KUBECONFIG} verified"
#unset KUBECONFIG
