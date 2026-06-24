import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get_storage/get_storage.dart';

import 'Login/LoginScreen.dart'; // Assuming this is EnterMobileScreen
import 'Login/LoginWithMpinScreen.dart';
import 'login/HomeScreen/HomeScreen.dart';

final storage = GetStorage();
String? fcmToken;
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

/// Background FCM handler - Must be a top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // Removed duplicate notification display to prevent double notifications
  log("🔔 Background message received: ${message.messageId}");
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initializeAllDependencies();
  }

  void _navigateToNextScreen() {
    final isLoggedIn = storage.read('isLoggedIn') ?? false;
    final target = isLoggedIn
        ? const LoginWithMpinScreen()
        : const EnterMobileScreen(); // Corrected class name as per your import

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => target,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  Future<void> _initializeAllDependencies() async {
    try {
      log("🚀 Starting init...");

      if (!await hasInternetConnection()) {
        log("❌ No internet. Skipping FCM init.");
        await Future.delayed(const Duration(seconds: 3));
        _navigateToNextScreen();
        return;
      }
      log("✅ Internet OK");

      await GetStorage.init();

      // 1) Init local notifications (main isolate)
      await _initLocalNotifications();

      // 2) FCM (foreground presentation is iOS-only, safe to call)
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
            alert: true,
            badge: true,
            sound: true,
          );

      final messaging = FirebaseMessaging.instance;

      // Ask notif permission (Android 13+/iOS) with timeout — NO dummy NotificationSettings
      try {
        final settings = await messaging
            .requestPermission(
              alert: true,
              badge: true,
              sound: true,
              // (optional extras) announcement/carPlay/criticalAlert/lockScreen/provisional/timeSensitive
            )
            .timeout(const Duration(seconds: 4));
        log('🔐 Notification permission: ${settings.authorizationStatus}');
      } on TimeoutException {
        log('⏱️ Permission request timed out (continuing).');
      } catch (e) {
        log('⚠️ requestPermission error: $e');
      }

      // Token + topic (guard with timeouts to avoid splash hang)
      try {
        fcmToken = await messaging.getToken().timeout(
          const Duration(seconds: 4),
        );
        if (fcmToken != null) {
          storage.write('fcmToken', fcmToken);
        }
        log("📲 Token saved => $fcmToken");
      } on TimeoutException {
        log("⏱️ getToken timed out");
      } catch (e) {
        log("⚠️ getToken error: $e");
      }

      try {
        await messaging
            .subscribeToTopic('All')
            .timeout(const Duration(seconds: 3));
        log("✅ Subscribed to 'All'");
      } on TimeoutException {
        log("⏱️ subscribeToTopic timed out");
      } catch (e) {
        log("⚠️ subscribeToTopic error: $e");
      }

      // Token refresh
      FirebaseMessaging.instance.onTokenRefresh.listen((token) {
        storage.write('fcmToken', token);
        log("♻️ Token refreshed");
      });

      // Foreground messages -> show local notification
      // Using the main notification handler from main.dart instead of duplicate
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        // Just log the message, don't show duplicate notification
        log("🔔 Foreground message received: ${message.messageId}");
      });

      // Notification tapped from terminated
      final initialMessage = await FirebaseMessaging.instance
          .getInitialMessage();
      if (initialMessage != null) {
        _handleMessageTap(initialMessage);
      }

      // Notification tapped from background
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageTap);

      // Device info (optional) — fire & forget
      _getAndSaveDeviceInfo();

      log("🎉 Init complete");
    } catch (e, st) {
      log("🚨 Init error: $e");
      log("$st");
    } finally {
      Future.delayed(const Duration(seconds: 3), _navigateToNextScreen);
    }
  }

  Future<void> _initLocalNotifications() async {
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/launcher_icon'),
    );

    await flutterLocalNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (resp) {
        log("🔗 Local notif tapped: ${resp.payload}");
      },
    );

    final androidImpl = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    // Ensure the same channel exists (idempotent)
    await androidImpl?.createNotificationChannel(
      const AndroidNotificationChannel(
        'default_channel',
        'Default Channel',
        description: 'Used for general notifications.',
        importance: Importance.high,
      ),
    );

    // Android 13+ POST_NOTIFICATIONS
    await androidImpl?.requestNotificationsPermission();
  }

  void _handleMessageTap(RemoteMessage message) {
    log("👉 Notification tapped with data: ${message.data}");
    // TODO: route using message.data if needed
    final target = HomeScreen();
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, a, __) => target,
        transitionsBuilder: (_, a, __, child) =>
            FadeTransition(opacity: a, child: child),
      ),
    );
  }

  Future<void> _getAndSaveDeviceInfo() async {
    final deviceInfoPlugin = DeviceInfoPlugin();
    String? deviceId;
    String? deviceName;

    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfoPlugin.androidInfo;
        deviceId = androidInfo.id;
        deviceName = androidInfo.model;
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfoPlugin.iosInfo;
        deviceId = iosInfo.identifierForVendor;
        deviceName = iosInfo.name;
      }
    } catch (e) {
      log('Error getting device info: $e');
    }

    if (deviceId != null) await storage.write('deviceId', deviceId);
    if (deviceName != null) await storage.write('deviceName', deviceName);
  }

  Future<bool> hasInternetConnection() async {
    final result = await Connectivity().checkConnectivity();
    return result != ConnectivityResult.none;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: SafeArea(
        child: SizedBox.expand(
          child: Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  'assets/images/splash_img.jpeg',
                  fit: BoxFit.cover,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
