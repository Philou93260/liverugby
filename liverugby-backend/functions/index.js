// Firebase Cloud Functions
const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

// Importer le module rugby-api
const rugbyAPI = require('./rugby-api');

// Importer le module push-notifications
const pushNotifications = require('./push-notifications');

// ============================================
// FONCTION 1 : Créer un profil utilisateur lors de l'inscription
// ============================================
exports.createUserProfile = functions.auth.user().onCreate(async (user) => {
  const userProfile = {
    uid: user.uid,
    email: user.email,
    displayName: user.displayName || '',
    photoURL: user.photoURL || '',
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    isPublic: false,
    settings: {
      notifications: true,
      theme: 'auto'
    }
  };
  
  try {
    await admin.firestore().collection('users').doc(user.uid).set(userProfile);
    console.log('Profil utilisateur créé:', user.uid);
  } catch (error) {
    console.error('Erreur création profil:', error);
  }
});

// ============================================
// FONCTION 2 : Nettoyer les données lors de la suppression d'un compte
// ============================================
exports.deleteUserData = functions.auth.user().onDelete(async (user) => {
  const uid = user.uid;
  
  try {
    // Supprimer le document utilisateur
    await admin.firestore().collection('users').doc(uid).delete();
    
    // Supprimer les fichiers storage de l'utilisateur
    const bucket = admin.storage().bucket();
    await bucket.deleteFiles({
      prefix: `users/${uid}/`
    });
    
    console.log('Données utilisateur supprimées:', uid);
  } catch (error) {
    console.error('Erreur suppression données:', error);
  }
});

// ============================================
// FONCTION 3 : Envoyer une notification de bienvenue
// ============================================
exports.sendWelcomeEmail = functions.firestore
  .document('users/{userId}')
  .onCreate(async (snap, context) => {
    const userData = snap.data();
    
    // Logique d'envoi d'email (intégrer avec un service comme SendGrid)
    console.log('Email de bienvenue pour:', userData.email);
    
    return null;
  });

// ============================================
// FONCTION 4 : API endpoint exemple
// ============================================
// Configuration CORS sécurisée
const ALLOWED_ORIGINS = [
  'http://localhost:3000',
  'http://localhost:5000',
  'https://liverugby-6f075.web.app',
  'https://liverugby-6f075.firebaseapp.com'
  // Ajoutez vos domaines de production ici
];

exports.api = functions.https.onRequest((req, res) => {
  const origin = req.headers.origin;

  // Vérifier si l'origine est autorisée
  if (origin && ALLOWED_ORIGINS.includes(origin)) {
    res.set('Access-Control-Allow-Origin', origin);
  }

  if (req.method === 'OPTIONS') {
    res.set('Access-Control-Allow-Methods', 'GET, POST');
    res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
    res.set('Access-Control-Max-Age', '3600');
    res.status(204).send('');
    return;
  }

  res.json({
    message: 'API Firebase fonctionnelle',
    timestamp: Date.now(),
    version: '1.0.0'
  });
});

// ============================================
// FONCTION 5 : Nettoyer les anciennes données (exécution quotidienne)
// ============================================
exports.cleanOldData = functions.pubsub
  .schedule('every 24 hours')
  .onRun(async (context) => {
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
    
    const snapshot = await admin.firestore()
      .collection('temporaryData')
      .where('createdAt', '<', thirtyDaysAgo)
      .get();
    
    const batch = admin.firestore().batch();
    snapshot.docs.forEach(doc => {
      batch.delete(doc.ref);
    });
    
    await batch.commit();
    console.log(`${snapshot.size} documents supprimés`);
    
    return null;
  });

// ============================================
// EXPORTER LES FONCTIONS RUGBY
// ============================================
exports.getTodayMatches = rugbyAPI.getTodayMatches;
exports.getLeagueMatches = rugbyAPI.getLeagueMatches;
exports.getTeamMatches = rugbyAPI.getTeamMatches;
exports.getLeagueTeams = rugbyAPI.getLeagueTeams;
exports.getLeagueStandings = rugbyAPI.getLeagueStandings;
exports.searchTeams = rugbyAPI.searchTeams;
exports.getMatchDetails = rugbyAPI.getMatchDetails;
exports.updateMatchesDaily = rugbyAPI.updateMatchesDaily;
exports.rugbyWebhook = rugbyAPI.rugbyWebhook;

// ============================================
// EXPORTER LES FONCTIONS PUSH NOTIFICATIONS
// ============================================
exports.registerFCMToken = pushNotifications.registerFCMToken;
exports.unregisterFCMToken = pushNotifications.unregisterFCMToken;
exports.subscribeToMatch = pushNotifications.subscribeToMatch;
exports.unsubscribeFromMatch = pushNotifications.unsubscribeFromMatch;
exports.addFavoriteTeam = pushNotifications.addFavoriteTeam;
exports.monitorLiveMatches = pushNotifications.monitorLiveMatches;
exports.notifyFavoriteTeamsMatches = pushNotifications.notifyFavoriteTeamsMatches;

// ============================================
// EXPORTER LES FONCTIONS LIVE ACTIVITIES (iOS)
// ============================================
exports.registerActivityPushToken = pushNotifications.registerActivityPushToken;
exports.unregisterActivityPushToken = pushNotifications.unregisterActivityPushToken;
