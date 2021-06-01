<table style="width: 100%"><tr>
    <td style="width: 33%; text-align: left"><a href="deploiement.md"><- Déploiement et mise en oeuvre</a></td>
    <td style="width: 33%; text-align: center"><a href="../README.md">HOME</a></td>
    <td style="width: 33%; text-align: right"><a href="utilisation_directe.md">Utilisation directe -></a></td>
</tr></table>

# Création des espaces utilisateur

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Index**

- [En ligne de commande](#en-ligne-de-commande)
- [Au travers d'ArgoCD](#au-travers-dargocd)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

Bien qu'il soit possible de déployer nos applications Spark dans le namespace par défaut, et avec une compte de type 'superadmin',
les bonnes pratiques requièrent que l'on déploie dans un namespace dédié (Ou partagé avec d'autres applications) et à partir d'un compte avec des permissions limitées au strict nécéssaire.

## En ligne de commande

Créer un tel environnement est l'objet du script <https://github.com/gha2/gha-workbench/blob/master/k8s/setup.sh>

> IMPORTANT: le bon fonctionnement de ce script nécessite la présence de deux petits utilitaires de manipulation [JSON (jq)](https://stedolan.github.io/jq/) et [YAML (yq)](https://mikefarah.gitbook.io/yq/). Il est donc nécessaire de les installer localement, en suivant la procédure adaptée au système d'exploitation.

Ce script va :

- Créer un namespace dédié ('spark' par défaut).
- Créer un compte de service.
- Créer un role RBAC avec les droits nécéssaires et suffisant pour lancer un Job Spark.
- Associer ce role au compte de service
- Générer localement un fichier de type 'kubconfig' permettant la connexion au cluster sous ce même compte de service.

Lors du lancement de ce script, `kubectl` doit etres configuré pour accéder au cluster cible, avec les droits d'administration.

Voici le résultat de l'exécution de ce script :

```
$ ./setup.sh
namespace/spark created
serviceaccount/spark created
role.rbac.authorization.k8s.io/spark created
rolebinding.rbac.authorization.k8s.io/spark created
To switch to spark config:
export KUBECONFIG=/Users/sa/dev/g6/git/gha-workbench/k8s/kubeconfig.spark.kspray1.local
```

On peut donc couper/coller la dernière ligne pour s'identifier sous le compte de service 'spark' et lancer ensuite des commandes `spark-submit`.

A noter que le compte de service ainsi créé est utilisé pour deux fonctions :

- Par l'utilisateur pour lancer les `spark submit`
- Par le driver Spark (Dans le POD lancé par le spark submit) pour interagir avec Kubernetes, notament pour lancer et controler les POD executor.

## Au travers d'ArgoCD

Il est aussi possible de créer cet espace utilisateur au travers d'une charte Helm, déployé par ArgoCD: <https://github.com/BROADSoftware/depack/tree/master/middlewares/spark/spark-namespace>

Il suffit de déployer cette charte avec le namespace souhaité comme cible (En activant la création du namespace dans ArgoCD). 

Dans ce namespace sera donc déployé compte de service et un Role RBAC permettant le déploiement et la bonne exécution d'applications Spark (En fait cela est équivalent au résultat du script `setup.sh` décrit au paragraphe précédent)

Ce namespace pourra ensuite etres utilisé pour les déploiements de `SparkApplication` et `ScheduledSparkApplication` au travers d'ArgoCD, ou bien par kubectl.

Dans ce dernier cas, on pourra fournir à l'utilisateur un 'kubconfig' approprié. Pour le générer, on pourra utiliser le script <https://github.com/gha2/gha-workbench/blob/master/spark-operator/user.sh>

<table style="width: 100%"><tr>
    <td style="width: 33%; text-align: left"><a href="deploiement.md"><- Déploiement et mise en oeuvre</a></td>
    <td style="width: 33%; text-align: center"><a href="../README.md">HOME</a></td>
    <td style="width: 33%; text-align: right"><a href="utilisation_directe.md">Utilisation directe -></a></td>
</tr></table>

