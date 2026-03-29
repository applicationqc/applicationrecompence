import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserProgressService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Système de niveaux 1-50
  static int calculateLevel(int totalXP) {
    // XP requis augmente de 1000 par niveau
    return (totalXP / 1000).floor() + 1;
  }

  static int getXPForNextLevel(int currentLevel) {
    return currentLevel * 1000;
  }

  static double getLevelBonus(int level) {
    // +5% par niveau (max 250% au niveau 50)
    return 1.0 + (level * 0.05);
  }

  static Future<Map<String, dynamic>> getUserProgress() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return {'level': 1, 'xp': 0, 'totalXP': 0};

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      final data = doc.data() ?? {};

      final totalXP = data['totalXP'] ?? 0;
      final level = calculateLevel(totalXP);
      final xpForNext = getXPForNextLevel(level);
      final currentLevelXP = totalXP % 1000;

      return {
        'level': level,
        'xp': currentLevelXP,
        'totalXP': totalXP,
        'xpForNext': xpForNext,
        'bonus': getLevelBonus(level),
      };
    } catch (e) {
      print('❌ Erreur getUserProgress: $e');
      return {'level': 1, 'xp': 0, 'totalXP': 0};
    }
  }

  static Future<void> addXP(int xpAmount, String reason) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('users').doc(user.uid).update({
        'totalXP': FieldValue.increment(xpAmount),
      });

      // Log l'activité XP
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('xp_history')
          .add({
        'amount': xpAmount,
        'reason': reason,
        'timestamp': FieldValue.serverTimestamp(),
      });

      print('⭐ +$xpAmount XP ($reason)');
    } catch (e) {
      print('❌ Erreur addXP: $e');
    }
  }
}
