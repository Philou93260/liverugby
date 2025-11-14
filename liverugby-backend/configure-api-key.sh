#!/bin/bash

# Script de configuration de la clé API-Sports pour Firebase Functions
# Ce script configure la clé API de manière sécurisée dans Firebase

echo "🔧 Configuration de la clé API-Sports pour Firebase Functions"
echo "============================================================"
echo ""

# Vérifier que Firebase CLI est installé
if ! command -v firebase &> /dev/null; then
    echo "❌ Firebase CLI n'est pas installé."
    echo "📦 Installation avec npm :"
    echo "   npm install -g firebase-tools"
    echo ""
    exit 1
fi

# Se connecter à Firebase si nécessaire
echo "🔐 Vérification de l'authentification Firebase..."
firebase projects:list &> /dev/null
if [ $? -ne 0 ]; then
    echo "⚠️  Vous devez vous connecter à Firebase"
    firebase login
fi

# Configurer la clé API
API_KEY="cc235d58ce04e8ed2b057dfe4b169783"

echo ""
echo "📝 Configuration de la clé API-Sports..."
firebase functions:config:set apisports.key="$API_KEY" --project liverugby-6f075

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Clé API configurée avec succès!"
    echo ""
    echo "📊 Vérification de la configuration..."
    firebase functions:config:get --project liverugby-6f075
    echo ""
    echo "🚀 Prochaines étapes :"
    echo "   1. Déployez vos fonctions : firebase deploy --only functions"
    echo "   2. Testez une fonction Rugby API depuis votre application"
    echo ""
else
    echo ""
    echo "❌ Erreur lors de la configuration"
    echo "💡 Essayez manuellement :"
    echo "   firebase functions:config:set apisports.key=\"cc235d58ce04e8ed2b057dfe4b169783\" --project liverugby-6f075"
    echo ""
    exit 1
fi
