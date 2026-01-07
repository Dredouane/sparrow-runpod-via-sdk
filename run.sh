#!/bin/bash
set -e

# --- 1. Démarrage d'Ollama ---
echo "Démarrage du service Ollama en arrière-plan..."

# CRITIQUE: Définir l'hôte pour que l'API Python puisse se connecter à Ollama
export OLLAMA_HOST=0.0.0.0

# Démarrer le service Ollama
ollama serve &

# Attendre que le service Ollama soit prêt
sleep 15 
# --- 2. Téléchargement du Modèle (Pour garantir la présence avant l'API) ---
echo "Téléchargement du modèle Mistral 7B..."
# Cette commande s'exécutera dans l'environnement le plus stable du run.sh
ollama pull mistral:7b-instruct-v0.2 || { 
  echo "Erreur critique : Le téléchargement du modèle Ollama a échoué. Arrêt du Pod."
  # Permet d'échouer le Pod si le modèle ne peut pas être téléchargé
  exit 1 
}

# --- 2. Lancement de l'API Sparrow ---
echo "Lancement de l'API Sparrow sur le port 8002 via Uvicorn..."

# 1. Se positionner dans le répertoire d'installation de l'API
# CORRECTION: Utiliser le chemin défini dans le Dockerfile
cd /app/sparrow_app

# 2. Lancer Uvicorn en utilisant le module 'api' (résolu localement)
# Le PYTHONPATH n'est plus nécessaire.
PYTHONUNBUFFERED=1 python3 -m uvicorn api:app --host 0.0.0.0 --port 8002 --workers 1

# Garder le conteneur actif
wait