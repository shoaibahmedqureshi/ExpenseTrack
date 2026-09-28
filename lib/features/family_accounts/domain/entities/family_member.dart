enum FamilyMemberRole { admin, member, viewer }

class FamilyMember {
  final String id;
  final String familyGroupId;
  final String userId;
  final String email;
  final String? name;
  final String? avatarUrl;
  final FamilyMemberRole role;
  final DateTime joinedAt;

  FamilyMember({
    required this.id,
    required this.familyGroupId,
    required this.userId,
    required this.email,
    this.name,
    this.avatarUrl,
    required this.role,
    required this.joinedAt,
  });

  FamilyMember copyWith({
    String? id,
    String? familyGroupId,
    String? userId,
    String? email,
    String? name,
    String? avatarUrl,
    FamilyMemberRole? role,
    DateTime? joinedAt,
  }) {
    return FamilyMember(
      id: id ?? this.id,
      familyGroupId: familyGroupId ?? this.familyGroupId,
      userId: userId ?? this.userId,
      email: email ?? this.email,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      role: role ?? this.role,
      joinedAt: joinedAt ?? this.joinedAt,
    );
  }

  bool get isAdmin => role == FamilyMemberRole.admin;
  bool get canEdit => isAdmin || role == FamilyMemberRole.member;
  bool get canViewOnly => role == FamilyMemberRole.viewer;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'family_group_id': familyGroupId,
      'user_id': userId,
      'email': email,
      'name': name,
      'avatar_url': avatarUrl,
      'role': role.name,
      'joined_at': joinedAt.toIso8601String(),
    };
  }

  factory FamilyMember.fromJson(Map<String, dynamic> json) {
    final roleStr = json['role'] as String? ?? 'member';
    final role = FamilyMemberRole.values.firstWhere(
      (r) => r.name == roleStr,
      orElse: () => FamilyMemberRole.member,
    );

    return FamilyMember(
      id: json['id'] as String,
      familyGroupId: json['family_group_id'] as String,
      userId: json['user_id'] as String,
      email: json['email'] as String,
      name: json['name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      role: role,
      joinedAt: DateTime.parse(json['joined_at'] as String),
    );
  }
}
