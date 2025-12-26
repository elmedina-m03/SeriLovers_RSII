import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'notification_service.dart';

/// Service for managing episode reminders
class ReminderService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final NotificationService _notificationService = NotificationService();
  static const String _reminderPrefix = 'reminder_';

  /// Enable reminder for a series
  Future<void> enableReminder(int seriesId, String seriesTitle) async {
    try {
      // Initialize notification service if needed
      await _notificationService.initialize();
      
      final reminderData = {
        'seriesId': seriesId,
        'seriesTitle': seriesTitle,
        'enabled': true,
        'enabledAt': DateTime.now().toIso8601String(),
      };
      await _storage.write(
        key: '$_reminderPrefix$seriesId',
        value: jsonEncode(reminderData),
      );
      
      // Schedule a test notification (for demonstration)
      // In production, this would be triggered when a new episode is actually added
      await _notificationService.scheduleTestNotification(
        seriesId: seriesId,
        seriesTitle: seriesTitle,
        delay: const Duration(seconds: 10), // Test notification after 10 seconds
      );
    } catch (e) {
      throw Exception('Failed to enable reminder: $e');
    }
  }

  /// Disable reminder for a series
  Future<void> disableReminder(int seriesId) async {
    try {
      await _storage.delete(key: '$_reminderPrefix$seriesId');
      // Cancel any scheduled notifications for this series
      await _notificationService.cancelNotification(seriesId);
    } catch (e) {
      throw Exception('Failed to disable reminder: $e');
    }
  }

  /// Check if reminder is enabled for a series
  Future<bool> isReminderEnabled(int seriesId) async {
    try {
      final reminderData = await _storage.read(key: '$_reminderPrefix$seriesId');
      if (reminderData == null) {
        return false;
      }
      final data = jsonDecode(reminderData) as Map<String, dynamic>;
      return data['enabled'] == true;
    } catch (e) {
      return false;
    }
  }

  /// Get all enabled reminders
  Future<List<Map<String, dynamic>>> getAllReminders() async {
    try {
      final allKeys = await _storage.readAll();
      final reminders = <Map<String, dynamic>>[];
      
      for (final entry in allKeys.entries) {
        if (entry.key.startsWith(_reminderPrefix)) {
          try {
            final data = jsonDecode(entry.value) as Map<String, dynamic>;
            if (data['enabled'] == true) {
              reminders.add(data);
            }
          } catch (e) {
            // Skip invalid entries
            continue;
          }
        }
      }
      
      return reminders;
    } catch (e) {
      return [];
    }
  }
}

