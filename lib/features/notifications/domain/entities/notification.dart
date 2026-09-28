class AppNotification {
  final String id;
  final String type; // budgetAlert, lowBalance, recurringReminder, goalReached, weeklyReport
  final String title;
  final String message;
  final DateTime createdAt;
  final bool isRead;
  final Map<String, dynamic>? metadata;

  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.createdAt,
    this.isRead = false,
    this.metadata,
  });

  AppNotification copyWith({
    String? id,
    String? type,
    String? title,
    String? message,
    DateTime? createdAt,
    bool? isRead,
    Map<String, dynamic>? metadata,
  }) {
    return AppNotification(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'title': title,
      'message': message,
      'createdAt': createdAt.toIso8601String(),
      'isRead': isRead,
      'metadata': metadata,
    };
  }

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      type: json['type'] as String,
      title: json['title'] as String,
      message: json['message'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      isRead: json['isRead'] as bool? ?? false,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}

class NotificationRule {
  final String id;
  final String type; // budgetAlert, lowBalance, weeklyReport, etc.
  final String title;
  final String description;
  final bool isEnabled;
  final double? threshold; // For threshold-based rules
  final DateTime? createdAt;

  NotificationRule({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.isEnabled,
    this.threshold,
    this.createdAt,
  });

  NotificationRule copyWith({
    String? id,
    String? type,
    String? title,
    String? description,
    bool? isEnabled,
    double? threshold,
    DateTime? createdAt,
  }) {
    return NotificationRule(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      description: description ?? this.description,
      isEnabled: isEnabled ?? this.isEnabled,
      threshold: threshold ?? this.threshold,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'title': title,
      'description': description,
      'isEnabled': isEnabled,
      'threshold': threshold,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  factory NotificationRule.fromJson(Map<String, dynamic> json) {
    return NotificationRule(
      id: json['id'] as String,
      type: json['type'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      isEnabled: json['isEnabled'] as bool? ?? true,
      threshold: (json['threshold'] as num?)?.toDouble(),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
    );
  }
}
