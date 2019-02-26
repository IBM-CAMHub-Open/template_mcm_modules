#!/bin/bash

set -e

# Get script parameters
while test $# -gt 0; do
  [[ $1 =~ ^-c|--cluster ]] && { PARAM_CLUSTER_CA_NAME="${2}"; shift 2; continue; };
  [[ $1 =~ ^-r|--registry ]] && { PARAM_CLUSTER_REGISTRY_SERVER_NAME="${2}"; shift 2; continue; };
  [[ $1 =~ ^-n|--cluster_name ]] && { PARAM_CLUSTER_NAME="${2}"; shift 2; continue; };  
  [[ $1 =~ ^-t|--path ]] && { MCM_PATH="${2}"; shift 2; continue; };
  [[ $1 =~ ^-u|--user ]] && { PARAM_AUTH_USER="${2}"; shift 2; continue; };
  [[ $1 =~ ^-p|--password ]] && { PARAM_AUTH_PASSWORD="${2}"; shift 2; continue; };
  [[ $1 =~ ^-a|--archive ]] && { PARAM_MCM="${2}"; shift 2; continue; };
  break;
done

PARAM_PPA_ARCHIVE_NAME="$(basename ${PARAM_MCM})"

# docker login
echo "docker login -u ${PARAM_AUTH_USER} -p ****** ${PARAM_CLUSTER_REGISTRY_SERVER_NAME}:8500"
if sudo docker login -u ${PARAM_AUTH_USER} -p ${PARAM_AUTH_PASSWORD} ${PARAM_CLUSTER_REGISTRY_SERVER_NAME}:8500 ; then
    echo "docker login success"
else
   echo "docker login failed"
   exit 1
fi 

#cloudctl login
echo "cloudctl login -u ${PARAM_AUTH_USER} -p ****** -a https://${PARAM_CLUSTER_CA_NAME}:8443 -n kube-system -c id-${PARAM_CLUSTER_NAME}-account --skip-ssl-validation"
if sudo cloudctl login -u ${PARAM_AUTH_USER} -p ${PARAM_AUTH_PASSWORD} -a https://${PARAM_CLUSTER_CA_NAME}:8443 -n kube-system  -c id-${PARAM_CLUSTER_NAME}-account --skip-ssl-validation ; then
    echo "cloudctl login success"
else
   echo "cloudctl login failed"
   exit 1
fi 

#cloudctl load-ppa-archive
echo "cloudctl catalog load-ppa-archive -a $MCM_PATH/${PARAM_PPA_ARCHIVE_NAME} --registry ${PARAM_CLUSTER_REGISTRY_SERVER_NAME}:8500/kube-system"
if sudo cloudctl catalog load-ppa-archive -a $MCM_PATH/${PARAM_PPA_ARCHIVE_NAME} --registry ${PARAM_CLUSTER_REGISTRY_SERVER_NAME}:8500/kube-system ; then
    echo "cloudctl catalog load-ppa-archive success"
else
   echo "cloudctl catalog load-ppa-archive failed"
   exit 1
fi

#wait for the ibm-mcm-prod chart to become available 
n=0
exit_code=0
until [ $n -ge 5 ]
do
  sudo cloudctl catalog charts | grep ibm-mcm-prod && break 
  exit_code=$?
  n=$[$n+1]
  echo "waiting for ibm-mcm-prod...";
  sleep 5
done
if [ $exit_code -eq 0 ]; then
    echo "ibm-mcm-prod loaded successfully"
else
    echo "ibm-mcm-prod failed to load successfully"
    exit
fi

#wait for the ibm-mcmk-prod chart to become available 
n=0
exit_code=0
until [ $n -ge 5 ]
do
  sudo cloudctl catalog charts | grep ibm-mcmk-prod && break
  exit_code=$?
  n=$[$n+1]
  echo "waiting for ibm-mcmk-prod...";
  sleep 5
done
if [ $exit_code -eq 0 ]; then
    echo "ibm-mcmk-prod loaded successfully"
else
    echo "ibm-mcmk-prod failed to load successfully"
    exit
fi

rm -rf $MCM_PATH

## wait for the repo sync to finish. TODO: helm API?
sleep 30
