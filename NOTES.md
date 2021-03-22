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

./submit.sh Json2Parquet --backDays 0 --maxFiles 1 --waitSeconds 0 --srcBucketFormat gharaw1 --s3Endpoint "https://minio1.shared1" --s3AccessKey minio --s3SecretKey minio123

./submit.sh CreateTable --s3Endpoint "https://minio1.shared1" --s3AccessKey minio --s3SecretKey minio123 --metastore thrift://tcp1.shared1:9083 --database gha --srcPath s3a://gha/raw --table t1 --select "actor.login as actor, actor.display_login as actor_display, org.login as  org, repo.name as repo, type, payload.action, src"

As S3 connection parameters are now in spark-submit:

./submit.sh Json2Parquet --backDays 0 --maxFiles 1 --waitSeconds 0 --srcBucketFormat gharaw1

./submit.sh CreateTable --metastore thrift://tcp1.shared1:9083 --database gha --srcPath s3a://gha/raw --table t2 --select "actor.login as actor, actor.display_login as actor_display, org.login as  org, repo.name as repo, type, payload.action, src"

# Image building

./spark-3.1.1/bin/docker-image-tool.sh -r registry.gitlab.com/gha1 -t latest build
./spark-3.1.1/bin/docker-image-tool.sh -r registry.gitlab.com/gha1 -t latest push

# Links

https://arnon.me/2015/08/spark-parquet-s3/

https://jaceklaskowski.gitbooks.io/mastering-spark-sql/content/spark-sql-hive-metastore.html

https://www.datamechanics.co/blog-post/setting-up-managing-monitoring-spark-on-kubernetes

https://medium.com/@adamrempter/running-spark-3-with-standalone-hive-metastore-3-0-b7dfa733de91

https://medium.com/@binfan_alluxio/running-presto-with-hive-metastore-on-a-laptop-in-10-minutes-72823f1ebf01

https://www.philipphoffmann.de/post/spark-shell-s3a-support/

https://www.margo-group.com/fr/actualite/tutoriel-delta-lake-premiere-prise-en-main/

https://stackoverflow.com/questions/61301704/how-to-run-apache-spark-with-s3-minio-secured-with-self-signed-certificate


