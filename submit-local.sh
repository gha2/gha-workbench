
MYDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

GHA2SPARK=$MYDIR/../gha2spark

ACTION_CLASS=$1
shift


cd $GHA2SPARK && gradle
if [ $? -ne 0 ]
then
  exit 1
fi


cd $MYDIR/spark-3.1.1 && ./bin/spark-submit --master local \
--driver-java-options "-Dlog4j.configuration=file:$MYDIR/spark-3.1.1/conf/log4j.properties  -Dcom.amazonaws.sdk.disableCertChecking=true" \
--conf "spark.executor.extraJavaOptions=-Dcom.amazonaws.sdk.disableCertChecking=true" \
--class gha2spark.${ACTION_CLASS} $GHA2SPARK/build/libs/gha2spark-0.1.0-uber.jar "$@"



