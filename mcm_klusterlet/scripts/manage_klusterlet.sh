#!/bin/bash

MCM_TAG=latest
while test $# -gt 0; do
  [[ $1 =~ ^-a|--action ]]  && { ACTION="${2}"; shift 2; continue; };
  [[ $1 =~ ^-c|--cluster ]] && { CLUSTER_NAME="${2}"; shift 2; continue; };
  [[ $1 =~ ^-m|--mcmtag ]]  && { MCM_TAG="${2}"; shift 2; continue; };
  [[ $1 =~ ^-s|--service ]] && { KUBE_SERVICE="${2}"; shift 2; continue; };
  [[ $1 =~ ^-w|--workdir ]] && { WORK_DIR="${2}"; shift 2; continue; };
  break;
done
DETAILS_FILE=${WORK_DIR}/details.txt
MCM_IMAGE=ibmcom/mcm-inception-amd64


function pullImage() {
    echo "Pulling image ${MCM_IMAGE}:${MCM_TAG} from repository..."
    sudo docker pull ${MCM_IMAGE}:${MCM_TAG}
}

function prepareClusterDir() {
    cd ${WORK_DIR}

    # Prepare the directory to be used by the MCM inception container
    echo "Preparing directory ${WORK_DIR}/cluster for MCM inception container..."
    sudo rm -rf ${WORK_DIR}/cluster
    sudo docker run -v $(pwd):/data -e LICENSE=accept \
            ${MCM_IMAGE}:${MCM_TAG} cp -r /installer/cluster.${KUBE_SERVICE} /data/cluster
}

function installKlusterlet() {
    cd ${WORK_DIR}/cluster

    echo "Installing the MCM klusterlet into the kubernetes service cluster..."
    sudo docker run --net=host -t -e LICENSE=accept \
            -v "$(pwd)":/installer/cluster ${MCM_IMAGE}:${MCM_TAG} install-mcm-klusterlet -v
}

function uninstallKlusterlet() {
    cd ${WORK_DIR}/cluster

    echo "Uninstalling the MCM klusterlet from the kubernetes service cluster..."
    sudo docker run --net=host -t -e LICENSE=accept \
            -v "$(pwd)":/installer/cluster ${MCM_IMAGE}:${MCM_TAG} uninstall-mcm-klusterlet -v
}


function verifyMcmControllerInformation() {
    MCM_ENDPOINT=$(cat ${DETAILS_FILE} | awk '/<MCMENDPOINT>/{text=1;next}/<\/MCMENDPOINT>/{text=0}text' | awk '{$1=$1};1')
    if [ -z "$(echo "${MCM_ENDPOINT}" | tr -d '[:space:]')" ]; then
        echo "MCM Controller endpoint is not available"
        exit 1
    fi
    MCM_TOKEN=$(cat ${DETAILS_FILE} | awk '/<MCMTOKEN>/{text=1;next}/<\/MCMTOKEN>/{text=0}text' | awk '{$1=$1};1')
    if [ -z "$(echo "${MCM_TOKEN}" | tr -d '[:space:]')" ]; then
        echo "MCM Controller token is not available"
        exit 1
    fi
}

function verifyIksInformation() {
    KUBECONFIG=$(cat ${DETAILS_FILE} | awk '/<KUBECONFIG>/{text=1;next}/<\/KUBECONFIG>/{text=0}text')
    if [ -z "$(echo "${KUBECONFIG}" | tr -d '[:space:]')" ]; then
        echo "IKS cluster identification details are not available"
        exit 1
    fi
    CA_CERTIFICATE=$(cat ${DETAILS_FILE} | awk '/<CACERTIFICATE>/{text=1;next}/<\/CACERTIFICATE>/{text=0}text')
    if [ -z "$(echo "${CA_CERTIFICATE}" | tr -d '[:space:]')" ]; then
        echo "IKS cluster certificate authority is not available"
        exit 1
    fi
    verifyMcmControllerInformation
}

function setIksKlusterletConfiguration() {
    echo "Parsing IKS identification details from kubeconfig data..."
    cluster=$(echo "${KUBECONFIG}" | grep "cluster: .*" | cut -f2 -d':' | awk '{$1=$1};1')
    owner=$(echo "${KUBECONFIG}"   | grep "user: .*"    | cut -f2 -d':' | awk '{$1=$1};1')
    namespace=$(echo "mcm-${CLUSTER_NAME}" | tr '[:upper:]' '[:lower:]')

    echo "Applying IKS details to MCM configuration file..."
    sudo sed -i -e "s!cluster-name:.*!cluster-name: ${cluster}!" \
                -e "s!cluster-namespace:.*!cluster-namespace: ${namespace}!" \
                -e "s!owner:.*!owner: \'${owner}\'!" \
                -e "s!hub-k8s-endpoint:.*!hub-k8s-endpoint: ${MCM_ENDPOINT}!" \
                -e "s!hub-k8s-token:.*!hub-k8s-token: ${MCM_TOKEN}!" ${WORK_DIR}/cluster/config.yaml
     
               
    cd ${WORK_DIR}
    echo "Creating IKS kubeconfig file..."
    kubeFile=./kube-${CLUSTER_NAME}.yml
    sudo echo "${KUBECONFIG}" > ${kubeFile}
    
    echo "Creating IKS certificate authority file..."
    certFile=$(grep certificate-authority ${kubeFile} | cut -f2 -d':' | awk '{$1=$1};1')
    sudo echo "${CA_CERTIFICATE}" > ./${certFile}

    echo "Creating ZIP file containing IKS cluster access credentials..."
    sudo zip ./kubeconfig.zip ${kubeFile} ${certFile}
    sudo mv -f ./kubeconfig.zip ./cluster/kubeconfig
}


function verifyAksInformation() {
    KUBECONFIG=$(cat ${DETAILS_FILE} | awk '/<KUBECONFIG>/{text=1;next}/<\/KUBECONFIG>/{text=0}text')
    if [ -z "$(echo "${KUBECONFIG}" | tr -d '[:space:]')" ]; then
        echo "AKS cluster identification details are not available"
        exit 1
    fi
    LOCATION=$(cat ${DETAILS_FILE} | awk '/<LOCATION>/{text=1;next}/<\/LOCATION>/{text=0}text')
    if [ -z "$(echo "${LOCATION}" | tr -d '[:space:]')" ]; then
        echo "AKS cluster location is not available"
        exit 1
    fi
    verifyMcmControllerInformation
}

function setAksKlusterletConfiguration() {
    echo "Parsing AKS identification details from kubeconfig data..."
    cluster=$(echo "${KUBECONFIG}" | grep "cluster: .*" | cut -f2 -d':' | awk '{$1=$1};1')
    owner=$(echo "${KUBECONFIG}"   | grep "user: .*"    | cut -f2 -d':' | awk '{$1=$1};1')
    namespace=$(echo "mcm-${CLUSTER_NAME}" | tr '[:upper:]' '[:lower:]')

    echo "Applying AKS details to MCM configuration file..."
    sudo sed -i -e "s!cluster-name:.*!cluster-name: ${cluster}!" \
                -e "s!cluster-namespace:.*!cluster-namespace: ${namespace}!" \
                -e "s!location:.*!location: ${LOCATION}!" \
                -e "s!owner:.*!owner: \'${owner}\'!" \
                -e "s!hub-k8s-endpoint:.*!hub-k8s-endpoint: ${MCM_ENDPOINT}!" \
                -e "s!hub-k8s-token:.*!hub-k8s-token: ${MCM_TOKEN}!" ${WORK_DIR}/cluster/config.yaml

    echo "Setting kubeconfig for MCM klusterlet management..."
    sudo echo "${KUBECONFIG}" > ${WORK_DIR}/cluster/kubeconfig
}


function verifyGkeInformation() {
    ACCOUNTKEY=$(cat ${DETAILS_FILE} | awk '/<ACCOUNTKEY>/{text=1;next}/<\/ACCOUNTKEY>/{text=0}text')
    if [ -z "$(echo "${ACCOUNTKEY}" | tr -d '[:space:]')" ]; then
        echo "Google Cloud service account key is not available"
        exit 1
    fi
    PROJECT=$(cat ${DETAILS_FILE} | awk '/<PROJECT>/{text=1;next}/<\/PROJECT>/{text=0}text')
    if [ -z "$(echo "${PROJECT}" | tr -d '[:space:]')" ]; then
        echo "GKE cluster project is not available"
        exit 1
    fi
    LOCATION=$(cat ${DETAILS_FILE} | awk '/<LOCATION>/{text=1;next}/<\/LOCATION>/{text=0}text')
    if [ -z "$(echo "${LOCATION}" | tr -d '[:space:]')" ]; then
        echo "GKE cluster location is not available"
        exit 1
    fi
    verifyMcmControllerInformation
}

function setGkeKlusterletConfiguration() {
    echo "Parsing GKE identification details from cluster data..."
    cluster="${CLUSTER_NAME}"
    owner="${KUBE_SERVICE}_${PROJECT}_${LOCATION}_${CLUSTER_NAME}"
    namespace=$(echo "mcm-${CLUSTER_NAME}" | tr '[:upper:]' '[:lower:]')

    echo "Applying GKE details to MCM configuration file..."
    sudo sed -i -e "s!cluster-name:.*!cluster-name: ${cluster}!" \
                -e "s!zone:.*!zone: ${LOCATION}!" \
                -e "s!project:.*!project: ${PROJECT}!" \
                -e "s!cluster-namespace:.*!cluster-namespace: ${namespace}!" \
                -e "s!owner:.*!owner: \'${owner}\'!" \
                -e "s!hub-k8s-endpoint:.*!hub-k8s-endpoint: ${MCM_ENDPOINT}!" \
                -e "s!hub-k8s-token:.*!hub-k8s-token: ${MCM_TOKEN}!" ${WORK_DIR}/cluster/config.yaml

    echo "Setting service account key for MCM klusterlet management..."
    sudo echo "${ACCOUNTKEY}" > ${WORK_DIR}/cluster/gke-sa-key.json
}


function verifyEksInformation() {
    LOCATION=$(cat ${DETAILS_FILE} | awk '/<LOCATION>/{text=1;next}/<\/LOCATION>/{text=0}text')
    if [ -z "$(echo "${LOCATION}" | tr -d '[:space:]')" ]; then
        echo "EKS cluster region is not available"
        exit 1
    fi
    credentials=$(cat ${DETAILS_FILE} | awk '/<CREDENTIALS>/{text=1;next}/<\/CREDENTIALS>/{text=0}text')
    if [ -z "$(echo "${credentials}" | tr -d '[:space:]')" ]; then
        echo "Amazon EC2 access key ID is not available"
        exit 1
    else
        ACCESSKEY=$(echo ${credentials} | cut -f1 -d';')
        KEYSECRET=$(echo ${credentials} | cut -f2 -d';')
    fi
    verifyMcmControllerInformation
}

function setEksKlusterletConfiguration() {
    echo "Parsing EKS identification details from cluster data..."
    cluster="${CLUSTER_NAME}"
    namespace=$(echo "mcm-${CLUSTER_NAME}" | tr '[:upper:]' '[:lower:]')

    echo "Applying EKS details to MCM configuration file..."
    sudo sed -i -e "s!aws_access_key_id:.*!aws_access_key_id: ${ACCESSKEY}!" \
                -e "s!aws_secret_access_key:.*!aws_secret_access_key: ${KEYSECRET}!" \
                -e "s!aws_region:.*!aws_region: ${LOCATION}!" \
                -e "s!eks-cluster:.*!eks-cluster: ${cluster}!" \
                -e "s!cluster-name:.*!cluster-name: ${cluster}!" \
                -e "s!cluster-namespace:.*!cluster-namespace: ${namespace}!" \
                -e "s!hub-k8s-endpoint:.*!hub-k8s-endpoint: ${MCM_ENDPOINT}!" \
                -e "s!hub-k8s-token:.*!hub-k8s-token: ${MCM_TOKEN}!" ${WORK_DIR}/cluster/config.yaml
}


## Perform setup tasks
if [ "${KUBE_SERVICE}" == "iks" ]; then
    echo "Preparing for MCM access to the IBM Cloud IKS cluster..."
    verifyIksInformation
    pullImage
    prepareClusterDir
    setIksKlusterletConfiguration
elif [ "${KUBE_SERVICE}" == "aks" ]; then
    echo "Preparing for MCM access to the Microsoft Azure AKS cluster..."
    verifyAksInformation
    pullImage
    prepareClusterDir
    setAksKlusterletConfiguration
elif [ "${KUBE_SERVICE}" == "gke" ]; then
    echo "Preparing for MCM access to the Google Cloud GKE cluster..."
    verifyGkeInformation
    pullImage
    prepareClusterDir
    setGkeKlusterletConfiguration
elif [ "${KUBE_SERVICE}" == "eks" ]; then
    echo "Preparing for MCM access to the Amazon EC2 EKS cluster..."
    verifyEksInformation
    pullImage
    prepareClusterDir
    setEksKlusterletConfiguration
else 
    echo "Unsupported kubernetes service - ${KUBE_SERVICE}; Exiting."
    exit 1
fi

## Perform requested action
if [ "${ACTION}" == "install" ]; then
    installKlusterlet
elif [ "${ACTION}" == "uninstall" ]; then
    uninstallKlusterlet
fi
