MYDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

IMG=registry.gitlab.com/gha1/spark-history-server:latest
cd $MYDIR

docker build . -t $IMG
docker push $IMG
