#!/bin/bash
set -e

# Supprimer le cluster K3d existant si nécessaire
k3d cluster delete mycluster || echo "Le cluster n'existe pas ou n'a pas été trouvé."

# Vérifier si Docker est déjà installé
if ! command -v docker &> /dev/null
then
    echo "Docker n'est pas installé, installation en cours..."
    
    # Installation de Docker
    curl -fsSL https://get.docker.com | sh
    sudo usermod -aG docker $USER
    newgrp docker
else
    echo "Docker est déjà installé. Passons à l'étape suivante."
fi

# Vérifier si Kubernetes (kubectl) est installé
if ! command -v kubectl &> /dev/null
then
    echo "kubectl n'est pas installé, installation en cours..."
    
    # Installation de kubectl
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    chmod +x kubectl
    sudo mv kubectl /usr/local/bin/
else
    echo "kubectl est déjà installé. Passons à l'étape suivante."
fi

# Vérifier si k3d est installé
if ! command -v k3d &> /dev/null
then
    echo "k3d n'est pas installé, installation en cours..."
    
    # Installation de k3d
    curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
else
    echo "k3d est déjà installé. Passons à l'étape suivante."
fi

# Vérifier si ArgoCD est installé
if ! command -v argocd &> /dev/null
then
    echo "ArgoCD CLI n'est pas installé, installation en cours..."
    
    # Installation de ArgoCD CLI
    curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
    chmod +x argocd
    sudo mv argocd /usr/local/bin/
else
    echo "ArgoCD CLI est déjà installé. Passons à l'étape suivante."
fi

# Création du cluster K3d
k3d cluster create mycluster --servers 1 --agents 1

# Création des namespaces
kubectl create namespace argocd
kubectl create namespace dev

# Installation d'Argocd dans le namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Attente pour que les pods ArgoCD soient en cours d'exécution
echo "Attente que les pods ArgoCD soient prêts..."
kubectl wait --for=condition=ready pod --all -n argocd --timeout=180s

# Forward port 8080 to access ArgoCD UI or CLI locally
kubectl port-forward svc/argocd-server -n argocd 8080:80 &

# Générer le mot de passe initial
PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

# Connexion à ArgoCD
argocd login localhost:8080 --insecure --username admin --password "$PASSWORD"

if [ $? -eq 0 ]; then
    echo "Connexion réussie à ArgoCD."
else
    echo "Échec de la connexion à ArgoCD."
    exit 1
fi

# Création de l'application sur ArgoCD
argocd app create mon-app \
    --repo https://github.com/Thebelovedcookie/mmahfoud.git \
    --path k8s \
    --dest-server https://kubernetes.default.svc \
    --dest-namespace dev \

# # Synchronisation de l'application depuis GitHub
# argocd app sync mon-app
