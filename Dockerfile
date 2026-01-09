# Fichier: Dockerfile (Alternative avec image PyTorch officielle)

# ====================================================================
# ÉTAPE 1: builder (Phase d'installation des dépendances lourdes)
# ====================================================================
# Utiliser l'image PyTorch officielle (pas besoin d'auth NVIDIA)
FROM pytorch/pytorch:2.5.1-cuda12.4-cudnn9-runtime AS builder

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

# ====================================================================
# ÉTAPE 2: final (Phase de production - Installation directe d'Ollama)
# ====================================================================
FROM pytorch/pytorch:2.5.1-cuda12.4-cudnn9-runtime AS final

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
# L'image PyTorch utilise conda, donc les packages sont dans /opt/conda
COPY --from=builder /opt/conda /opt/conda

# 3. Créer le répertoire pour les modèles Ollama
RUN mkdir -p /root/.ollama/models

# 4. Copier le code de l'application (sparrow/sparrow-ml/llm)
COPY sparrow/sparrow-ml/llm /app/sparrow_app

# 5. Copier le script de lancement run.sh et le rendre exécutable
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