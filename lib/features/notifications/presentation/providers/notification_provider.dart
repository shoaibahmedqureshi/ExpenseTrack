import 'package:flutter/material.dart';

import '../../domain/entities/notification.dart';
import '../../domain/repositories/notification_repository.dart';

class NotificationProvider extends ChangeNotifier {
  final NotificationRepository repository;

  List<AppNotification> _notifications = [];
  List<NotificationRule> _rules = [];
  bool _isLoading = false;
  String? _error;

  NotificationProvider({required this.repository});

  // Getters
  List<AppNotification> get notifications => _notifications;
  List<NotificationRule> get rules => _rules;
  bool get isLoading => _isLoading;
  String? get error => _error;

  int get unreadCount => _notifications.where((n) => !n.isRead).length;
  List<AppNotification> get unreadNotifications =>
      _notifications.where((n) => !n.isRead).toList();

  /// Load all notifications
  Future<void> loadNotifications() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _notifications = await repository.getNotifications();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load all notification rules
  Future<void> loadRules() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _rules = await repository.getRules();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      await repository.markAsRead(notificationId);
      await loadNotifications();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    try {
      await repository.markAllAsRead();
      await loadNotifications();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Delete a notification
  Future<void> deleteNotification(String notificationId) async {
    try {
      await repository.deleteNotification(notificationId);
      _notifications.removeWhere((n) => n.id == notificationId);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Update rule status (enable/disable)
  Future<void> updateRuleStatus(String ruleId, bool isEnabled) async {
    try {
      await repository.updateRuleStatus(ruleId, isEnabled);
      await loadRules();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Delete a rule
  Future<void> deleteRule(String ruleId) async {
    try {
      await repository.deleteRule(ruleId);
      await loadRules();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Add a new notification (for testing/manual triggers)
  void addNotification(AppNotification notification) {
    _notifications.insert(0, notification);
    notifyListeners();
  }

  /// Trigger budget alert if threshold reached
  void checkBudgetAlert(double spent, double budget) {
    final threshold = 0.8;
    final percentSpent = spent / budget;

    if (percentSpent >= threshold) {
      final rule = _rules.firstWhere(
        (r) => r.type == 'budgetAlert' && r.isEnabled,
        orElse: () => NotificationRule(
          id: '',
          type: '',
          title: '',
          description: '',
          isEnabled: false,
        ),
      );

      if (rule.isEnabled) {
        addNotification(
          AppNotification(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            type: 'budgetAlert',
            title: 'Budget Alert',
            message: 'You\'ve spent ${(percentSpent * 100).toStringAsFixed(1)}% of your budget',
            createdAt: DateTime.now(),
            metadata: {'spent': spent, 'budget': budget},
          ),
        );
      }
    }
  }

  /// Trigger low balance alert
  void checkLowBalance(double balance) {
    final rule = _rules.firstWhere(
      (r) => r.type == 'lowBalance' && r.isEnabled,
      orElse: () => NotificationRule(
        id: '',
        type: '',
        title: '',
        description: '',
        isEnabled: false,
      ),
    );

    if (rule.isEnabled && rule.threshold != null && balance < rule.threshold!) {
      addNotification(
        AppNotification(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          type: 'lowBalance',
          title: 'Low Balance Alert',
          message: 'Your account balance is low: ${balance.toStringAsFixed(2)}',
          createdAt: DateTime.now(),
          metadata: {'balance': balance},
        ),
      );
    }
  }

  /// Clear all notifications
  void clearAll() {
    _notifications.clear();
    notifyListeners();
  }
}
