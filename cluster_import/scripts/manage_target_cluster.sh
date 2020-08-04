#!/bin/bash
##------------------------------------------------------------------------------
## Licensed Materials - Property of IBM
## 5737-E67
## (C) Copyright IBM Corporation 2019 All Rights Reserved.
## US Government Users Restricted Rights - Use, duplication or
## disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
##------------------------------------------------------------------------------
## This script is used to manage operations pertaining to the relationship
## between a MCM hub-cluster and a target Kubernetes cluster:
##   - Import a Kubernetes cluster into the MCM hub-cluster
##   - Remove a Kubernetes cluster from the MCM hub-cluster
##
## Target Kubernetes clusters are supported within the following environments:
##   - Microsoft Azure Kubernetes Service (AKS)
##   - Amazon Elastic Kubernetes Service (EKS)
##   - Google Kubernetes Engine (GKE)
##   - IBM Cloud Kubernetes Service (IKS)
##   - IBM Cloud Private (ICP)
##   - IBM Cloud Private with Openshift (OCP)
##
## Details pertaining to the actions to be taken and target cluster to be
## managed should be provided via the following command-line parameters or <environment variable>:
## Required:
##   -ac|--action <ACTION>                          Action to be taken; Valid values include (import, remove)
##   -wd|--workdir <WORK_DIR>                       Directory where temporary work files will be created during the action
##   -hs|--hubserverurl <HUB_URL>                   URL (including port) of the MCM hub-cluster
##   -hu|--hubuser <HUB_ADMIN_USER>                 User name for connecting to the MCM hub-cluster
##   -hp|--hubpassword <HUB_ADMIN_PASSWORD>         Password used to authenticate with the MCM hub-cluster
##   -cn|--clustername <CLUSTER_NAME>               Name of the target cluster
##   -ce|--clusterendpoint <CLUSTER_ENDPOINT>       URL for accessing the target cluster
##   -cu|--clusteruser <CLUSTER_USER>               Username for accessing the target cluster
##   -ck|--clustertoken <CLUSTER_TOKEN>             Authorization token for accessing the target cluster
##   -cc|--clustercreds <CLUSTER_CREDENTIALS>       JSON-formated file containing cluster endpoint, user and token information;
##                                                  Supercedes the individual cluster endpoint, user and token inputs
##   
## Optional:
##   -cs|--clusternamespace <CLUSTER_NAMESPACE>     Namespace on the hub cluster into which the target cluster will be imported
##   -ir|--imageregistry <IMAGE_REGISTRY>           Name of the registry containing the MCM image(s)
##   -ix|--imagesuffix <IMAGE_SUFFIX>               Suffix (e.g. platform type) to be appended to image name
##   -iv|--imageversion <IMAGE_VERSION>             Version (tag) of the MCM image to be pulled
##   -du|--dockeruser <DOCKER_USER>                 User name for authenticating with the image registry
##   -dp|--dockerpassword <DOCKER_PASSWORD>         Password for authenticating with the image registry
##------------------------------------------------------------------------------

set -e
trap cleanup KILL ERR QUIT TERM INT EXIT
trap "kill 0" EXIT

## Perform cleanup tasks prior to exit
function cleanup() {
    if [ "${ACTION}" == "import"  -a  "${IMPORT_STATUS}" != "imported" ]; then
        echo "Unable to import the managed cluster; Exiting..."
    fi
}

## Download and install the cloudctl utility used to import/remove the managed cluster
function installCloudctlLocally() {
    if [ ! -x ${WORK_DIR}/bin/hub-cloudctl ]; then
        echo "Installing cloudctl into ${WORK_DIR}..."
        wget --quiet --no-check-certificate ${HUB_URL}/api/cli/cloudctl-linux-amd64 -P ${WORK_DIR}/bin
        mv ${WORK_DIR}/bin/cloudctl-linux-amd64 ${WORK_DIR}/bin/hub-cloudctl
        chmod +x ${WORK_DIR}/bin/hub-cloudctl
    else
        echo "cloudctl has already been installed; No action taken"
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
        wget --quiet https://storage.googleapis.com/kubernetes-release/release/${kversion}/bin/linux/amd64/kubectl -P ${WORK_DIR}/bin
        chmod +x ${WORK_DIR}/bin/kubectl
    else
        echo "kubectl has already been installed; No action taken"
    fi
}

## Verify that required details pertaining to the MCM hub-cluster have been provided
function verifyMcmHubClusterInformation() {
    if [ -z "$(echo "${HUB_URL}" | tr -d '[:space:]')" ]; then
        echo "${WARN_ON}MCM hub-cluster API URL is not available${WARN_OFF}"
        exit 1
    fi
    if [ -z "$(echo "${HUB_ADMIN_USER}" | tr -d '[:space:]')" ]; then
        echo "${WARN_ON}MCM hub-cluster admin username is not available${WARN_OFF}"
        exit 1
    fi
    if [ -z "$(echo "${HUB_ADMIN_PASSWORD}" | tr -d '[:space:]')" ]; then
        echo "${WARN_ON}MCM hub-cluster admin password is not available${WARN_OFF}"
        exit 1
    fi
    installKubectlLocally
    installCloudctlLocally
}

## Parse the cluster credentials from specified file
function parseTargetClusterCredentials() {
    echo "Parsing cluster credentials from ${CLUSTER_CREDENTIALS}..."
    if [ -f "${CLUSTER_CREDENTIALS}" ]; then
         ## Credentials provided via JSON file; Parse endpoint, user and token from file for later verification
         CLUSTER_ENDPOINT=$(cat ${CLUSTER_CREDENTIALS} | jq -r '.endpoint')
         CLUSTER_USER=$(cat ${CLUSTER_CREDENTIALS}     | jq -r '.user')
         CLUSTER_TOKEN=$(cat ${CLUSTER_CREDENTIALS}    | jq -r '.token')
    fi
}

## Verify the information needed to access the target cluster
function verifyTargetClusterInformation() {
    ## Verify details for accessing to the target cluster
    if [ -z "$(echo "${CLUSTER_NAME}" | tr -d '[:space:]')" ]; then
        echo "${WARN_ON}Cluster name has not been specified; Exiting...${WARN_OFF}"
        exit 1
    fi
    if [ -z "$(echo "${CLUSTER_ENDPOINT}" | tr -d '[:space:]')" ]; then
        echo "${WARN_ON}Cluster server URL has not been specified; Exiting...${WARN_OFF}"
        exit 1
    fi
    if [ -z "$(echo "${CLUSTER_USER}" | tr -d '[:space:]')" ]; then
        echo "${WARN_ON}Cluster user has not been specified; Exiting...${WARN_OFF}"
        exit 1
    fi
    if [ -z "$(echo "${CLUSTER_TOKEN}" | tr -d '[:space:]')" ]; then
        echo "${WARN_ON}Authorization token has not been specified; Exiting...${WARN_OFF}"
        exit 1
    fi

    ## Configure kubectl
    installKubectlLocally
    ${WORK_DIR}/bin/kubectl config set-cluster     ${CLUSTER_NAME} --insecure-skip-tls-verify=true --server=${CLUSTER_ENDPOINT}
    ${WORK_DIR}/bin/kubectl config set-credentials ${CLUSTER_USER} --token=${CLUSTER_TOKEN}
    ${WORK_DIR}/bin/kubectl config set-context     ${CLUSTER_NAME} --user=${CLUSTER_USER} --namespace=kube-system --cluster=${CLUSTER_NAME}
    ${WORK_DIR}/bin/kubectl config use-context     ${CLUSTER_NAME}

    ## Generate KUBECONFIG file to be used when accessing the target cluster
    ${WORK_DIR}/bin/kubectl config view --minify=true --flatten=true > ${KUBECONFIG_FILE}

    verifyTargetClusterAccess
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

## Authenticate with MCM hub-cluster in order to perform import/remove operations
function hubClusterLogin() {
    echo "Logging into the MCM hub cluster..."
    mkdir -p ${WORK_DIR}/.helm
    export CLOUDCTL_HOME=${WORK_DIR}/.helm
    hub-cloudctl login -a ${HUB_URL} --skip-ssl-validation -u ${HUB_ADMIN_USER} -p ${HUB_ADMIN_PASSWORD} -n default
}

## Logout from the MCM hub-cluster
function hubClusterLogout() {
    echo "Logging out of MCM hub cluster..."
    export CLOUDCTL_HOME=${WORK_DIR}/.helm
    hub-cloudctl logout
}

## Prepare for the target cluster to be imported into the hub cluster:
##   - Create configuration file
##   - Create cluster resource
##   - Generate import file to be applied to target cluster
function prepareClusterImport() {
    ## Connect to hub cluster
    hubClusterLogin

    echo "Generating configuration file template..."
    nameSpace=${CLUSTER_NAME}
    if [ ! -z "$(echo "${CLUSTER_NAMESPACE}" | tr -d '[:space:]')" ]; then
        nameSpace="${CLUSTER_NAMESPACE}"
    fi
    hub-cloudctl mc cluster template ${CLUSTER_NAME} -n ${nameSpace} > ${CONFIG_FILE}

    ## If image registry is provided, modify config template to include registry details
    imageRegistry="$(echo ${IMAGE_REGISTRY} | tr -d '[:space:]')"
    if [ ! -z "${imageRegistry}" ]; then
        sed -i -e "s/# *private_registry_enabled:.*/private_registry_enabled: true/" \
               -e "s|# *imageRegistry:.*|imageRegistry: ${imageRegistry}|" ${CONFIG_FILE}
        if [ ! -z "$(echo "${IMAGE_SUFFIX}" | tr -d '[:space:]')" ]; then
            sed -i -e "s/# *imageNamePostfix:.*/imageNamePostfix: ${IMAGE_SUFFIX}/" ${CONFIG_FILE}
        fi
        if [ ! -z "$(echo "${DOCKER_USER}" | tr -d '[:space:]')" ]; then
            sed -i -e "s/# *docker_username:.*/docker_username: ${DOCKER_USER}/" ${CONFIG_FILE}
        fi
        if [ ! -z "$(echo "${DOCKER_PASSWORD}" | tr -d '[:space:]')" ]; then
            sed -i -e "s/# *docker_password:.*/docker_password: ${DOCKER_PASSWORD}/" ${CONFIG_FILE}
        fi
        if [ ! -z "$(echo "${IMAGE_VERSION}" | tr -d '[:space:]')" ]; then
            sed -i -e "s/version:.*/version: ${IMAGE_VERSION}/" ${CONFIG_FILE}
        fi
    fi
    echo "Configuration file for cluster resource created"
    echo "==============================================="
    cat ${CONFIG_FILE}
    echo "==============================================="
    IMPORT_STATUS="configured"

    ## Create the cluster resource, if it does not already exist
    clusterCount=$(kubectl get clusters -n ${nameSpace} | grep ${CLUSTER_NAME} | wc -l)
    clusterPending=$(kubectl get clusters -n ${nameSpace} | grep ${CLUSTER_NAME} | grep "Pending" | wc -l)
    if [ $clusterCount -eq 0 ]; then
        echo "Creating the resource for cluster ${CLUSTER_NAME}..."
        hub-cloudctl mc cluster create -f ${CONFIG_FILE}
    elif [ $clusterPending -eq 1 ]; then
        echo "Cluster ${CLUSTER_NAME} has previously been created; Import is pending..."
    else
        echo "Cluster ${CLUSTER_NAME} already exists in hub with an unexpected state; Exiting"
        kubectl get clusters -n ${nameSpace}
        exit 1
    fi
    IMPORT_STATUS="created"

    echo "Generating import file for target cluster ${CLUSTER_NAME}..."
    hub-cloudctl mc cluster import ${CLUSTER_NAME} -n ${nameSpace} > ${IMPORT_FILE}
    echo "Import file for target cluster created"
    echo "==============================================="
    cat ${IMPORT_FILE}
    echo "==============================================="
    IMPORT_STATUS="prepared"

    ## Disconnect from hub cluster
    hubClusterLogout
}

## Initiate the import of the target cluster
function initiateClusterImport() {
    echo "Applying import file to target cluster ${CLUSTER_NAME}..."
    export KUBECONFIG=${KUBECONFIG_FILE}
	set +e
	iterationMax=5
    iterationCount=1
	#
    #See CP4MCM import cli doc, apply will fail with 
    #no matches for kind "Endpoint" in version "multicloud.ibm.com/v1beta1"
    #retry 5 times
    #    
    while [ ${iterationCount} -lt ${iterationMax} ]; do     
    	OUT=`${WORK_DIR}/bin/kubectl apply -f ${IMPORT_FILE} 2>&1`   
    	RC=$?
		echo $OUT    	
    	echo "Import return code is "$RC
    	if [[ $RC -ne 0 ]]; then            
        	echo "Import apply failed, retry ..."
        	iterationCount=$((iterationCount + 1))
    	else
    		break
    	fi
	done
    if [[ $RC -ne 0 ]]; then
    	echo "${WARN_ON}${errMessage}; Unable to apply the import file to target cluster${WARN_OFF}"
    fi
    IMPORT_STATUS="applied"
    unset KUBECONFIG
    set -e
}

## Monitor the import status of the target cluster
function monitorClusterImport() {
    echo "Monitoring the import status of target cluster ${CLUSTER_NAME}..."
    nameSpace=${CLUSTER_NAME}
    if [ ! -z "$(echo "${CLUSTER_NAMESPACE}" | tr -d '[:space:]')" ]; then
        nameSpace="${CLUSTER_NAMESPACE}"
    fi

    ## Connect to hub cluster
    hubClusterLogin

    ## Check status, waiting for success/failure status
    iterationCount=1
    iterationInterval=15
    maxMinutes=20
    iterationMax=$((maxMinutes * 60 / iterationInterval))
    initialStatus="Pending"
    clusterStatus=`kubectl get clusters -n ${nameSpace} | tail -1 | awk {'print $(NF-1)'}`
    while [ "${clusterStatus}" == "${initialStatus}"  -a  ${iterationCount} -lt ${iterationMax} ]; do
        echo "Checking cluster status; Iteration ${iterationCount}..."
        clusterStatus=`kubectl get clusters -n ${nameSpace} | tail -1 | awk {'print $(NF-1)'}`
        echo "Current cluster status is: ${clusterStatus}"
        if [ "${clusterStatus}" != "${initialStatus}" ]; then
            ## Status changed; Prepare to exit loop
            iterationCount=${iterationMax}
        else
            echo "Status has not changed; Waiting for next check..."
            iterationCount=$((iterationCount + 1))
            sleep ${iterationInterval}
        fi
    done
    if [ "${clusterStatus}" != "Ready" ]; then
        echo "${WARN_ON}Cluster is not ready within the allotted time; Exiting...${WARN_OFF}"
        echo "${WARN_ON}State of target cluster shown below:${WARN_OFF}"
        export KUBECONFIG=${KUBECONFIG_FILE}
        ${WORK_DIR}/bin/kubectl get pods -n multicluster-endpoint
        unset KUBECONFIG
        exit 1
    else
        echo "Import of cluster ${CLUSTER_NAME} is successful"
        IMPORT_STATUS="imported"
    fi

    ## Disconnect from hub cluster
    hubClusterLogout
}

## Remove the target cluster from the hub cluster.
function initiateClusterRemoval() {
    ## Connect to hub cluster
    hubClusterLogin

    nameSpace=${CLUSTER_NAME}
    if [ ! -z "$(echo "${CLUSTER_NAMESPACE}" | tr -d '[:space:]')" ]; then
        nameSpace="${CLUSTER_NAMESPACE}"
    fi

    indicatorFile=${WORK_DIR}/.cluster_deleted
    iterationCount=1
    iterationInterval=15
    maxMinutes=20
    iterationMax=$((maxMinutes * 60 / iterationInterval))
    rm -f ${indicatorFile}

    echo "Initiating removal of target cluster ${CLUSTER_NAME}..."
    (${WORK_DIR}/bin/kubectl delete cluster ${CLUSTER_NAME} --namespace ${nameSpace}; touch ${indicatorFile}) &
    while [ ! -f ${indicatorFile}  -a  ${iterationCount} -lt ${iterationMax} ]; do
        echo "Waiting for removal of target cluster ${CLUSTER_NAME}..."
        if [ -f ${indicatorFile} ]; then
            ## Indicator exists; Prepare to exit loop
            iterationCount=${iterationMax}
        else
            echo "Cluster delete still in progress; Waiting for next check..."
            iterationCount=$((iterationCount + 1))
            sleep ${iterationInterval}
        fi
    done
    if [ ! -f ${indicatorFile} ]; then
        echo "${WARN_ON}Cluster was not deleted within the allotted time; Exiting...${WARN_OFF}"
        exit 1
    else
        echo "Delete of cluster ${CLUSTER_NAME} was successful"
        IMPORT_STATUS="deleted"
    fi

    ## Disconnect from hub cluster
    hubClusterLogout
}

## Perform the requested cluster management operation
function performRequestedAction() {
    if [ "${ACTION}" == "import" ]; then
        prepareClusterImport
        initiateClusterImport
        monitorClusterImport
    elif [ "${ACTION}" == "remove" ]; then
        initiateClusterRemoval
    else 
        echo "Unsupported management action - ${ACTION}; Exiting."
        exit 1
    fi
}

## Perform the tasks required to complete the cluster management operation
function run() {
    ## Prepare work directory and install common utilities
    mkdir -p ${WORK_DIR}/bin
    export PATH=${WORK_DIR}/bin:${PATH}

    ## Check provided hub and target cluster information
    verifyMcmHubClusterInformation
    parseTargetClusterCredentials
    if [ "${ACTION}" == "import" ]; then
        verifyTargetClusterInformation
    elif [ "${ACTION}" == "remove" ]; then
        if [ -z "$(echo "${CLUSTER_NAME}" | tr -d '[:space:]')" ]; then
            echo "${WARN_ON}Target cluster name was not provided${WARN_OFF}"
            exit 1
        fi
    fi

    ## Perform Kubernetes service-specific tasks for the requested action
    performRequestedAction
}

##------------------------------------------------------------------------------------------------
##************************************************************************************************
##------------------------------------------------------------------------------------------------

## Gather information provided via the command line parameters
while test ${#} -gt 0; do
    [[ $1 =~ ^-ac|--action ]]           && { ACTION="${2}";                      shift 2; continue; };
    [[ $1 =~ ^-wd|--workdir ]]          && { WORK_DIR="${2}";                    shift 2; continue; };
    [[ $1 =~ ^-cn|--clustername ]]      && { CLUSTER_NAME="${2}";                shift 2; continue; };
    [[ $1 =~ ^-hs|--hubserverurl ]]     && { HUB_URL="${2}";                     shift 2; continue; };
    [[ $1 =~ ^-hu|--hubuser ]]          && { HUB_ADMIN_USER="${2}";              shift 2; continue; };
    [[ $1 =~ ^-hp|--hubpassword ]]      && { HUB_ADMIN_PASSWORD="${2}";          shift 2; continue; };
    [[ $1 =~ ^-ce|--clusterendpoint ]]  && { CLUSTER_ENDPOINT="${2}";            shift 2; continue; };
    [[ $1 =~ ^-cu|--clusteruser ]]      && { CLUSTER_USER="${2}";                shift 2; continue; };
    [[ $1 =~ ^-ck|--clustertoken ]]     && { CLUSTER_TOKEN="${2}";               shift 2; continue; };
    [[ $1 =~ ^-cc|--clustercreds ]]     && { CLUSTER_CREDENTIALS="${2}";         shift 2; continue; };

    [[ $1 =~ ^-cs|--clusternamespace ]] && { CLUSTER_NAMESPACE="${2}";           shift 2; continue; };
    [[ $1 =~ ^-ir|--imageregistry ]]    && { IMAGE_REGISTRY="${2}";              shift 2; continue; };
    [[ $1 =~ ^-ix|--imagesuffix ]]      && { IMAGE_SUFFIX="${2}";                shift 2; continue; };
    [[ $1 =~ ^-iv|--imageversion ]]     && { IMAGE_VERSION="${2}";               shift 2; continue; };
    [[ $1 =~ ^-du|--dockeruser ]]       && { DOCKER_USER="${2}";                 shift 2; continue; };
    [[ $1 =~ ^-dp|--dockerpassword ]]   && { DOCKER_PASSWORD="${2}";             shift 2; continue; };
    break;
done
ACTION="$(echo "${ACTION}" | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')"
if [ "${ACTION}" != "import"  -a  "${ACTION}" != "remove" ]; then
    echo "${WARN_ON}Management action (e.g. import, remove) has not been specified; Exiting...${WARN_OFF}"
    exit 1
fi
if [ -z "$(echo "${WORK_DIR}" | tr -d '[:space:]')" ]; then
    echo "${WARN_ON}Location of the work directory has not been specified; Exiting...${WARN_OFF}"
    exit 1
fi

## Prepare work directory
mkdir -p ${WORK_DIR}/bin
export PATH=${WORK_DIR}/bin:${PATH}

## Set default variable values
IMPORT_STATUS="unknown"
CONFIG_FILE=${WORK_DIR}/cluster-config.yaml
IMPORT_FILE=${WORK_DIR}/cluster-import.yaml
KUBECONFIG_FILE=${WORK_DIR}/kubeconfig.yaml
WARN_ON='\033[0;31m'
WARN_OFF='\033[0m'

## Run the necessary action(s)
run
