# Utilisation au travers de l'opérateur Spark.

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Index**

- [Mise à disposition du Jar applicatif](#mise-%C3%A0-disposition-du-jar-applicatif)
- [Soumission en ligne de commande](#soumission-en-ligne-de-commande)
- [Déploiement au travers d'ArgoCD](#d%C3%A9ploiement-au-travers-dargocd)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

## Mise à disposition du Jar applicatif

Comme l'image Spark est indépendante de toute application, il faut que le jar applicatif soit mis à la disposition du driver et des exécuteur Spark. 
Pour cela, le moyen le plus simple dans notre contexte est d'utiliser notre stockage S3.

Un script [upload.sh](https://github.com/gha2/gha-workbench/blob/master/spark-operator/upload.sh) permet d'effectuer cette opération en utilisant la commande `mc` de Minio. Préalablement, il va compiler le module `gha2spark` intégrant nos applications Spark.

Ensuite ce script vas rendre le jar accessible au travers d'HTTPS sans authentification.

> A noter que cette opération n'etait pas nécessaire avec le lancement par `spark submit`. En effet, cette commande prend en charge automatiquement l'upload de notre jar dans le stockage S3.

## Soumission en ligne de commande

Soumettre un job Spark va maintenant consister à soumettre un manifest tel que celui-ci:

``` 
---
apiVersion: "sparkoperator.k8s.io/v1beta2"
kind: SparkApplication
metadata:
  name: spark-j2p   # Used as the drive name prefix
  namespace: spark1
spec:
  type: Scala
  mode: cluster
  image: "registry.gitlab.com/gha1/spark"
  imagePullPolicy: Always
  mainClass: "gha2spark.Json2Parquet"
  #mainApplicationFile: "s3a://spark/jars/gha2spark-0.1.0-uber.jar"
  mainApplicationFile: "https://minio1.shared1/spark/jars/gha2spark-0.1.0-uber.jar"
  sparkVersion: "3.1.1"
  restartPolicy:
    type: Never
  arguments:
    - --backDays
    - "0"
    - --maxFiles
    - "1"
    - --waitSeconds
    - "0"
    - --srcBucketFormat
    - gha-primary-1
    - --dstBucketFormat
    - gha-secondary-1
    - --dstObjectFormat
    - "raw/year={{year}}/month={{month}}/day={{day}}/hour={{hour}}"
    - --appName
    - spark-j2p   # Will be used for executor name prefix
    # The following does not work. Seems 'arguments' are not interpolated with env variable.
    # So, the variable fetching is handled in the code of the application.
    # - --s3Endpoint
    # - "${S3_ENDPOINT}"
  sparkConf:
    "spark.kubernetes.file.upload.path": "s3a://spark/shared"
    "spark.hadoop.fs.s3a.impl": "org.apache.hadoop.fs.s3a.S3AFileSystem"
    "spark.hadoop.fs.s3a.fast.upload": "true"
    "spark.hadoop.fs.s3a.path.style.access": "true"
    "spark.eventLog.enabled": "true"
    "spark.eventLog.dir": "s3a://spark/eventlogs"
  driver:
    env:
      - name: S3_ENDPOINT
        valueFrom:
          secretKeyRef:
            name: minio-server
            key: serverUrl
      - name: S3_ACCESS_KEY
        valueFrom:
          secretKeyRef:
            name: minio-server
            key: accessKey
      - name: S3_SECRET_KEY
        valueFrom:
          secretKeyRef:
            name: minio-server
            key: secretKey
    cores: 1
    coreLimit: "4"
    memory: "4G"
    labels:
      version: "3.1.1"
    podName: spark-j2p-driver
    serviceAccount: spark
  executor:
    instances: 2
    cores: 1
    coreLimit: "4"
    memory: "4G"
    labels:
      version: "3.1.1"
```

Ce manifest (`spark-j2p.yaml`) ainsi que d'autres exemple se trouve [ic](https://github.com/gha2/gha-workbench/tree/master/spark-operator)

Ce job Spark vas donc lancer la commande `json2parquet` sur un fichier (`--maxFiles 1`) et ensuite s'arrèter (`--waitSeconds 0`). C'est l'équivalent du premier exemple d'utilisation du chapitre précédent.

Quelques remarques :

- Le namespace `spark1` aura été préalablement crée au travers d'ArgoCD (Voir [Création des espaces utilisateur](./creation_espace_utilisateur.md)). 
- On voit deux moyens de récuperer le Jar applicatif (Propriété `mainApplicationFile`) : Par un acces par S3 ou bien au travers d'une requète HTTPS. C'est ce second choix qui est ici retenu.

 La raison en est que l'utilisation de S3 requiert de s'authentifier. Ce qui aurait impliqué de définir les credentials d'accès dans le configuration Spark (Propriété `sparkConf`), donc en clair.

  Le choix retenu permet de les récupérer depuis un secret et ultérieurement depuis un Vault externe.

Après avoir créé le secret pour les credentials d'accès Minio, on pourra lancer ce job par un classique `kubectl apply ....`

``` 
cd ..../spark-operator
kubectl apply -f minio-server.yaml
kubectl apply -f spark-j2p.yaml.yaml
```

A noter qu'une fois executé sans erreur, le Job reste dans l'état `completed` et ne sera pas relancé par un autre `apply`. (C'est le fonctionnement habituel d'un Job Kubernete). Pour le relancer, il faudra donc faire:

``` 
kubectl delete -f spark-j2p.yaml.yaml && kubectl apply -f spark-j2p.yaml.yaml
```

Dans cet exemple, la plue-value apporté par l'opérateur Spark par rapport à un `spark submit` n'est pas évidente. En fait, celui-ci prend tout son sens lors de son utilisation dans le cadre d'un déploiement continu, par exemple avec ArgoCD.

## Déploiement au travers d'ArgoCD

Un exemple d'un tel déploiement se trouve ici : <https://github.com/BROADSoftware/depack/tree/master/apps/gha/json2parquet>.

Il s'agit dune petite charte Helm permettant le deploiement d'une resource de type `ScheduledSparkApplication`. Celle-ci lance la commande `json2parquet` de manière régulière, avec une logique de crontab.

Cette charte intègre un certain nombre de paramètre de configuration. Un fichier `values.yaml` fournis des valeurs par défaut, sauf pour les credentials d'accès minio qui devront ètre défini explicitement à chaque déploiement.

Voici un exemple d'application ArgoCD utilisant cette charte en modifiant certaines valeurs :

```
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: gha-json2parquet
  namespace: argocd
spec:
  source:
    path: apps/gha/json2parquet
    repoURL: https://github.com/BROADSoftware/depack.git
    helm:
      values: |
        json2parquet:
          schedule: "@every 1m"
          minio:
            serverUrl: https://minio.minio1.svc
            accessKey: minio
            secretKey: minio123
          backDays: 0
          maxFiles: 1
          driver:
            cores: 1
          executor:
            instances: 2
            cores: 1
  destination:
    namespace: spark1
    server: https://kubernetes.default.svc
  project: default
  syncPolicy:
    syncOptions:
      - CreateNamespace=false
```
