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
admin_user=$2
admin_password=$3
host=$4
mycluster=$5

  if ! [ $(whoami) == 'root' ]
  then
    sudo chown $(whoami) /home/icpdeploy/.kube/config
  fi


# CLIs should be installed
sudo cloudctl login -a https://${host}:8443 --skip-ssl-validation -u ${admin_user} -p ${admin_password} -c id-${mycluster}-account -n kube-system
sudo cloudctl catalog delete-chart --name ibm-mcm-prod
sudo cloudctl catalog delete-chart --name ibm-mcmk-prod

if sudo kubectl get secret ${helm_secret}; then
	sudo kubectl delete secret ${helm_secret} -n kube-system
fi	
