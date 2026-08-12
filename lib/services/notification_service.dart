import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;
  bool _initFailed = false;

  Future<void> initNotification() async {
    if (_isInitialized || _initFailed) return;

    try {
      // Android ayarları
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      // iOS ayarları — izinleri BURADA İSTEMEYİZ, sadece kanal kurarız
      // İzin isteme işlemi uygulamanın ilerleyen akışında yapılmalı
      const DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
        // iOS 26 / Xcode 17 uyumluluğu için defaultPresentAlert kapatıldı
        defaultPresentAlert: false,
        defaultPresentBadge: false,
        defaultPresentSound: false,
      );

      const InitializationSettings initializationSettings =
          InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );

      final bool? result = await _notificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          if (kDebugMode) {
            debugPrint('Notification clicked: ${response.payload}');
          }
        },
      );

      _isInitialized = result ?? false;
    } catch (e) {
      _initFailed = true;
      debugPrint('NotificationService init exception (non-fatal): $e');
    }
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_isInitialized) return;
    try {
      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        'temasan_orders_channel',
        'Temasan Sipariş Bildirimleri',
        channelDescription: 'Yeni sipariş ve kurye durum bildirim kanalı',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
      );

      const NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(),
      );

      await _notificationsPlugin.show(
        id,
        title,
        body,
        notificationDetails,
        payload: payload,
      );
    } catch (e) {
      debugPrint('showNotification error (non-fatal): $e');
    }
  }
}
