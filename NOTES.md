# Setup

tar xvzf spark-3.1.1-bin-hadoop3.2.tgz
mv spark-3.1.1-bin-hadoop3.2 spark-3.1.1
mv spark-3.1.1-bin-hadoop3.2.tgz archives/

Hadoop version is defined by looking on spark-3.1.1/jars/hadoop*/jar

wget https://archive.apache.org/dist/hadoop/common/hadoop-3.2.0/hadoop-3.2.0.tar.gz
tar xvzf hadoop-3.2.0.tar.gz
mv hadoop-3.2.0.tar.gz archives/
cp ./hadoop-3.2.0/share/hadoop/tools/lib/hadoop-aws-3.2.0.jar spark-3.1.1/jars
cp ./hadoop-3.2.0/share/hadoop/tools/lib/aws-java-sdk-bundle-1.11.375.jar spark-3.1.1/jars
# Not needed anymore
rm -rf hadoop-3.2.0/

# Doc

doctoc README.md --github

# test (local)


./submit.sh Json2Parquet --backDays 2 --maxFiles 2
./submit.sh Show s3a://gha/raw

./submit.sh Json2Parquet --backDays 0 --maxFiles 1 --waitSeconds 0 --srcBucketFormat gharaw --s3Endpoint "http://localhost:9000" --s3AccessKey accesskey --s3SecretKey secretkey

./submit.sh CreateTable --s3Endpoint "http://localhost:9000" --s3AccessKey accesskey --s3SecretKey secretkey --database gha --srcPath s3a://gha/raw --table t1 --select "actor.login as actor, actor.display_login as actor_display, org.login as  org, repo.name as repo, type, payload.action, src"

scala> spark.sql("REFRESH TABLE gha2.t2")

scala> spark.sql("SELECT * from gha.t1 ORDER BY actor LIMIT 20").show()
scala> spark.sql("SELECT type, count(*) AS cnt  from gha2.t2 GROUP BY type ORDER BY cnt DESC").show()

scala> spark.sql("SELECT DISTINCT type, action FROM gha.t ORDER BY type").show()

## On kspray1

### Local

./submit-local.sh Json2Parquet --backDays 0 --maxFiles 1 --waitSeconds 0 --srcBucketFormat gharaw1 --s3Endpoint "https://minio1.shared1" --s3AccessKey minio --s3SecretKey minio123

./submit-local.sh CreateTable --s3Endpoint "https://minio1.shared1" --s3AccessKey minio --s3SecretKey minio123 --metastore thrift://tcp1.shared1:9083 --database gha --srcPath s3a://gha/raw --table t1 --select "SELECT actor.login as actor, actor.display_login as actor_display, org.login as  org, repo.name as repo, type, payload.action, src FROM _src_"

### Cluster

time ./submit.sh Json2Parquet json2parquet1 --backDays 0 --maxFiles 1 --waitSeconds 0 --srcBucketFormat gha-primary-1 \
--dstBucketFormat gha-secondary-1 --dstObjectFormat "raw/year={{year}}/month={{month}}/day={{day}}/hour={{hour}}"


./submit.sh Json2Parquet j2p-daemon --backDays 0 --waitSeconds 30 --srcBucketFormat gha-primary-1 \
--dstBucketFormat gha-secondary-1 --dstObjectFormat "raw/year={{year}}/month={{month}}/day={{day}}/hour={{hour}}"



time ./submit.sh CreateTable create-t1 --metastore thrift://metastore.hive-metastore.svc:9083 --srcPath s3a://gha-secondary-1/raw \
--database gha_dm_1 --table t1 --dstBucket gha-dm-1  --waitOnEnd 0 \
--select "SELECT year, month, day, hour, actor.login as actor, actor.display_login as actor_display, org.login as  org, repo.name as repo, type, payload.action FROM _src_"


time ./submit.sh CreateTable create-t2 --metastore thrift://metastore.hive-metastore.svc:9083 --srcPath s3a://gha-secondary-1/raw \
--database gha_dm_1 --table t2 --dstBucket gha-dm-1 --waitOnEnd 0 \
--select "SELECT year, month, day, hour, actor.login as actor, actor.display_login as actor_display, org.login as  org, repo.name as repo, type, payload.action FROM _src_ WHERE year='2021' AND month='04' ORDER BY repo"




time ./submit.sh Count --srcPath s3a://gha-secondary-1/raw --waitOnEnd 0
time ./submit.sh Count --srcPath s3a://gha-dm-1/t2 --waitOnEnd 0




# Image building

./spark-3.1.1/bin/docker-image-tool.sh -r registry.gitlab.com/gha1 -t latest build
./spark-3.1.1/bin/docker-image-tool.sh -r registry.gitlab.com/gha1 -t latest push

# Pbs

2021-03-28-05: This file hang when handled on K8S (Works when handled locally)

# Links

https://arnon.me/2015/08/spark-parquet-s3/

https://jaceklaskowski.gitbooks.io/mastering-spark-sql/content/spark-sql-hive-metastore.html

https://www.datamechanics.co/blog-post/setting-up-managing-monitoring-spark-on-kubernetes

https://medium.com/@adamrempter/running-spark-3-with-standalone-hive-metastore-3-0-b7dfa733de91

https://medium.com/@binfan_alluxio/running-presto-with-hive-metastore-on-a-laptop-in-10-minutes-72823f1ebf01

https://www.philipphoffmann.de/post/spark-shell-s3a-support/

https://www.margo-group.com/fr/actualite/tutoriel-delta-lake-premiere-prise-en-main/

https://stackoverflow.com/questions/61301704/how-to-run-apache-spark-with-s3-minio-secured-with-self-signed-certificate

https://engineering.linkedin.com/blog/2020/open-sourcing-kube2hadoop

https://towardsdatascience.com/jupyter-notebook-spark-on-kubernetes-880af7e06351

https://medium.com/@carlosescura/run-spark-history-server-on-kubernetes-using-helm-7b03bfed20f6
https://medium.com/@GusCavanaugh/how-to-install-spark-history-server-on-aws-eks-with-helm-85e2d3f356f7

https://github.com/JahstreetOrg/spark-on-kubernetes-helm