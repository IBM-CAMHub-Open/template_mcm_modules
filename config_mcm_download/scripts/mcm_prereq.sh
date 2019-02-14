#!/bin/bash
#
#Licensed Materials - Property of IBM
#5737-E67
#(C) Copyright IBM Corporation 2016, 2017 All Rights Reserved.
#US Government Users Restricted Rights - Use, duplication or
#disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
#
set -e

helm_secret=$1
cluster_ca_name=$2
cluster_name=$3
admin_user=$4
admin_password=$5

helm_version=2.9.1

# Get the architecture
systemArch=$(arch)
if [ "${systemArch}" == "x86_64" ]; then systemArch='amd64'; fi
# Set arch in dev.yaml
if [ "${systemArch}" == 'ppc64le' ]; then
	if $(grep -q "^arch:*" dev.yaml); then
		echo "arch line found"
		sed -i -e "/arch:*/c\arch:\ ${systemArch}" dev.yaml
	else
		echo 'arch line not found'
		sed -i -e '$a'"arch:\ ${systemArch}" dev.yaml
	fi
fi

if ! which kubectl; then
	echo "install kubectl"
	curl -kLo kubectl-linux-${systemArch} https://${cluster_ca_name}:8443/api/cli/kubectl-linux-amd64	
	chmod +x ./kubectl-linux-${systemArch}	
	sudo mv ./kubectl-linux-${systemArch} /usr/local/bin/kubectl
fi

if ! which cloudctl; then
	echo "install cloudctl"
	curl -kLo "cloudctl-linux-${systemArch}" https://${cluster_ca_name}:8443/api/cli/cloudctl-linux-amd64
	chmod +x "./cloudctl-linux-${systemArch}"
	sudo mv "./cloudctl-linux-${systemArch}" /usr/local/bin/cloudctl
fi

if ! which helm; then
	echo " Getting helm from icp ... "
    curl -kLo "helm-linux-${systemArch}-v2.9.1.tar.gz" https://${cluster_ca_name}:8443/api/cli/helm-linux-amd64.tar.gz	
	tar -xvf "helm-linux-${systemArch}-v2.9.1.tar.gz"
	chmod +x  "./linux-${systemArch}/helm"
	sudo mv "./linux-${systemArch}/helm" /usr/local/bin/helm	
	sudo mkdir -p /var/lib/helm
	export HELM_HOME=~/.helm
fi

if which cloudctl; then
	#cloudctl login
    echo "cloudctl login -u ${admin_user} -p ****** -a https://${cluster_ca_name}:8443 -n kube-system -c id-${cluster_name}-account --skip-ssl-validation"
    if sudo cloudctl login -u ${admin_user} -p ${admin_password} -a https://${cluster_ca_name}:8443 -n kube-system -c id-${cluster_name}-account --skip-ssl-validation ; then
      echo "cloudctl login success"
    else
       echo "cloudctl login failed"
       exit 1
    fi 
fi

if ! sudo kubectl get secret ${helm_secret}; then
	echo "kubectl create secret tls ${helm_secret} --key ~/.helm/key.pem --cert ~/.helm/cert.pem -n kube-system"
	sudo kubectl create secret tls ${helm_secret} --key ~/.helm/key.pem  --cert ~/.helm/cert.pem -n kube-system
else
	echo "secret ${helm_secret} already exists"
fi