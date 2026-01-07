# Fichier: Dockerfile (Optimisé - Multi-Stage Build)

# ====================================================================
# ÉTAPE 1: builder (Phase d'installation des dépendances lourdes)
# ====================================================================
FROM nvcr.io/nvidia/pytorch:24.11-py3 AS builder

WORKDIR /app

# 1. Installer les dépendances système critiques (Poppler, etc.)
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    poppler-utils \
    libpoppler-cpp-dev \
    && rm -rf /var/lib/apt/lists/*

# 2. Copier et installer les dépendances Python
COPY requirements_docker.txt .
RUN pip install --no-cache-dir -r requirements_docker.txt

# 3. [SUPPRIMÉ] Installation d'Ollama déplacée dans l'image finale

# ====================================================================
# ÉTAPE 2: final (Phase de production - Installation directe d'Ollama)
# ====================================================================
FROM nvcr.io/nvidia/pytorch:24.11-py3 AS final

WORKDIR /app

# 1. Installer les dépendances système + Ollama directement
# CRITIQUE: Installation directe évite les problèmes de copie de binaires
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    poppler-utils \
    libpoppler-cpp-dev \
    && curl -fsSL https://ollama.com/install.sh | sh \
    && rm -rf /var/lib/apt/lists/*

# 2. Copier le runtime Python (les packages installés) de l'étape builder
COPY --from=builder /usr/local/lib/python3.12/dist-packages /usr/local/lib/python3.12/dist-packages
COPY --from=builder /usr/local/bin /usr/local/bin

# 3. Créer le répertoire pour les modèles Ollama
RUN mkdir -p /root/.ollama/models

# 5. Copier le code de l'application (sparrow/sparrow-ml/llm)
COPY sparrow/sparrow-ml/llm /app/sparrow_app

# 6. Copier le script de lancement run.sh et le rendre exécutable
COPY run.sh .
RUN chmod +x run.sh

# Le port de l'API Sparrow
EXPOSE 8002
# Port Ollama (si besoin d'y accéder directement)
EXPOSE 11434

# Health Check pour l'API Sparrow sur 8002
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:8002/health || exit 1

# Lancement AUTOMATIQUE du serveur Sparrow/Ollama au démarrage du Pod
CMD ["./run.sh"]