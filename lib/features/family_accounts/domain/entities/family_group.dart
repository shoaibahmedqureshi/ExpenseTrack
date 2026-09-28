class FamilyGroup {
  final String id;
  final String creatorId;
  final String name;
  final String? description;
  final String? avatarUrl;
  final int memberCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  FamilyGroup({
    required this.id,
    required this.creatorId,
    required this.name,
    this.description,
    this.avatarUrl,
    required this.memberCount,
    required this.createdAt,
    required this.updatedAt,
  });

  FamilyGroup copyWith({
    String? id,
    String? creatorId,
    String? name,
    String? description,
    String? avatarUrl,
    int? memberCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FamilyGroup(
      id: id ?? this.id,
      creatorId: creatorId ?? this.creatorId,
      name: name ?? this.name,
      description: description ?? this.description,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      memberCount: memberCount ?? this.memberCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'creator_id': creatorId,
      'name': name,
      'description': description,
      'avatar_url': avatarUrl,
      'member_count': memberCount,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory FamilyGroup.fromJson(Map<String, dynamic> json) {
    return FamilyGroup(
      id: json['id'] as String,
      creatorId: json['creator_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      memberCount: json['member_count'] as int? ?? 1,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}
