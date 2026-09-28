import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/family_group.dart';
import '../../domain/entities/family_member.dart';
import '../../domain/entities/family_invitation.dart';
import '../../domain/repositories/family_repository.dart';
import '../models/family_group_model.dart';
import '../models/family_member_model.dart';
import '../models/family_invitation_model.dart';

class FamilyRepositoryImpl implements FamilyRepository {
  final SupabaseClient supabase;

  FamilyRepositoryImpl({required this.supabase});

  String get _userId => supabase.auth.currentUser!.id;

  // ── Family Group Operations ──────────────────────────────────────

  @override
  Future<FamilyGroup> createFamilyGroup({
    required String userId,
    required String name,
    String? description,
    String? avatarUrl,
  }) async {
    final response = await supabase
        .from('family_groups')
        .insert({
          'user_id': userId,
          'name': name,
          'description': description,
          'avatar_url': avatarUrl,
        })
        .select()
        .single();

    final model = FamilyGroupModel.fromJson(response);

    // Auto-add creator as admin
    await addFamilyMember(
      familyGroupId: model.id,
      userId: userId,
      email: supabase.auth.currentUser!.email!,
      role: 'admin',
    );

    return model;
  }

  @override
  Future<FamilyGroup?> getFamilyGroup(String familyGroupId) async {
    try {
      final response = await supabase
          .from('family_groups')
          .select()
          .eq('id', int.parse(familyGroupId))
          .single();

      return FamilyGroupModel.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<List<FamilyGroup>> getUserFamilyGroups(String userId) async {
    try {
      final response = await supabase
          .from('family_groups')
          .select()
          .eq('user_id', userId);

      return (response as List)
          .map((json) => FamilyGroupModel.fromJson(json))
          .toList();
    } catch (e) {
      return [];
    }
  }

  @override
  Future<void> updateFamilyGroup(FamilyGroup familyGroup) async {
    final model = FamilyGroupModel.fromEntity(familyGroup);
    await supabase
        .from('family_groups')
        .update(model.toUpdateJson())
        .eq('id', int.parse(familyGroup.id));
  }

  @override
  Future<void> deleteFamilyGroup(String familyGroupId) async {
    await supabase
        .from('family_groups')
        .delete()
        .eq('id', int.parse(familyGroupId));
  }

  // ── Family Member Operations ─────────────────────────────────────

  @override
  Future<FamilyMember> addFamilyMember({
    required String familyGroupId,
    required String userId,
    required String email,
    required String role,
  }) async {
    final response = await supabase
        .from('family_members')
        .insert({
          'family_id': int.parse(familyGroupId),
          'user_id': userId,
          'email': email,
          'role': role,
        })
        .select()
        .single();

    return FamilyMemberModel.fromJson(response);
  }

  @override
  Future<List<FamilyMember>> getFamilyMembers(String familyGroupId) async {
    try {
      final response = await supabase
          .from('family_members')
          .select()
          .eq('family_id', int.parse(familyGroupId));

      return (response as List)
          .map((json) => FamilyMemberModel.fromJson(json))
          .toList();
    } catch (e) {
      return [];
    }
  }

  @override
  Future<FamilyMember?> getFamilyMember(
    String familyGroupId,
    String userId,
  ) async {
    try {
      final response = await supabase
          .from('family_members')
          .select()
          .eq('family_id', int.parse(familyGroupId))
          .eq('user_id', userId)
          .single();

      return FamilyMemberModel.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> updateMemberRole(
    String familyGroupId,
    String userId,
    String newRole,
  ) async {
    await supabase
        .from('family_members')
        .update({'role': newRole})
        .eq('family_id', int.parse(familyGroupId))
        .eq('user_id', userId);
  }

  @override
  Future<void> removeFamilyMember(String familyGroupId, String userId) async {
    await supabase
        .from('family_members')
        .delete()
        .eq('family_id', int.parse(familyGroupId))
        .eq('user_id', userId);
  }

  // ── Family Invitation Operations ─────────────────────────────────

  @override
  Future<FamilyInvitation> sendInvitation({
    required String familyGroupId,
    required String invitedEmail,
    required String invitedById,
    required String role,
  }) async {
    final response = await supabase
        .from('family_invitations')
        .insert({
          'family_id': int.parse(familyGroupId),
          'invited_email': invitedEmail,
          'invited_by': invitedById,
          'role': role,
        })
        .select()
        .single();

    return FamilyInvitationModel.fromJson(response);
  }

  @override
  Future<List<FamilyInvitation>> getPendingInvitations(String email) async {
    try {
      final response = await supabase
          .from('family_invitations')
          .select()
          .eq('invited_email', email)
          .eq('status', 'pending');

      return (response as List)
          .map((json) => FamilyInvitationModel.fromJson(json))
          .toList();
    } catch (e) {
      return [];
    }
  }

  @override
  Future<FamilyInvitation?> getInvitation(String invitationId) async {
    try {
      final response = await supabase
          .from('family_invitations')
          .select()
          .eq('id', int.parse(invitationId))
          .single();

      return FamilyInvitationModel.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> acceptInvitation(String invitationId, String userId) async {
    final invitation = await getInvitation(invitationId);
    if (invitation == null) return;

    // Update invitation status
    await supabase
        .from('family_invitations')
        .update({'status': 'accepted'})
        .eq('id', int.parse(invitationId));

    // Add user as family member
    await addFamilyMember(
      familyGroupId: invitation.familyGroupId,
      userId: userId,
      email: invitation.invitedEmail,
      role: invitation.role,
    );
  }

  @override
  Future<void> rejectInvitation(String invitationId) async {
    await supabase
        .from('family_invitations')
        .update({'status': 'rejected'})
        .eq('id', int.parse(invitationId));
  }

  @override
  Future<void> cancelInvitation(String invitationId) async {
    await supabase
        .from('family_invitations')
        .update({'status': 'expired'})
        .eq('id', int.parse(invitationId));
  }

  // ── Query Operations ─────────────────────────────────────────────

  @override
  Future<bool> isUserInFamily(String userId, String familyGroupId) async {
    try {
      final response = await supabase
          .from('family_members')
          .select('id')
          .eq('family_id', int.parse(familyGroupId))
          .eq('user_id', userId);

      return (response as List).isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<String?> getUserFamilyRole(String userId, String familyGroupId) async {
    try {
      final response = await supabase
          .from('family_members')
          .select('role')
          .eq('family_id', int.parse(familyGroupId))
          .eq('user_id', userId)
          .single();

      return response['role'] as String?;
    } catch (e) {
      return null;
    }
  }

  @override
  Future<int> getFamilyMemberCount(String familyGroupId) async {
    try {
      final response = await supabase
          .from('family_members')
          .select('id')
          .eq('family_id', int.parse(familyGroupId));

      return (response as List).length;
    } catch (e) {
      return 0;
    }
  }
}
