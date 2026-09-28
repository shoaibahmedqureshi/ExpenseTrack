import '../../domain/entities/family_member.dart';

class FamilyMemberModel extends FamilyMember {
  FamilyMemberModel({
    required super.id,
    required super.familyGroupId,
    required super.userId,
    required super.email,
    super.name,
    super.avatarUrl,
    required super.role,
    required super.joinedAt,
  });

  factory FamilyMemberModel.fromJson(Map<String, dynamic> json) {
    final roleStr = json['role'] as String? ?? 'member';
    final role = FamilyMemberRole.values.firstWhere(
      (r) => r.name == roleStr,
      orElse: () => FamilyMemberRole.member,
    );

    return FamilyMemberModel(
      id: json['id'].toString(),
      familyGroupId: json['family_id'].toString(),
      userId: json['user_id'] as String,
      email: json['email'] as String? ?? '',
      name: json['name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      role: role,
      joinedAt: DateTime.parse(json['joined_at'] as String),
    );
  }

  factory FamilyMemberModel.fromEntity(FamilyMember entity) {
    return FamilyMemberModel(
      id: entity.id,
      familyGroupId: entity.familyGroupId,
      userId: entity.userId,
      email: entity.email,
      name: entity.name,
      avatarUrl: entity.avatarUrl,
      role: entity.role,
      joinedAt: entity.joinedAt,
    );
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'family_id': int.tryParse(familyGroupId) ?? 0,
      'user_id': userId,
      'email': email,
      'name': name,
      'avatar_url': avatarUrl,
      'role': role.name,
    };
  }

  Map<String, dynamic> toUpdateJson() {
    return {
      'role': role.name,
    };
  }
}
