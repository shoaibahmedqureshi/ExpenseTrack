import '../../domain/entities/family_invitation.dart';

class FamilyInvitationModel extends FamilyInvitation {
  FamilyInvitationModel({
    required super.id,
    required super.familyGroupId,
    required super.familyGroupName,
    required super.invitedEmail,
    required super.invitedById,
    required super.invitedByEmail,
    required super.role,
    required super.status,
    required super.createdAt,
    required super.expiresAt,
  });

  factory FamilyInvitationModel.fromJson(Map<String, dynamic> json) {
    final statusStr = json['status'] as String? ?? 'pending';
    final status = InvitationStatus.values.firstWhere(
      (s) => s.name == statusStr,
      orElse: () => InvitationStatus.pending,
    );

    return FamilyInvitationModel(
      id: json['id'].toString(),
      familyGroupId: json['family_id'].toString(),
      familyGroupName: json['family_group_name'] as String? ?? '',
      invitedEmail: json['invited_email'] as String,
      invitedById: json['invited_by'] as String? ?? '',
      invitedByEmail: json['invited_by_email'] as String? ?? '',
      role: json['role'] as String? ?? 'member',
      status: status,
      createdAt: DateTime.parse(json['created_at'] as String),
      expiresAt: DateTime.parse(json['expires_at'] as String),
    );
  }

  factory FamilyInvitationModel.fromEntity(FamilyInvitation entity) {
    return FamilyInvitationModel(
      id: entity.id,
      familyGroupId: entity.familyGroupId,
      familyGroupName: entity.familyGroupName,
      invitedEmail: entity.invitedEmail,
      invitedById: entity.invitedById,
      invitedByEmail: entity.invitedByEmail,
      role: entity.role,
      status: entity.status,
      createdAt: entity.createdAt,
      expiresAt: entity.expiresAt,
    );
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'family_id': int.tryParse(familyGroupId) ?? 0,
      'invited_email': invitedEmail,
      'invited_by': invitedById,
      'role': role,
    };
  }

  Map<String, dynamic> toUpdateJson() {
    return {
      'status': status.name,
    };
  }
}
