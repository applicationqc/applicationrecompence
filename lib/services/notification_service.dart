import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    // Demander la permission
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('✅ Notifications autorisées');

      // Initialiser les notifications locales
      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidSettings);

      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (details) {
          print('Notification cliquée: ${details.payload}');
        },
      );

      // Planifier les notifications quotidiennes
      await _scheduleNotifications();
    }
  }

  static Future<void> _scheduleNotifications() async {
    final prefs = await SharedPreferences.getInstance();

    // Notification pour le coffre (6h après la dernière ouverture)
    final lastChestOpened = prefs.getString('last_chest_opened');
    if (lastChestOpened != null) {
      final lastOpened = DateTime.parse(lastChestOpened);
      final nextAvailable = lastOpened.add(const Duration(hours: 6));

      if (nextAvailable.isAfter(DateTime.now())) {
        await _scheduleNotification(
          id: 1,
          title: '🎁 Ton coffre est prêt!',
          body: 'Viens récupérer ta récompense gratuite!',
          scheduledDate: nextAvailable,
        );
      }
    }

    // Notification quotidienne pour les missions (minuit)
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);

    await _scheduleNotification(
      id: 2,
      title: '📋 Nouvelles missions!',
      body: 'De nouvelles missions quotidiennes t\'attendent!',
      scheduledDate: tomorrow,
    );

    // Notification de rappel (si pas de connexion depuis 20h)
    final lastLoginDate = prefs.getString('last_login_date');
    if (lastLoginDate != null) {
      final lastLogin = DateTime.parse(lastLoginDate);
      final reminderTime = lastLogin.add(const Duration(hours: 20));

      if (reminderTime.isAfter(DateTime.now())) {
        await _scheduleNotification(
          id: 3,
          title: '🔥 Ne perds pas ta série!',
          body: 'Connecte-toi pour maintenir ton bonus quotidien!',
          scheduledDate: reminderTime,
        );
      }
    }
  }

  static Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      'le_ptit_cash_channel',
      'Récompenses Le P\'tit Cash',
      channelDescription: 'Notifications pour les récompenses et bonus',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    final notificationDetails = NotificationDetails(android: androidDetails);

    // Calculer le délai
    final delay = scheduledDate.difference(DateTime.now());

    if (delay.isNegative) return; // Ne pas planifier si c'est dans le passé

    await Future.delayed(delay, () async {
      await _localNotifications.show(
        id,
        title,
        body,
        notificationDetails,
      );
    });
  }

  // Notifier immédiatement (pour les événements)
  static Future<void> showInstantNotification({
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'le_ptit_cash_channel',
      'Récompenses Le P\'tit Cash',
      channelDescription: 'Notifications pour les récompenses et bonus',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const notificationDetails = NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      notificationDetails,
    );
  }

  // Mettre à jour la notification du coffre
  static Future<void> updateChestNotification() async {
    final prefs = await SharedPreferences.getInstance();
    final lastChestOpened = prefs.getString('last_chest_opened');

    if (lastChestOpened != null) {
      final nextAvailable = DateTime.parse(lastChestOpened).add(
        const Duration(hours: 6),
      );

      await _scheduleNotification(
        id: 1,
        title: '🎁 Ton coffre est prêt!',
        body: 'Viens récupérer ta récompense gratuite!',
        scheduledDate: nextAvailable,
      );
    }
  }
}
