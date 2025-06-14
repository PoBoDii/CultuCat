import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import '/screens/login/login_screen.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'config/firebase_config.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '/utils/server_url.dart';
import '../utils/user_preferences.dart';
import '../utils/globals.dart';
import 'package:flutter/services.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
import '/screens/event_map/event.dart';
// ignore_for_file: deprecated_member_use

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await FirebaseConfig.initializeFirebase();
  print('📥 [BG] Mensaje en background: ${message.messageId}');
  print('📥 [BG] Título: ${message.notification?.title}');
  print('📥 [BG] Cuerpo: ${message.notification?.body}');
  print('📥 [BG] Data: ${message.data}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  await FirebaseConfig.initializeFirebase();

  // Firebase Performance monitoring
  final Trace startupTrace = FirebasePerformance.instance.newTrace("startup_trace");
  await startupTrace.start();

  // System UI configuration
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  // Crashlytics setup
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterError;
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  // Initialize local notifications with enhanced configuration
  await _initializeLocalNotifications();

  // Configure handler for background messages
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Setup FCM globally
  await _setupFCM();

  runZonedGuarded(() {
    runApp(
      EasyLocalization(
        supportedLocales: const [Locale('es'), Locale('en'), Locale('ca')],
        path: 'assets/lang',
        fallbackLocale: const Locale('es'),
        startLocale: const Locale('es'),
        child: MyApp(),
      ),
    );
  }, (error, stackTrace) {
    FirebaseCrashlytics.instance.recordError(error, stackTrace, fatal: true);
  });

  await startupTrace.stop();
}

Future<void> _initializeLocalNotifications() async {
  const AndroidInitializationSettings androidSettings =
  AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initSettings =
  InitializationSettings(android: androidSettings);

  await flutterLocalNotificationsPlugin.initialize(
    initSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      print('📱 Notificación tocada: ${response.payload}');
      // Navigate to specific chat screen
      _handleNotificationTap(response.payload);
    },
  );

  // Create notification channel for Android
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'chat_channel', // id
    'Chat Notifications', // name
    description: 'Notificaciones de mensajes de chat',
    importance: Importance.max,
    enableVibration: true,
    playSound: true,
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);
}

Future<void> _setupFCM() async {
  FirebaseMessaging messaging = FirebaseMessaging.instance;

  // Request permissions with complete configuration
  NotificationSettings settings = await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
    provisional: false,
    criticalAlert: false,
    announcement: false,
  );

  if (settings.authorizationStatus == AuthorizationStatus.authorized) {
    print('✅ Permisos de notificación concedidos');

    // Get and send token to backend
    String? token = await messaging.getToken();
    if (token != null) {
      print('📱 FCM Token: $token');
      await _sendTokenToBackend(token);
    }

    // 🔄 ENHANCED: Listener for foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print("📩 Notificación en foreground: ${message.data}");
      print('🔄 FCM Data recibida: ${message.data}');
      print('🔄 Tipo de mensaje: ${message.data['type']}');

      // Verify it's a group chat message
      if (message.data['type'] == 'new_group_message' || message.data['type'] == 'new_message') {
        // 🆕 ENSURE that data is complete
        try {
          final chatId = int.tryParse(message.data['chat_id']?.toString() ?? '');
          final senderUsername = message.data['sender_username']?.toString();
          final text = message.data['text']?.toString();
          final type = message.data['type']?.toString();
          final group_id = message.data['group_id']?.toString();

          if (chatId != null && senderUsername != null && text != null) {
            print('🔄 Actualizando chat con ID: $chatId');

            // Update the ValueNotifier
            newMessageNotifier.value = {
              'chat_id': chatId,
              'sender_username': senderUsername,
              'text': text,
              'timestamp': DateTime.now().millisecondsSinceEpoch,
              'type': type,
              'group_id': group_id,
            };

            // 🆕 RESET the notifier after a brief delay to allow multiple messages
            Future.delayed(Duration(milliseconds: 10000), () {
              newMessageNotifier.value = null;
            });
          } else {
            print('⚠️ Datos incompletos en el mensaje FCM');
            print('ChatId: $chatId, Sender: $senderUsername, Text: $text');
          }
        } catch (e) {
          print('❌ Error procesando mensaje: $e');
        }
        if (!onChat) _showLocalNotification(message);
      }

      // Show local notification only if necessary
      if (!onChat) _showLocalNotification(message);
    });

    // Listener for when token is updated
    messaging.onTokenRefresh.listen((String newToken) {
      print('🔄 Token actualizado: $newToken');
      _sendTokenToBackend(newToken);
    });

    // Handle notifications when app opens from a notification
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('📱 App abierta desde notificación: ${message.data}');
      _handleNotificationTap(message.data);
    });

    // Check if app opened from notification (when it was terminated)
    RemoteMessage? initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      print('📱 App iniciada desde notificación: ${initialMessage.data}');
      _handleNotificationTap(initialMessage.data);
    }
  } else {
    print('❌ Permisos de notificación denegados');
  }
}

void _handleNotificationTap(dynamic data) {
  // Implement navigation to specific chat
  // For example, if data contains chat_id, navigate to that chat
  print('🔔 Manejando tap en notificación con data: $data');

  // Example of how you could navigate:
  // if (data is Map && data.containsKey('chat_id')) {
  //   String chatId = data['chat_id'];
  //   NavigatorService.navigateToChat(chatId);
  // }
}

Future<void> _sendTokenToBackend(String token) async {
  try {
    final mytoken = await UserPreferences.getToken();
    if (mytoken != null) {
      final response = await http.post(
        Uri.parse('${ServerUrl.getBaseUrl()}/api/save-fcm-token/'),
        headers: {
          'Authorization': 'Token $mytoken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'token': token}),
      );

      if (response.statusCode == 200) {
        print('✅ Token enviado al backend exitosamente');
      } else {
        print('⚠️ Error al enviar token: ${response.statusCode} - ${response.body}');
      }
    }
  } catch (e) {
    print('❌ Error enviando token al backend: $e');
  }
}

void _showLocalNotification(RemoteMessage message) async {
  // Create payload with chat information for navigation
  String payload = '';
  if (message.data.containsKey('chat_id')) {
    payload = jsonEncode(message.data);
  }

  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'chat_channel',
    'Chat Notifications',
    channelDescription: 'Notificaciones de mensajes de chat',
    importance: Importance.max,
    priority: Priority.high,
    enableVibration: true,
    playSound: true,
    icon: '@mipmap/ic_launcher',
    showWhen: true,
  );

  const NotificationDetails platformDetails = NotificationDetails(
    android: androidDetails,
  );

  await flutterLocalNotificationsPlugin.show(
    DateTime.now().millisecondsSinceEpoch ~/ 1000, // Unique ID
    message.notification?.title ?? 'Nuevo mensaje',
    message.notification?.body ?? '',
    platformDetails,
    payload: payload,
  );
}

class MyApp extends StatefulWidget {
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _setupDynamicLinks();
  }

  void _setupDynamicLinks() async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final PendingDynamicLinkData? initialLink =
      await FirebaseDynamicLinks.instance.getInitialLink();
      await _handleDeepLink(initialLink);

      FirebaseDynamicLinks.instance.onLink.listen((dynamicLinkData) {
        _handleDeepLink(dynamicLinkData);
      }).onError((error) {
        print('Error en dynamic link: $error');
      });
    });
  }

  Future<void> _handleDeepLink(PendingDynamicLinkData? data) async {
    final Uri? deepLink = data?.link;
    print('DeepLink recibido: $deepLink');
    if (deepLink == null) return;

    final String? eventId = deepLink.queryParameters['id'];
    final String? eventName = deepLink.queryParameters['name'];
    print('eventId recibido: $eventId');
    print('eventName recibido: $eventName');

    final bool isLoggedIn = await UserPreferences.isLoggedIn();
    print('Usuario logueado: $isLoggedIn');

    if (eventId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final navigator = navigatorKey.currentState;
        if (navigator == null) {
          print("⚠️ navigatorKey.currentState es null");
          return;
        }

        if (isLoggedIn) {
          navigator.pushReplacement(
            MaterialPageRoute(
              builder: (_) => EventScreen(
                texto: eventName ?? 'Shared Event',
                id: eventId,
              ),
            ),
          );
        } else {
          navigator.pushReplacement(
            MaterialPageRoute(
              builder: (_) => LoginScreen(),
            ),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'app_title'.tr(),
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      theme: ThemeData(primarySwatch: Colors.blue),
      home: LoginScreen(),
    );
  }
}