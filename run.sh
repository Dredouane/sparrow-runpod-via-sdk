#!/bin/bash
set -e  # Arrêter en cas d'erreur

echo "========================================="
echo "🔍 Vérifications préliminaires"
echo "========================================="

# Vérifier que ollama est installé
if ! command -v ollama &> /dev/null; then
    echo "❌ ERREUR: ollama n'est pas installé ou pas dans le PATH"
    echo "Recherche d'ollama..."
    find / -name ollama -type f 2>/dev/null || echo "Ollama introuvable sur le système"
    exit 1
fi

echo "✅ Ollama trouvé: $(which ollama)"
echo "Version: $(ollama --version 2>&1 || echo 'Version non disponible')"

# Vérifier les GPUs disponibles
echo ""
echo "🎮 Vérification des GPUs:"
nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader 2>/dev/null || echo "⚠️  nvidia-smi non disponible"

# Vérifier les variables d'environnement CUDA
echo ""
echo "🔧 Variables d'environnement CUDA:"
env | grep -i cuda || echo "Aucune variable CUDA définie"

echo ""
echo "========================================="
echo "🚀 Démarrage du service Ollama"
echo "========================================="

# Créer le répertoire des modèles si nécessaire
mkdir -p /root/.ollama/models

# Démarrer Ollama avec logging verbeux
OLLAMA_DEBUG=1 \
OLLAMA_HOST=0.0.0.0:11434 \
ollama serve 2>&1 | tee /tmp/ollama.log &

OLLAMA_PID=$!
echo "PID Ollama: $OLLAMA_PID"

# Petit délai pour laisser le processus démarrer
sleep 3

# Vérifier immédiatement si le processus est toujours vivant
if ! kill -0 $OLLAMA_PID 2>/dev/null; then
    echo ""
    echo "❌ ERREUR CRITIQUE: Le processus Ollama s'est arrêté immédiatement!"
    echo ""
    echo "📋 Logs Ollama complets:"
    echo "----------------------------------------"
    cat /tmp/ollama.log
    echo "----------------------------------------"
    echo ""
    echo "🔍 Dernières lignes de dmesg (erreurs kernel):"
    dmesg | tail -20
    exit 1
fi

# Attendre qu'Ollama soit prêt (maximum 60 secondes)
echo ""
echo "⏳ Attente du démarrage d'Ollama..."
MAX_WAIT=60
WAITED=0
while [ $WAITED -lt $MAX_WAIT ]; do
    if curl -s http://localhost:11434/api/tags >/dev/null 2>&1; then
        echo "✅ Ollama est prêt et répond aux requêtes!"
        break
    fi
    
    # Vérifier si le processus Ollama est toujours vivant
    if ! kill -0 $OLLAMA_PID 2>/dev/null; then
        echo ""
        echo "❌ ERREUR: Le processus Ollama s'est arrêté prématurément!"
        echo ""
        echo "📋 Logs Ollama:"
        echo "----------------------------------------"
        cat /tmp/ollama.log
        echo "----------------------------------------"
        exit 1
    fi
    
    echo "⏳ Attente d'Ollama... ($WAITED/$MAX_WAIT secondes)"
    sleep 2
    WAITED=$((WAITED + 2))
done

if [ $WAITED -ge $MAX_WAIT ]; then
    echo ""
    echo "❌ ERREUR: Ollama n'a pas démarré dans les temps!"
    echo ""
    echo "📋 Logs Ollama:"
    echo "----------------------------------------"
    cat /tmp/ollama.log
    echo "----------------------------------------"
    exit 1
fi

# Test de l'API Ollama
echo ""
echo "🧪 Test de l'API Ollama:"
curl -s http://localhost:11434/api/tags | head -20

echo ""
echo "========================================="
echo "🚀 Démarrage de l'application Sparrow"
echo "========================================="

cd /app/sparrow_app

# Vérifier que le fichier api.py existe
if [ ! -f "api.py" ]; then
    echo "❌ ERREUR: api.py introuvable dans /app/sparrow_app"
    echo "Contenu du répertoire:"
    ls -la
    exit 1
fi

echo "✅ Fichier api.py trouvé"
echo ""
echo "📝 Démarrage de l'API Sparrow sur le port 8002..."

# Démarrer l'application Sparrow
exec uvicorn api:app --host 0.0.0.0 --port 8002 --log-level info