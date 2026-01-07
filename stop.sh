#!/bin/bash
set -e

if [ -z "$RUNPOD_API_KEY" ]; then
    echo "❌ Erreur: RUNPOD_API_KEY non définie"
    exit 1
fi

# Activer l'environnement virtuel
if [ ! -d "venv" ]; then
    echo "❌ Environnement virtuel non trouvé. Lancez d'abord ./deploy.sh"
    exit 1
fi

source venv/bin/activate

# Installer les dépendances du SDK si elles manquent (vérification rapide)
if ! python3 -c "import runpod" 2>/dev/null; then
    echo "📥 Installation des dépendances du SDK..."
    pip install -q -r requirements_sdk.txt
fi

python3 stop.py

deactivate