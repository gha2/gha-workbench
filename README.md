

# KDP: POC Spark on Kubernetes/S3

## Overview

Le but de ce POC est de valider la faisabilité d'une double problématique :

- Déploiement Spark sur Kubernetes
- Remplacement de HDFS par un stockage object de type S3.

Pour ce POC, nous utiliserons les [archives Github](https://www.gharchive.org/).

Cette première étape n'integrera que des traitements batch. Les traitements en mode streaming pourrons faire l'objet d'une étude complémentaire.

Voici le schéma général :

![](docs/overview.jpg)

- Github publie toute les heures un nouveau fichier regroupant toutes les opérations. Un premier module (gha2minio) se charge de collecter 
  ces fichiers et de les stocker tel quel dans un premier espace de stockage (Lac primaire). Ces fichiers sont au format json.
- Un second processus (Json2parquet) se charge de transformer ces données en format parquet, permettant ainsi de les voir comme une table unique. Ces données sont stockées dans un espace désigné comme Lac secondaire.
- Ensuite, des processus spécifiques (CreateTable) restructure cette table de base en une ou plusieurs tables adapté aux objectifs d'analyse. A la différence de la table de base, les définitions de ces tables sont référencées dans un metastore, basé sur celui utilisé par Hive. Les données elles même étant stockées dans S3, dans un troisième espace (Datamart).

A chacun de ces trois espaces correspond un bucket S3. 

Les détails du format de stockage seront décrit ultérieurement.

## Composant d'infrastructure

### ArgoCD 

ArgoCD est une application Kubernetes permettant l'automatisation des déploiements aussi bien applicatif que middleware. 

Il permet le pattern GitOps, évolution de l'IAC (Infrastructure As Code) en automatisant la réconciliation entre les définitions stockées dans Git et la réalité des applications déployés sur le cluster.

Avec ArgoCD, un déploiement peut lui-même être décrit sous la forme d'un manifest Kubernetes, ce qui permet le pattern appsOfApps.

L'ensemble des déploiements utilisés pour ce Poc sont [dans ce repo](https://github.com/BROADSoftware/depack). 

Pour pouvoir rentrer dans ce moule, un déploiement doit pouvoir être entièrement défini sous forme de manifest Kubernetes. Ce qui est généralement le cas, à l'exception de certain middlewares spécifiques. 

### Minio

Minio est un projet opensource fournissant un stockage de type S3 sur une infrastructure bare-metal. 
Dans notre contexte, il sera utilisé comme stockage principal pour tous les déployments hors cloud.

Outre la fonctionnalité serveur de stockage, Minio fournis aussi un interface CLI et des SDK dans différents languages, permettant l'accès à des fonctionnalités étendues. Mais, un serveur Minio est aussi accessible en utilisant les outils (CLI, libraries, SDK) standard AWS.

#### Déployment

Le serveur Minio peut etre déployé directement sur les machines (VMs ou Bare-metal). Il peut aussi etres déployé sur une infrastructure Kubernetes. ceci soit:

- Directement, au travers d'une chartre Helm.
- Ou bien par l'intermédiaire d'un opérateur.

Cette deuxième méthode a été utilisée dans notre contexte. [Voir ici pour le déploiement](https://github.com/BROADSoftware/depack/tree/master/middlewares/minio.3.0.28)

### Topolvm

Topolvm est un driver CSI (Container Storage Interface) permettant la création dynamique de Logical Volume LVM et leur attachement aux containers applicatifs.

Il est notamment utilisé pour satisfaire les PVC (PersistantVolumeClaim) générés par Minio.

Topolvm est déployé à la création du cluster. (Il est incompatible avec le pattern appsOfApps)

### Spark

Le fonctionnement de Spark sur Kubernetes est assez analogue à celui sur Yarn, excepté que driver et executors sont maintenant déployé dans des containers Kubernetes.

Dans le cadre de notre POC, l'autre différence est la substitution du stockage HDFS par S3

#### Spark operateur

Out of the box, le déploiement d'une application Spark consiste à lancer un spark-submit à l'extérieur du cluster. Ce pattern impératif n'est donc pas compatible avec une logique GitOps.

Un projet de google [Spark Operateur](https://github.com/GoogleCloudPlatform/spark-on-k8s-operator) permet de résoudre ce problème en permettant de définir une application spark de manière déclarative.

## Composant applicatifs

### gha2minio

![](.README_images/gharaw1.png)

### Json2Parquet

![](.README_images/gha-raw.png)

### Hive Metastore



### CreateTable

![](.README_images/gha-t1.png)



Namespace and Account setup

https://mikefarah.gitbook.io/yq/




Next steps
- spark operator
- Benchmark (TPC-DS, ....)
- Etude de l'utilisation du stockage (Spilling)
- Setup history server
- Limitation des ressources
- Gestion des droits S3
- Deployement AWS
- Etude DeltaLake
- Etude YuniKorn
- Access (beeline, JDBC, spark Thrift server)
- Jupyter notebook
- [Securisation](http://spark.apache.org/docs/latest/security.html).
- Meilleure gestion du certificat TLS Minio.(Actuellement disableCertCheck).  
- HDFS on kubernetes ?




