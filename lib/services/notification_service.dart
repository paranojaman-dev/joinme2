import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    var status = await Permission.notification.status;
    if (!status.isGranted) {
      await Permission.notification.request();
    }

    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/launcher_icon');
    
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: DarwinInitializationSettings(),
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (details) {
        debugPrint("Kliknięto w powiadomienie!");
      },
    );

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showLocalNotification(message);
    });
  }

  static void _showLocalNotification(RemoteMessage message) async {
    showSimpleNotification(
      title: message.notification?.title ?? "JoinMe",
      body: message.notification?.body ?? "",
      payload: message.data.toString(),
    );
  }

  // Nowa uniwersalna metoda do wyświetlania powiadomień
  static Future<void> showSimpleNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'high_importance_channel',
      'High Importance Notifications',
      channelDescription: 'Ważne powiadomienia JoinMe',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/launcher_icon',
    );

    const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      DateTime.now().millisecond, // Unikalne ID
      title,
      body,
      platformDetails,
      payload: payload,
    );
  }

  static Future<String?> getToken() async {
    try {
      return await _messaging.getToken();
    } catch (e) {
      return null;
    }
  }
}
