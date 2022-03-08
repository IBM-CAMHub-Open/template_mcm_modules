#!/bin/bash
##------------------------------------------------------------------------------
## Licensed Materials - Property of IBM
## 5737-E67
## (C) Copyright IBM Corporation 2020 All Rights Reserved.
## US Government Users Restricted Rights - Use, duplication or
## disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
##------------------------------------------------------------------------------
## This script is used to obtain an authorization token for a specific
## Kubernetes cluster.
##
## Supported Kubernetes clusters include:
##   - Microsoft Azure Kubernetes Service (AKS)
##   - Amazon Elastic Kubernetes Service (EKS)
##   - Google Kubernetes Engine (GKE)
##   - IBM Cloud Kubernetes Service (IKS)
##   - IBM Cloud Private (ICP)
##   - IBM Cloud Private with Openshift (OCP)
##
## Details pertaining to the actions to be taken and target cluster to be
## managed should be provided via the following command-line parameters or <environment variable>:
## Required for all cluster types:
##   -cn|--clustername <CLUSTER_NAME>               Name of the target cluster
##   -ct|--clustertype <CLUSTER_TYPE>               Type of cluser to be targeted; Valid values include (aks, eks, gke, iks)
##   -cf|--credfile <CREDENTIALS_FILE>              Path/name of file in which cluster access credentials will be recorded
##   -wd|--workdir <WORK_DIR>                       Directory where temporary work files will be created during the action
## For ICP:
##   -is|--icpserverurl <ICP_URL>                   URL (including port) of the ICP server
##   -iu|--icpuser <ICP_ADMIN_USER>                 Name of the ICP administration user
##   -ip|--icppassword <ICP_ADMIN_PASSWORD>         Password used to authenticate with the ICP server
## For OCP:
##   -os|--ocpserverurl <OCP_URL>                   URL (including port) of the OCP server
##   -oa|--ocpoauthurl <OCP_OAUTH_URL>              URL (including port) of the OCP OAUTH server
##   -ou|--ocpuser <OCP_ADMIN_USER>                 Name of the OCP administration user
##   -op|--ocppassword <OCP_ADMIN_PASSWORD>         Password used to authenticate with the OCP server
## For AKS, EKS, GKE, IKS:
##   -kc|--kubeconfig <CLUSTER_CONFIG_FILE>         Path to file of the target cluster's KUBECONFIG file
## For IKS:
##   -ca|--ikscacert <CLUSTER_CA_CERTIFICATE_FILE>  Path to file of the target cluster's CA certificate (Base64 encoded); Applicable for IKS
## For EKS:
##   -ek|--ekskeyid <ACCESS_KEY_ID>                 Access Key ID; Used to authenticate with EKS
##   -es|--ekssecret <SECRET_ACCESS_KEY>            Secret Access key; Used to authenticate with EKS
##   -cr|--clusterregion <CLUSTER_REGION>           Name of the region containing the target cluster; Used to authenticate with EKS
## For GKE:
##   -gc|--gkecreds <SERVICE_ACCOUNT_CREDENTIALS>   Credentials (Base64 encoded) for the service account; Used to authenticate with GKE cluster
##------------------------------------------------------------------------------

set -e
trap cleanup KILL ERR QUIT TERM INT EXIT

## Perform cleanup tasks prior to exit
function cleanup() {
    rm -f ${KUBECONFIG_FILE}
    if [ "${CLUSTER_TYPE}" == "gke" ]; then
        echo "Performing cleanup tasks for the Google Cloud (GKE) cluster..."
        gcloudLogout
    fi
}

## Download and install the cloudctl utility from the ICP server
function installIcpCloudctlLocally() {
    if [ ! -x ${WORK_DIR}/bin/icp-cloudctl ]; then
        echo "Installing cloudctl into ${WORK_DIR}..."
        wget --quiet --no-check-certificate ${ICP_URL}/api/cli/cloudctl-linux-${ARCH} -P ${WORK_DIR}/bin
        mv ${WORK_DIR}/bin/cloudctl-linux-${ARCH} ${WORK_DIR}/bin/icp-cloudctl
        chmod +x ${WORK_DIR}/bin/icp-cloudctl
    else
        echo "icp-cloudctl has already been installed; No action taken"
    fi
}

## Download and install the kubectl utility used to import/remove the managed cluster
function installKubectlLocally() {
    ## This script should be running with a unique HOME directory; Initialize '.kube' directory
    rm -rf   ${HOME}/.kube
    mkdir -p ${HOME}/.kube

    ## Install kubectl, if necessary
    if [ ! -x ${WORK_DIR}/bin/kubectl ]; then
        kversion=$(wget -qO- https://storage.googleapis.com/kubernetes-release/release/stable.txt)

        echo "Installing kubectl (version ${kversion}) into ${WORK_DIR}..."
        wget --quiet https://storage.googleapis.com/kubernetes-release/release/${kversion}/bin/linux/${ARCH}/kubectl -P ${WORK_DIR}/bin
        chmod +x ${WORK_DIR}/bin/kubectl
    else
        echo "kubectl has already been installed; No action taken"
    fi
}

## Download and install AWS tool used to authenticate with the EKS cluster
function installAwsLocally() {
    if [ ! -x ${WORK_DIR}/bin/aws-iam-authenticator ]; then
        echo "Installing AWS IAM Authenticator into ${WORK_DIR}..."
        wget --quiet https://amazon-eks.s3-us-west-2.amazonaws.com/1.13.7/2019-06-11/bin/linux/${ARCH}/aws-iam-authenticator -P ${WORK_DIR}/bin
        chmod +x ${WORK_DIR}/bin/aws-iam-authenticator
        export AWS_ACCESS_KEY_ID=${ACCESS_KEY_ID}
        export AWS_SECRET_ACCESS_KEY=${SECRET_ACCESS_KEY}
        export AWS_DEFAULT_REGION=${CLUSTER_REGION}
        aws-iam-authenticator version
        echo "AWS IAM Authenticator has been successfully installed"
    else
        aws-iam-authenticator version
        echo "AWS IAM Authenticator has already been installed; No action taken"
    fi
}

## Download and install Google Cloud tool used to authenticate with the GKE cluster
function installGcloudLocally() {
    if [ ! -x ${WORK_DIR}/bin/gcloud ]; then
        echo "Installing Google Cloud CLI into ${WORK_DIR}..."
        mkdir -p ${WORK_DIR}/.gke
        rm -rf ${WORK_DIR}/google-cloud-sdk*
        wget --quiet https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-sdk-254.0.0-linux-x86_64.tar.gz -P ${WORK_DIR}
        tar -zxvf ${WORK_DIR}/google-cloud-sdk-254.0.0-linux-x86_64.tar.gz --directory ${WORK_DIR}

        gcloud version
        echo "Google Cloud CLI has been successfully installed"
    else
        gcloud version
        echo "Google Cloud CLI has already been installed; No action taken"
    fi
}


## Verify the information needed to access the target cluster
function verifyTargetClusterInformation() {
    installKubectlLocally

    ## KUBECONFIG file provided; Verify cloud-specific details
    if [ "${CLUSTER_TYPE}" == "icp" ]; then
        verifyIcpInformation
        installIcpCloudctlLocally
        icpClusterLogin
    elif [ "${CLUSTER_TYPE}" == "ocp" ]; then
        verifyOcpInformation
        ocpClusterLogin
    elif [ "${CLUSTER_TYPE}" == "iks" ]; then
        verifyIksInformation
	elif [ "${CLUSTER_TYPE}" == "roks" ]; then
        verifyROKSInformation        
    elif [ "${CLUSTER_TYPE}" == "aks" ]; then
        verifyAksInformation
    elif [ "${CLUSTER_TYPE}" == "eks" ]; then
        verifyEksInformation
        installAwsLocally
    elif [ "${CLUSTER_TYPE}" == "gke" ]; then
        export PATH=${WORK_DIR}/google-cloud-sdk/bin:${PATH}
        installGcloudLocally
        verifyGkeInformation
        gcloudLogin
    else 
        echo "Unsupported Kubernetes service - ${CLUSTER_TYPE}; Exiting."
        exit 1
    fi

    verifyTargetClusterAccess
    parseClusterCredentials
}

## Verify the target cluster can be accessed
function verifyTargetClusterAccess() {
    set +e
    echo "Verifying access to target cluster..."
    export KUBECONFIG=${KUBECONFIG_FILE}
    ${WORK_DIR}/bin/kubectl get nodes
    if [ $? -ne 0 ]; then
        echo "${WARN_ON}Unable to access the target cluster; Exiting...${WARN_OFF}"
        exit 1
    fi
    unset KUBECONFIG
    set -e
}

## Parse the cluster credentials from the kubeconfig file
function parseClusterCredentials() {
    echo "Parsing verified credentials from kubeconfig data..."
    CREDENTIALS_CLUSTER=$(sed -n '/clusters:/,//p' ${KUBECONFIG_FILE} | grep "name: .*" | head -n 1 | awk -F ' +' '{print $3}' | awk '{$1=$1};1' | cut -f2 -d'/')
    CREDENTIALS_ENDPOINT=$(sed -n '/clusters:/,//p' ${KUBECONFIG_FILE} | grep "server: .*" | head -n 1 | awk -F ' +' '{print $3}' | awk '{$1=$1};1')
    CREDENTIALS_USER=$(sed -n '/users:/,//p' ${KUBECONFIG_FILE} | grep "\- name: .*" | head -n 1 | awk -F ' +' '{print $3}' | awk '{$1=$1};1' | cut -f2 -d'/')
    
    if [ "${CLUSTER_TYPE}" == "iks" ]; then
        CREDENTIALS_TOKEN=$(sed -n '/users:/,//p' ${KUBECONFIG_FILE} | grep "id-token: .*" | head -n 1 | awk -F ' +' '{print $3}' | awk '{$1=$1};1')
    elif [ "${CLUSTER_TYPE}" == "gke" ]; then
        CREDENTIALS_TOKEN=$(sed -n '/users:/,//p' ${KUBECONFIG_FILE} | grep "access-token: .*" | head -n 1 | awk -F ' +' '{print $3}' | awk '{$1=$1};1')
    elif [ "${CLUSTER_TYPE}" == "eks" ]; then
        CREDENTIALS_TOKEN=$(aws-iam-authenticator token -i ${CREDENTIALS_CLUSTER} | jq -r '.status.token')
    else
        CREDENTIALS_TOKEN=$(sed -n '/users:/,//p' ${KUBECONFIG_FILE} | grep "token: .*" | head -n 1 | awk -F ' +' '{print $3}' | awk '{$1=$1};1')
    fi

    echo "Recording verified credentials..."
    jq -n --arg c_cluster  "${CREDENTIALS_CLUSTER}"   \
          --arg c_endpoint "${CREDENTIALS_ENDPOINT}"  \
          --arg c_user     "${CREDENTIALS_USER}"      \
          --arg c_token    "${CREDENTIALS_TOKEN}"     \
          '{cluster:($c_cluster), endpoint:($c_endpoint), user:($c_user), token:($c_token)}' > ${CREDENTIALS_FILE}
}

## Verify that required details pertaining to the IKS cluster have been provided
function verifyIksInformation() {
    # Verify cluster-specific information is provided via environment variables
    KUBECONFIG_TEXT=$(cat ${CLUSTER_CONFIG_FILE})
    if [ -z "$(echo "${KUBECONFIG_TEXT}" | tr -d '[:space:]')" ]; then
        echo "${WARN_ON}IKS cluster identification details are not available${WARN_OFF}"
        exit 1
    else
        echo "Creating kubeconfig file..."
        echo "${KUBECONFIG_TEXT}" > ${KUBECONFIG_FILE}
    fi
    CA_CERTIFICATE=$(cat ${CLUSTER_CA_CERTIFICATE_FILE})
    if [ -z "$(echo "${CA_CERTIFICATE}" | tr -d '[:space:]')" ]; then
        echo "${WARN_ON}IKS cluster certificate authority is not available${WARN_OFF}"
        exit 1
    else
        echo "Embedding CA certificate into IKS kubeconfig file..."
        sed -i -e "s|certificate-authority:.*|certificate-authority-data: ${CA_CERTIFICATE}|" ${KUBECONFIG_FILE}
    fi
}

## Verify that required details pertaining to the ROKS cluster have been provided
function verifyROKSInformation() {
    # Verify cluster-specific information is provided via environment variables
    KUBECONFIG_TEXT=$(cat ${CLUSTER_CONFIG_FILE})
    if [ -z "$(echo "${KUBECONFIG_TEXT}" | tr -d '[:space:]')" ]; then
        echo "${WARN_ON}IKS cluster identification details are not available${WARN_OFF}"
        exit 1
    else
        echo "Creating kubeconfig file..."
        echo "${KUBECONFIG_TEXT}" > ${KUBECONFIG_FILE}
    fi
}

## Verify that required details pertaining to the AKS cluster have been provided
function verifyAksInformation() {
    # Verify cluster-specific information is provided via environment variables
    KUBECONFIG_TEXT=$(cat ${CLUSTER_CONFIG_FILE})
    if [ -z "$(echo "${KUBECONFIG_TEXT}" | tr -d '[:space:]')" ]; then
        echo "${WARN_ON}AKS cluster identification details are not available${WARN_OFF}"
        exit 1
    else
        echo "Creating kubeconfig file..."
        echo "${KUBECONFIG_TEXT}" > ${KUBECONFIG_FILE}
    fi
}

## Verify that required details pertaining to the EKS cluster have been provided
function verifyEksInformation() {
    # Verify cluster-specific information is provided via environment variables
    KUBECONFIG_TEXT=$(cat ${CLUSTER_CONFIG_FILE})
    if [ -z "$(echo "${KUBECONFIG_TEXT}" | tr -d '[:space:]')" ]; then
        echo "${WARN_ON}EKS cluster identification details are not available${WARN_OFF}"
        exit 1
    else
        echo "Creating kubeconfig file..."
        echo "${KUBECONFIG_TEXT}" > ${KUBECONFIG_FILE}
    fi
    if [ -z "$(echo "${ACCESS_KEY_ID}" | tr -d '[:space:]')" ]; then
        echo "${WARN_ON}EKS access key ID is not available${WARN_OFF}"
        exit 1
    fi
    if [ -z "$(echo "${SECRET_ACCESS_KEY}" | tr -d '[:space:]')" ]; then
        echo "${WARN_ON}EKS secret access key is not available${WARN_OFF}"
        exit 1
    fi
    if [ -z "$(echo "${CLUSTER_REGION}" | tr -d '[:space:]')" ]; then
        echo "${WARN_ON}EKS region name is not available${WARN_OFF}"
        exit 1
    fi
}

## Verify that required details pertaining to the GKE cluster have been provided
function verifyGkeInformation() {
    # Verify cluster-specific information is provided via environment variables
    KUBECONFIG_TEXT=$(cat ${CLUSTER_CONFIG_FILE})
    if [ -z "$(echo "${KUBECONFIG_TEXT}" | tr -d '[:space:]')" ]; then
        echo "${WARN_ON}GKE cluster identification details are not available${WARN_OFF}"
        exit 1
    else
        echo "Creating kubeconfig file..."
        echo "${KUBECONFIG_TEXT}" > ${KUBECONFIG_FILE}
    fi
    if [ -z "$(echo "${SERVICE_ACCOUNT_CREDENTIALS}" | tr -d '[:space:]')" ]; then
        echo "${WARN_ON}GKE service account credentials are not available${WARN_OFF}"
        exit 1
    fi
}

## Authenticate with Google Cloud in order to perform operations against the GKE cluster
function gcloudLogin() {
    # Authenticate using the GKE service account credentials
    export CLOUDSDK_CONFIG=${WORK_DIR}/.gke
    echo "Authenticating with GKE..."
    acctCredentialsFile=${WORK_DIR}/gkeCredentials.json
    echo "${SERVICE_ACCOUNT_CREDENTIALS}" | base64 -d > ${acctCredentialsFile}
    gcloud auth activate-service-account --key-file ${acctCredentialsFile}
}

## Logout from Google Cloud after performing operations against the GKE cluster
function gcloudLogout() {
    # Revoke authorization for GKE access
    export CLOUDSDK_CONFIG=${WORK_DIR}/.gke
    echo "Revoking GKE access..."
    acctCredentialsFile=${WORK_DIR}/gkeCredentials.json
    echo "${SERVICE_ACCOUNT_CREDENTIALS}" | base64 -d > ${acctCredentialsFile}
    acctEmail=$(cat ${acctCredentialsFile} | grep client_email | cut -f4 -d'"')
    if [ -z "$(echo "${acctEmail}" | tr -d '[:space:]')" ]; then
        echo "Revoking gcloud access for all"
        gcloud auth revoke --all
    else
        echo "Revoking gcloud access for ${acctEmail}"
        gcloud auth revoke ${acctEmail}
    fi
}

## Verify that required details pertaining to the ICP server have been provided
function verifyIcpInformation() {
    if [ -z "$(echo "${ICP_URL}" | tr -d '[:space:]')" ]; then
        echo "${WARN_ON}ICP API URL is not available${WARN_OFF}"
        exit 1
    fi
    if [ -z "$(echo "${ICP_ADMIN_USER}" | tr -d '[:space:]')" ]; then
        echo "${WARN_ON}ICP admin username is not available${WARN_OFF}"
        exit 1
    fi
    if [ -z "$(echo "${ICP_ADMIN_PASSWORD}" | tr -d '[:space:]')" ]; then
        echo "${WARN_ON}ICP admin password is not available${WARN_OFF}"
        exit 1
    fi
}

## Authenticate with ICP server in order to obtain cluster-specific information
function icpClusterLogin() {
    echo "Logging into the ICP server..."
    mkdir -p ${WORK_DIR}/.helm
    export CLOUDCTL_HOME=${WORK_DIR}/.helm
    icp-cloudctl login -a ${ICP_URL} --skip-ssl-validation -u ${ICP_ADMIN_USER} -p ${ICP_ADMIN_PASSWORD} -n default

    ## Generate KUBECONFIG file to be used when accessing the target cluster
    ${WORK_DIR}/bin/kubectl config view --minify=true --flatten=true > ${KUBECONFIG_FILE}

    echo "Logging out of ICP server..."
    icp-cloudctl logout
}

## Verify that required details pertaining to the OCP server have been provided
function verifyOcpInformation() {
    if [ -z "$(echo "${OCP_URL}" | tr -d '[:space:]')" ]; then
        echo "${WARN_ON}OCP API URL is not available${WARN_OFF}"
        exit 1
    fi
    if [ -z "$(echo "${OCP_OAUTH_URL}" | tr -d '[:space:]')" ]; then
        echo "${WARN_ON}OCP OAUTH URL is not available; Using OCP API URL${WARN_OFF}"
        OCP_OAUTH_URL=${OCP_URL}
    fi
    if [ -z "$(echo "${OCP_ADMIN_USER}" | tr -d '[:space:]')" ]; then
        echo "${WARN_ON}OCP admin username is not available${WARN_OFF}"
        exit 1
    fi
    if [ -z "$(echo "${OCP_ADMIN_PASSWORD}" | tr -d '[:space:]')" ]; then
        echo "${WARN_ON}OCP admin password is not available${WARN_OFF}"
        exit 1
    fi
}

## Authenticate with OCP server in order to obtain cluster-specific information
function ocpClusterLogin() {
    set +e
    echo "Authenticating with OCP OAUTH server to obtain token for use with kubectl..."
    ocpToken=$(curl -u ${OCP_ADMIN_USER}:${OCP_ADMIN_PASSWORD} -kI "${OCP_OAUTH_URL}/oauth/authorize?client_id=openshift-challenging-client&response_type=token" | grep -oP "access_token=\K[^&]*")
    if [ $? -ne 0 ]; then
        echo "${WARN_ON}Unable to obtain access token for OCP cluster ${CLUSTER_NAME}"
        exit 1
    fi
    set -e
    
    ## Generate KUBECONFIG file to be used when accessing the target cluster
    ${WORK_DIR}/bin/kubectl config set-cluster     ${CLUSTER_NAME}   --insecure-skip-tls-verify=true --server=${OCP_URL}
    ${WORK_DIR}/bin/kubectl config set-credentials ${OCP_ADMIN_USER} --token=${ocpToken}
    ${WORK_DIR}/bin/kubectl config set-context     ${CLUSTER_NAME}   --user=${OCP_ADMIN_USER} --namespace=kube-system --cluster=${CLUSTER_NAME}
    ${WORK_DIR}/bin/kubectl config use-context     ${CLUSTER_NAME}
    ${WORK_DIR}/bin/kubectl config view --minify=true --flatten=true > ${KUBECONFIG_FILE}
}

## Perform the tasks required to complete the cluster management operation
function run() {
    ## Prepare work directory and install common utilities
    mkdir -p ${WORK_DIR}/bin
    export PATH=${WORK_DIR}/bin:${PATH}

    ## Check provided cluster information
    if [ -z "$(echo "${CLUSTER_TYPE}" | tr -d '[:space:]')" ]; then
        echo "${WARN_ON}Type of cluster to be managed has not been specified; Exiting...${WARN_OFF}"
        exit 1
    fi
    if [ "${CLUSTER_TYPE}" != "icp" ]; then
        if [ -z "$(echo "${CLUSTER_NAME}" | tr -d '[:space:]')" ]; then
            echo "${WARN_ON}Target cluster name was not provided${WARN_OFF}"
            exit 1
        fi
    fi

    ## Verify given cluster details and generate access credentials
    verifyTargetClusterInformation
}

##------------------------------------------------------------------------------------------------
##************************************************************************************************
##------------------------------------------------------------------------------------------------

## Gather information provided via the command line parameters
while test ${#} -gt 0; do
    [[ $1 =~ ^-ct|--clustertype ]]      && { CLUSTER_TYPE="${2}";                shift 2; continue; };
    [[ $1 =~ ^-wd|--workdir ]]          && { WORK_DIR="${2}";                    shift 2; continue; };
    [[ $1 =~ ^-cf|--credfile ]]         && { CREDENTIALS_FILE="${2}";            shift 2; continue; };

    [[ $1 =~ ^-cn|--clustername ]]      && { CLUSTER_NAME="${2}";                shift 2; continue; };
    [[ $1 =~ ^-kc|--kubeconfig ]]       && { CLUSTER_CONFIG_FILE="${2}";         shift 2; continue; };

    [[ $1 =~ ^-is|--icpserverurl ]]     && { ICP_URL="${2}";                     shift 2; continue; };
    [[ $1 =~ ^-iu|--icpuser ]]          && { ICP_ADMIN_USER="${2}";              shift 2; continue; };
    [[ $1 =~ ^-ip|--icppassword ]]      && { ICP_ADMIN_PASSWORD="${2}";          shift 2; continue; };

    [[ $1 =~ ^-os|--ocpserverurl ]]     && { OCP_URL="${2}";                     shift 2; continue; };
    [[ $1 =~ ^-oa|--ocpoauthurl ]]      && { OCP_OAUTH_URL="${2}";               shift 2; continue; };
    [[ $1 =~ ^-ou|--ocpuser ]]          && { OCP_ADMIN_USER="${2}";              shift 2; continue; };
    [[ $1 =~ ^-op|--ocppassword ]]      && { OCP_ADMIN_PASSWORD="${2}";          shift 2; continue; };
    
    [[ $1 =~ ^-ca|--ikscacert ]]        && { CLUSTER_CA_CERTIFICATE_FILE="${2}"; shift 2; continue; };  					  	
    [[ $1 =~ ^-cr|--clusterregion ]]    && { CLUSTER_REGION="${2}";              shift 2; continue; };
    [[ $1 =~ ^-ek|--ekskeyid ]]         && { ACCESS_KEY_ID="${2}";               shift 2; continue; };  					  	
    [[ $1 =~ ^-es|--ekssecret ]]        && { SECRET_ACCESS_KEY="${2}";           shift 2; continue; };  					  	
    [[ $1 =~ ^-gc|--gkecreds ]]         && { SERVICE_ACCOUNT_CREDENTIALS="${2}"; shift 2; continue; };  					  	
    break;
done
if [ -z "$(echo "${WORK_DIR}" | tr -d '[:space:]')" ]; then
    echo "${WARN_ON}Location of the work directory has not been specified; Exiting...${WARN_OFF}"
    exit 1
fi
if [ -z "$(echo "${CREDENTIALS_FILE}" | tr -d '[:space:]')" ]; then
    echo "${WARN_ON}Location of the credentials file to be created has not been specified; Exiting...${WARN_OFF}"
    exit 1
fi

## Prepare work directory
mkdir -p ${WORK_DIR}/bin
export PATH=${WORK_DIR}/bin:${PATH}

## Set default variable values
CREDENTIALS_CLUSTER=""
CREDENTIALS_ENDPOINT=""
CREDENTIALS_USER=""
CREDENTIALS_TOKEN=""
KUBECONFIG_FILE=${WORK_DIR}/kubeconfig.yaml
WARN_ON='\033[0;31m'
WARN_OFF='\033[0m'

ARCH="amd64"
CURRENTARCH=`arch`
if [[ "$CURRENTARCH" == "ppc64le" ]]
then
    ARCH="ppc64le"
fi
if [[ "$CURRENTARCH" == "s390x" ]]
then
    ARCH="s390x"
fi   

## Run the necessary action(s)
run
