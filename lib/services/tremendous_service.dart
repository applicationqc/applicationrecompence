/// ⚠️ SERVICE DÉSACTIVÉ - Application de jeu uniquement
/// Ce service n'est plus utilisé car l'application ne traite
/// aucun paiement réel. Tous les points sont virtuels.
class TremendousService {
  // SERVICE DÉSACTIVÉ - L'application utilise uniquement des récompenses virtuelles

  /// Service désactivé - retourne toujours null
  ///
  /// Cette fonction est conservée pour compatibilité mais ne fait rien.
  /// L'application n'envoie plus de récompenses réelles.
  static Future<String?> sendGiftCard({
    required String type,
    required double amount,
    required String recipientEmail,
    required String recipientName,
    required String userFirebaseId,
  }) async {
    print('⚠️ Service Tremendous désactivé - Application de jeu uniquement');
    print('ℹ️ Les récompenses sont virtuelles et restent dans l\'application');
    return null;
  }

  /// Service désactivé - retourne toujours null
  static Future<String?> sendPayPalPayment({
    required double amount,
    required String recipientEmail,
    required String recipientName,
    required String userFirebaseId,
  }) async {
    print('⚠️ Service Tremendous désactivé - Application de jeu uniquement');
    return null;
  }

  /// Service désactivé - retourne toujours null
  static Future<Map<String, dynamic>?> getOrderStatus(String orderId) async {
    print('⚠️ Service Tremendous désactivé');
    return null;
  }

  /// Service désactivé
  static Future<double?> getAccountBalance() async {
    print('⚠️ Service Tremendous désactivé');
    return null;
  }
}
