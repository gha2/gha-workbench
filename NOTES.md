# Setup

tar xvzf spark-3.1.1-bin-hadoop3.2.tgz
mv spark-3.1.1-bin-hadoop3.2 spark-3.1.1
mv spark-3.1.1-bin-hadoop3.2.tgz archives/

# Hadoop version is defined by looking on spark-3.1.1/jars/hadoop*/jar
wget https://archive.apache.org/dist/hadoop/common/hadoop-3.2.0/hadoop-3.2.0.tar.gz
tar xvzf hadoop-3.2.0.tar.gz
mv hadoop-3.2.0.tar.gz archives/
cp ./hadoop-3.2.0/share/hadoop/tools/lib/hadoop-aws-3.2.0.jar spark-3.1.1/jars
cp ./hadoop-3.2.0/share/hadoop/tools/lib/aws-java-sdk-bundle-1.11.375.jar spark-3.1.1/jars
# Not needed anymore
rm -rf hadoop-3.2.0/



# test

./json2parquet.sh xxx s3a://gha2minio-2021/2021/03/07/00.json.gz






# Links

https://arnon.me/2015/08/spark-parquet-s3/
https://jaceklaskowski.gitbooks.io/mastering-spark-sql/content/spark-sql-hive-metastore.html
https://www.datamechanics.co/blog-post/setting-up-managing-monitoring-spark-on-kubernetes
https://medium.com/@adamrempter/running-spark-3-with-standalone-hive-metastore-3-0-b7dfa733de91
https://medium.com/@binfan_alluxio/running-presto-with-hive-metastore-on-a-laptop-in-10-minutes-72823f1ebf01
https://www.philipphoffmann.de/post/spark-shell-s3a-support/
https://www.margo-group.com/fr/actualite/tutoriel-delta-lake-premiere-prise-en-main/
https://www.margo-group.com/fr/actualite/tutoriel-delta-lake-premiere-prise-en-main/

