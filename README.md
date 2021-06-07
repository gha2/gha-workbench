# KDP: POC Spark on Kubernetes/S3

## Index

- [Overview](#Overview)
- [Composants d'infrastructure](docs/composants_infrastructure.md)
- [Composants applicatifs](docs/composants_applicatifs.md)
- [Déploiement et mise en oeuvre](docs/deploiement.md)
- [Creation des espaces utilisateurs](docs/creation_espace_utilisateur.md)
- [Utilisation directe](docs/utilisation_directe.md)
- [Utlisation au travers de l'opérateur Spark](docs/utilisation_spark_operator.md)
- [Deployment sur AWS (En cours)](docs/aws.md) 
- [Ensuite...](docs/ensuite.md)

## Overview

Le but de ce POC est de valider la faisabilité d'une double problématique :

- Déploiement Spark sur Kubernetes
- Remplacement de HDFS par un stockage object de type S3.

Pour ce POC, nous utiliserons les [archives Github](https://www.gharchive.org/).

Cette première étape n'integrera que des traitements batch. Les traitements en mode streaming pourrons faire l'objet d'une étude complémentaire.

Voici le schéma général :

![](docs/overview.jpg)

- Github publie toute les heures un nouveau fichier regroupant toutes les opérations. Un premier module (`gha2minio`) se charge de collecter 
  ces fichiers et de les stocker tel quel dans un premier espace de stockage (Lac primaire). Ces fichiers sont au format JSON.
- Un second processus (`Json2parquet`) se charge de transformer ces données en format parquet, permettant ainsi de les voir comme une table unique. Ces données sont stockées dans un espace désigné comme Lac secondaire.
- Ensuite, des processus spécifiques (`CreateTable`) restructure cette table de base en une ou plusieurs tables adapté aux objectifs d'analyse. A la différence de la table de base, les définitions de ces tables sont référencées dans un metastore, basé sur celui utilisé par Hive. Les données elles même étant stockées dans S3, dans un troisième espace (Datamart).

A chacun de ces trois espaces correspond un bucket S3. 

Les détails du format de stockage seront décrit dans la suite.
