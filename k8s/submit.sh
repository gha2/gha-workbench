#!/bin/bash

MYDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BASEDIR="$(cd .. && pwd)"

if [ -z "$1" ]; then echo "Missing parameter (Json2parquet or CreateTable)"; exit 1; fi

ACTION_CLASS=$1
shift


if [ -z "${NAMESPACE}" ]; then export NAMESPACE=spark; fi
if [ -z "${SERVICE_ACCOUNT}" ]; then export SERVICE_ACCOUNT=spark; fi
if [ -z "${IMAGE_PULL_POLICY}" ]; then export IMAGE_PULL_POLICY=Always; fi
if [ -z "${S3_ENDOINT}" ]; then export S3_ENDOINT="https://minio1.ingress.kspray1.ctb01/"; fi


if [ -z "${KUBECONFIG}" ]; then export KUBECONFIG=~/.kube/config; fi
if [ ! -f "$KUBECONFIG" ]
then
    echo "KUBECONFIG variable must be defined and set to a k8s config file"
    exit 1
fi

GHA2SPARK=$BASEDIR/../gha2spark

cd $GHA2SPARK && ./gradlew
if [ $? -ne 0 ]
then
  exit 1
fi

#cd $MYDIR/spark-3.1.1 && ./bin/spark-submit --master k8s://http://localhost:8001 \

SERVER=$(yq e -j $KUBECONFIG | jq '.clusters[0].cluster.server')
SERVER="${SERVER%\"}"
SERVER="${SERVER#\"}"

#export _JAVA_OPTIONS="-Dcom.amazonaws.sdk.disableCertChecking=true"
export JAVA_TOOL_OPTIONS="-Dcom.amazonaws.sdk.disableCertChecking=true"

cd $BASEDIR/spark-3.1.1 && ./bin/spark-submit --verbose --master k8s://$SERVER \
--deploy-mode cluster \
--name ${ACTION_CLASS} \
--class gha2spark.${ACTION_CLASS} \
--conf spark.kubernetes.file.upload.path=s3a://spark/shared \
--conf spark.hadoop.fs.s3a.impl=org.apache.hadoop.fs.s3a.S3AFileSystem \
--conf spark.hadoop.fs.s3a.fast.upload=true \
--conf spark.hadoop.fs.s3a.endpoint=${S3_ENDOINT} \
--conf spark.hadoop.fs.s3a.connection.ssl.enabled=true \
--conf spark.hadoop.fs.s3a.access.key=minio \
--conf spark.hadoop.fs.s3a.secret.key=minio123 \
--conf spark.hadoop.fs.s3a.path.style.access=true \
--conf spark.executor.instances=5 \
--conf spark.kubernetes.authenticate.driver.serviceAccountName=${SERVICE_ACCOUNT} \
--conf spark.kubernetes.namespace=${NAMESPACE} \
--conf spark.kubernetes.container.image=registry.gitlab.com/gha1/spark \
--conf spark.kubernetes.container.image.pullPolicy=${IMAGE_PULL_POLICY} \
file://$GHA2SPARK/build/libs/gha2spark-0.1.0-uber.jar "$@"

#local:////opt/spark/examples/jars/spark-examples_2.12-3.1.1.jar

#--packages com.amazonaws:aws-java-sdk-bundle:1.11.375,org.apache.hadoop:hadoop-aws:3.2.0 \
#--conf spark.driver.extraJavaOptions="-Divy.cache.dir=/tmp -Divy.home=/tmp" \
#--conf spark.executor.extraJavaOptions="-Divy.cache.dir=/tmp -Divy.home=/tmp" \
#--conf hive.metastore.uris=thrift://tcp1.shared1:9083 \
#--conf spark.hive.metastore.uris=thrift://tcp1.shared1:9083 \
#--driver-java-options "-Dlog4j.configuration=file:../log4j.xml -Dcom.amazonaws.sdk.disableCertChecking=true" \
#--conf "spark.driver.extraJavaOptions=-Dcom.amazonaws.sdk.disableCertChecking=true" \
#--conf "spark.executor.extraJavaOptions=-Dcom.amazonaws.sdk.disableCertChecking=true" \



