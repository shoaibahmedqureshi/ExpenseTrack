import '../entities/notification.dart';

abstract class NotificationRepository {
  /// Get all notifications for user
  Future<List<AppNotification>> getNotifications();

  /// Get unread notifications count
  Future<int> getUnreadCount();

  /// Mark notification as read
  Future<void> markAsRead(String notificationId);

  /// Mark all notifications as read
  Future<void> markAllAsRead();

  /// Delete notification
  Future<void> deleteNotification(String notificationId);

  /// Save notification rule
  Future<void> saveRule(NotificationRule rule);

  /// Get all notification rules
  Future<List<NotificationRule>> getRules();

  /// Delete notification rule
  Future<void> deleteRule(String ruleId);

  /// Update rule status
  Future<void> updateRuleStatus(String ruleId, bool isEnabled);
}
