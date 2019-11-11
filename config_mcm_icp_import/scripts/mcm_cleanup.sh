#!/bin/bash
#
#Licensed Materials - Property of IBM
#5737-E67
#(C) Copyright IBM Corporation 2019 All Rights Reserved.
#US Government Users Restricted Rights - Use, duplication or
#disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
#

set -e

KUBECONFIG_FILE=/var/lib/registry/mcm_scripts/managedconfig
WARN='\033[0;31m'
REGULAR='\033[0m'

# Get script parameters
while test $# -gt 0; do
  [[ $1 =~ ^-cm|--cluster ]] && { PARAM_CLUSTER="${2}"; shift 2; continue; };
  [[ $1 =~ ^-hs|--hub ]] && { HUB="${2}"; shift 2; continue; };
  [[ $1 =~ ^-hu|--hubuser ]] && { HUBUSER="${2}"; shift 2; continue; };
  [[ $1 =~ ^-hp|--hubpassword ]] && { HUBPASS="${2}"; shift 2; continue; };
  [[ $1 =~ ^-mch|--manclusterhub ]] && { MANCLUSTERHUB="${2}"; shift 2; continue; };
  [[ $1 =~ ^-u|--user ]] && { ADMIN_USER="${2}"; shift 2; continue; };
  [[ $1 =~ ^-pw|--password ]] && { ADMIN_PASS="${2}"; shift 2; continue; };
  [[ $1 =~ ^-s|--icpsrvrurl ]] && { PARAM_ICP_SRVR_URL="${2}"; shift 2; continue; };  	
  [[ $1 =~ ^-pa|--path ]] && { ICPDIR="${2}"; shift 2; continue; };  	
  #[[ $1 =~ ^-kc|--kubeconfig ]] && { CLUSTER_CONFIG="${2}"; shift 2; continue; };
  #[[ $1 =~ ^-kk|--kubecacert ]] && { CLUSTER_CA_CERT="${2}"; shift 2; continue; };  	
  break;
done

#if [ -z "$CLUSTER_CONFIG" ]; then
#	echo "Kubernetes config of managed ICP is missing. Provide base64 encoded configuration value and re-deploy. Failed to register ICP to hub cluster."
#	exit 1
#fi

#if [ -z "$CLUSTER_CA_CERT" ]; then
#	echo "Kubernetes CA certificate is missing. Will connect without CA certificate."
#fi

if [ -z "$PARAM_CLUSTER" ]; then
	echo "ICP cluster name on managed ICP is missing. Failed to cleanup ICP from hub cluster."
	exit 1
fi

if [ -z "$HUBUSER" ]; then
	echo "Hub cluster user name is missing. Failed to cleanup ICP from hub cluster."
	exit 1
fi

if [ -z "$HUBPASS" ]; then
	echo "Hub cluster user password is missing. Failed to cleanup ICP from hub cluster."
	exit 1
fi

if [ -z "$HUB" ]; then
	echo "Hub cluster server is missing. Failed to cleanup ICP from hub cluster."
	exit 1
fi

if [ -z "$MANCLUSTERHUB" ]; then
	echo "Name to identify managed cluster on hub missing. Using ${PARAM_CLUSTER}-managed"
fi

if [ -z "$PARAM_ICP_SRVR_URL" ]; then
	echo "Managed ICP server URL. Failed to cleanup ICP from hub cluster."
	exit 1
fi

if [ -z "$ADMIN_USER" ]; then
	echo "Managed cluster administrator user name is missing. Failed to cleanup ICP from hub cluster."
	exit 1
fi

if [ -z "$ADMIN_PASS" ]; then
	echo "Managed cluster administrator user password is missing. Failed to cleanup ICP from hub cluster."
	exit 1
fi

#Namespace of managed cluster on hub
MANNSHUB=mcmns-${MANCLUSTERHUB}
#Cluster context
CLUSTER_CONTEXT=${PARAM_CLUSTER}-context

#echo "Generate kube config for managed cluster from kubeconfig data object"
KUBECONFIG_FILE=/var/lib/registry/mcm_scripts/managedconfig
#echo ${CLUSTER_CONFIG} | base64 -d > ${KUBECONFIG_FILE}
export KUBECONFIG=${KUBECONFIG_FILE}
#if [[ ! -z "$CLUSTER_CA_CERT" ]]; then
#	CERT_LOC=$(sudo grep "certificate-authority:" ${KUBECONFIG_FILE} | cut -d':' -f2 | cut -d' ' -f2)
#	if [[ ! -z "$CERT_LOC" ]]; then
#		echo "${CLUSTER_CA_CERT}" | base64 -d > ./${CERT_LOC}
#	fi
#fi

echo "Login to ICP ${PARAM_ICP_SRVR_URL}"
sudo KUBECONFIG=${KUBECONFIG_FILE} /usr/local/bin/cloudctl login -a ${PARAM_ICP_SRVR_URL} -u ${ADMIN_USER} -p ${ADMIN_PASS} --skip-ssl-validation -n default

echo "Verify if the ICP kubeconfig is valid"
set +e
sudo KUBECONFIG=${KUBECONFIG_FILE} kubectl get nodes
RESULT=$(echo $?)
if [ $RESULT -eq 1 ]; then
	echo "Unable to connect to ICP cluster. Kubeconfig validation failed. Verify if the value for Managed Cluster Kubernetes Configuration is valid."
	unset KUBECONFIG
	exit 1	
fi
set -e

echo "Login to hub ${HUB}"
sudo /usr/local/bin/cloudctl login -a ${HUB} -u ${HUBUSER} -p ${HUBPASS} --skip-ssl-validation -n kube-system
	
echo "Add docker credentials to configmap"
echo "sudo kubectl get configmap -n ${MANNSHUB} ${MANCLUSTERHUB}-bootstrap-config -o yaml"
sudo kubectl get configmap -n ${MANNSHUB} ${MANCLUSTERHUB}-bootstrap-config -o yaml | tee /var/lib/registry/mcm_scripts/patch.yaml
sed -i -e "s/#docker_password:/docker_password: ${ADMIN_PASS}/" /var/lib/registry/mcm_scripts/patch.yaml
sed -i -e "s/#docker_username:/docker_username: ${ADMIN_USER}/" /var/lib/registry/mcm_scripts/patch.yaml
echo "sudo kubectl patch configmap -n ${MANNSHUB} ${MANCLUSTERHUB}-bootstrap-config --type merge --patch "
sudo kubectl patch configmap -n ${MANNSHUB} ${MANCLUSTERHUB}-bootstrap-config --type merge --patch "$(cat /var/lib/registry/mcm_scripts/patch.yaml)"
	

echo "Clean up managed cluster ${MANCLUSTERHUB} on hub ${HUB}"
sudo cloudctl mc cluster remove ${MANCLUSTERHUB} -n ${MANNSHUB} -C ${CLUSTER_CONTEXT} -K ${KUBECONFIG_FILE}
sudo kubectl delete cluster ${MANCLUSTERHUB} -n ${MANNSHUB}	
#sudo kubectl delete configmap ${MANCLUSTERHUB}-bootstrap-config -n ${MANNSHUB}
sudo /usr/local/bin/cloudctl logout
sudo kubectl config unset current-context
if [ -z "$ICPDIR" ]; then
	echo -e "${WARN}Input for ICP install directory of managed ICP is missing. The config.yaml file would not be reverted to original state. You need to manually update the file.${REGULAR}"
else
	if [ -f "${ICPDIR}/config.yaml.mcm320disabled" ]; then
		echo "Revert to original config.yaml file."
		sudo cp ${ICPDIR}/config.yaml ${ICPDIR}/config.yaml.mcm320enabled
		sudo cp ${ICPDIR}/config.yaml.mcm320disabled ${ICPDIR}/config.yaml
	else
		echo -e "${WARN}Original ICP configuration backup file ${ICPDIR}/config.yaml.mcm320disabled not found. The config.yaml file would not be reverted to original state. You need to manually update the file.${REGULAR}"
	fi
fi	
	


