#!/bin/bash

# export NS_CS=ibm-common-services
# export PM_NAMESPACE=pm1
# export SC_NAME=managed-nfs-storage
# ./install-pm.sh ${NS_CS} ${PM_NAMESPACE} ${SC_NAME}

export NS_CS="$1"
if [ -z "${NS_CS}" ]; then
    echo "ERROR: Namespace for common services not set"
    exit
fi

export PM_NAMESPACE="$2"
if [ -z "${PM_NAMESPACE}" ]; then
    echo "ERROR: Namespace for process mining not set"
    exit
fi

export SC_NAME="$3"
if [ -z "${SC_NAME}" ]; then
    echo "ERROR: Storage class not set"
    exit
fi

if [ -z "${CP4BA_AUTO_ENTITLEMENT_KEY}" ]; then
    echo "ERROR: Env var CP4BA_AUTO_ENTITLEMENT_KEY not set"
    exit
fi

echo "Namespace common services: "${NS_CS}

_NS="openshift-marketplace"
_RES_TYPE="catalogsource"
_RES_NAME="ibm-operator-catalog"
_WAIT_SECS=5
_WAIT_SECS_PM=30


storageClassExist () {
    if [ $(oc get sc ${SC_NAME} | grep ${SC_NAME} | wc -l) -lt 1 ];
    then
        return 0
    fi
    return 1
}

resourceExist () {
    if [ $(oc get $2 -n $1 $3 | grep $3 | wc -l) -lt 1 ];
    then
        return 0
    fi
    return 1
}

waitForResourceCreated () {
#    echo "namespace name: $1"
#    echo "resource type: $2"
#    echo "resource name: $3"
#    echo "time to wait: $4"

    while [ true ]
    do
        resourceExist $1 $2 $3 $4
        if [ $? -eq 0 ]; then
            echo "Wait for resource '$3' in namespace '$1' created, sleep $4 seconds"
            sleep $4
        else
            break
        fi
    done
}

waitForResourceReady () {
#    echo "namespace name: $1"
#    echo "resource type: $2"
#    echo "resource name: $3"
#    echo "time to wait: $4"

    while [ true ]
    do
        _READY=$(oc get $2 -n $1 $3 -o jsonpath="{.status.connectionState.lastObservedState}")
        if [ "${_READY}" = "READY" ]; then
            echo "Resource '$3' in namespace '$1' is READY"
            break
        else
            echo "Wait for resource '$3' in namespace '$1' to be READY, sleep $4 seconds"
            sleep $4
        fi
    done
}

waitForPMReady () {
    while [ true ]
    do
        _PM_READY=$(oc get processmining -n ${PM_NAMESPACE} | grep -v NAME | awk '{print $2}')
        if [ "${_PM_READY}" = "True" ]; then
            echo "Process Mining in namespace '${PM_NAMESPACE}' is READY"
            break
        else
            echo "Wait for Process Mining in namespace '${PM_NAMESPACE}' to be READY, sleep $1 seconds"
            sleep $1
        fi
    done
}


createCatalogSource_ibm_operator_catalog () {

resourceExist openshift-marketplace CatalogSource ibm-operator-catalog
if [ $? -eq 0 ]; then

cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: ibm-operator-catalog
  namespace: openshift-marketplace
spec:
  displayName: ibm-operator-catalog
  publisher: IBM Content
  sourceType: grpc
  image: icr.io/cpopen/ibm-operator-catalog:v1.24-20221121.235749-CB8AEDD71
  updateStrategy:
    registryPoll:
      interval: 45m
EOF

fi
}


createNsOgSubs () {

resourceExist default namespace ${NS_CS}
if [ $? -eq 0 ]; then

cat <<EOF | oc apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: ${NS_CS}
EOF

fi

resourceExist ${NS_CS} operatorgroup operatorgroup
if [ $? -eq 0 ]; then

cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1alpha2
kind: OperatorGroup
metadata:
  name: operatorgroup
  namespace: ${NS_CS}
spec:
  targetNamespaces:
  - ${NS_CS}
EOF

fi

resourceExist ${NS_CS} Subscription ibm-common-service-operator
if [ $? -eq 0 ]; then

cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: ibm-common-service-operator
  namespace: ${NS_CS}
spec:
  channel: v3.22
  installPlanApproval: Automatic
  name: ibm-common-service-operator
  source: ibm-operator-catalog
  sourceNamespace: openshift-marketplace
EOF

echo "Wait ibm-common-service-operator setup in namespace '${NS_CS}' ..."
sleep 30
oc -n ${NS_CS} get csv
oc get crd | grep operandrequest

fi

}

patchLicense() {
oc patch -n ${NS_CS} commonservice/common-service --type=merge -p '{"spec": {"license": {"accept": true } } }'
}

setCredentials() {
resourceExist ${NS_CS} secret ibm-entitlement-key
if [ $? -eq 0 ]; then
  oc create secret docker-registry -n ${NS_CS} ibm-entitlement-key \
      --docker-username=cp \
      --docker-password=${CP4BA_AUTO_ENTITLEMENT_KEY} \
      --docker-server=cp.icr.io
fi

resourceExist ${NS_CS} secret ibm-registry
if [ $? -eq 0 ]; then
  oc create secret docker-registry -n ${NS_CS} ibm-registry \
      --docker-username=cp \
      --docker-password=${CP4BA_AUTO_ENTITLEMENT_KEY} \
      --docker-server=cp.icr.io
fi
}

createOperandRequest() {

resourceExist ${NS_CS} OperandRequest common-service
if [ $? -eq 0 ]; then

cat <<EOF | oc apply -f -
apiVersion: operator.ibm.com/v1alpha1
kind: OperandRequest
metadata:
  name: common-service
  namespace: ${NS_CS}
spec:
  requests:
    - operands:
        - name: ibm-cert-manager-operator
        - name: ibm-mongodb-operator
        - name: ibm-iam-operator
        - name: ibm-monitoring-grafana-operator
        - name: ibm-healthcheck-operator
        - name: ibm-management-ingress-operator
        - name: ibm-licensing-operator
        - name: ibm-commonui-operator
        - name: ibm-events-operator
        - name: ibm-ingress-nginx-operator
        - name: ibm-auditlogging-operator
        - name: ibm-platform-api-operator
        - name: ibm-zen-operator
        - name: ibm-db2u-operator
        - name: cloud-native-postgresql
        - name: ibm-user-data-services-operator
        - name: ibm-zen-cpp-operator
        - name: ibm-bts-operator
      registry: common-service
EOF

echo "Wait pods setup..."
sleep 180

else 
  echo "OperandRequest 'common-service' in namespace '${NS_CS}' already exists"; 
fi

}


waitForPodsReady () {
#    echo "namespace name: $1"
#    echo "resource type: $2"
#    echo "resource name: $3"
#    echo "time to wait: $4"

    echo "Wait for pods in namespace '$1' to be READY, sleep $2 seconds"
    sleep $2
    while [ true ]
    do
        if [ $(oc get pods -n $1 | grep Completed | wc -l) -gt 0 ]; then
            oc get pods -n $1 | grep Completed | awk '{print $1}' | xargs oc delete pod -n $1
        fi

        _NR=$(oc get pods -n $1 -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}' | grep False)

        if [ ! -z "${_NR}" ]; then echo "wait..."; sleep 5; else echo "Pods ready"; fi

        _READY=$(oc get pods -n $1 -o jsonpath="{.status.connectionState.lastObservedState}")
        if [ -z "${_NR}" ]; then
            echo "Pods in namespace '$1' are READY"
            break
        else
            echo "Wait for pods in namespace '$1' to be READY, sleep $2 seconds"
            sleep $2
        fi
    done
}

showConsoleAndCredentials() {
URL=$(oc get route -n ${NS_CS} cp-console -o jsonpath='{.spec.host}')
PMURL=$(oc get route -n ${PM_NAMESPACE} cpd -o jsonpath='{.spec.host}')
USERNAME=$(oc -n ${NS_CS} get secret platform-auth-idp-credentials -o jsonpath='{.data.admin_username}' | base64 -d)
PASSWD=$(oc -n ${NS_CS} get secret platform-auth-idp-credentials -o jsonpath='{.data.admin_password}' | base64 -d)
echo
echo "========================================"
echo "CP-CONSOLE https://"${URL}
echo "PM-CONSOLE https://"${PMURL}
echo "User name [${USERNAME}]"
echo "Password  [${PASSWD}]"
echo "========================================"
}

stashStorageForDb2() {
oc get no -l node-role.kubernetes.io/worker --no-headers -o name | xargs -I {} \
   -- oc debug -n default {} \
   -- chroot /host sh -c 'grep "^Domain = slnfsv4.coms" /etc/idmapd.conf || ( sed -i "s/.*Domain =.*/Domain = slnfsv4.com/g" /etc/idmapd.conf; nfsidmap -c; rpc.idmapd )'

}

createPMNamespace() {
oc new-project ${PM_NAMESPACE}

# imposta credenziali
oc create secret docker-registry -n ${PM_NAMESPACE} ibm-entitlement-key \
    --docker-username=cp \
    --docker-password=${CP4BA_AUTO_ENTITLEMENT_KEY} \
    --docker-server=cp.icr.io

oc create secret docker-registry -n ${PM_NAMESPACE} ibm-registry \
    --docker-username=cp \
    --docker-password=${CP4BA_AUTO_ENTITLEMENT_KEY} \
    --docker-server=cp.icr.io

}

createCatalogSourcesAndOperatorGroup() {

resourceExist openshift-marketplace CatalogSource ibm-db2uoperator-catalog
if [ $? -eq 0 ]; then

cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: ibm-db2uoperator-catalog
  namespace: openshift-marketplace
spec:
  sourceType: grpc
  image: icr.io/cpopen/ibm-db2uoperator-catalog@sha256:99f725098b801474ff77e880ca235023452116e4b005e49de613496a1917f719
  imagePullPolicy: Always
  displayName: IBM Db2U Catalog
  publisher: IBM
  updateStrategy:
    registryPoll:
      interval: 45m
EOF

fi

resourceExist openshift-marketplace CatalogSource ibm-cloud-databases-redis-operator-catalog
if [ $? -eq 0 ]; then

cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: ibm-cloud-databases-redis-operator-catalog
  namespace: openshift-marketplace
spec:
  displayName: ibm-cloud-databases-redis-operator-catalog
  publisher: IBM
  sourceType: grpc
  image: icr.io/cpopen/ibm-cloud-databases-redis-catalog@sha256:f7125e46c322421067a70a00227b3244f86c111e301d2695ba9e30e12ec19955
  updateStrategy:
    registryPoll:
      interval: 45m
EOF

fi

resourceExist openshift-marketplace CatalogSource opencloud-operators
if [ $? -eq 0 ]; then

cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: opencloud-operators
  namespace: openshift-marketplace
spec:
  displayName: IBMCS Operators
  publisher: IBM
  sourceType: grpc
  image: icr.io/cpopen/ibm-common-service-catalog@sha256:54a294b34afe71ceede6ebe6c8922b5a8accc7ca3bc23a828b885fc795d32c72
  updateStrategy:
    registryPoll:
      interval: 45m
EOF

fi

resourceExist openshift-marketplace CatalogSource ibm-automation-processminings
if [ $? -eq 0 ]; then

cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: ibm-automation-processminings
  namespace: openshift-marketplace
spec:
  displayName: IBM ProcessMining Operators
  publisher: IBM
  sourceType: grpc
  image: icr.io/cpopen/processmining-operator-catalog@sha256:6ce95e4b4bb8f3c19e7ac64a58039bdbf7c1f6990c8a22ec3d88c5b10400eae5
  updateStrategy:
    registryPoll:
      interval: 45m
EOF

fi

# imposta operator group
cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1alpha2
kind: OperatorGroup
metadata:
  name: processmining-group
  namespace: ${PM_NAMESPACE}
spec:
  targetNamespaces:
  - ${PM_NAMESPACE}
EOF

cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: processmining-subscription
  namespace: ${PM_NAMESPACE}
spec:
  channel: v2.0
  installPlanApproval: Automatic
  name: ibm-automation-processmining
  source: ibm-automation-processminings
  sourceNamespace: openshift-marketplace
EOF

}

#------------------------------------------------
# deployments
createPMDeploymentProcessAndTask() {
cat <<EOF | oc apply -f -
apiVersion: processmining.ibm.com/v1beta1
kind: ProcessMining
metadata:
  name: pm-instance
  namespace: ${PM_NAMESPACE}
spec:
  license:
    accept: true
    cloudPak: IBM Cloud Pak for Business Automation
  defaultStorageClassName: ${SC_NAME}
EOF

}

createPMDeploymentOnlyProcess() {
cat <<EOF | oc apply -f -
apiVersion: processmining.ibm.com/v1beta1
kind: ProcessMining
metadata:
  name: pm-instance-no-tm
  namespace: ${PM_NAMESPACE}
spec:
  version : 1.13.2
  license:
    accept: true
    cloudPak: IBM Cloud Pak for Business Automation
  defaultStorageClassName: ${SC_NAME}
  taskmining: 
    install: false
EOF
}


createPMDeploymentOnlyProcessMinimal() {
cat <<EOF | oc apply -f -
apiVersion: processmining.ibm.com/v1beta1
kind: ProcessMining
metadata:
  name: pm-minimal-demo
  namespace: ${PM_NAMESPACE}
spec:
  version : 1.13.2
  license:
    accept: true
    cloudPak: IBM Cloud Pak for Business Automation
  defaultStorageClassName: ${SC_NAME}
  processmining:
    storage:
      redis: 
        install: false
  taskmining: 
    install: false
EOF
}
#------------------------------------------------


#============================
# Begin installation
#============================

storageClassExist
if [ $? -eq 0 ]; then
    echo "ERROR: Storage class not found"
    exit
fi

createCatalogSource_ibm_operator_catalog
waitForResourceCreated ${_NS} ${_RES_TYPE} ${_RES_NAME} ${_WAIT_SECS}
waitForResourceReady ${_NS} ${_RES_TYPE} ${_RES_NAME} ${_WAIT_SECS}

createNsOgSubs
waitForResourceCreated ${NS_CS} commonservice common-service ${_WAIT_SECS}

patchLicense

setCredentials

createOperandRequest

waitForPodsReady ${_NS} ${_WAIT_SECS}

stashStorageForDb2

createPMNamespace

createCatalogSourcesAndOperatorGroup

# allungare attesa o trovare altro modo per verificare completamento setup operatori
echo "Wait catalogs and operator group setup..."
sleep 120

#---------------------------------------
# crea deployment (usare uno tra i 3)
# createPMDeploymentProcessAndTask
createPMDeploymentOnlyProcess
# createPMDeploymentOnlyProcessMinimal
#---------------------------------------


# attendere completamento
waitForPMReady ${_WAIT_SECS_PM}

showConsoleAndCredentials
