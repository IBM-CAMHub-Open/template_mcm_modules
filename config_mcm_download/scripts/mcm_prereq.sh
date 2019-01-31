#!/bin/bash
#
#Licensed Materials - Property of IBM
#5737-E67
#(C) Copyright IBM Corporation 2016, 2017 All Rights Reserved.
#US Government Users Restricted Rights - Use, duplication or
#disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
#

helm_secret=$1
cluster_name=$2
admin_user=$3
admin_password=$4
icp_version=$5

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
	curl -kLo kubectl-linux-${systemArch} https://${cluster_name}:8443/api/cli/kubectl-linux-amd64	
	chmod +x ./kubectl-linux-${systemArch}	
	sudo mv ./kubectl-linux-${systemArch} /usr/local/bin/kubectl
fi

if ! which cloudctl; then
	echo "install kubectl"
	curl -kLo "cloudctl-linux-${systemArch}" https://${cluster_name}:8443/api/cli/cloudctl-linux-amd64
	chmod +x "./cloudctl-linux-${systemArch}"
	sudo mv "./cloudctl-linux-${systemArch}" /usr/local/bin/cloudctl
fi

if ! which helm; then
	echo " Getting helm from icp ... "
    curl -kLo "helm-linux-${systemArch}-v2.9.1.tar.gz" https://${cluster_name}:8443/api/cli/helm-linux-amd64.tar.gz	
	tar -xvf "helm-linux-${systemArch}-v2.9.1.tar.gz"
	chmod +x  "./linux-${systemArch}/helm"
	sudo mv "./linux-${systemArch}/helm" /usr/local/bin/helm	
	sudo mkdir -p /var/lib/helm
	export HELM_HOME=~/.helm
fi

if [[ "${icp_version}" == "2.1.0.3" ]]; then
	if ! which bx; then
		echo "installing bx client"
		# the following script handles ppc64le automagically !!
		curl -fsSL https://clis.ng.bluemix.net/install/linux | sh
		rm -f icp-linux-${systemArch}
		wget https://localhost:8443/api/cli/icp-linux-${systemArch} --no-check-certificate
		bx plugin install -f icp-linux-${systemArch}
	fi
	echo "run bx pr login"
	bx pr login -a https://localhost:8443 --skip-ssl-validation -u ${admin_user} -p ${admin_password} -c id-${cluster_name}-account
fi

if which cloudctl; then
    #echo "cloudctl login -a https://${host}:8443 --skip-ssl-validation -u ${admin_user} -p ** -c id-${cluster_name}-account -n kube-system"
	#cloudctl login -a https://${host}:8443 --skip-ssl-validation -u ${admin_user} -p ${admin_password} -c id-${cluster_name}-account -n kube-system

	#cloudctl login
    echo "cloudctl login -u ${admin_user} -p ****** -a https://${cluster_name}:8443 -n kube-system --skip-ssl-validation"
    sudo cloudctl login -u ${admin_user} -p ${admin_password} -a https://${cluster_name}:8443 -n kube-system --skip-ssl-validation

fi


echo "kubectl create secret tls ${helm_secret} --key ~/.helm/key.pem --cert ~/.helm/cert.pem -n kube-system"
sudo kubectl create secret tls ${helm_secret} --key ~/.helm/key.pem  --cert ~/.helm/cert.pem -n kube-system