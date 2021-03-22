#!/bin/bash

MYDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BASEDIR="$(cd .. && pwd)"

if [ -z "${NAMESPACE}" ]; then export NAMESPACE=spark; fi
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

cat <<EOF | kubectl apply -f -
---
apiVersion: v1
kind: Namespace
metadata:
  name: ${NAMESPACE}
---
apiVersion: v1
kind: ServiceAccount
metadata:
  namespace: ${NAMESPACE}
  name: ${SERVICE_ACCOUNT}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: spark
  namespace: ${NAMESPACE}
rules:
  - apiGroups: ["","extensions", "apps"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete" ]
    resources: ["pods", "configmaps", "deployments", "secrets", services ]
#  - apiGroups: ['policy']
#    resources: ['podsecuritypolicies']
#    verbs:     ['use']
#    resourceNames: ["privileged"]   # WARNING: "provileged' is for test only.
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: spark
  namespace: ${NAMESPACE}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: spark
subjects:
  - kind: ServiceAccount
    name: ${SERVICE_ACCOUNT}
    namespace: ${NAMESPACE}
EOF

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
echo "export KUBECONFIG=$KUBECONFIG_SPARK"


