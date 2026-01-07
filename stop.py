#!/usr/bin/env python3
import runpod
import os
import sys

RUNPOD_API_KEY = os.getenv("RUNPOD_API_KEY")
POD_NAME = "sparrow-pod" # Nom du pod pour Sparrow

if not RUNPOD_API_KEY:
    print("❌ RUNPOD_API_KEY non définie")
    sys.exit(1)

runpod.api_key = RUNPOD_API_KEY

pods = runpod.get_pods()
for pod in pods:
    if pod.get("name") == POD_NAME:
        print(f"⏸️  Arrêt du pod {pod['id']}...")
        runpod.stop_pod(pod["id"])
        print("✅ Pod arrêté")
        sys.exit(0)

print("❌ Pod non trouvé")
sys.exit(1)