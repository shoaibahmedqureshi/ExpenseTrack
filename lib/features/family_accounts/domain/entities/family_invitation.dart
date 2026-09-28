enum InvitationStatus { pending, accepted, rejected, expired }

class FamilyInvitation {
  final String id;
  final String familyGroupId;
  final String familyGroupName;
  final String invitedEmail;
  final String invitedById;
  final String invitedByEmail;
  final String role;
  final InvitationStatus status;
  final DateTime createdAt;
  final DateTime expiresAt;

  FamilyInvitation({
    required this.id,
    required this.familyGroupId,
    required this.familyGroupName,
    required this.invitedEmail,
    required this.invitedById,
    required this.invitedByEmail,
    required this.role,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isAcceptable => status == InvitationStatus.pending && !isExpired;

  FamilyInvitation copyWith({
    String? id,
    String? familyGroupId,
    String? familyGroupName,
    String? invitedEmail,
    String? invitedById,
    String? invitedByEmail,
    String? role,
    InvitationStatus? status,
    DateTime? createdAt,
    DateTime? expiresAt,
  }) {
    return FamilyInvitation(
      id: id ?? this.id,
      familyGroupId: familyGroupId ?? this.familyGroupId,
      familyGroupName: familyGroupName ?? this.familyGroupName,
      invitedEmail: invitedEmail ?? this.invitedEmail,
      invitedById: invitedById ?? this.invitedById,
      invitedByEmail: invitedByEmail ?? this.invitedByEmail,
      role: role ?? this.role,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'family_group_id': familyGroupId,
      'family_group_name': familyGroupName,
      'invited_email': invitedEmail,
      'invited_by_id': invitedById,
      'invited_by_email': invitedByEmail,
      'role': role,
      'status': status.name,
      'created_at': createdAt.toIso8601String(),
      'expires_at': expiresAt.toIso8601String(),
    };
  }

  factory FamilyInvitation.fromJson(Map<String, dynamic> json) {
    final statusStr = json['status'] as String? ?? 'pending';
    final status = InvitationStatus.values.firstWhere(
      (s) => s.name == statusStr,
      orElse: () => InvitationStatus.pending,
    );

    return FamilyInvitation(
      id: json['id'] as String,
      familyGroupId: json['family_group_id'] as String,
      familyGroupName: json['family_group_name'] as String? ?? '',
      invitedEmail: json['invited_email'] as String,
      invitedById: json['invited_by_id'] as String,
      invitedByEmail: json['invited_by_email'] as String? ?? '',
      role: json['role'] as String? ?? 'member',
      status: status,
      createdAt: DateTime.parse(json['created_at'] as String),
      expiresAt: DateTime.parse(json['expires_at'] as String),
    );
  }
}
