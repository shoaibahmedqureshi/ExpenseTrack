import '../../domain/entities/family_group.dart';

class FamilyGroupModel extends FamilyGroup {
  FamilyGroupModel({
    required super.id,
    required super.creatorId,
    required super.name,
    super.description,
    super.avatarUrl,
    required super.memberCount,
    required super.createdAt,
    required super.updatedAt,
  });

  factory FamilyGroupModel.fromJson(Map<String, dynamic> json) {
    return FamilyGroupModel(
      id: json['id'].toString(),
      creatorId: json['user_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      memberCount: json['member_count'] as int? ?? 1,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  factory FamilyGroupModel.fromEntity(FamilyGroup entity) {
    return FamilyGroupModel(
      id: entity.id,
      creatorId: entity.creatorId,
      name: entity.name,
      description: entity.description,
      avatarUrl: entity.avatarUrl,
      memberCount: entity.memberCount,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'user_id': creatorId,
      'name': name,
      'description': description,
      'avatar_url': avatarUrl,
    };
  }

  Map<String, dynamic> toUpdateJson() {
    return {
      'name': name,
      'description': description,
      'avatar_url': avatarUrl,
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
