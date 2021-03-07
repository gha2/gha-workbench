
MYDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

GHA2SPARK=$MYDIR/../gha2spark

cd $GHA2SPARK && gradle
if [ $? -ne 0 ]
then
  exit 1
fi

cd $MYDIR/spark-3.1.1 && ./bin/spark-submit --master local --driver-java-options -Dlog4j.configuration=file:../log4j.xml \
--class gha2spark.Json2parquet $GHA2SPARK/build/libs/gha2spark-0.1.0-uber.jar "$@"



