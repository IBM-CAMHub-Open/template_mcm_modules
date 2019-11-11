#!/bin/bash
##------------------------------------------------------------------------------
## This script is used to manage operations pertaining to the relationship
## between a MCM hub-cluster and clusters within a managed kubernetes service:
##   - Import a kubernetes cluster into the MCM hub-cluster
##   - Remove a kubernetes cluster from the MCM hub-cluster
##
## Supported Kubernetes Services include:
##   - Microsoft Azure Kubernetes Service (AKS)
##   - Amazon Elastic Kubernetes Service (EKS)
##   - Google Kubernetes Engine (GKE)
##   - IBM Cloud Kubernetes Service (IKS)
##
## Details pertaining to the kubernetes cluster to be imported/removed should
## be provided via the following environment variables:
##   - CLUSTER_CONFIG:      Contents of the cluster's KUBECONFIG file
##   - CLUSTER_NAME:        Name of the kubernetes cluster
##   - ICP_URL:             URL (including port) of the ICP server hosting the MCM hub-cluster
##   - ICP_ADMIN_USER:      Name of the ICP administration user
##   - ICP_ADMIN_PASSWORD:  Password used to authenticate with the ICP server
##   - MCM_ENDPOINT:        URL (including port) of the MCM hub-cluster
##
##   - CLUSTER_CA_CERTIFICATE:       The cluster's CA certificate; Applicable for IKS
##   - SERVICE_ACCOUNT_CREDENTIALS:  Credentials for the service account; Used to authenticate with GKE cluster
##   - ACCESS_KEY_ID:                Access Key ID; Used to authenticate with EKS
##   - SECRET_ACCESS_KEY:            Secret Access key; Used to authenticate with EKS
##   - CLUSTER_REGION:               Name of the region containing the cluster; Used to authenticate with EKS
##------------------------------------------------------------------------------

set -e
trap cleanup KILL ERR QUIT TERM INT EXIT

## Perform cleanup tasks prior to exit
function cleanup() {
    if [ "${ACTION}" == "import"  -a  "${IMPORT_STATUS}" == "attempted" ]; then
        echo "Unable to import the managed cluster; Performing clean up from failed attempt..."
        removeImportedCluster
    fi
    if [ "${KUBE_SERVICE}" == "gke" ]; then
        echo "Performing cleanup tasks for the Google Cloud (GKE) cluster..."
        gcloudLogout
    fi
}

## Download and install the cloudctl utility used to import/remove the managed cluster
function installCloudctlLocally() {
    if [ ! -x ${WORK_DIR}/bin/cloudctl ]; then
        echo "Installing cloudctl into ${WORK_DIR}..."
        curl -kLo ${WORK_DIR}/bin/cloudctl ${ICP_URL}/api/cli/cloudctl-linux-amd64
        chmod +x ${WORK_DIR}/bin/cloudctl
    else
        echo "cloudctl has already been installed; No action taken"
    fi
}

## Download and install the kubectl utility used to import/remove the managed cluster
function installKubectlLocally() {
    if [ ! -x ${WORK_DIR}/bin/kubectl ]; then
        kversion=$(wget -qO- https://storage.googleapis.com/kubernetes-release/release/stable.txt)

        echo "Installing kubectl (version ${kversion}) into ${WORK_DIR}..."
        wget --quiet https://storage.googleapis.com/kubernetes-release/release/${kversion}/bin/linux/amd64/kubectl -P ${WORK_DIR}/bin
        chmod +x ${WORK_DIR}/bin/kubectl

        mkdir -p ${HOME}/.kube
    else
        echo "kubectl has already been installed; No action taken"
    fi
}

## Download and install AWS tool used to authenticate with the EKS cluster
function installAwsLocally() {
    if [ ! -x ${WORK_DIR}/bin/aws-iam-authenticator ]; then
        echo "Installing AWS IAM Authenticator into ${WORK_DIR}..."
        wget --quiet https://amazon-eks.s3-us-west-2.amazonaws.com/1.13.7/2019-06-11/bin/linux/amd64/aws-iam-authenticator -P ${WORK_DIR}/bin
        chmod +x ${WORK_DIR}/bin/aws-iam-authenticator
        export AWS_ACCESS_KEY_ID=${ACCESS_KEY_ID}
        export AWS_SECRET_ACCESS_KEY=${SECRET_ACCESS_KEY}
        export AWS_DEFAULT_REGION=${REGION_NAME}
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

## Verify that required details pertaining to the MCM hub-cluster have been provided
function verifyMcmControllerInformation() {
    if [ -z "$(echo "${ICP_URL}" | tr -d '[:space:]')" ]; then
        echo "ICP API URL is not available"
        exit 1
    fi
    if [ -z "$(echo "${ICP_ADMIN_USER}" | tr -d '[:space:]')" ]; then
        echo "ICP admin username is not available"
        exit 1
    fi
    if [ -z "$(echo "${ICP_ADMIN_PASSWORD}" | tr -d '[:space:]')" ]; then
        echo "ICP admin password is not available"
        exit 1
    fi
    if [ -z "$(echo "${MCM_ENDPOINT}" | tr -d '[:space:]')" ]; then
        echo "MCM hub cluster endpoint is not available"
        exit 1
    fi
}

## Verify that required details pertaining to the IKS cluster have been provided
function verifyIksInformation() {
    # Verify cluster-specific information is provided via environment variables
    KUBECONFIG_TEXT=${CLUSTER_CONFIG}
    if [ -z "$(echo "${KUBECONFIG_TEXT}" | tr -d '[:space:]')" ]; then
        echo "IKS cluster identification details are not available"
        exit 1
    else
        echo "Creating kubeconfig file..."
        echo "${KUBECONFIG_TEXT}" > ${KUBECONFIG_FILE}
    fi
    CA_CERTIFICATE=${CLUSTER_CA_CERTIFICATE}
    if [ -z "$(echo "${CA_CERTIFICATE}" | tr -d '[:space:]')" ]; then
        echo "IKS cluster certificate authority is not available"
        exit 1
    else
        echo "Creating IKS certificate authority file..."
        certFileName=$(grep certificate-authority ${KUBECONFIG_FILE} | cut -f2 -d':' | awk '{$1=$1};1')
        echo "${CA_CERTIFICATE}" > ${WORK_DIR}/${certFileName}
    fi

    # Verify the MCM hub cluster information was provided
    verifyMcmControllerInformation
}

## Extract administrative details pertaining to the IKS cluster and apply to the import template
function setIksImportDetails() {
    # Set container runtime utilized by the IKS cluster.  MCM currently supports: docker, containerd
    CLUSTER_CONTAINER_RUNTIME="containerd"

    echo "Parsing IKS identification details from kubeconfig data..."
    CLUSTER_ADMIN_USER=$(sed -n '/users:/,//p' ${KUBECONFIG_FILE} | grep "\- name: .*" | head -n 1 | cut -f2 -d':' | awk '{$1=$1};1')
    CLUSTER_CONTEXT=$(cat "${KUBECONFIG_FILE}" | grep "current-context: .*" | cut -f2 -d':' | awk '{$1=$1};1')

    # Generate the import template file
    generateImportTemplate
}

## Verify that required details pertaining to the AKS cluster have been provided
function verifyAksInformation() {
    # Verify cluster-specific information is provided via environment variables
    KUBECONFIG_TEXT=${CLUSTER_CONFIG}
    if [ -z "$(echo "${KUBECONFIG_TEXT}" | tr -d '[:space:]')" ]; then
        echo "AKS cluster identification details are not available"
        exit 1
    else
        echo "Creating kubeconfig file..."
        echo "${KUBECONFIG_TEXT}" > ${KUBECONFIG_FILE}
    fi

    # Verify the MCM hub cluster information was provided
    verifyMcmControllerInformation
}

## Extract administrative details pertaining to the IKS cluster and apply to the import template
function setAksImportDetails() {
    # Set container runtime utilized by the AKS cluster.  MCM currently supports: docker, containerd
    containerRuntime="docker"

    echo "Parsing AKS identification details from kubeconfig data..."
    CLUSTER_ADMIN_USER=$(sed -n '/users:/,//p' ${KUBECONFIG_FILE} | grep "\- name: .*" | head -n 1 | cut -f2 -d':' | awk '{$1=$1};1')
    CLUSTER_CONTEXT=$(cat "${KUBECONFIG_FILE}" | grep "current-context: .*" | cut -f2 -d':' | awk '{$1=$1};1')

    # Generate the import template file
    generateImportTemplate
}

## Verify that required details pertaining to the EKS cluster have been provided
function verifyEksInformation() {
    # Verify cluster-specific information is provided via environment variables
    KUBECONFIG_TEXT=${CLUSTER_CONFIG}
    if [ -z "$(echo "${KUBECONFIG_TEXT}" | tr -d '[:space:]')" ]; then
        echo "EKS cluster identification details are not available"
        exit 1
    else
        echo "Creating kubeconfig file..."
        echo "${KUBECONFIG_TEXT}" > ${KUBECONFIG_FILE}
    fi
    ACCESS_KEY=${ACCESS_KEY_ID}
    if [ -z "$(echo "${ACCESS_KEY}" | tr -d '[:space:]')" ]; then
        echo "EKS access key ID is not available"
        exit 1
    fi
    ACCESS_SECRET=${SECRET_ACCESS_KEY}
    if [ -z "$(echo "${ACCESS_SECRET}" | tr -d '[:space:]')" ]; then
        echo "EKS secret access key is not available"
        exit 1
    fi
    REGION_NAME=${CLUSTER_REGION}
    if [ -z "$(echo "${REGION_NAME}" | tr -d '[:space:]')" ]; then
        echo "EKS region name is not available"
        exit 1
    fi

    # Verify the MCM hub cluster information was provided
    verifyMcmControllerInformation
}

## Extract administrative details pertaining to the EKS cluster and apply to the import template
function setEksImportDetails() {
    # Set container runtime utilized by the EKS cluster.  MCM currently supports: docker, containerd
    containerRuntime="docker"

    echo "Parsing EKS identification details from kubeconfig data..."
    CLUSTER_ADMIN_USER=$(sed -n '/users:/,//p' ${KUBECONFIG_FILE} | grep "\- name: .*" | head -n 1 | awk '{$1=$1};1' | cut -f3 -d' ' | cut -f2 -d'/')
    CLUSTER_CONTEXT=$(cat "${KUBECONFIG_FILE}" | grep "current-context: .*" | awk '{$1=$1};1' | cut -f2 -d' ')

    # Generate the import template file
    generateImportTemplate
}

## Verify that required details pertaining to the GKE cluster have been provided
function verifyGkeInformation() {
    # Verify cluster-specific information is provided via environment variables
    KUBECONFIG_TEXT=${CLUSTER_CONFIG}
    if [ -z "$(echo "${KUBECONFIG_TEXT}" | tr -d '[:space:]')" ]; then
        echo "GKE cluster identification details are not available"
        exit 1
    else
        echo "Creating kubeconfig file..."
        echo "${KUBECONFIG_TEXT}" > ${KUBECONFIG_FILE}
    fi
    ACCOUNT_CREDENTIALS=${SERVICE_ACCOUNT_CREDENTIALS}
    if [ -z "$(echo "${ACCOUNT_CREDENTIALS}" | tr -d '[:space:]')" ]; then
        echo "GKE service account credentials are not available"
        exit 1
    fi

    # Verify the MCM hub cluster information was provided
    verifyMcmControllerInformation
}

## Extract administrative details pertaining to the GKE cluster and apply to the import template
function setGkeImportDetails() {
    # Set container runtime utilized by the GKE cluster.  MCM currently supports: docker, containerd
    containerRuntime="containerd"

    echo "Parsing GKE identification details from kubeconfig data..."
    CLUSTER_ADMIN_USER=$(sed -n '/users:/,//p' ${KUBECONFIG_FILE} | grep "\- name: .*" | head -n 1 | cut -f2 -d':' | awk '{$1=$1};1')
    CLUSTER_CONTEXT=$(cat "${KUBECONFIG_FILE}" | grep "current-context: .*" | cut -f2 -d':' | awk '{$1=$1};1')

    # Generate the import template file
    generateImportTemplate
}

## Authenticate with Google Cloud in order to perform operations against the GKE cluster
function gcloudLogin() {
    # Authenticate using the GKE service account credentials.  This will allow
    # the cloudctl command(s) to obtain and use a valid token for the kubernetes operations.
    echo "Authenticating with GKE..."
    acctCredentialsFile=${WORK_DIR}/gkeCredentials.json
    echo "${ACCOUNT_CREDENTIALS}" > ${acctCredentialsFile}
    gcloud auth activate-service-account --key-file ${acctCredentialsFile}
}

## Logout from Google Cloud after performing operations against the GKE cluster
function gcloudLogout() {
    # Revoke authorization for GKE access
    echo "Revoking GKE access..."
    acctCredentialsFile=${WORK_DIR}/gkeCredentials.json
    echo "${ACCOUNT_CREDENTIALS}" > ${acctCredentialsFile}
    acctEmail=$(cat ${acctCredentialsFile} | grep client_email | cut -f4 -d'"')
    if [ -z "$(echo "${acctEmail}" | tr -d '[:space:]')" ]; then
        echo "Revoking gcloud access for all"
        gcloud auth revoke --all
    else
        echo "Revoking gcloud access for ${acctEmail}"
        gcloud auth revoke ${acctEmail}
    fi
}

## Authenticate with MCM hub-cluster in order to perform import/remove operations
function hubClusterLogin() {
    echo "Logging into the MCM hub cluster..."
    mkdir -p ${WORK_DIR}/.helm
    export CLOUDCTL_HOME=${WORK_DIR}/.helm
    cloudctl login -a ${ICP_URL} --skip-ssl-validation -u ${ICP_ADMIN_USER} -p ${ICP_ADMIN_PASSWORD} -n default
}

## Generate the template file to be used when importing the managed cluster into the MCM hub-cluster
function generateImportTemplate() {
    hubClusterLogin
    echo "Generating template file for the cluster import..."
    cloudctl mc cluster template ${CLUSTER_NAME} -n mcm-${CLUSTER_NAME} > ${IMPORT_FILE}
    hubClusterLogout

    echo "Modifying import template with cluster-specific details..."
    if [ ! -z "${CLUSTER_ADMIN_USER}" ]; then
        sed -i -e "s/default_admin_user:.*/default_admin_user: ${CLUSTER_ADMIN_USER//\//\\/}/" ${IMPORT_FILE}
    fi
    if [ ! -z "${CLUSTER_CONTAINER_RUNTIME}" ]; then
        sed -i -e "s/container_runtime:.*/container_runtime: ${CLUSTER_CONTAINER_RUNTIME}/" ${IMPORT_FILE}
    fi
}

## Perform the import of the managed cluster into the MCM hub-cluster
function importManagedCluster() {
    IMPORT_STATUS="attempted"
    hubClusterLogin
    echo "Importing the managed cluster into the MCM hub cluster..."
    cloudctl mc cluster import -f ${IMPORT_FILE} --cluster-kubeconfig ${KUBECONFIG_FILE} --cluster-context ${CLUSTER_CONTEXT}
    hubClusterLogout
    IMPORT_STATUS="completed"
}

## Remove the managed cluster from the MCM hub-cluster
function removeImportedCluster() {
    hubClusterLogin
    echo "Removing the imported cluster from the MCM hub cluster..."
    cloudctl mc cluster remove ${CLUSTER_NAME} -n mcm-${CLUSTER_NAME} -C ${CLUSTER_CONTEXT} -K ${KUBECONFIG_FILE}
    hubClusterLogout
    IMPORT_STATUS="removed"
}

## Logout from MCM hub-cluster after performing import/remove operations
function hubClusterLogout() {
    echo "Logging out from the MCM hub cluster..."
    export CLOUDCTL_HOME=${WORK_DIR}/.helm
    cloudctl logout
}

## Delete historical data pertaining to a previously imported cluster from the MCM hub-cluster
function deleteClusterResource() {
    echo "Deleting cluster resource from MCM hub cluster; Cluster within managed Kubernetes Service is not affected..."

    ## Fetch and parse the current authentication token from the ICP server hosting the MCM controller
    AUTH_TOKEN=$(curl -k -X POST "${ICP_URL}/idprovider/v1/auth/identitytoken" \
                      -H "Content-Type: application/x-www-form-urlencoded;charset=UTF-8" \
                      -d "grant_type=password&username=${ICP_ADMIN_USER}&password=${ICP_ADMIN_PASSWORD}&scope=openid" \
                      --insecure | jq --raw-output .id_token)
    if [ -z "$(echo "${AUTH_TOKEN}" | tr -d '[:space:]')" ]; then
        echo "ICP authorization token is not available"
        exit 1
    fi

    ## Prepare cache directory for kubectl
    cacheDir=${WORK_DIR}/.kube/http-cache
    mkdir -p ${cacheDir}
    kubectl --cache-dir ${cacheDir} config set-cluster icp-320-minimal --server=${MCM_ENDPOINT} --insecure-skip-tls-verify=true
    kubectl --cache-dir ${cacheDir} config set-context icp-320-minimal-context --cluster=icp-320-minimal
    kubectl --cache-dir ${cacheDir} config set-credentials admin --token=${AUTH_TOKEN}
    kubectl --cache-dir ${cacheDir} config set-context icp-320-minimal-context --user=${ICP_ADMIN_USER} --namespace=default
    kubectl --cache-dir ${cacheDir} config use-context icp-320-minimal-context
    kubectl --cache-dir ${cacheDir} delete cluster ${CLUSTER_NAME} -n mcm-${CLUSTER_NAME}

    IMPORT_STATUS="deleted"
}

## Perform the requested cluster management operation
function performRequestedAction() {
    if [ "${ACTION}" == "import" ]; then
        importManagedCluster
    elif [ "${ACTION}" == "remove" ]; then
        removeImportedCluster
    elif [ "${ACTION}" == "delete" ]; then
        removeImportedCluster
        deleteClusterResource
    else 
        echo "Unsupported management action - ${ACTION}; Exiting."
        exit 1
    fi
}

## Perform the tasks required to complete the cluster management operation
function run() {
    ## Prepare work directory and install common utilities
    mkdir -p ${WORK_DIR}/bin
    export PATH=./${WORK_DIR}/bin:${PATH}
    installCloudctlLocally
    installKubectlLocally

    ## Perform kubernetes service-specific tasks for the requested action
    if [ "${KUBE_SERVICE}" == "iks" ]; then
        echo "Preparing for MCM access to the IBM Cloud (IKS) cluster..."
        verifyIksInformation
        setIksImportDetails
        performRequestedAction
    elif [ "${KUBE_SERVICE}" == "aks" ]; then
        echo "Preparing for MCM access to the Microsoft Azure (AKS) cluster..."
        verifyAksInformation
        setAksImportDetails
        performRequestedAction
    elif [ "${KUBE_SERVICE}" == "eks" ]; then
        echo "Preparing for MCM access to the Amazon Elastic (EKS) cluster..."
        verifyEksInformation
        installAwsLocally
        setEksImportDetails
        performRequestedAction
    elif [ "${KUBE_SERVICE}" == "gke" ]; then
        echo "Preparing for MCM access to the Google Cloud (GKE) cluster..."
        export PATH=./${WORK_DIR}/google-cloud-sdk/bin:${PATH}
        installGcloudLocally
        verifyGkeInformation
        setGkeImportDetails
        gcloudLogin
        performRequestedAction
    else 
        echo "Unsupported kubernetes service - ${KUBE_SERVICE}; Exiting."
        exit 1
    fi
}


## Gather information provided via the command line and set additional variables
## to be used during the management operations
while test $# -gt 0; do
    [[ $1 =~ ^-a|--action ]]   && { ACTION="${2}";            shift 2; continue; };
    [[ $1 =~ ^-s|--service ]]  && { KUBE_SERVICE="${2}";      shift 2; continue; };
    [[ $1 =~ ^-w|--workdir ]]  && { WORK_DIR="${2}";          shift 2; continue; };
    [[ $1 =~ ^-l|--lockwait ]] && { LOCK_WAIT_MINUTES="${2}"; shift 2; continue; };
    break;
done
CLUSTER_ADMIN_USER=""
CLUSTER_CONTAINER_RUNTIME=""
CLUSTER_CONTEXT=""
IMPORT_FILE=${WORK_DIR}/cluster-import.yaml
IMPORT_STATUS="unknown"
KUBECONFIG_FILE=${WORK_DIR}/kubeconfig.yaml
if [[ ! "${LOCK_WAIT_MINUTES}" =~ ^[0-9]+$ ]]; then
    ## Max lock wait time not given or is invalid; Set to default
    LOCK_WAIT_MINUTES=15
fi

## The utilities cloudctl and kubectl, invoked via this script, will create and
## delete work files in the user's HOME directory.  Thus, concurrent executions
## of this script may result in conflicts.
##
## Use 'flock' to obtain a lock associated with this script before any cluster
## management operations are performed.  This ensures that any critical operations
## will not be run concurrently with any other instance.
##
## This script will wait up to $LOCK_WAIT_MINUTES (default = 15) minutes to obtain
## the lock before exiting without performing the requested action.
attemptCount=1
attemptInterval=10
attemptMax=$((LOCK_WAIT_MINUTES * 60 / attemptInterval))
lockFile="/tmp/.mcmKlusterlet.lck"
lockStatus="unknown"
while [ ${attemptCount} -lt ${attemptMax} ]; do
    echo "Attempt ${attemptCount} to obtain lock..."
    exec 8>${lockFile}
    if flock -n -x 8; then
        ## Lock obtained; Prepare to exit loop
        attemptCount=${attemptMax}
        lockStatus="locked"
    else
        echo "Unable to obtain lock; Waiting for next attempt..."
        attemptCount=$((attemptCount + 1))
        sleep ${attemptInterval}
    fi
done
if [ ${lockStatus} != "locked" ]; then
    echo "Failed to obtain lock within the allotted time; Exiting..."
    exit 1
else
    echo "Obtained lock; Initiating the ${ACTION} operation for the ${KUBE_SERVICE} cluster..."
    run
fi
