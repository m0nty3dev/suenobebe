import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class NotificationService {
  static final _localNotifications = FlutterLocalNotificationsPlugin();
  static StreamSubscription<String>? _tokenRefreshSub;

  static Future<void> initialize() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _localNotifications.initialize(initSettings);
    _setupFcmForeground();
    _setupTokenRefresh();
  }

  static void _setupFcmForeground() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      if (notification == null) return;
      _showLocalNotification(
        title: notification.title ?? 'Sueño Bebé',
        body: notification.body ?? '',
      );
    });
  }

  // Listens for token rotations and keeps Firestore in sync automatically.
  static void _setupTokenRefresh() {
    _tokenRefreshSub?.cancel();
    _tokenRefreshSub =
        FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      try {
        final deviceId = await _getOrCreateDeviceId();
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'fcmTokens.$deviceId': {
            'token': token,
            'updatedAt': FieldValue.serverTimestamp(),
          },
        });
      } catch (_) {
        // Non-critical — next successful persistToken call will sync the token.
      }
    });
  }

  static Future<void> _showLocalNotification({
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'suenobebe_main',
      'Sueño Bebé',
      channelDescription: 'Notificaciones de Sueño Bebé',
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails);
    await _localNotifications.show(0, title, body, details);
  }

  static Future<String> _getOrCreateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    var deviceId = prefs.getString('fcm_device_id');
    if (deviceId == null) {
      deviceId = const Uuid().v4();
      await prefs.setString('fcm_device_id', deviceId);
    }
    return deviceId;
  }

  /// Reads the current FCM token and persists it to Firestore.
  /// Call after every successful login.
  static Future<void> persistToken(String uid) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      final deviceId = await _getOrCreateDeviceId();
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'fcmTokens.$deviceId': {
          'token': token,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      });
    } catch (_) {
      // Non-critical — notification delivery will still work if next persist succeeds.
    }
  }

  /// Removes the token for this device from Firestore.
  /// Call on sign-out so the user stops receiving notifications.
  static Future<void> removeToken(String uid) async {
    try {
      final deviceId = await _getOrCreateDeviceId();
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'fcmTokens.$deviceId': FieldValue.delete(),
      });
    } catch (_) {}
  }

  static Future<String?> getToken() => FirebaseMessaging.instance.getToken();

  static Future<void> requestPermission() async {
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
  }
}
