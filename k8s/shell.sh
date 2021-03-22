

MYDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BASEDIR="$(cd .. && pwd)"

export JAVA_TOOL_OPTIONS="-Dcom.amazonaws.sdk.disableCertChecking=true"

cd $BASEDIR/spark-3.1.1 && ./bin/spark-shell

