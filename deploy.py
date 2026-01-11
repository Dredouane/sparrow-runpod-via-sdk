#!/usr/bin/env python3
import runpod
import os
import sys
import time

RUNPOD_API_KEY = os.getenv("RUNPOD_API_KEY")
IMAGE_NAME = "dekarredouane/sparrow-runpod:latest"
POD_NAME = "sparrow-pod"

if not RUNPOD_API_KEY:
    print("❌ RUNPOD_API_KEY non définie")
    sys.exit(1)

runpod.api_key = RUNPOD_API_KEY

# Liste de GPUs par ordre de préférence
GPU_FALLBACK = [
    "NVIDIA RTX A5000",
    "NVIDIA RTX 3090",
    "NVIDIA GeForce RTX 4090",
    "NVIDIA RTX A4000",  # Ajout d'options supplémentaires
    "NVIDIA RTX 4080"
]

# Supprimer l'ancien pod (logique de nettoyage)
print("🔍 Recherche des pods existants...")
try:
    pods = runpod.get_pods()
    for pod in pods:
        if pod.get("name") == POD_NAME:
            print(f"🗑️  Suppression du pod {pod['id']}...")
            try:
                runpod.stop_pod(pod["id"])
                time.sleep(5)
                runpod.terminate_pod(pod["id"])
                print(f"✅ Pod {pod['id']} supprimé")
                time.sleep(10)
            except Exception as e:
                print(f"⚠️  Erreur lors de la suppression: {e}")
except Exception as e:
    print(f"⚠️  Erreur lors de la récupération des pods: {e}")

# Configuration des variables d'environnement pour le conteneur
# CRITIQUE: Ces variables sont essentielles pour Ollama et CUDA
container_env = {
    # Variables Ollama
    "OLLAMA_HOST": "0.0.0.0:11434",
    "OLLAMA_MODELS": "/root/.ollama/models",
    "OLLAMA_DEBUG": "1",  # Active le mode debug pour plus de logs
    
    # Variables NVIDIA/CUDA (CRITIQUE pour le GPU)
    "NVIDIA_VISIBLE_DEVICES": "all",
    "NVIDIA_DRIVER_CAPABILITIES": "compute,utility",
    "CUDA_VISIBLE_DEVICES": "0",
    
    # Variables de votre application
    "MODEL_ID": "sparrow-model-name",
    "OLLAMA_MODEL": "qwen2.5vl:7b"
}

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
            
            # Stockage
            container_disk_in_gb=30,
            volume_in_gb=50,
            volume_mount_path="/app/data",
            
            # Ports exposés (Sparrow + Ollama)
            ports="8002/http,11434/http",  # Ajout du port Ollama pour debug
            
            # Variables d'environnement
            env=container_env
        )
        
        print(f"✅ Pod créé avec succès!")
        print(f"   GPU: {gpu_type}")
        print(f"   Pod ID: {pod['id']}")
        print(f"   Nom: {POD_NAME}")
        print(f"\n📊 Informations du pod:")
        print(f"   - API Sparrow: https://{pod['id']}-8002.proxy.runpod.net")
        print(f"   - API Ollama (debug): https://{pod['id']}-11434.proxy.runpod.net")
        print(f"\n⏳ Attente du démarrage du pod (60 secondes)...")
        
        time.sleep(60)
        
        # Récupérer les logs du pod pour vérifier le démarrage
        print(f"\n📋 Récupération des logs initiaux...")
        try:
            logs = runpod.get_pod_logs(pod['id'])
            if logs:
                print("Logs du conteneur:")
                print("-" * 50)
                print(logs[-2000:] if len(logs) > 2000 else logs)  # Derniers 2000 caractères
                print("-" * 50)
        except Exception as e:
            print(f"⚠️  Impossible de récupérer les logs: {e}")
        
        print(f"\n✅ Déploiement terminé!")
        print(f"🔗 URL de l'API: https://{pod['id']}-8002.proxy.runpod.net")
        
        pod_created = True
        break
        
    except ValueError as e:
        print(f"⚠️  {gpu_type} non disponible: {e}")
        continue
    except Exception as e:
        print(f"❌ Erreur avec {gpu_type}: {str(e)}")
        import traceback
        traceback.print_exc()
        continue

if not pod_created:
    print("\n❌ Aucun GPU disponible parmi les options")
    print("💡 Solutions:")
    print("   1. Vérifiez votre crédit RunPod")
    print("   2. Essayez une autre région")
    print("   3. Attendez quelques minutes et réessayez")
    sys.exit(1)

print("\n🎉 Déploiement réussi!")