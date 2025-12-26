import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';

/// Service for managing local notifications
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Initialize the notification service
  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    final initialized = await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    if (initialized != null && initialized) {
      _initialized = true;
      debugPrint('NotificationService initialized successfully');
    } else {
      debugPrint('NotificationService initialization failed');
    }
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');
    // You can navigate to a specific screen based on the payload
  }

  /// Show a notification for a new episode
  Future<void> showNewEpisodeNotification({
    required int seriesId,
    required String seriesTitle,
    required String episodeTitle,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    const androidDetails = AndroidNotificationDetails(
      'new_episodes',
      'New Episodes',
      channelDescription: 'Notifications for new episodes of your favorite series',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      seriesId, // Use seriesId as notification ID to avoid duplicates
      'New Episode Available!',
      'A new episode of $seriesTitle is now available: $episodeTitle',
      details,
      payload: 'series_$seriesId',
    );
  }

  /// Schedule a test notification (for demonstration)
  /// In production, this would be triggered when a new episode is actually added
  Future<void> scheduleTestNotification({
    required int seriesId,
    required String seriesTitle,
    Duration delay = const Duration(seconds: 10),
  }) async {
    if (!_initialized) {
      await initialize();
    }

    // For demonstration, we'll show a notification after a delay
    // In production, this would be triggered by backend/webhook when episode count increases
    Future.delayed(delay, () async {
      await showNewEpisodeNotification(
        seriesId: seriesId,
        seriesTitle: seriesTitle,
        episodeTitle: 'New Episode',
      );
    });
  }

  /// Cancel a notification
  Future<void> cancelNotification(int notificationId) async {
    await _notifications.cancel(notificationId);
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }
}

