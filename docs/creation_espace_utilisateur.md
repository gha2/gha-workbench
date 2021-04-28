# Création des espaces utilisateur

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Index**

  - [En mode direct](#en-mode-direct)
- [Au travers d'ArgoCD](#au-travers-dargocd)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->


## En mode direct

Bien qu'il soit possible de déployer nos applications Spark dans le namespace par défaut, et avec une compte de type 'superadmin',
les bonnes pratiques requièrent que l'on déploie dans un namespace dédié (Ou partagé avec d'autres applications) et à partir d'un compte limité au strict nécéssaire.

Créer cet environnement est l'objet du script <https://github.com/gha2/gha-workbench/blob/master/k8s/setup.sh>

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

On peut donc couper/coller la dernière ligne pour s'identifier sous le compte de service 'spark'

# Au travers d'ArgoCD

