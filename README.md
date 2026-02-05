# Atelier K3d & Codespace: From Image to Cluster

Ce projet a pour objectif d'industrialiser le cycle de vie d'une application web simple. Il automatise la création d'une image Docker personnalisée, son import dans un cluster Kubernetes (K3d) et son déploiement via Ansible, le tout au sein d'un environnement GitHub Codespaces.

![Architecture Cible](Architecture_cible.png)

## Prérequis

Le projet est conçu pour fonctionner nativement dans **GitHub Codespaces**.
Aucune installation manuelle n'est requise : le script d'automatisation se charge d'installer les outils nécessaires (`Packer`, `K3d`, `Ansible`, `Python libs`) s'ils sont absents.

## Démarrage Rapide

L'intégralité du déploiement est pilotée par un **Makefile** pour simplifier l'exécution.

1. **Lancer le déploiement complet :**
Cette commande installe les dépendances, crée le cluster, construit l'image et déploie l'application.

```bash
make run
```

2. **Accéder à l'application :**
Une fois le déploiement terminé (message de succès), lancez le port-forwarding en arrière-plan :

```bash
make port-forward
```


*Ouvrez ensuite votre navigateur sur l'adresse locale (port 8081) ou via l'onglet "PORTS" de Codespaces.*

3. **Arrêter l'accès :**

```bash
make stop
```



## Architecture Technique

Le projet s'articule autour de trois composants majeurs orchestrés en séquence :

### 1. Build (Packer)

Nous utilisons **Packer** pour créer une image Docker immuable basée sur Nginx.

* **Fichier :** `nginx.pkr.hcl`
* **Action :** Récupère l'image `nginx:latest`, y injecte le fichier `index.html` local et tag l'image finale (`nginx-image-td:v1`).

### 2. Infrastructure (K3d)

Un cluster Kubernetes léger (**K3d**) est utilisé pour l'exécution.

* **Configuration :** 1 Master, 2 Agents.
* **Spécificité :** L'image construite par Packer est importée directement dans le registre interne du cluster (`k3d image import`) pour éviter de passer par un Docker Hub externe.

### 3. Déploiement (Ansible)

**Ansible** est utilisé comme outil d'Infrastructure as Code (IaC) pour piloter Kubernetes.

* **Fichier :** `deploy.yml`
* **Action :** Communique avec l'API Kubernetes pour créer les ressources :

  * `Deployment` : Gère les réplicas de l'application (Pods).
  * `Service` (NodePort) : Expose l'application sur le port 30080.

## Automatisation (Makefile)

Un fichier `Makefile` a été mis en place pour standardiser les opérations, de l'installation au nettoyage.

| Catégorie | Commande | Description |
| :--- | :--- | :--- |
| **Globales** | `make help` | Affiche les commandes disponibles dans le Makefile. | 
| | `make run` | **Commande recommandée.** Lance tout le cycle : Setup -> Cluster -> Build -> Import -> Deploy -> Check. |
| | `make update` | À utiliser après une modification du HTML. Reconstruit l'image et redéploie sans couper le cluster. |
| **Accès** | `make port-forward` | Rend le site accessible sur `http://localhost:8081` (avec la possibilité de l'exposer publiquement via Codespace). |
| | `make stop` | Arrête le processus de port-forwarding. |
| **Étapes (Debug)** | `make setup` | Installe uniquement les prérequis (`Packer`, `K3d`, `Ansible`). |
| | `make cluster` | Crée le cluster K3d (si inexistant). |
| | `make build` | Lance uniquement la construction de l'image Docker avec Packer. |
| | `make import` | Importe l'image locale dans le registre du cluster K3d. |
| | `make deploy` | Exécute uniquement le playbook Ansible pour le déploiement. |
| | `make check` | Vérifie l'état des pods et teste la réponse HTTP. |
| **Nettoyage** | `make clean` | Supprime le déploiement et le service (garde le cluster actif). |
| | `make fclean` | **Reset total.** Supprime le cluster K3d et tous les fichiers temporaires. |

## Structure du projet

```text
.
├── deploy.yml       # Playbook Ansible pour Kubernetes
├── index.html       # Code source du site web
├── Makefile         # Script d'automatisation et orchestration
├── nginx.pkr.hcl    # Template de construction Packer
└── README.md        # Documentation du projet

```

## Vérification

Le projet intègre une étape de validation automatique (`make check`).
Si vous souhaitez vérifier manuellement :

1. Les pods doivent être en statut `Running` : `kubectl get pods`
2. Le service doit être actif : `kubectl get svc`