import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserDataService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Initialise les données utilisateur lors de la première connexion
  static Future<void> initializeUserData() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final userDoc = _firestore.collection('users').doc(user.uid);
    final docSnapshot = await userDoc.get();

    if (!docSnapshot.exists) {
      // Créer le profil utilisateur
      await userDoc.set({
        'email': user.email,
        'createdAt': FieldValue.serverTimestamp(),
        'totalPoints': 0,
        'videosWatched': 0,
        'videosWatchedToday': 0,
        'surveysCompleted': 0,
        'surveysCompletedToday': 0,
        'lastResetDate': DateTime.now().toString().substring(0, 10),
        'lastActivity': FieldValue.serverTimestamp(),
      });
    } else {
      // Mettre à jour la dernière activité
      await userDoc.update({
        'lastActivity': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Récupère les données utilisateur
  static Future<Map<String, dynamic>?> getUserData() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final doc = await _firestore.collection('users').doc(user.uid).get();
    return doc.data();
  }

  /// Met à jour les points de l'utilisateur
  static Future<void> updatePoints(int points) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore.collection('users').doc(user.uid).update({
      'totalPoints': FieldValue.increment(points),
      'lastActivity': FieldValue.serverTimestamp(),
    });
  }

  /// Enregistre une vidéo regardée
  static Future<void> recordVideoWatched(int pointsEarned) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final today = DateTime.now().toString().substring(0, 10);
    final userDoc = _firestore.collection('users').doc(user.uid);

    // Récupérer les données actuelles pour vérifier la date
    final doc = await userDoc.get();
    final data = doc.data();
    final lastResetDate = data?['lastResetDate'] ?? '';

    if (lastResetDate != today) {
      // Nouveau jour - réinitialiser les compteurs quotidiens
      await userDoc.update({
        'videosWatchedToday': 1,
        'surveysCompletedToday': 0,
        'lastResetDate': today,
        'videosWatched': FieldValue.increment(1),
        'totalPoints': FieldValue.increment(pointsEarned),
        'lastActivity': FieldValue.serverTimestamp(),
      });
    } else {
      // Même jour - incrémenter
      await userDoc.update({
        'videosWatchedToday': FieldValue.increment(1),
        'videosWatched': FieldValue.increment(1),
        'totalPoints': FieldValue.increment(pointsEarned),
        'lastActivity': FieldValue.serverTimestamp(),
      });
    }

    // Enregistrer dans l'historique des activités
    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('activities')
        .add({
      'type': 'video_watched',
      'points': pointsEarned,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Enregistre un sondage complété
  static Future<void> recordSurveyCompleted(int pointsEarned) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final today = DateTime.now().toString().substring(0, 10);
    final userDoc = _firestore.collection('users').doc(user.uid);

    final doc = await userDoc.get();
    final data = doc.data();
    final lastResetDate = data?['lastResetDate'] ?? '';

    if (lastResetDate != today) {
      await userDoc.update({
        'surveysCompletedToday': 1,
        'videosWatchedToday': 0,
        'lastResetDate': today,
        'surveysCompleted': FieldValue.increment(1),
        'totalPoints': FieldValue.increment(pointsEarned),
        'lastActivity': FieldValue.serverTimestamp(),
      });
    } else {
      await userDoc.update({
        'surveysCompletedToday': FieldValue.increment(1),
        'surveysCompleted': FieldValue.increment(1),
        'totalPoints': FieldValue.increment(pointsEarned),
        'lastActivity': FieldValue.serverTimestamp(),
      });
    }

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('activities')
        .add({
      'type': 'survey_completed',
      'points': pointsEarned,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Enregistre une échange de récompense
  static Future<void> recordRedemption({
    required String type,
    required double amount,
    required int pointsDeducted,
    required String recipientEmail,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    // Déduire les points
    await _firestore.collection('users').doc(user.uid).update({
      'totalPoints': FieldValue.increment(-pointsDeducted),
      'lastActivity': FieldValue.serverTimestamp(),
    });

    // Enregistrer l'échange dans l'historique
    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('redemptions')
        .add({
      'type': type,
      'amount': amount,
      'pointsDeducted': pointsDeducted,
      'recipientEmail': recipientEmail,
      'status': 'pending',
      'requestedAt': FieldValue.serverTimestamp(),
    });

    // Enregistrer dans les activités globales
    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('activities')
        .add({
      'type': 'reward_redeemed',
      'rewardType': type,
      'amount': amount,
      'points': -pointsDeducted,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Synchronise les données locales avec Firestore
  static Future<void> syncLocalData({
    required int localPoints,
    required int localVideos,
    required int localSurveys,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final userDoc = _firestore.collection('users').doc(user.uid);
    final doc = await userDoc.get();

    if (!doc.exists) {
      // Créer avec les données locales
      await userDoc.set({
        'email': user.email,
        'createdAt': FieldValue.serverTimestamp(),
        'totalPoints': localPoints,
        'videosWatched': localVideos,
        'surveysCompleted': localSurveys,
        'videosWatchedToday': 0,
        'surveysCompletedToday': 0,
        'lastResetDate': DateTime.now().toString().substring(0, 10),
        'lastActivity': FieldValue.serverTimestamp(),
      });
    } else {
      // Mettre à jour si les données locales sont plus élevées
      final data = doc.data();
      final cloudPoints = data?['totalPoints'] ?? 0;

      if (localPoints > cloudPoints) {
        await userDoc.update({
          'totalPoints': localPoints,
          'lastActivity': FieldValue.serverTimestamp(),
        });
      }
    }
  }

  /// Récupère l'historique des échanges de récompenses
  static Future<List<Map<String, dynamic>>> getRedemptionHistory() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    final snapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('redemptions')
        .orderBy('requestedAt', descending: true)
        .limit(50)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  /// Récupère les statistiques globales (pour admin)
  static Future<Map<String, dynamic>> getGlobalStats() async {
    final usersSnapshot = await _firestore.collection('users').get();

    int totalUsers = usersSnapshot.docs.length;
    int totalVideos = 0;
    int totalSurveys = 0;
    int totalPoints = 0;

    for (var doc in usersSnapshot.docs) {
      final data = doc.data();
      totalVideos += (data['videosWatched'] ?? 0) as int;
      totalSurveys += (data['surveysCompleted'] ?? 0) as int;
      totalPoints += (data['totalPoints'] ?? 0) as int;
    }

    return {
      'totalUsers': totalUsers,
      'totalVideosWatched': totalVideos,
      'totalSurveysCompleted': totalSurveys,
      'totalPointsEarned': totalPoints,
    };
  }
}
