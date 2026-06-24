import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'Splash.dart';
import 'package:get/get.dart';
import 'Helper/NetworkController.dart';
import 'Support/ChatSupport/ChatScreenNew.dart' as new_sara;


// ---------- Background Handler (Separate Isolate) ----------
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // ❌ IMPORTANT: NO local notification here (this caused double notifications)
  print("🔥 Background message received: ${message.messageId}");
}

// ---------- Local Notifications Setup ----------
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

Future<void> _bootstrapLocalNotifications() async {
  const initSettings = InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/launcher_icon'),
  );

  await flutterLocalNotificationsPlugin.initialize(initSettings);

  const channel = AndroidNotificationChannel(
    'default_channel',
    'Default Channel',
    description: 'Used for general notifications.',
    importance: Importance.high,
  );

  final android = flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>();

  await android?.createNotificationChannel(channel);

  // Android 13+ permission
  await android?.requestNotificationsPermission();
}

// ---------- Main Function ----------
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Register background handler BEFORE runApp
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  await _bootstrapLocalNotifications();

  DependencyInjection.init();

  // Background / Terminated state notification click handler
  FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
    if (message != null) {
      print("🔥 App launched from notification!");
      Future.delayed(const Duration(seconds: 2), () {
        Get.to(() => const new_sara.ChatScreenNew());
      });
    }
  });

  // Foreground / Background state notification click handler
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    print("🔥 Notification clicked from background!");
    Get.to(() => const new_sara.ChatScreenNew());
  });

  // Foreground notification handler (safe)
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    final notification = message.notification;
    final android = message.notification?.android;

    if (notification != null && android != null) {
      flutterLocalNotificationsPlugin.show(
        notification.hashCode,
        notification.title,
        notification.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'default_channel',
            'Default Channel',
            channelDescription: 'Used for general notifications.',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            icon: '@mipmap/launcher_icon',
          ),
        ),
      );
    }
  });

  runApp(const MyApp());
}

// ---------- MyApp Widget ----------
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Sara777',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}
