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
icp_version=$5
mycluster=$6

# CLIs should be installed
if [[ "${icp_version}" == "2.1.0.3" ]]; then
    sudo bx pr login -a https://localhost:8443 --skip-ssl-validation -u ${admin_user} -p ${admin_password} -c id-${mycluster}-account
    sudo bx pr delete-helm-chart --name ibm-mcm-prod
    sudo bx pr delete-helm-chart --name ibm-mcmk-prod
else
    sudo cloudctl login -a https://${host}:8443 --skip-ssl-validation -u ${admin_user} -p ${admin_password} -c id-${mycluster}-account -n kube-system
    sudo cloudctl catalog delete-chart --name ibm-mcm-prod
    sudo cloudctl catalog delete-chart --name ibm-mcmk-prod
fi

#kubectl delete secret ${helm_secret} -n kube-system
