#!/bin/bash
#
#Licensed Materials - Property of IBM
#5737-E67
#(C) Copyright IBM Corporation 2019 All Rights Reserved.
#US Government Users Restricted Rights - Use, duplication or
#disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
#
set -e

#Default values
PARAM_CLUSTER_REG_PORT=8500
PARAM_CLUSTER_INCEPTION_IMAGE=ibmcom/icp-inception-amd64:3.2.0-ee
MANCLUSTERCLOUD=IBM
MANCLUSTERVEN=ICP
MANCLUSTERENV=DEV
MANCLUSTERREG=US
MANCLUSTERDC=toronto
MANCLUSTEROWN=marketing
WARN='\033[0;31m'
REGULAR='\033[0m'

# Get script parameters
while test $# -gt 0; do
  [[ $1 =~ ^-rh|--clusterregsrvr ]] && { PARAM_CLUSTER_REG_SERVER="${2}"; shift 2; continue; };
  [[ $1 =~ ^-rp|--clusterregport ]] && { PARAM_CLUSTER_REG_PORT="${2}"; shift 2; continue; };   	 	
  [[ $1 =~ ^-rca|--clusterregca ]] && { PARAM_CLUSTER_REG_CA_CERT="${2}"; shift 2; continue; };  	
  [[ $1 =~ ^-ri|--clusterregsrverip ]] && { PARAM_CLUSTER_REG_IP="${2}"; shift 2; continue; };
  [[ $1 =~ ^-cm|--cluster ]] && { PARAM_CLUSTER="${2}"; shift 2; continue; }; 	
  [[ $1 =~ ^-pa|--path ]] && { ICPDIR="${2}"; shift 2; continue; };
  [[ $1 =~ ^-hs|--hub ]] && { HUB="${2}"; shift 2; continue; };
  [[ $1 =~ ^-hu|--hubuser ]] && { HUBUSER="${2}"; shift 2; continue; };
  [[ $1 =~ ^-hp|--hubpassword ]] && { HUBPASS="${2}"; shift 2; continue; };
  [[ $1 =~ ^-mch|--manclusterhub ]] && { MANCLUSTERHUB="${2}"; shift 2; continue; };
  [[ $1 =~ ^-u|--user ]] && { ADMIN_USER="${2}"; shift 2; continue; };
  [[ $1 =~ ^-pw|--password ]] && { ADMIN_PASS="${2}"; shift 2; continue; };
  [[ $1 =~ ^-s|--icpsrvrurl ]] && { PARAM_ICP_SRVR_URL="${2}"; shift 2; continue; };  	
  [[ $1 =~ ^-v|--icpimage ]] && { PARAM_CLUSTER_INCEPTION_IMAGE="${2}"; shift 2; continue; };  	
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


#if [ -z "$CLUSTER_CONFIG" ]; then
#	echo "Kubernetes config of managed ICP is missing. Provide base64 encoded configuration value and re-deploy. Failed to register ICP to hub cluster."
#	exit 1
#fi

#if [ -z "$CLUSTER_CA_CERT" ]; then
#	echo "Kubernetes CA certificate is missing. Will connect without CA certificate."
#fi

if [ -z "$PARAM_CLUSTER" ]; then
	echo "ICP cluster name on managed ICP is missing. Failed to register ICP to hub cluster."
	exit 1
fi

if [ -z "$HUBUSER" ]; then
	echo "Hub cluster user name is missing. Failed to register ICP to hub cluster."
	exit 1
fi

if [ -z "$HUBPASS" ]; then
	echo "Hub cluster user password is missing. Failed to register ICP to hub cluster."
	exit 1
fi

if [ -z "$HUB" ]; then
	echo "Hub cluster server is missing. Failed to register ICP to hub cluster."
	exit 1
fi

if [ -z "$ADMIN_USER" ]; then
	echo "Managed cluster administrator user name is missing. Failed to register ICP to hub cluster."
	exit 1
fi

if [ -z "$ADMIN_PASS" ]; then
	echo "Managed cluster administrator user password is missing. Failed to register ICP to hub cluster."
	exit 1
fi

if [ -z "$PARAM_ICP_SRVR_URL" ]; then
	echo "Managed cluster ICP Server URL is missing. Failed to register ICP to hub cluster."
	exit 1
fi

if [ -z "$MANCLUSTERHUB" ]; then
	echo "Name to identify managed cluster on hub missing. Using ${PARAM_CLUSTER}-managed"
fi

if [ -z "$PARAM_CLUSTER_REG_PORT" ]; then
	echo "Registry port of managed ICP is missing. Will use default port 8500."
fi	

if [ -z "$PARAM_CLUSTER_INCEPTION_IMAGE" ]; then
	echo "ICP Version of managed ICP is missing. Will use default ibmcom/icp-inception-amd64:3.2.0-ee."
fi			

if [ -z "$PARAM_CLUSTER_REG_CA_CERT" ]; then
	echo "Private docker registry CA certificate is missing. Import command may fail to bootstrap."
else
	if [ -d "/etc/docker/certs.d/${PARAM_CLUSTER_REG_SERVER}:${PARAM_CLUSTER_REG_PORT}" ]; then
		echo "Directory /etc/docker/certs.d/${PARAM_CLUSTER_REG_SERVER}:${PARAM_CLUSTER_REG_PORT} found"
	else
		echo "Directory /etc/docker/certs.d/${PARAM_CLUSTER_REG_SERVER}:${PARAM_CLUSTER_REG_PORT} not found, create a new one"
		sudo mkdir -p /etc/docker/certs.d/${PARAM_CLUSTER_REG_SERVER}:${PARAM_CLUSTER_REG_PORT}
    fi
    if [ -f "/etc/docker/certs.d/${PARAM_CLUSTER_REG_SERVER}:${PARAM_CLUSTER_REG_PORT}/ca.crt" ]; then
    	echo "File /etc/docker/certs.d/${PARAM_CLUSTER_REG_SERVER}:${PARAM_CLUSTER_REG_PORT}/ca.crt found."
    else
		echo "File /etc/docker/certs.d/${PARAM_CLUSTER_REG_SERVER}:${PARAM_CLUSTER_REG_PORT}/ca.crt not found, create a new one."
		echo "${PARAM_CLUSTER_REG_CA_CERT}" | base64 -d | sudo tee /etc/docker/certs.d/${PARAM_CLUSTER_REG_SERVER}:${PARAM_CLUSTER_REG_PORT}/ca.crt
	fi
fi

if [ -z "$PARAM_CLUSTER_REG_IP" ]; then
	echo "Private docker registry IP address is missing. Import command may fail if docker client is unable reach the server using hostname."
else
	echo "Add docker private registry entry in /etc/hosts"
	echo ${PARAM_CLUSTER_REG_IP} ${PARAM_CLUSTER_REG_SERVER} |	sudo tee -a /etc/hosts
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

#Namespace of managed cluster on hub
MANNSHUB=mcmns-${MANCLUSTERHUB}
#Cluster context
CLUSTER_CONTEXT=${PARAM_CLUSTER}-context

#CONTEXTNAME=$(sudo KUBECONFIG=${KUBECONFIG_FILE} kubectl config view -o jsonpath='{.contexts[?(@.context.cluster == "'"${PARAM_CLUSTER}"'")].name}')
#if [ -z "$CONTEXTNAME" ]; then
#	echo "Cluster context missing for ${PARAM_CLUSTER} set cluster context ${PARAM_CLUSTER}-context"
#	CLUSTER_CONTEXT=${PARAM_CLUSTER}-context
#	sudo KUBECONFIG=${KUBECONFIG_FILE} kubectl config set-context ${PARAM_CLUSTER}-context --cluster=${PARAM_CLUSTER} --namespace=default
#fi	
unset KUBECONFIG

echo "Login to hub ${HUB}"
sudo /usr/local/bin/cloudctl login -a ${HUB} -u ${HUBUSER} -p ${HUBPASS} --skip-ssl-validation -n kube-system
	
echo "Get cluster template from hub"
sudo /usr/local/bin/cloudctl mc cluster template ${MANCLUSTERHUB} -n ${MANNSHUB} | tee /var/lib/registry/mcm_scripts/cluster-import.yaml

sed -i -e "s/default_admin_user:.*/default_admin_user: ${ADMIN_USER}/" /var/lib/registry/mcm_scripts/cluster-import.yaml
#sed -i -e 's/    environment:.*/    environment: "'"${MANCLUSTERENV}"'"/' /var/lib/registry/mcm_scripts/cluster-import.yaml
#sed -i -e 's/    region:.*/    region: "'"${MANCLUSTERREG}"'"/' /var/lib/registry/mcm_scripts/cluster-import.yaml
#sed -i -e 's/    datacenter:.*/    datacenter: "'"${MANCLUSTERDC}"'"/' /var/lib/registry/mcm_scripts/cluster-import.yaml
#sed -i -e 's/    owner:.*/    owner: "'"${MANCLUSTEROWN}"'"/' /var/lib/registry/mcm_scripts/cluster-import.yaml

#Check if image is ee or ce
tag=$(echo ${PARAM_CLUSTER_INCEPTION_IMAGE} | cut -d":" -f2)
CE=true 
if [[ $tag == *-ee ]]
then
	CE=false
fi

if [ -z "$PARAM_CLUSTER_REG_SERVER" ] || [[ "$CE" == "true" ]]; then
	echo "Managed ICP Private Docker Registry Server Name is empty or this is a CE image. Private registry disabled in import configuration."
else	
	echo "Customize cluster template for private repository"
	echo "image_repo: ${PARAM_CLUSTER_REG_SERVER}:${PARAM_CLUSTER_REG_PORT}/ibmcom" | tee -a /var/lib/registry/mcm_scripts/cluster-import.yaml
	echo "private_registry_enabled: true" | tee -a /var/lib/registry/mcm_scripts/cluster-import.yaml
	echo "docker_username: ${ADMIN_USER}" | tee -a /var/lib/registry/mcm_scripts/cluster-import.yaml
	echo "docker_password: ${ADMIN_PASS}" | tee -a /var/lib/registry/mcm_scripts/cluster-import.yaml
	sed -i -e "s|inception_image:.*|inception_image: ${PARAM_CLUSTER_REG_SERVER}:${PARAM_CLUSTER_REG_PORT}/${PARAM_CLUSTER_INCEPTION_IMAGE}|" /var/lib/registry/mcm_scripts/cluster-import.yaml	
fi

echo "Import template to hub"
echo "sudo /usr/local/bin/cloudctl mc cluster import -f cluster-import.yaml --cluster-context ${CLUSTER_CONTEXT} -K ${KUBECONFIG_FILE}"
sudo /usr/local/bin/cloudctl mc cluster import -f /var/lib/registry/mcm_scripts/cluster-import.yaml --cluster-context ${CLUSTER_CONTEXT} -K ${KUBECONFIG_FILE}

if [ -z "$PARAM_CLUSTER_REG_SERVER" ] || [[ "$CE" == "true" ]]; then
	echo "Public registry, no clean up required"
else
	echo "Clean up hub cluster configmap"
	echo "sudo kubectl get configmap -n ${MANNSHUB} ${MANCLUSTERHUB}-bootstrap-config -o yaml"
	sudo kubectl get configmap -n ${MANNSHUB} ${MANCLUSTERHUB}-bootstrap-config -o yaml | tee /var/lib/registry/mcm_scripts/patch.yaml
	sed -i -e "s/docker_password:.*/#docker_password:/" /var/lib/registry/mcm_scripts/patch.yaml
	sed -i -e "s/docker_username:.*/#docker_username:/" /var/lib/registry/mcm_scripts/patch.yaml
	echo "sudo kubectl patch configmap -n ${MANNSHUB} ${MANCLUSTERHUB}-bootstrap-config --type merge --patch "
	sudo kubectl patch configmap -n ${MANNSHUB} ${MANCLUSTERHUB}-bootstrap-config --type merge --patch "$(cat /var/lib/registry/mcm_scripts/patch.yaml)"
fi
	
if [ -z "$ICPDIR" ]; then
	echo -e "${WARN}Input for Managed ICP Install Directory is empty, config.yaml file not updated with MCM data. Manually update config.yaml using output variable Import confguration.${REGULAR}"
else
	if [ -f "${ICPDIR}/config.yaml" ]; then
		echo "Append import configuration of config file"
		sudo cp ${ICPDIR}/config.yaml ${ICPDIR}/config.yaml.mcm320disabled
		sudo sed -i -e "s/multicluster-endpoint: disabled/multicluster-endpoint: enabled/" ${ICPDIR}/config.yaml
		sudo tee -a ${ICPDIR}/config.yaml < /var/lib/registry/mcm_scripts/cluster-import.yaml
	else
		echo -e "${WARN}Managed ICP configuration file ${ICPDIR}/config.yaml not found. Verify if you are running this script on ICP boot node.${REGULAR}"
	fi
fi

echo "Logout from hub"
sudo /usr/local/bin/cloudctl logout
sudo kubectl config unset current-context
