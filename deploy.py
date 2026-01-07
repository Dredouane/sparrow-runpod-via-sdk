#!/usr/bin/env python3
import runpod
import os
import sys
import time

RUNPOD_API_KEY = os.getenv("RUNPOD_API_KEY")
IMAGE_NAME = "dekarredouane/sparrow-runpod:latest" # Nom de l'image pour Sparrow
POD_NAME = "sparrow-pod" # Nom du pod pour Sparrow

if not RUNPOD_API_KEY:
    print("❌ RUNPOD_API_KEY non définie")
    sys.exit(1)

runpod.api_key = RUNPOD_API_KEY

# Liste de GPUs par ordre de préférence (à ajuster selon vos préférences de coût/performance)
GPU_FALLBACK = [
    "NVIDIA RTX A5000",
    "NVIDIA RTX 3090",
    "NVIDIA GeForce RTX 4090"
]

# Supprimer l'ancien pod (logique de nettoyage)
print("🔍 Recherche des pods existants...")
pods = runpod.get_pods()
for pod in pods:
    if pod.get("name") == POD_NAME:
        print(f"🗑️  Suppression du pod {pod['id']}...")
        runpod.stop_pod(pod["id"]) # Arrêter d'abord
        time.sleep(5)
        runpod.terminate_pod(pod["id"]) # Puis terminer
        time.sleep(10)

# Essayer de créer le pod avec fallback GPU
pod_created = False
for gpu_type in GPU_FALLBACK:
    try:
        print(f"🚀 Tentative de création avec {gpu_type}...")
        pod = runpod.create_pod(
            name=POD_NAME,
            image_name=IMAGE_NAME,
            gpu_type_id=gpu_type,
            cloud_type="SECURE",
            container_disk_in_gb=30,
            volume_in_gb=50,
            volume_mount_path="/app/data",
            # Ports exposés pour Sparrow (doit correspondre à EXPOSE 8002 dans le Dockerfile)
            ports="8002/http",
            # Environnement pour votre modèle Sparrow/Ollama
            env={"MODEL_ID": "sparrow-model-name", "OLLAMA_MODEL": "llama3:8b"} 
        )
        print(f"✅ Pod créé avec {gpu_type}: {pod['id']}")
        pod_created = True
        break
    except ValueError as e:
        print(f"⚠️  {gpu_type} non disponible, essai du suivant...")
        continue
    except Exception as e:
        print(f"❌ Erreur avec {gpu_type}: {str(e)}")
        continue

if not pod_created:
    print("❌ Aucun GPU disponible parmi les options")
    sys.exit(1)
