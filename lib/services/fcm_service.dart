import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'token_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Top-level background message handler.
// Must be a top-level (non-anonymous, non-class) function.
// FCM invokes this in an isolate when the app is in background / terminated.
// ─────────────────────────────────────────────────────────────────────────────
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Nothing special needed — FCM displays the notification automatically
  // when the app is in background/terminated and the payload contains a
  // 'notification' object.  Data-only messages can be processed here if needed.
  debugPrint('[FCM BG] Received: ${message.messageId}');
}

// ─────────────────────────────────────────────────────────────────────────────
// Android notification channel (required for Android 8+)
// ─────────────────────────────────────────────────────────────────────────────
const AndroidNotificationChannel _channel = AndroidNotificationChannel(
  'bsm_high_importance_channel',           // id  — must match AndroidManifest
  'BSM Notifications',                      // name
  description: 'Business alerts from BSM Agro Industry',
  importance: Importance.high,
  playSound: true,
  enableVibration: true,
);

/// Central service for Firebase Cloud Messaging.
///
/// Usage:
///   1. Call [FcmService.init] once in `main()` before [runApp].
///   2. After login call [FcmService.instance.registerToken].
///   3. Before logout call [FcmService.instance.unregisterToken].
class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();

  final FirebaseMessaging _fm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotif =
      FlutterLocalNotificationsPlugin();

  /// Injected by [MyApp] so foreground-notification taps can navigate.
  GlobalKey<NavigatorState>? navigatorKey;

  // Base URL mirrors DioClient — keeps FCM token calls independent of the
  // Dio singleton lifecycle (token must be saveable even before full DioClient
  // is wired up, and deletable even after DioClient is reset on logout).
  static const String _baseUrl =
      'https://bsm-backend-6e0m.onrender.com/api';

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Call once from `main()` — before [runApp].
  static Future<void> init({required GlobalKey<NavigatorState> navigatorKey}) async {
    final svc = FcmService.instance;
    svc.navigatorKey = navigatorKey;

    // 1. Register the background handler (must happen before any listeners).
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // 2. Request permission (also shown on first run for iOS / Android 13+).
    await svc._requestPermission();

    // 3. Initialize the local notification plugin.
    await svc._initLocalNotifications();

    // 4. Set up foreground notification display.
    svc._listenForeground();

    // 5. Handle notification taps when app is in background (opened via tap).
    svc._listenBackgroundOpen();

    // 6. Handle notification tap when app was fully terminated.
    await svc._handleTerminatedLaunch();

    // 7. Listen for token refreshes and auto-update the backend.
    svc._listenTokenRefresh();

    debugPrint('[FCM] Service initialized');
  }

  /// Called right after a successful login.
  /// Gets the FCM token and POSTs it to the backend.
  Future<void> registerToken() async {
    try {
      final token = await _fm.getToken();
      if (token == null || token.isEmpty) return;
      debugPrint('[FCM] Registering token: ${token.substring(0, 20)}…');
      await _postTokenToBackend(token);
    } catch (e) {
      debugPrint('[FCM] registerToken error: $e');
    }
  }

  /// Called right before logout.
  /// DELETEs the token from the backend, then removes the stored token.
  Future<void> unregisterToken() async {
    try {
      await _deleteTokenFromBackend();
      await _fm.deleteToken(); // rotate local token so it can't be re-used
      debugPrint('[FCM] Token unregistered');
    } catch (e) {
      debugPrint('[FCM] unregisterToken error: $e');
    }
  }

  // ── Permission ─────────────────────────────────────────────────────────────

  Future<void> _requestPermission() async {
    final settings = await _fm.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
    debugPrint('[FCM] Permission: ${settings.authorizationStatus}');

    // On Android, ensure foreground notifications are always shown.
    await _fm.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  // ── Local notifications init ───────────────────────────────────────────────

  Future<void> _initLocalNotifications() async {
    // Android init — @mipmap/ic_launcher used as the notification icon.
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    // iOS init.
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false, // already asked via FirebaseMessaging
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _localNotif.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (details) {
        // User tapped a local notification shown in the foreground.
        _handlePayload(details.payload);
      },
    );

    // Create the high-importance Android channel.
    await _localNotif
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);
  }

  // ── Foreground listener ────────────────────────────────────────────────────

  void _listenForeground() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('[FCM FG] title=${message.notification?.title}');
      _showLocalNotification(message);
    });
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    final android = AndroidNotificationDetails(
      _channel.id,
      _channel.name,
      channelDescription: _channel.description,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
    );

    await _localNotif.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(android: android),
      payload: jsonEncode(message.data),
    );
  }

  // ── Background / terminated tap handlers ──────────────────────────────────

  /// App is in background and the user taps the notification.
  void _listenBackgroundOpen() {
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('[FCM BG-TAP] data=${message.data}');
      _navigateFromData(message.data);
    });
  }

  /// App was fully terminated — check if it was launched from a notification.
  Future<void> _handleTerminatedLaunch() async {
    final initial = await _fm.getInitialMessage();
    if (initial != null) {
      debugPrint('[FCM TERMINATED-TAP] data=${initial.data}');
      // Small delay so the widget tree is ready.
      await Future<void>.delayed(const Duration(milliseconds: 500));
      _navigateFromData(initial.data);
    }
  }

  // ── Token refresh ──────────────────────────────────────────────────────────

  void _listenTokenRefresh() {
    _fm.onTokenRefresh.listen((newToken) async {
      debugPrint('[FCM] Token refreshed');
      await _postTokenToBackend(newToken);
    });
  }

  // ── Navigation ─────────────────────────────────────────────────────────────

  /// Routes to the correct screen based on the notification [data] payload.
  ///
  /// Payload `type` values:
  ///   - "new_delivery"      → DeliveryListScreen
  ///   - "customer_payment"  → CustomersScreen
  ///   - "low_stock"         → InventoryListScreen
  void _navigateFromData(Map<String, dynamic> data) {
    final nav = navigatorKey?.currentState;
    if (nav == null) {
      debugPrint('[FCM] Navigator not ready — skipping navigation');
      return;
    }

    final type = data['type']?.toString() ?? '';
    debugPrint('[FCM] Navigating for type=$type');

    switch (type) {
      case 'new_delivery':
        nav.pushNamed('/delivery');
        break;
      case 'customer_payment':
        nav.pushNamed('/customers');
        break;
      case 'low_stock':
        nav.pushNamed('/inventory');
        break;
      default:
        debugPrint('[FCM] Unknown notification type: $type');
    }
  }

  /// Parses a JSON payload string (from local notification tap) and navigates.
  void _handlePayload(String? payload) {
    if (payload == null || payload.isEmpty) return;
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      _navigateFromData(data);
    } catch (e) {
      debugPrint('[FCM] Failed to parse payload: $e');
    }
  }

  // ── Backend HTTP calls ─────────────────────────────────────────────────────

  // Future<String?> _getAuthToken() async {
  //   final prefs = await SharedPreferences.getInstance();
  //   return prefs.getString('token');
  // }
  Future<String?> _getAuthToken() async {
  try {
    final tokenService = await TokenService.getInstance();
    return tokenService.getToken();
  } catch (e) {
    debugPrint('[FCM] Error getting auth token: $e');
    return null;
  }
}

  Future<void> _postTokenToBackend(String fcmToken) async {
    final authToken = await _getAuthToken();
    if (authToken == null || authToken.isEmpty) {
      debugPrint('[FCM] No auth token — skipping POST');
      return;
    }

    try {
      final dio = Dio(BaseOptions(
        baseUrl: _baseUrl,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ));
      await dio.post('/auth/fcm-token', data: {'fcmToken': fcmToken});
      debugPrint('[FCM] JWT Found: ${authToken != null}');
debugPrint('[FCM] Sending token to backend');
      debugPrint('[FCM] Token saved to backend ✓');
    } catch (e) {
      debugPrint('[FCM] POST /auth/fcm-token error: $e');
    }
    
  }

  Future<void> _deleteTokenFromBackend() async {
    final authToken = await _getAuthToken();
    if (authToken == null || authToken.isEmpty) return;

    try {
      final dio = Dio(BaseOptions(
        baseUrl: _baseUrl,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ));
      await dio.delete('/auth/fcm-token');
      debugPrint('[FCM] Token removed from backend ✓');
    } catch (e) {
      debugPrint('[FCM] DELETE /auth/fcm-token error: $e');
    }
  }
}
