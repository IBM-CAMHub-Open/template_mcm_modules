#!/bin/bash
#
#Licensed Materials - Property of IBM
#5737-E67
#(C) Copyright IBM Corporation 2019 All Rights Reserved.
#US Government Users Restricted Rights - Use, duplication or
#disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
#
set -e

#Default port values
PARAM_HUB_CONSOLE_PORT=8443
MANCLUSTERCLOUD=RedHat
MANCLUSTERVEN=OpenShift
MANCLUSTERENV=DEV
MANCLUSTERREG=US
MANCLUSTERDC=toronto
MANCLUSTEROWN=marketing

# Get script parameters
while test $# -gt 0; do
  [[ $1 =~ ^-hs|--hub ]] && { HUB="${2}"; shift 2; continue; };
  [[ $1 =~ ^-hu|--hubuser ]] && { HUBUSER="${2}"; shift 2; continue; };
  [[ $1 =~ ^-hp|--hubpassword ]] && { HUBPASS="${2}"; shift 2; continue; };
  [[ $1 =~ ^-mch|--manclusterhub ]] && { MANCLUSTERHUB="${2}"; shift 2; continue; };
  [[ $1 =~ ^-u|--user ]] && { ADMIN_USER="${2}"; shift 2; continue; };
  [[ $1 =~ ^-ru|--rhususer ]] && { RHSM_USERNAME="${2}"; shift 2; continue; };
  [[ $1 =~ ^-rp|--rhuspass ]] && { RHSM_PASSWORD="${2}"; shift 2; continue; }; 
  [[ $1 =~ ^-osu|--srvrurl ]] && { OCP_SERVER_URL="${2}"; shift 2; continue; };
  [[ $1 =~ ^-p|--pass ]] && { ADMIN_PASS="${2}"; shift 2; continue; };
  	
  #[[ $1 =~ ^-mcc|--manclustercloud ]] && { MANCLUSTERCLOUD="${2}"; shift 2; continue; };
  #[[ $1 =~ ^-mcv|--manclustervendor ]] && { MANCLUSTERVEN="${2}"; shift 2; continue; };
  #[[ $1 =~ ^-mce|--manclusterenv ]] && { MANCLUSTERENV="${2}"; shift 2; continue; };
  #[[ $1 =~ ^-mcr|--manclusterreg ]] && { MANCLUSTERREG="${2}"; shift 2; continue; };
  #[[ $1 =~ ^-mcd|--manclusterdctr ]] && { MANCLUSTERDC="${2}"; shift 2; continue; };
  #[[ $1 =~ ^-mco|--manclusterown ]] && { MANCLUSTEROWN="${2}"; shift 2; continue; };	
  #[[ $1 =~ ^-kc|--kubeconfig ]] && { CLUSTER_CONFIG="${2}"; shift 2; continue; };
  #[[ $1 =~ ^-kk|--kubecacert ]] && { CLUSTER_CA_CERT="${2}"; shift 2; continue; };  	 	
  break;
done

if [ -z "$OCP_SERVER_URL" ]; then
	echo "Managed cluster server URL is missing. Failed to register OCP to hub cluster."
	exit 1
fi

if [ -z "$ADMIN_USER" ]; then
	echo "Managed cluster administrator user name is missing. Failed to register OCP to hub cluster."
	exit 1
fi

if [ -z "$ADMIN_PASS" ]; then
	echo "Managed cluster administrator password is missing. Failed to register OCP to hub cluster."
	exit 1
fi


#if [ -z "$CLUSTER_CONFIG" ]; then
#	echo "Kubernetes config of managed ICP is missing. Provide base64 encoded configuration value and re-deploy. Failed to register ICP to hub cluster."
#	exit 1
#fi

#if [ -z "$CLUSTER_CA_CERT" ]; then
#	echo "Kubernetes CA certificate is missing. Will connect without CA certificate."
#fi

if [ -z "$HUB" ]; then
	echo "Hub cluster server is missing. Failed to register OCP to hub cluster."
	exit 1
fi

if [ -z "$RHSM_USERNAME" ]; then
	echo "RedHat subscription username is missing. Failed to register to hub cluster."
	exit 1
fi

if [ -z "$RHSM_PASSWORD" ]; then
	echo "RedHat subscription password is missing. Failed to register to hub cluster."
	exit 1
fi	


if [ -z "$HUBUSER" ]; then
	echo "Hub cluster user name is missing. Failed to register OCP to hub cluster."
	exit 1
fi

if [ -z "$HUBPASS" ]; then
	echo "Hub cluster user password is missing. Failed to register OCP to hub cluster."
	exit 1
fi

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

sudo KUBECONFIG=${KUBECONFIG_FILE} oc login ${OCP_SERVER_URL} -u ${ADMIN_USER} -p ${ADMIN_PASS}

echo "Verify if the OCP kubeconfig is valid"
set +e
sudo KUBECONFIG=${KUBECONFIG_FILE} kubectl get nodes
RESULT=$(echo $?)
if [ $RESULT -eq 1 ]; then
	echo "Unable to connect to OCP cluster. Kubeconfig validation failed. Verify if the value for Managed Cluster Kubernetes Configuration is valid."
	unset KUBECONFIG
	exit 1	
fi
set -e
 
#Namespace of managed cluster on hub
MANNSHUB=mcm-${MANCLUSTERHUB}
CLUSTER_CONTEXT=$(sudo KUBECONFIG=${KUBECONFIG_FILE} kubectl config view -o jsonpath='{.contexts[0].name}')
unset KUBECONFIG

echo "Login to hub ${HUB}"
sudo /usr/local/bin/cloudctl login -a ${HUB} -u ${HUBUSER} -p ${HUBPASS} --skip-ssl-validation -n kube-system
	
echo "Get cluster template from hub"
sudo /usr/local/bin/cloudctl mc cluster template ${MANCLUSTERHUB} -n ${MANNSHUB} | tee /var/lib/registry/mcm_scripts/cluster-import.yaml

echo "Customize cluster template"
echo "docker_username: ${RHSM_USERNAME}" | tee -a /var/lib/registry/mcm_scripts/cluster-import.yaml
echo "docker_password: ${RHSM_PASSWORD}" | tee -a /var/lib/registry/mcm_scripts/cluster-import.yaml	
sed -i -e "s/default_admin_user:.*/default_admin_user: ${ADMIN_USER}/" /var/lib/registry/mcm_scripts/cluster-import.yaml
#sed -i -e 's/    environment:.*/    environment: "'"${MANCLUSTERENV}"'"/' /var/lib/registry/mcm_scripts/cluster-import.yaml
#sed -i -e 's/    region:.*/    region: "'"${MANCLUSTERREG}"'"/' /var/lib/registry/mcm_scripts/cluster-import.yaml
#sed -i -e 's/    datacenter:.*/    datacenter: "'"${MANCLUSTERDC}"'"/' /var/lib/registry/mcm_scripts/cluster-import.yaml
#sed -i -e 's/    owner:.*/    owner: "'"${MANCLUSTEROWN}"'"/' /var/lib/registry/mcm_scripts/cluster-import.yaml

echo "Import template to hub"
sudo /usr/local/bin/cloudctl mc cluster import -f /var/lib/registry/mcm_scripts/cluster-import.yaml --cluster-context ${CLUSTER_CONTEXT} -K ${KUBECONFIG_FILE}

echo "Clean up hub cluster configmap"
echo "sudo kubectl get configmap -n ${MANNSHUB} ${MANCLUSTERHUB}-bootstrap-config -o yaml"
sudo kubectl get configmap -n ${MANNSHUB} ${MANCLUSTERHUB}-bootstrap-config -o yaml | tee /var/lib/registry/mcm_scripts/patch.yaml
sed -i -e "s/docker_password:.*/#docker_password:/" /var/lib/registry/mcm_scripts/patch.yaml
sed -i -e "s/docker_username:.*/#docker_username:/" /var/lib/registry/mcm_scripts/patch.yaml
echo "sudo kubectl patch configmap -n ${MANNSHUB} ${MANCLUSTERHUB}-bootstrap-config --type merge --patch "
sudo kubectl patch configmap -n ${MANNSHUB} ${MANCLUSTERHUB}-bootstrap-config --type merge --patch "$(cat /var/lib/registry/mcm_scripts/patch.yaml)"

sudo /usr/local/bin/cloudctl logout
sudo kubectl config unset current-context	


