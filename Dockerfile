# Fichier: Dockerfile (Optimisé - Multi-Stage Build)

# ====================================================================
# ÉTAPE 1: builder (Phase d'installation des dépendances lourdes)
# ====================================================================
# Utiliser une image de base complète pour l'installation
FROM nvcr.io/nvidia/pytorch:24.11-py3 AS builder

WORKDIR /app

# 1. Installer les dépendances système critiques (Poppler, etc.)
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    poppler-utils \
    libpoppler-cpp-dev \
    && rm -rf /var/lib/apt/lists/*

# 2. Copier et installer les dépendances Python
# L'ordonnancement est CRITIQUE pour le cache: les dépendances changent rarement.
COPY requirements_docker.txt .
RUN pip install --no-cache-dir -r requirements_docker.txt

# 3. Installer le binaire Ollama (pour le backend)
RUN curl -fsSL https://ollama.com/install.sh | sh


# ====================================================================
# ÉTAPE 2: final (Phase de réduction de taille - Image minimale de production)
# ====================================================================
# Utiliser une image de base plus légère si possible, mais ici nous gardons l'image NVIDIA
# pour garantir la compatibilité GPU/CUDA, même si elle reste volumineuse (30 GiB).
# Si vous aviez besoin d'une taille minimale, nous utiliserions 'ubuntu' ou 'python:3.12-slim'.
FROM nvcr.io/nvidia/pytorch:24.11-py3 AS final

WORKDIR /app

# 1. Copier le runtime Python (les packages installés) de l'étape builder
# Ceci est la CLÉ du Multi-Stage Build
COPY --from=builder /usr/local/lib/python3.12/dist-packages /usr/local/lib/python3.12/dist-packages
COPY --from=builder /usr/local/bin /usr/local/bin

# 2. Copier le binaire Ollama
COPY --from=builder /usr/local/bin/ollama /usr/local/bin/ollama

# 3. Copier le code de l'application (sparrow/sparrow-ml/llm)
# CORRECTION D'ORDONNANCEMENT: Placez la copie du code source après les installations (Maximisation du cache)
# Si vous modifiez uniquement le code, Docker réutilisera les 6 étapes précédentes.
COPY sparrow/sparrow-ml/llm /app/sparrow_app

# 4. Copier le script de lancement run.sh et le rendre exécutable
COPY run.sh .
RUN chmod +x run.sh

# Le port de l'API Sparrow
EXPOSE 8002

# Health Check pour l'API Sparrow sur 8002
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:8002/health || exit 1

# Lancement AUTOMATIQUE du serveur Sparrow/Ollama au démarrage du Pod
CMD ["./run.sh"]