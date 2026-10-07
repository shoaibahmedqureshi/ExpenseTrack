class InboxItem {
  const InboxItem({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.data,
    required this.createdAt,
    this.readAt,
  });

  final int id;
  final String type;
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final DateTime createdAt;
  final DateTime? readAt;

  bool get isRead => readAt != null;

  InboxItem markedRead() => InboxItem(
        id: id,
        type: type,
        title: title,
        body: body,
        data: data,
        createdAt: createdAt,
        readAt: readAt ?? DateTime.now(),
      );

  /// Where tapping this notification should take the user.
  String get target => switch (type) {
        'split_added' || 'payment_recorded' => 'splits',
        'family_invite' => 'invites',
        'member_joined' => 'family',
        'creator_application' => 'growth',
        _ => '',
      };

  factory InboxItem.fromJson(Map<String, dynamic> j) => InboxItem(
        id: j['id'] as int,
        type: j['type'] as String,
        title: j['title'] as String,
        body: j['body'] as String,
        data: Map<String, dynamic>.from((j['data'] as Map?) ?? const {}),
        createdAt: DateTime.parse(j['created_at'] as String).toLocal(),
        readAt: j['read_at'] == null ? null : DateTime.parse(j['read_at'] as String).toLocal(),
      );
}
