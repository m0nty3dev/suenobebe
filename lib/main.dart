import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'core/services/firebase/firebase_init.dart';
import 'core/services/notifications/notification_service.dart';
import 'core/services/ads/consent_service.dart';
import 'features/settings/presentation/controllers/theme_controller.dart';
import 'app/app.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: firebaseOptions);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  tz.initializeTimeZones();

  await Firebase.initializeApp(options: firebaseOptions);

  FirebaseFirestore.instance.settings =
      const Settings(persistenceEnabled: true, cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED);

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  await NotificationService.initialize();
  await ConsentService.initialize();

  // Load theme preference before first frame to avoid ThemeMode.system flash.
  final prefs = await SharedPreferences.getInstance();
  final savedTheme = prefs.getString('theme_mode');
  final initialTheme = savedTheme != null
      ? ThemeMode.values.firstWhere(
          (e) => e.name == savedTheme,
          orElse: () => ThemeMode.system,
        )
      : ThemeMode.system;

  runApp(ProviderScope(
    overrides: [
      themeModeNotifierProvider.overrideWith(
        () => ThemeModeNotifier(initialTheme: initialTheme),
      ),
    ],
    child: const SuenoBebe(),
  ));
}
