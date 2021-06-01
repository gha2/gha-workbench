# Composants d'infrastructure

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Index**

- [Kubernetes](#kubernetes)
- [ArgoCD](#argocd)
- [Minio](#minio)
  - [Minio: Déploiement](#minio-d%C3%A9ploiement)
- [Topolvm](#topolvm)
- [Spark](#spark)
  - [Spark: Gestion des Jars applicatif.](#spark-gestion-des-jars-applicatif)
- [Operateur Spark](#operateur-spark)
- [Spark history server](#spark-history-server)
- [Hive Metastore](#hive-metastore)
- [Postgresql](#postgresql)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->



## Kubernetes

Ce POC est déployé sur un cluster Kubernetes installé en utilisant [kubespray](https://github.com/kubernetes-sigs/kubespray). Même si ce déploiement est en pratique effectué sur une infrastructure de virtualisation, il est très proche d'un déploiement 'bare metal'.

`RBAC` et les `PodSecurityPolicy` sont activés.

## ArgoCD

ArgoCD est une application Kubernetes permettant l'automatisation des déploiements aussi bien applicatif que middleware.

Il permet le pattern GitOps, évolution de l'IAC (Infrastructure As Code) en automatisant la réconciliation entre les définitions stockées dans Git et la réalité des applications déployées sur le cluster.

Avec ArgoCD, un déploiement peut lui-même être décrit sous la forme d'un manifest Kubernetes, ce qui permet le pattern app-of-apps (Ou Meta-Application).

L'ensemble des déploiements utilisés pour ce Poc sont [dans ce repo](https://github.com/BROADSoftware/depack).

> A noter que ce repo contient aussi des déploiements sans relation avec ce POC.

Pour pouvoir rentrer dans ce moule, un déploiement doit pouvoir être entièrement défini sous forme de manifest Kubernetes. Ce qui est généralement le cas, à l'exception de certain middlewares spécifiques.

## Minio

Minio est un projet opensource fournissant un stockage de type S3 sur une infrastructure bare-metal.
Dans notre contexte, il sera utilisé comme stockage principal pour tous les déployments hors cloud.

Outre la fonctionnalité serveur de stockage, Minio fournis aussi un interface CLI et des SDK dans différents languages, permettant l'accès à des fonctionnalités étendues. Mais, un serveur Minio est aussi accessible en utilisant les outils  standard AWS (CLI, libraries, SDK).

Dans le cadre de ce POC, Minio est configuré de manière 'secure', en utilisant https. Le certificat serveur étant émis par une autorité globale au cluster, il y aura donc lieux, pour les applications y accédant:

- soit de désactiver la vérification de validité du certificat serveur.
- soit de fournir le certificat de cette autorité

Les deux solutions on été successivement utilisées dans le cadre de ce POC.

### Minio: Déploiement

Le serveur Minio peut etre déployé directement sur les machines (VMs ou Bare-metal). Il peut aussi etres déployé sur une infrastructure Kubernetes. ceci soit:

- Directement, au travers d'une chartre Helm.
- Ou bien par l'intermédiaire d'un opérateur.

Cette deuxième méthode a été utilisée dans notre contexte. [Voir ici](https://github.com/BROADSoftware/depack/tree/master/middlewares/minio.3.0.28)

## Topolvm

Topolvm est un driver CSI (Container Storage Interface) permettant la création dynamique de `LogicalVolume` LVM et leur attachement aux containers applicatifs en tant que `PersistentVolumes`.

Il est notamment utilisé pour satisfaire les PVC (`PersistantVolumeClaim`) demandés par Minio.

Topolvm est déployé à la création du cluster. (Il est incompatible avec le pattern appsOfApps, car il nécessite notamment le déployement de modules systemd).

Topolvm intègre aussi une extention du Scheduler kubernetes, afin d'influencer les règles de placement en fonction de l'espace disque restant dicponible sur chaque noeud.

## Spark

Le fonctionnement de Spark sur Kubernetes est assez analogue à celui sur Yarn, excepté que driver et executors sont maintenant déployé dans des containers Kubernetes.

Dans le cadre de notre POC, l'autre différence par rapport à un context Hadoop est la substitution du stockage HDFS par S3.

### Spark: Gestion des Jars applicatif.

Pour son fonctionnement, Spark va charger dynamiquement un (ou plusieurs) jars applicatif, en utilisant le 'ClassLoader' de Java.

Spark étant par nature distribué, la mise à disposition de ce Jar applicatif à l'ensemble des instances d'exécution demande un traitement particulier.

Dans notre contexte Kubernetes, deux solutions sont possibles :

- Embarquer le jar applicatif dans l'image Docker.
- Stocker le jar applicatif dans un stockage partagé et configurer Spark pour le retrouver dynamiquement.

La première solution est la plus simple à mettre en oeuvre. Mais, elle impose un cycle de mise au point plus lourd. Elle pourra toutefois ètre privilégiée si l'on dispose d'une chaine CI/CD efficace, automatisant les nombreuses reconstruction de l'image.

La seconde solution est un peu plus exigente en terme de configuration. C'est celle retenue pour ce POC.

## Operateur Spark

En standard, le déploiement d'une application Spark consiste à lancer une commande `spark-submit` depuis l'extérieur du cluster. Ce pattern impératif n'est donc pas compatible avec une logique GitOps.

[L'opérateur Spark](https://github.com/GoogleCloudPlatform/spark-on-k8s-operator) est un projet de Google résolvant ce problème en permettant de définir une application spark de manière déclarative.

Il permet aussi de définir un lancement récurent d'application Spark, avec une logique de Crontab.

## Spark history server

Lors de l'exécution d'un job spark, le driver offre un front-end web permettant de monitorer l'exécution des tâches. Ce front-end est géré par le `driver` spark, ce qui implique qu'il va disparaitre à la fin du traitement.

Néanmoins, à la fin de ce traitement, les journaux d'événement Spark sont sauvegardés dans un bucket S3. Et le `Spark history server` permet de les visualiser.

Pour notre POC, ce server est bien sur containerisé et accessible au travers d'un ingress controller.

## Hive Metastore

Le Metastore Hive permet un référencement des métadonnées (Database, Tables, Column, etc...). Il est implémenté sous la forme d'un container, dont la construction sera détaillée ultérieurement.

Il requiert un SGBD tel que PostgreSQL, Oracle ou MySQL.

A noter qu'il peut jouer le role d'un référentiel partagé avec d'autre applications (Presto par exemple)

## Postgresql

Pour le Metastore Hive, PostgreSQL sera utilisé, dans sa version 9.6.

Le deploiement dans notre contexte est [ici](https://github.com/BROADSoftware/depack/tree/master/middlewares/postgresql/server)

A noter que dans le cadre de ce POC, la persistence est généralement assurée par un stockage local (En utilisant Topolvm). Ce qui implique une adhérence entre le serveur et le noeud qui le porte. Ceci est bien évidement inacceptable dans un contexte autre que celui d'un POC.
