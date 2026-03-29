import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StreakService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Bonus progressifs par jour de streak (RÉDUIT 70% pour rentabilité)
  static int getStreakBonus(int streakDays) {
    if (streakDays == 1) return 30; // 100→30
    if (streakDays == 3) return 90; // 300→90
    if (streakDays == 7) return 300; // 1000→300
    if (streakDays == 14) return 750; // 2500→750
    if (streakDays == 30) return 3000; // 10000→3000
    return 0; // Pas de bonus aujourd'hui
  }

  static String getStreakEmoji(int streakDays) {
    if (streakDays >= 30) return '🔥🔥🔥';
    if (streakDays >= 14) return '🔥🔥';
    if (streakDays >= 7) return '🔥';
    return '⭐';
  }

  static Future<Map<String, dynamic>> updateStreak() async {
    final prefs = await SharedPreferences.getInstance();
    final user = FirebaseAuth.instance.currentUser;

    final today = DateTime.now().toIso8601String().substring(0, 10);
    final lastLogin = prefs.getString('last_login_date') ?? '';
    final currentStreak = prefs.getInt('login_streak') ?? 0;

    if (lastLogin == today) {
      // Déjà connecté aujourd'hui
      return {
        'streak': currentStreak,
        'bonus': 0,
        'newStreak': false,
      };
    }

    final yesterday = DateTime.now()
        .subtract(const Duration(days: 1))
        .toIso8601String()
        .substring(0, 10);

    int newStreak;
    if (lastLogin == yesterday) {
      // Continue le streak
      newStreak = currentStreak + 1;
    } else {
      // Reset le streak
      newStreak = 1;
    }

    final bonus = getStreakBonus(newStreak);

    await prefs.setString('last_login_date', today);
    await prefs.setInt('login_streak', newStreak);

    // Sauvegarder dans Firestore
    if (user != null) {
      try {
        await _firestore.collection('users').doc(user.uid).update({
          'loginStreak': newStreak,
          'lastLoginDate': today,
          'longestStreak':
              FieldValue.increment(newStreak > currentStreak ? 1 : 0),
        });

        if (bonus > 0) {
          await _firestore.collection('users').doc(user.uid).update({
            'totalPoints': FieldValue.increment(bonus),
          });
        }
      } catch (e) {
        print('❌ Erreur updateStreak Firestore: $e');
      }
    }

    return {
      'streak': newStreak,
      'bonus': bonus,
      'newStreak': true,
      'emoji': getStreakEmoji(newStreak),
    };
  }

  static Future<int> getCurrentStreak() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('login_streak') ?? 0;
  }

  static Future<int> getLongestStreak() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 0;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      return doc.data()?['longestStreak'] ?? 0;
    } catch (e) {
      return 0;
    }
  }
}
