import '../entities/family_group.dart';
import '../entities/family_member.dart';
import '../entities/family_invitation.dart';

abstract class FamilyRepository {
  // Family Group Operations
  Future<FamilyGroup> createFamilyGroup({
    required String userId,
    required String name,
    String? description,
    String? avatarUrl,
  });

  Future<FamilyGroup?> getFamilyGroup(String familyGroupId);
  Future<List<FamilyGroup>> getUserFamilyGroups(String userId);
  Future<void> updateFamilyGroup(FamilyGroup familyGroup);
  Future<void> deleteFamilyGroup(String familyGroupId);

  // Family Member Operations
  Future<FamilyMember> addFamilyMember({
    required String familyGroupId,
    required String userId,
    required String email,
    required String role,
  });

  Future<List<FamilyMember>> getFamilyMembers(String familyGroupId);
  Future<FamilyMember?> getFamilyMember(String familyGroupId, String userId);
  Future<void> updateMemberRole(
    String familyGroupId,
    String userId,
    String newRole,
  );
  Future<void> removeFamilyMember(String familyGroupId, String userId);

  // Family Invitation Operations
  Future<FamilyInvitation> sendInvitation({
    required String familyGroupId,
    required String invitedEmail,
    required String invitedById,
    required String role,
  });

  Future<List<FamilyInvitation>> getPendingInvitations(String email);
  Future<FamilyInvitation?> getInvitation(String invitationId);
  Future<void> acceptInvitation(String invitationId, String userId);
  Future<void> rejectInvitation(String invitationId);
  Future<void> cancelInvitation(String invitationId);

  // Query Operations
  Future<bool> isUserInFamily(String userId, String familyGroupId);
  Future<String?> getUserFamilyRole(String userId, String familyGroupId);
  Future<int> getFamilyMemberCount(String familyGroupId);
}
