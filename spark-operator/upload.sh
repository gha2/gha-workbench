#!/bin/bash

MYDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BASEDIR="$(cd .. && pwd)"

if [ -z "${MC_ALIAS}" ]; then export MC_ALIAS="minio1.shared1"; fi


GHA2SPARK=$BASEDIR/../gha2spark

cd $GHA2SPARK && ./gradlew
if [ $? -ne 0 ]
then
  exit 1
fi

mc cp $GHA2SPARK/build/libs/gha2spark-0.1.0-uber.jar ${MC_ALIAS}/spark/jars/gha2spark-0.1.0-uber.jar

mc policy set download ${MC_ALIAS}/spark/jars/gha2spark-0.1.0-uber.jar

