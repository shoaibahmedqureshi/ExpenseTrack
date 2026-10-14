/// Whether a family currently works, as decided by the server: a family is tied to its admin's MAX plan.
class FamilyAccess {
  const FamilyAccess({required this.active, required this.isOwner, this.adminMaxExpiresAt});

  factory FamilyAccess.fromJson(Map<String, dynamic> json) => FamilyAccess(
        active: json['active'] == true,
        isOwner: json['is_owner'] == true,
        adminMaxExpiresAt: DateTime.tryParse('${json['admin_max_expires_at'] ?? ''}'),
      );

  final bool active;
  final bool isOwner;

  /// When the admin's MAX runs out, if the server knows.
  final DateTime? adminMaxExpiresAt;
}
