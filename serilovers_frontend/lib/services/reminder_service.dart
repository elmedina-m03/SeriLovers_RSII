import 'api_service.dart';
import 'notification_service.dart';

/// Service for managing episode reminders via backend API
class ReminderService {
  final ApiService _apiService;
  final NotificationService _notificationService = NotificationService();

  ReminderService({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  /// Enable reminder for a series
  Future<void> enableReminder(int seriesId, String seriesTitle, {String? token}) async {
    try {
      if (token == null || token.isEmpty) {
        throw Exception('Authentication required');
      }

      // Initialize notification service if needed
      await _notificationService.initialize();

      // Call backend API to enable reminder
      await _apiService.post(
        '/Reminder',
        {
          'seriesId': seriesId,
        },
        token: token,
      );

      // Note: Backend will handle tracking episode counts
      // Frontend notification service is still used for local notifications
      // when backend sends notification triggers (to be implemented)
    } catch (e) {
      throw Exception('Failed to enable reminder: $e');
    }
  }

  /// Disable reminder for a series
  Future<void> disableReminder(int seriesId, {String? token}) async {
    try {
      if (token == null || token.isEmpty) {
        throw Exception('Authentication required');
      }

      // Call backend API to disable reminder
      await _apiService.delete(
        '/Reminder/series/$seriesId',
        token: token,
      );

      // Cancel any scheduled notifications for this series
      await _notificationService.cancelNotification(seriesId);
    } catch (e) {
      throw Exception('Failed to disable reminder: $e');
    }
  }

  /// Check if reminder is enabled for a series
  Future<bool> isReminderEnabled(int seriesId, {String? token}) async {
    try {
      if (token == null || token.isEmpty) {
        return false;
      }

      // Call backend API to check reminder status
      final response = await _apiService.get(
        '/Reminder/series/$seriesId',
        token: token,
      );

      if (response is bool) {
        return response;
      }
      return false;
    } catch (e) {
      // If error, return false (reminder not enabled)
      return false;
    }
  }

  /// Get all enabled reminders for the current user
  Future<List<Map<String, dynamic>>> getAllReminders({String? token}) async {
    try {
      if (token == null || token.isEmpty) {
        return [];
      }

      final response = await _apiService.get(
        '/Reminder',
        token: token,
      );

      if (response is List) {
        return response
            .map((item) => item as Map<String, dynamic>)
            .toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }
}
