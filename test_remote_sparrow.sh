#!/bin/bash
# Scripts de test pour l'API Sparrow sur RunPod

# ============================================
# CONFIGURATION
# ============================================
# Remplacez par l'ID de votre pod RunPod
POD_ID="votre-pod-id-ici"
API_URL="https://${POD_ID}-8002.proxy.runpod.net"

# Chemin vers votre fichier PDF local à tester
PDF_FILE="./document.pdf"

echo "🔗 URL de l'API: $API_URL"
echo ""

# ============================================
# TEST 1: Health Check
# ============================================
echo "📊 Test 1: Health Check"
echo "----------------------------------------"
curl -s "$API_URL/health" | jq '.'
echo ""
echo ""

# ============================================
# TEST 2: Vérifier les modèles Ollama disponibles
# ============================================
echo "🤖 Test 2: Modèles Ollama disponibles"
echo "----------------------------------------"
OLLAMA_URL="https://${POD_ID}-11434.proxy.runpod.net"
curl -s "$OLLAMA_URL/api/tags" | jq '.'
echo ""
echo ""

# ============================================
# TEST 3: Extraction de document avec Sparrow Parse
# ============================================
echo "📄 Test 3: Extraction de document PDF"
echo "----------------------------------------"

if [ ! -f "$PDF_FILE" ]; then
    echo "⚠️  Fichier $PDF_FILE introuvable!"
    echo "💡 Créez un fichier PDF ou changez la variable PDF_FILE"
else
    # Query pour extraire des champs spécifiques
    # Adaptez selon vos besoins: nom du champ et type de données
    QUERY='[{"field_name":"invoice_number","type":"string"},{"field_name":"total_amount","type":"number"}]'
    
    # Pipeline: sparrow-parse (utilise Sparrow Parse pour l'extraction)
    PIPELINE="sparrow-parse"
    
    # Options: Ollama avec le modèle qwen2.5vl:7b
    # Format: backend,nom_du_modele
    OPTIONS="ollama,qwen2.5vl:7b"
    
    echo "📤 Envoi du PDF: $PDF_FILE"
    echo "🔍 Query: $QUERY"
    echo "⚙️  Options: $OPTIONS"
    echo ""
    
    curl -X POST "${API_URL}/api/v1/sparrow-llm/inference" \
      -H 'Content-Type: multipart/form-data' \
      -F "query=$QUERY" \
      -F "pipeline=$PIPELINE" \
      -F "options=$OPTIONS" \
      -F "file=@$PDF_FILE" \
      -o response.json
    
    echo ""
    echo "✅ Réponse reçue et sauvegardée dans response.json"
    echo ""
    echo "📋 Résultat:"
    cat response.json | jq '.'
fi

echo ""
echo ""

# ============================================
# TEST 4: Instruction textuelle (sans PDF)
# ============================================
echo "💬 Test 4: Instruction textuelle"
echo "----------------------------------------"

INSTRUCTION="instruction: analyze the following data and extract key information"
PAYLOAD='{"company": "Acme Corp", "revenue": 1000000, "employees": 50}'
QUERY_TEXT="$INSTRUCTION, payload: $PAYLOAD"

curl -X POST "${API_URL}/api/v1/sparrow-llm/instruction-inference" \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  -d "query=$QUERY_TEXT" \
  -d "pipeline=sparrow-parse" \
  -d "options=ollama,qwen2.5vl:7b" \
  | jq '.'

echo ""
echo ""
echo "✅ Tests terminés!"