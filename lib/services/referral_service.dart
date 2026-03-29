import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';

class ReferralService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Génère un code de parrainage unique (6 caractères)
  static String generateReferralCode() {
    const chars =
        'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // Pas de 0,O,1,I pour éviter confusion
    final random = Random();
    return List.generate(6, (_) => chars[random.nextInt(chars.length)]).join();
  }

  static Future<String> getUserReferralCode() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return '';

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      String? code = doc.data()?['referralCode'];

      if (code == null) {
        // Créer un nouveau code
        code = generateReferralCode();
        await _firestore.collection('users').doc(user.uid).update({
          'referralCode': code,
        });

        // Enregistrer dans l'index des codes
        await _firestore.collection('referral_codes').doc(code).set({
          'userId': user.uid,
          'email': user.email,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      return code;
    } catch (e) {
      print('❌ Erreur getUserReferralCode: $e');
      return '';
    }
  }

  static Future<bool> useReferralCode(String code) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    try {
      // Vérifier si l'utilisateur a déjà utilisé un code
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.data()?['usedReferralCode'] != null) {
        print('❌ Code de parrainage déjà utilisé');
        return false;
      }

      // Vérifier que le code existe
      final codeDoc =
          await _firestore.collection('referral_codes').doc(code).get();
      if (!codeDoc.exists) {
        print('❌ Code invalide');
        return false;
      }

      final referrerId = codeDoc.data()?['userId'];
      if (referrerId == user.uid) {
        print('❌ Tu ne peux pas utiliser ton propre code!');
        return false;
      }

      // Donner le bonus au filleul (RÉDUIT 80% pour rentabilité)
      await _firestore.collection('users').doc(user.uid).update({
        'totalPoints': FieldValue.increment(1000), // 5000→1000
        'usedReferralCode': code,
        'referredBy': referrerId,
      });

      // Donner le bonus au parrain
      await _firestore.collection('users').doc(referrerId).update({
        'totalPoints': FieldValue.increment(1000), // 5000→1000
        'referralsCount': FieldValue.increment(1),
      });

      // Enregistrer le parrainage
      await _firestore
          .collection('users')
          .doc(referrerId)
          .collection('referrals')
          .add({
        'userId': user.uid,
        'email': user.email,
        'timestamp': FieldValue.serverTimestamp(),
        'bonus': 1000, // 5000→1000
      });

      print('🎉 Code de parrainage appliqué! +1000 PtitCoins');
      return true;
    } catch (e) {
      print('❌ Erreur useReferralCode: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>> getReferralStats() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return {'count': 0, 'earnings': 0, 'code': ''};

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      final data = doc.data() ?? {};

      final referrals = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('referrals')
          .get();

      final totalEarnings = referrals.docs.fold(0, (sum, doc) {
        return sum + (doc.data()['bonus'] as int? ?? 0);
      });

      return {
        'count': data['referralsCount'] ?? 0,
        'earnings': totalEarnings,
        'code': data['referralCode'] ?? '',
        'referrals': referrals.docs.map((d) => d.data()).toList(),
      };
    } catch (e) {
      print('❌ Erreur getReferralStats: $e');
      return {'count': 0, 'earnings': 0, 'code': ''};
    }
  }

  // Bonus 10% des gains des filleuls
  static Future<void> addReferralBonus(String userId, int points) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final referrerId = userDoc.data()?['referredBy'];

      if (referrerId != null) {
        final bonus = (points * 0.1).round(); // 10%
        await _firestore.collection('users').doc(referrerId).update({
          'totalPoints': FieldValue.increment(bonus),
        });
        print('💰 Bonus parrainage: +$bonus PtitCoins pour le parrain');
      }
    } catch (e) {
      print('❌ Erreur addReferralBonus: $e');
    }
  }
}
