#!/bin/bash

# export NS_CS=ibm-common-services
# export PM_NAMESPACE=pm1
# ./showConsole.sh ${NS_CS} ${PM_NAMESPACE}

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

showConsoleAndCredentials

