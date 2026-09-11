import 'dart:async';
import 'dart:convert';

import 'package:firebase_app_installations/firebase_app_installations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../../app/config/firebase_config.dart';
import '../../../core/network/api_client.dart';
import '../domain/repositories/push_notification_repository.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (!FirebaseConfig.isConfigured) return;

  try {
    await Firebase.initializeApp(options: FirebaseConfig.currentPlatform);
  } catch (_) {
    // Firebase may already be initialized by the host process.
  }
}

class FirebasePushNotificationRepository implements PushNotificationRepository {
  static const _channelId = 'erp_notifications';
  static const _channelName = 'ERP notifications';
  static const _channelDescription = 'Notifications for ERP approvals and operations.';

  final ApiClient _apiClient;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final StreamController<Map<String, String>> _openedNotificationController =
      StreamController<Map<String, String>>.broadcast();

  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  StreamSubscription<String>? _installationIdSubscription;

  bool _initialized = false;
  bool _authenticated = false;
  bool _registrationInProgress = false;
  String? _registeredInstallationId;

  FirebasePushNotificationRepository(this._apiClient);

  @override
  Stream<Map<String, String>> get openedNotifications =>
      _openedNotificationController.stream;

  @override
  Future<void> initialize() async {
    if (_initialized || !FirebaseConfig.isConfigured) return;

    try {
      await Firebase.initializeApp(options: FirebaseConfig.currentPlatform);

      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      await _initializeLocalNotifications();
      await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
        alert: false,
        badge: false,
        sound: false,
      );

      _foregroundSubscription = FirebaseMessaging.onMessage.listen(
        _showForegroundNotification,
      );
      _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
        _publishOpenedNotification,
      );
      _installationIdSubscription =
          FirebaseInstallations.instance.onIdChange.listen((installationId) {
        if (_authenticated) {
          unawaited(_registerInstallation(installationId));
        }
      });

      final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        _publishOpenedNotification(initialMessage);
      }

      _initialized = true;
    } catch (error) {
      debugPrint('Firebase push initialization failed: $error');
    }
  }

  @override
  Future<void> setAuthenticated(bool authenticated) async {
    if (!FirebaseConfig.isConfigured || !_initialized) return;

    if (!authenticated) {
      if (_authenticated) {
        await _unregisterCurrentInstallation();
      }
      _authenticated = false;
      _registeredInstallationId = null;
      return;
    }

    _authenticated = true;
    await _requestPermissionAndRegister();
  }

  Future<void> _requestPermissionAndRegister() async {
    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      debugPrint('Push notification permission: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.denied) return;
      await _registerCurrentInstallation();
    } catch (error) {
      debugPrint('Push notification permission failed: $error');
    }
  }

  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _localNotifications.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) return;
        try {
          final decoded = jsonDecode(payload);
          if (decoded is Map<String, dynamic>) {
            _openedNotificationController.add(
              decoded.map((key, value) => MapEntry(key, value.toString())),
            );
          }
        } catch (_) {
          // Ignore malformed local notification payloads.
        }
      },
    );

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.high,
      ),
    );
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final remoteNotification = message.notification;
    if (remoteNotification == null) return;

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();

    await _localNotifications.show(
      _notificationId(message),
      remoteNotification.title,
      remoteNotification.body,
      NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      ),
      payload: jsonEncode(_notificationPayload(message)),
    );
  }

  int _notificationId(RemoteMessage message) {
    final messageId = message.messageId;
    final raw = messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch;
    return raw & 0x7fffffff;
  }

  Map<String, String> _notificationPayload(RemoteMessage message) {
    return {
      'notification_id': message.data['notification_id']?.toString() ?? '',
      'notification_type': message.data['notification_type']?.toString() ?? '',
      'target_type': message.data['target_type']?.toString() ?? '',
      'target_id': message.data['target_id']?.toString() ?? '',
    };
  }

  void _publishOpenedNotification(RemoteMessage message) {
    final payload = <String, String>{
      ..._notificationPayload(message),
      ...message.data.map((key, value) => MapEntry(key, value.toString())),
    };
    _openedNotificationController.add(payload);
  }

  Future<void> _registerCurrentInstallation() async {
    final installationId = await FirebaseInstallations.instance.getId();
    await _registerInstallation(installationId);
  }

  Future<void> _registerInstallation(String installationId) async {
    if (!_authenticated || _registrationInProgress) return;
    if (_registeredInstallationId == installationId) return;

    _registrationInProgress = true;
    try {
      final platform = defaultTargetPlatform == TargetPlatform.iOS
          ? 'ios'
          : 'android';
      final appId = Firebase.app().options.appId;

      await _apiClient.dio.post(
        '/notifications/devices/',
        data: {
          'installation_id': installationId,
          'platform': platform,
          'firebase_app_id': appId,
        },
      );
      _registeredInstallationId = installationId;
    } catch (error) {
      debugPrint('Push device registration failed: $error');
    } finally {
      _registrationInProgress = false;
    }
  }

  Future<void> _unregisterCurrentInstallation() async {
    final installationId = _registeredInstallationId;
    if (installationId == null || installationId.isEmpty) return;

    try {
      final encodedInstallationId = Uri.encodeComponent(installationId);
      await _apiClient.dio.delete('/notifications/devices/$encodedInstallationId/');
    } catch (error) {
      debugPrint('Push device unregister failed: $error');
    }
  }

  Future<void> dispose() async {
    await _foregroundSubscription?.cancel();
    await _openedSubscription?.cancel();
    await _installationIdSubscription?.cancel();
    await _openedNotificationController.close();
  }
}
