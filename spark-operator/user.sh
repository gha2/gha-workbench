#!/bin/bash

MYDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"


if [ -z "${NAMESPACE}" ]; then export NAMESPACE=spark1; fi
if [ -z "${SERVICE_ACCOUNT}" ]; then export SERVICE_ACCOUNT=spark; fi


if [ -z "${KUBECONFIG}" ]; then export KUBECONFIG=~/.kube/config; fi
if [ ! -f "$KUBECONFIG" ]
then
    echo "KUBECONFIG variable must be defined and set to a k8s config file"
    exit 1
fi

SERVER=$(yq e -j $KUBECONFIG | jq '.clusters[0].cluster.server')
SERVER="${SERVER%\"}"
SERVER="${SERVER#\"}"

CLUSTER=$(yq e -j $KUBECONFIG | jq '.clusters[0].name')
CLUSTER="${CLUSTER%\"}"
CLUSTER="${CLUSTER#\"}"

KUBECONFIG_SPARK=${MYDIR}/kubeconfig.spark.${CLUSTER}

SECRET_NAME=$(kubectl -n ${NAMESPACE} get serviceaccounts  ${SERVICE_ACCOUNT} -o jsonpath='{.secrets[0].name}')
CA=$(kubectl -n ${NAMESPACE} get secret/$SECRET_NAME -o jsonpath='{.data.ca\.crt}')
TOKEN=$(kubectl -n ${NAMESPACE} get secret/$SECRET_NAME -o jsonpath='{.data.token}' | base64 --decode)

cat >${KUBECONFIG_SPARK} <<EOF
  apiVersion: v1
  kind: Config
  clusters:
  - name: default-cluster
    cluster:
      certificate-authority-data: ${CA}
      server: ${SERVER}
  contexts:
  - name: default-context
    context:
      cluster: default-cluster
      namespace: ${NAMESPACE}
      user: spark-user
  current-context: default-context
  users:
  - name: spark-user
    user:
      token: ${TOKEN}
EOF

echo "To switch to spark config:"
echo "export KUBECONFIG_OLD=$KUBECONFIG; export KUBECONFIG=$KUBECONFIG_SPARK"
echo "and to revert:"
echo 'export KUBECONFIG=$KUBECONFIG_OLD'


