#!/bin/bash

MYDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BASEDIR="$(cd .. && pwd)"

if [ -z "${NAMESPACE}" ]; then export NAMESPACE=spark; fi
if [ -z "${SERVICE_ACCOUNT}" ]; then export SERVICE_ACCOUNT=spark; fi
if [ -z "${IMAGE_PULL_POLICY}" ]; then export IMAGE_PULL_POLICY=Always; fi


if [ -z "${KUBECONFIG}" ]; then export KUBECONFIG=~/.kube/config; fi
if [ ! -f "$KUBECONFIG" ]
then
    echo "KUBECONFIG variable must be defined and set to a k8s config file"
    exit 1
fi

GHA2SPARK=$BASEDIR/../gha2spark

cd $GHA2SPARK && gradle
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
--name spark-pi \
--class org.apache.spark.examples.SparkPi \
--packages com.amazonaws:aws-java-sdk-bundle:1.11.375,org.apache.hadoop:hadoop-aws:3.2.0 \
--driver-java-options "-Dlog4j.configuration=file:../log4j.xml -Dcom.amazonaws.sdk.disableCertChecking=true" \
--conf "spark.driver.extraJavaOptions=-Dcom.amazonaws.sdk.disableCertChecking=true" \
--conf "spark.executor.extraJavaOptions=-Dcom.amazonaws.sdk.disableCertChecking=true" \
--conf spark.kubernetes.file.upload.path=s3a://spark/shared \
--conf spark.hadoop.fs.s3a.impl=org.apache.hadoop.fs.s3a.S3AFileSystem \
--conf spark.hadoop.fs.s3a.fast.upload=true \
--conf spark.hadoop.fs.s3a.endpoint=https://minio1.shared1 \
--conf spark.hadoop.fs.s3a.access.key=minio \
--conf spark.hadoop.fs.s3a.secret.key=minio123 \
--conf spark.hadoop.fs.s3a.path.style.access=true \
--conf spark.driver.extraJavaOptions="-Divy.cache.dir=/tmp -Divy.home=/tmp" \
--conf spark.executor.instances=5 \
--conf spark.kubernetes.authenticate.driver.serviceAccountName=${SERVICE_ACCOUNT} \
--conf spark.kubernetes.namespace=${NAMESPACE} \
--conf spark.kubernetes.container.image=registry.gitlab.com/gha1/spark \
--conf spark.kubernetes.container.image.pullPolicy=${IMAGE_PULL_POLICY} \
file://$BASEDIR/spark-3.1.1/examples/jars/spark-examples_2.12-3.1.1.jar
#local:////opt/spark/examples/jars/spark-examples_2.12-3.1.1.jar




