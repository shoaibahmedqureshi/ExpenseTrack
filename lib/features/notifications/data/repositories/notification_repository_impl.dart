import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/notification.dart';
import '../../domain/repositories/notification_repository.dart';

class NotificationRepositoryImpl implements NotificationRepository {
  final SharedPreferences prefs;

  static const String _notificationsKey = 'notifications';
  static const String _rulesKey = 'notification_rules';
  static const String _unreadCountKey = 'unread_count';

  NotificationRepositoryImpl({required this.prefs});

  @override
  Future<List<AppNotification>> getNotifications() async {
    try {
      final jsonString = prefs.getString(_notificationsKey);
      if (jsonString == null) return [];

      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList
          .map((json) => AppNotification.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  @override
  Future<int> getUnreadCount() async {
    try {
      final notifications = await getNotifications();
      return notifications.where((n) => !n.isRead).length;
    } catch (e) {
      return 0;
    }
  }

  @override
  Future<void> markAsRead(String notificationId) async {
    try {
      final notifications = await getNotifications();
      notifications.asMap().forEach((index, notification) {
        if (notification.id == notificationId) {
          notifications[index] = notification.copyWith(isRead: true);
        }
      });
      await _saveNotifications(notifications);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> markAllAsRead() async {
    try {
      final notifications = await getNotifications();
      notifications.asMap().forEach((index, notification) {
        notifications[index] = notification.copyWith(isRead: true);
      });
      await _saveNotifications(notifications);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> deleteNotification(String notificationId) async {
    try {
      final notifications = await getNotifications();
      notifications.removeWhere((n) => n.id == notificationId);
      await _saveNotifications(notifications);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> saveRule(NotificationRule rule) async {
    try {
      final rules = await getRules();
      // Remove if exists, then add
      rules.removeWhere((r) => r.id == rule.id);
      rules.add(rule);
      await _saveRules(rules);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<NotificationRule>> getRules() async {
    try {
      final jsonString = prefs.getString(_rulesKey);
      if (jsonString == null) {
        // Return default rules
        return [
          NotificationRule(
            id: 'budget_alert',
            type: 'budgetAlert',
            title: 'Budget Alert',
            description: 'Alert when spending reaches 80% of budget',
            isEnabled: true,
            threshold: 0.8,
          ),
          NotificationRule(
            id: 'low_balance',
            type: 'lowBalance',
            title: 'Low Balance Alert',
            description: 'Alert when account balance is low',
            isEnabled: true,
            threshold: 1000,
          ),
          NotificationRule(
            id: 'weekly_report',
            type: 'weeklyReport',
            title: 'Weekly Report',
            description: 'Send weekly spending summary every Sunday',
            isEnabled: true,
          ),
        ];
      }

      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList
          .map((json) => NotificationRule.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  @override
  Future<void> deleteRule(String ruleId) async {
    try {
      final rules = await getRules();
      rules.removeWhere((r) => r.id == ruleId);
      await _saveRules(rules);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> updateRuleStatus(String ruleId, bool isEnabled) async {
    try {
      final rules = await getRules();
      for (var i = 0; i < rules.length; i++) {
        if (rules[i].id == ruleId) {
          rules[i] = rules[i].copyWith(isEnabled: isEnabled);
          break;
        }
      }
      await _saveRules(rules);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _saveNotifications(List<AppNotification> notifications) async {
    final jsonList = notifications.map((n) => n.toJson()).toList();
    await prefs.setString(_notificationsKey, jsonEncode(jsonList));
  }

  Future<void> _saveRules(List<NotificationRule> rules) async {
    final jsonList = rules.map((r) => r.toJson()).toList();
    await prefs.setString(_rulesKey, jsonEncode(jsonList));
  }
}
