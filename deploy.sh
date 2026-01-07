#!/bin/bash
set -e

# Vérifier que la clé API est définie
if [ -z "$RUNPOD_API_KEY" ]; then
    echo "❌ Erreur: RUNPOD_API_KEY non définie"
    exit 1
fi

# Activer l'environnement virtuel s'il existe, sinon le créer
if [ ! -d "venv" ]; then
    echo "📦 Création de l'environnement virtuel..."
    python3 -m venv venv
fi

source venv/bin/activate

# Installer les dépendances du SDK
if ! python3 -c "import runpod" 2>/dev/null; then
    echo "📥 Installation des dépendances (runpod, docker)..."
    pip install -q -r requirements_sdk.txt
fi

IMAGE_NAME="dekarredouane/sparrow-runpod:latest"

echo "🔨 Build de l'image Docker avec BuildKit et cache distant..."
# Utilisation de la variable pour le build
docker build --cache-from $IMAGE_NAME -t $IMAGE_NAME .

echo "📤 Push de l'image Docker..."
docker push $IMAGE_NAME

# === 2. Nettoyage immédiat du cache de build ===
echo "🧹 Nettoyage immédiat des couches intermédiaires non utilisées..."
# Supprime les caches de build et les couches orphelines
docker builder prune -f

# Déploiement via Python
echo "🚀 Déploiement du pod..."
python3 deploy.py

deactivate
