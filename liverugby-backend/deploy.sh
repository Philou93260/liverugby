#!/bin/bash

# ============================================
# Script de déploiement LiveRugby Backend
# ============================================

set -e  # Exit on error

PROJECT_ID="liverugby-6f075"
API_KEY="cc235d58ce04e8ed2b057dfe4b169783"

echo "╔═══════════════════════════════════════════════╗"
echo "║   🚀 Déploiement LiveRugby Backend Firebase  ║"
echo "║   Project ID: liverugby-6f075                 ║"
echo "╚═══════════════════════════════════════════════╝"
echo ""

# ============================================
# ÉTAPE 1 : Vérifications préliminaires
# ============================================
echo "📋 ÉTAPE 1/5 : Vérifications préliminaires"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Vérifier Firebase CLI
if ! command -v firebase &> /dev/null; then
    echo "❌ Firebase CLI n'est pas installé"
    echo ""
    echo "📦 Installation requise :"
    echo "   npm install -g firebase-tools"
    echo ""
    exit 1
fi

echo "✅ Firebase CLI installé : $(firebase --version)"

# Vérifier Node.js
if ! command -v node &> /dev/null; then
    echo "❌ Node.js n'est pas installé"
    exit 1
fi

echo "✅ Node.js installé : $(node --version)"

# Vérifier npm
if ! command -v npm &> /dev/null; then
    echo "❌ npm n'est pas installé"
    exit 1
fi

echo "✅ npm installé : $(npm --version)"

# Vérifier que les dépendances sont installées
if [ ! -d "functions/node_modules" ]; then
    echo "⚠️  node_modules non trouvé, installation des dépendances..."
    cd functions
    npm install
    cd ..
    echo "✅ Dépendances installées"
else
    echo "✅ Dépendances déjà installées"
fi

echo ""

# ============================================
# ÉTAPE 2 : Authentification Firebase
# ============================================
echo "🔐 ÉTAPE 2/5 : Authentification Firebase"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Vérifier si déjà connecté
firebase projects:list &> /dev/null
if [ $? -ne 0 ]; then
    echo "⚠️  Vous devez vous connecter à Firebase"
    echo "🌐 Ouverture de la page de connexion..."
    firebase login

    if [ $? -ne 0 ]; then
        echo "❌ Échec de l'authentification"
        exit 1
    fi
fi

echo "✅ Authentifié sur Firebase"

# Vérifier l'accès au projet
firebase projects:list | grep -q "$PROJECT_ID"
if [ $? -ne 0 ]; then
    echo "❌ Vous n'avez pas accès au projet $PROJECT_ID"
    echo "💡 Vérifiez que vous êtes connecté avec le bon compte Google"
    exit 1
fi

echo "✅ Accès au projet $PROJECT_ID confirmé"
echo ""

# ============================================
# ÉTAPE 3 : Configuration de la clé API
# ============================================
echo "🔑 ÉTAPE 3/5 : Configuration de la clé API-Sports"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Vérifier si la clé est déjà configurée
CURRENT_KEY=$(firebase functions:config:get apisports.key --project $PROJECT_ID 2>/dev/null)

if [ -z "$CURRENT_KEY" ] || [ "$CURRENT_KEY" == "null" ]; then
    echo "⚙️  Configuration de la clé API-Sports..."
    firebase functions:config:set apisports.key="$API_KEY" --project $PROJECT_ID

    if [ $? -eq 0 ]; then
        echo "✅ Clé API configurée avec succès"
    else
        echo "❌ Échec de la configuration de la clé API"
        exit 1
    fi
else
    echo "✅ Clé API déjà configurée"
fi

echo ""

# ============================================
# ÉTAPE 4 : Déploiement
# ============================================
echo "🚀 ÉTAPE 4/5 : Déploiement sur Firebase"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo ""
echo "📦 Éléments à déployer :"
echo "   • Cloud Functions (16 fonctions)"
echo "   • Règles Firestore"
echo "   • Règles Storage"
echo ""

read -p "Voulez-vous continuer ? (o/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Oo]$ ]]; then
    echo "❌ Déploiement annulé"
    exit 1
fi

echo ""
echo "📤 Déploiement en cours..."
echo "⏳ Cela peut prendre plusieurs minutes..."
echo ""

# Déployer tout
firebase deploy --project $PROJECT_ID

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Déploiement réussi !"
else
    echo ""
    echo "❌ Échec du déploiement"
    echo "💡 Consultez les logs ci-dessus pour plus d'informations"
    exit 1
fi

echo ""

# ============================================
# ÉTAPE 5 : Vérification
# ============================================
echo "🔍 ÉTAPE 5/5 : Vérification du déploiement"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo ""
echo "📊 Liste des fonctions déployées :"
firebase functions:list --project $PROJECT_ID

echo ""
echo "⚙️  Configuration Firebase Functions :"
firebase functions:config:get --project $PROJECT_ID

echo ""
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║                  ✅ DÉPLOIEMENT TERMINÉ !                 ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""
echo "🎉 Votre backend LiveRugby est maintenant en ligne !"
echo ""
echo "📋 Prochaines étapes :"
echo ""
echo "1️⃣  Configurer APNs pour iOS :"
echo "   → Firebase Console > Cloud Messaging > iOS app configuration"
echo "   → Uploader votre clé .p8 depuis Apple Developer"
echo ""
echo "2️⃣  Intégrer dans votre app iOS :"
echo "   → Suivre le guide : IOS_PUSH_NOTIFICATIONS.md"
echo ""
echo "3️⃣  Tester les fonctions :"
echo "   → Console Firebase : https://console.firebase.google.com/project/$PROJECT_ID/functions"
echo ""
echo "4️⃣  Voir les logs :"
echo "   → firebase functions:log --project $PROJECT_ID"
echo ""
echo "📱 URL de votre projet :"
echo "   https://console.firebase.google.com/project/$PROJECT_ID"
echo ""
echo "🔥 Fonctions disponibles :"
echo "   • getTodayMatches - Matchs du jour"
echo "   • subscribeToMatch - Abonnement notifications"
echo "   • addFavoriteTeam - Équipes favorites"
echo "   • monitorLiveMatches - Monitoring temps réel (auto)"
echo "   • + 12 autres fonctions"
echo ""
echo "💡 Besoin d'aide ? Consultez README.md"
echo ""
