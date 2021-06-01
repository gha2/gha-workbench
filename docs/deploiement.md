# Déploiement et mise en oeuvre

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Index**

- [Docker image registry](#docker-image-registry)
- [Hive Metastore](#hive-metastore)
  - [Hive Metastore: Création de l'image docker.](#hive-metastore-cr%C3%A9ation-de-limage-docker)
  - [Hive Metastore: Déploiement sur Kubernetes](#hive-metastore-d%C3%A9ploiement-sur-kubernetes)
- [Spark](#spark)
  - [Spark: Déploiement de l'arborescence.](#spark-d%C3%A9ploiement-de-larborescence)
  - [Spark: Configuration de l'arborescence.](#spark-configuration-de-larborescence)
  - [Spark: Generation de l'image.](#spark-generation-de-limage)
- [S3 setup](#s3-setup)
- [Spark History Server](#spark-history-server)
- [Spark operator](#spark-operator)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

## Docker image registry

Pour la mise en oeuvre de ce POC, il est nécessaire de construite des images docker, qui devront ensuite êtres déployées dans le ou les clusters cible.

Pour cela, le plus simple est d'utiliser une 'Container Registry' publique, telle que Docker Hub.
Toutefois, les récentes limitations de celui-ci, en termes de nombre de requètes ont conduit à trouver une alternative.

Pour ce POC, il a été utilisé la solution (gratuite) fournie par GitLab.

## Hive Metastore

Dans le cadre de ce POC, le Metastore Hive a vocation à être containerisé pour fonctionner dans Kubernetes

### Hive Metastore: Création de l'image docker.

Le projet <https://github.com/gha2/standalone-hive-metastore> héberge le Dockerfile adéquat, et les scripts associés.

Ce Dokerfile part d'une image `openjdk 1.8`. Ensuite:

- Il télécharge les binaires d'une version standalone du Metastore Hive et les déploie.
- Il télécharge les binaires `hadoop common` et les déploie.
- Il supprime une configuration `log4j` conflictuelle.
- Il ajoute les modules nécéssaires à la connection postgresql
- Il ajuste les droits pour permettre le fonctionnement sous un compte non-root `hive`
- Il ajoute une configuration de `sudoers`, pour permettre de passer `root`. Ceci est très utile pour la mise au point, mais devra être supprimé par la suite.
  (A noter que pour pouvoir passer `root` il faut aussi activer une `PodSecurityPolicy` libérale).
- Il copie le script de lancement.

Ce script de lancement accepte de nombreux paramètre en entrée, passés sous forme de variable d'environnement.

A noter qu'il est susceptible d'initialiser la base de données si elle n'est pas présente. Il est donc aussi nécessaire de fournir les paramètres requis pour cette initialisation.

Le script de lancement va donc:

- Tester la présence des paramètres obligatoires et fournir des valeurs par défaut pour les autres.
- Générer un fichier `metastore-log4j2.properties` avec un niveau de trace paramétrable.
- Générer le fichier de configuration principal `metastore-site.xml`, en y incluant les paramètres de configuration fournis sous forme de variable d'environnement. A noter que, même si les tables sont externes, le Metastore Hive effectue des accès au stockage S3. Il est donc nécessaire que celui-ci soit configuré correctement. Sinon, les tentatives de génération de table échoueront.
- Attendre que le serveur postgresql soit disponible.
- Initialiser la base de donné si elle n'existe pas
- Lancer le métastore Hive

A noter en fin de script une astuce optionnelle retardant la fin d'exécution du script en cas d'erreur. Ceci pour permettre de visualiser les logs et/ou dans lancer un `kubectl exec ... /bin/sh` pour investiguer.

### Hive Metastore: Déploiement sur Kubernetes

Le déploiement du Metastore Hive dans le cadre de notre POC est défini ici : <https://github.com/BROADSoftware/depack/tree/master/middlewares/hive-metastore>

Ce déploiement contient trois ressources :

- Un Secret contenant les paramètres d'accès à Minio.
- Le Déploiement lui-même.
- Le Service permettant l'accès, avec éventuellement un point d'accès depuis l'extérieur

Il est effectué dans le namespace `spark-system`.

## Spark

### Spark: Déploiement de l'arborescence.

L'ensemble des scripts et autres fichiers de configuration qui sont utilisé dans la suite de ce document sont regroupé dans le repository <https://github.com/gha2/gha-workbench>. Si vous souhaitez reproduire ce POC dans votre contexte, clonez le sur votre système, et de se placez vous à sa racine.

Il est d'abord nécessaire de déployer une arborescence Spark, pour deux usages :

- Etre à la base de la construction des images docker Spark.
- Permettre l'exécution en local de `spark-submit`, `spark-shell`, etc....

Pour cela, il faut télécharger sur le site Spark la version `Pre-built for Apache Hadoop 3.2 and later`, puis la déployer dans la racine de notre projet.
On pourra aussi le renommer, pour simplifier le path

```
tar xvzf spark-3.1.1-bin-hadoop3.2.tgz
mv spark-3.1.1-bin-hadoop3.2 spark-3.1.1
```

L'archive pouvant ensuite êtres mise de coté 'au cas où'.

```
mv spark-3.1.1-bin-hadoop3.2.tgz archives/
```

Il faut maintenant rajouter dans cette arborescence deux fichiers jars permettant l'accès à S3. Mais, ceux-ci doivent correspondre strictement à la version précise d'Hadoop.
Le plus simple est donc de les extraire de la distribution correspondante.

Il faut donc d'abord déterminer la version précise de l'Hadoop embarqué. Pour cela:

```
ls ./spark-3.1.1/jars/hadoop*.jar
spark-3.1.1/jars/hadoop-annotations-3.2.0.jar			spark-3.1.1/jars/hadoop-mapreduce-client-jobclient-3.2.0.jar
spark-3.1.1/jars/hadoop-auth-3.2.0.jar				spark-3.1.1/jars/hadoop-yarn-api-3.2.0.jar
......
```

Dans notre cas, il s'agit donc de la version 3.2.0.

Nous pouvons donc récupérer l'archive correspondante, et en copier les fichiers qui nous intéressent dans notre déploiement Spark:

```
wget https://archive.apache.org/dist/hadoop/common/hadoop-3.2.0/hadoop-3.2.0.tar.gz
tar xvzf hadoop-3.2.0.tar.gz
cp ./hadoop-3.2.0/share/hadoop/tools/lib/hadoop-aws-3.2.0.jar spark-3.1.1/jars
cp ./hadoop-3.2.0/share/hadoop/tools/lib/aws-java-sdk-bundle-1.11.375.jar spark-3.1.1/jars
```

Nous pouvons ensuite supprimer le déploiement Hadoop et mettre l'archive de côté, au cas où :

```
rm -rf hadoop-3.2.0/
mv hadoop-3.2.0.tar.gz archives/
```

### Spark: Configuration de l'arborescence.

Il faut maintenant mettre en place certains fichiers de configuration :

> Les fichiers ajoutés ou modifiés sont accessible ici : <https://github.com/gha2/gha-workbench/tree/master/spark-3.1.1>

- Créer un fichier `log4j.properties` en dupliquant le template. A priori, aucune modification n'est nécésaire.

```
  cp spark-3.1.1/conf/log4j.properties.template spark-3.1.1/conf/log4j.properties
```

- Configurer le fichier `spark-3.1.1/conf/spark-defaults.conf` avec les informations suivantes

```
  spark.hadoop.mapreduce.outputcommitter.factory.scheme.s3a org.apache.hadoop.fs.s3a.commit.S3ACommitterFactory
  spark.hadoop.fs.s3a.committer.name directory
  spark.hadoop.fs.s3a.committer.staging.tmp.path /tmp/spark_staging
  spark.hadoop.fs.s3a.buffer.dir /tmp/spark_local_buf
  spark.hadoop.fs.s3a.committer.staging.conflict-mode fail
  spark.hadoop.fs.s3a.impl org.apache.hadoop.fs.s3a.S3AFileSystem
  spark.hadoop.fs.s3a.path.style.access true
  
  #spark.hadoop.fs.s3a.endpoint https://minio1.shared1/
  #spark.hadoop.fs.s3a.access.key minio
  #spark.hadoop.fs.s3a.secret.key minio123
  
  #spark.hive.metastore.uris thrift://tcp1.shared1:9083
```

  Les quatre dernières lignes devront être activées (dé-commentées) si l'on souhaite utiliser `spark-sql`, ou `spark-shell` en mode local, avec l'accès au Metastore Hive et aux données dans le stockage S3.

  > Si l'on souhaite plus d'information sur cette configuration, notamment sur la manière dont l'écriture sur S3 s'effectue, on pourra se reporter à ce lien : <https://hadoop.apache.org/docs/r3.1.1/hadoop-aws/tools/hadoop-aws/committers.html>

- Modifier le script `spark-3.1.1/kubernetes/dockerfiles/spark/entrypoint.sh` avec deux changements :

    - Ajouter une ligne `export _JAVA_OPTIONS="-Dlog4j.configuration=file:///opt/spark/log4j.properties"` avant le lancement des exécutables, pour la bonne prise en compte de ce fichier de configuration des logs applicatifs.
    - Si l'on ne prévoit pas d'ajouter une autorité de certification dans l'image (Voir plus bas), on complétera cette ligne par `" -Dcom.amazonaws.sdk.disableCertChecking=true"` . Ceci afin d'admettre des certificats signées par une autorité inconnue. Ce qui serait le cas dans le cadre de notre POC pour l'accès à Minio.
    - Ajouter une option `--verbose` au lancement du driver. Ceci est optionnel, et permet l'affichage des valeurs retenues pour la configuration.

  Voici un extrait de ce fichier avec les modifications :

```
  .....
  
  # export _JAVA_OPTIONS="-Dlog4j.configuration=file:///opt/spark/log4j.properties -Dcom.amazonaws.sdk.disableCertChecking=true"
  export _JAVA_OPTIONS="-Dlog4j.configuration=file:///opt/spark/log4j.properties"
  
  case "$1" in
  driver)
  shift 1
  CMD=(
  "$SPARK_HOME/bin/spark-submit"
  --verbose
  --conf "spark.driver.bindAddress=$SPARK_DRIVER_BIND_ADDRESS"
  --deploy-mode client
  .....
```

Le fichier complet est disponible à cet endroit : <https://github.com/gha2/gha-workbench/blob/master/spark-3.1.1/kubernetes/dockerfiles/spark/entrypoint.sh>.

- Modifier le `Dockerfile`

    - Ajouter une ligne pour copier le fichier log4j.properties à l'emplacement défini précédement.
    - Ajouter les deux lignes permettant de copier le certificat de la CA de Minio et de l'ajouter dans le truststore. (Bien sur, ce certificat devra avant avoir été placé manuellement dans le répertoire `spark-3.1.1/kubernetes/dockerfiles/spark/`)

    > Il est aussi possible de se contenter d'invalider la validation du certificat, comme évoqué précédement.

```
.....
COPY data /opt/spark/data

COPY conf/log4j.properties /opt/spark/log4j.properties

COPY kubernetes/dockerfiles/spark/ca2.crt $JAVA_HOME/lib/security
RUN cd $JAVA_HOME/lib/security && keytool -cacerts -storepass changeit -noprompt -trustcacerts -importcert -alias ca2.broadsoftware.com -file ca2.crt

ENV SPARK_HOME /opt/spark
.....
```

### Spark: Generation de l'image.

A partir de cette arborescence, il est maintenant simple de créer une image `spark`, qui sera téléchargé dans une registry accessible publiquement.

Spark fournis en effet les scripts nécessaires :

```
./spark-3.1.1/bin/docker-image-tool.sh -r registry.gitlab.com/gha1 -t latest build
./spark-3.1.1/bin/docker-image-tool.sh -r registry.gitlab.com/gha1 -t latest push
```

A noter que cette image Spark est générique, c'est à dire qu'elle n'embarque pas de module applicatif.


## S3 setup

Il est de plus nécessaire de créer un bucket `spark` qui aura deux usages :

- Etre la zone d'échange permettant de rendre accessible le jar applicatif par les containers
- Stocker les `event logs` spark, en vue de leur exploitation par le spark history server.

Pour cela, avec la commande `mc`, de `Minio` :

```
mc mb minio1.shared1/spark
touch _empty_
mc cp empty  minio1.shared1/spark/eventlogs/empty
rm _empty_
```

Bien sur, `minio1.shared1` devra ici être remplacé par le point d'accès Minio correct.

> Comme la logique de Minio ne permet pas la création explicite d'un répertoire vide, on a recours à la copie d'un fichier vide.

## Spark History Server

Voici le [Dockerfile](https://github.com/gha2/gha-workbench/blob/master/docker/spark-hs/Dockerfile) permettant la création de l'image pour le Spark history server :

```
FROM registry.gitlab.com/gha1/spark:latest

USER root

RUN adduser --uid 185 spark

USER 185
```

> Pour des raisons obscures, l'application HistoryServer requiert que l'utilisateur soit nommé, alors que l'image Spark standard se contente d'un `uid`.

On trouvera une Chart Helm de déploiement ici : <https://github.com/BROADSoftware/depack/tree/master/middlewares/spark/history-server>

A noter que ce déploiement est effectué dans le namespace `spark-system`.

## Spark operator

Cet opérateur Spark se compose des éléments suivants:

- Deux CRD (`CustomResourceDefinition`) décrivant les ressouces `SparkApplication` et `ScheduledSparkApplication`
- Le déploiement d'un Pod `SparkOperator`, agissant en tant que controleur des deux ressources précédentes.
- Un `ClusterRole` déclarant les privilèges nécéssaires pour le fonctionnement de l'opérateur, ainsi que `ServiceAccount` associé.
- Un `MutatingWebHook` optionnel, mais nécessaire dans le cadre de ce POC, afin de permettre l'injection des variables d'environment.

Une charte Helm est founie avec l'opérateur, prenant en charge tous les aspects du déploiement.

> Cette charte intègre aussi d'autres éléments, tel qu'une configuration prometheus ou une configuration permettant le déploiement des jobs Spark dans le même namespace, ce que l'on ne souhaite pas ici.

Une possibilité serait donc de recopier cette charte dans notre repository de référence.

Toutefois, cette solution manque de souplesse. On utilisera donc un autre pattern, qui consiste a créer une indirection vers la charte d'origine en créant une charte intermédiaire qui dépend de la charte d'origine. 

Cette charte ce trouve ici : <https://github.com/BROADSoftware/depack/tree/master/middlewares/spark/spark-operator>

Pour ce POC, le déploiement de cette charte sera effectué par ArgoCD, dans le namespace `spark-system`.

On profitera de cette charte intermédiaire pour ajoute un fichier [`values.yaml`](https://github.com/BROADSoftware/depack/blob/master/middlewares/spark/spark-operator/values.yaml) intégrant les configurations spécifiques de notre POC:

- `securityContext.runAsUser: 1001` pour être compliant avec une PSP (`PodSecurityPolicy`) `restricted`.
- Activation du webhook.  
- Une image plus récente que celle définie par défault dans la charte (Qui comporte un bug empéchant les variables d'environment d'ètres renseignés).
- Ne pas créer de compte de service pour Spark, car nous ne souhaitons pas déployer les applications dans ce même namespace.

A propos du Webhook, il est a noter que la charte Helm n'intègre pas de définition d'une resource `MutatingWebhookConfiguration`. Cette resource est créée dynamiquement par le pod `spark-operateur` lors de son initialisation. On notera aussi la présence d'un pod `spark-operator-webhook-init` qui va créer un secret contenant un certficat dédié à la communication entre ce webhook et l'api server.

