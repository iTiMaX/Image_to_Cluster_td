# Variables de configuration
CLUSTER_NAME    = lab
IMAGE_NAME      = nginx-image-td:v1
DEPLOYMENT_NAME = nginx-td
SERVICE_NAME    = nginx-td-service

# Cibles phony (ne créent pas de fichiers)
.PHONY: help setup cluster build import deploy run update check port-forward clean fclean

help:
	@echo "------------------------------------------------------------------"
	@echo "                        AIDE DU MAKEFILE"
	@echo "------------------------------------------------------------------"
	@echo "COMMANDES PRINCIPALES :"
	@echo "  make run           : Installe, construit et déploie tout le projet (Recommandé)"
	@echo "  make update        : Met à jour l'application après modif du HTML (Zero downtime)"
	@echo "  make port-forward  : Ouvre l'accès au site sur le port 8081 (Background)"
	@echo "  make stop          : Arrête le processus de port-forward"
	@echo ""
	@echo "ÉTAPES INDIVIDUELLES (DÉBUG) :"
	@echo "  make setup         : Installe les dépendances (Packer, K3d, Ansible)"
	@echo "  make cluster       : Crée le cluster K3d"
	@echo "  make build         : Construit l'image Docker avec Packer"
	@echo "  make import        : Importe l'image dans le registre du cluster"
	@echo "  make deploy        : Lance le déploiement Ansible"
	@echo "  make check         : Vérifie l'état des pods et teste la réponse HTTP"
	@echo ""
	@echo "NETTOYAGE :"
	@echo "  make clean         : Supprime le déploiement et le service (Garde le cluster)"
	@echo "  make fclean        : Supprime tout (Cluster K3d complet)"
	@echo "------------------------------------------------------------------"
	
# --- Installation des outils ---
setup:
	@echo "[INFO] Vérification et installation des prérequis..."
	@# Installation Packer si non présent
	@command -v packer >/dev/null || (sudo apt-get update && sudo apt-get install -y packer)
	@# Installation K3d si non présent
	@command -v k3d >/dev/null || (curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash)
	@# Installation librairies Python
	@pip install ansible kubernetes --quiet
	@ansible-galaxy collection install kubernetes.core --force > /dev/null

cluster:
	@echo "[INFO] Vérification du cluster K3d..."
	@k3d cluster list | grep -q $(CLUSTER_NAME) || k3d cluster create $(CLUSTER_NAME) --servers 1 --agents 2

# --- Construction et Déploiement ---
build:
	@echo "[INFO] Construction de l'image Packer..."
	packer init nginx.pkr.hcl
	packer build nginx.pkr.hcl

import:
	@echo "[INFO] Import de l'image dans le cluster..."
	k3d image import $(IMAGE_NAME) -c $(CLUSTER_NAME)

deploy:
	@echo "[INFO] Lancement du playbook Ansible..."
	ansible-playbook deploy.yml

# --- Vérification ---
check:
	@echo "[INFO] Attente de la disponibilité des pods..."
	@kubectl wait --for=condition=ready pod -l app=$(DEPLOYMENT_NAME) --timeout=60s
	@echo "[INFO] Test de réponse du service..."
	@kubectl run curl-test --image=curlimages/curl -i --rm --restart=Never -- -s http://$(SERVICE_NAME) 2>/dev/null

# --- Commandes principales ---
run: setup cluster build import deploy check
	@echo "--------------------------------------------------"
	@echo "Déploiement terminé avec succès."
	@echo "Utilisez 'make port-forward' pour accéder au site."
	@echo "--------------------------------------------------"

update: build import
	@echo "[INFO] Mise à jour du déploiement..."
	kubectl rollout restart deployment/$(DEPLOYMENT_NAME)
	@echo "Pods redémarrés."

port-forward:
	@echo "[INFO] Port-forwarding actif sur le port 8081 (background)..."
	@echo "Pensez à rendre l'URL publique dans Codespaces"
	@kubectl port-forward svc/$(SERVICE_NAME) 8081:80 >/tmp/nginx.log 2>&1 &
	@echo "Logs disponibles dans /tmp/nginx.log"

stop:
	@echo "[INFO] Arrêt du port-forward..."
	@pkill -f "kubectl port-forward" || echo "Aucun processus trouvé."

clean:
	@echo "[INFO] Suppression du déploiement..."
	@kubectl delete deployment $(DEPLOYMENT_NAME) --ignore-not-found
	@kubectl delete service $(SERVICE_NAME) --ignore-not-found

fclean: clean
	@echo "[INFO] Suppression du cluster..."
	@k3d cluster delete $(CLUSTER_NAME)