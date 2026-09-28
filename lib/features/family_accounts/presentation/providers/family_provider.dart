import 'package:flutter/material.dart';
import '../../domain/entities/family_group.dart';
import '../../domain/entities/family_member.dart';
import '../../domain/entities/family_invitation.dart';
import '../../domain/repositories/family_repository.dart';

class FamilyProvider extends ChangeNotifier {
  final FamilyRepository repository;
  final String Function() getCurrentUserId;

  FamilyProvider({
    required this.repository,
    required this.getCurrentUserId,
  });

  FamilyGroup? _currentFamily;
  List<FamilyGroup> _userFamilies = [];
  List<FamilyMember> _familyMembers = [];
  List<FamilyInvitation> _pendingInvitations = [];
  bool _isLoading = false;
  String? _error;

  // Getters
  FamilyGroup? get currentFamily => _currentFamily;
  List<FamilyGroup> get userFamilies => _userFamilies;
  List<FamilyMember> get familyMembers => _familyMembers;
  List<FamilyInvitation> get pendingInvitations => _pendingInvitations;
  bool get isLoading => _isLoading;
  String? get error => _error;

  bool get hasFamily => _currentFamily != null;
  bool get isFamilyAdmin {
    if (_currentFamily == null) return false;
    final currentMember = _familyMembers.firstWhere(
      (m) => m.userId == getCurrentUserId(),
      orElse: () => FamilyMember(
        id: '',
        familyGroupId: '',
        userId: '',
        email: '',
        role: FamilyMemberRole.viewer,
        joinedAt: DateTime.now(),
      ),
    );
    return currentMember.isAdmin;
  }

  /// Create a new family group
  Future<bool> createFamily({
    required String name,
    String? description,
    String? avatarUrl,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final userId = getCurrentUserId();
      final family = await repository.createFamilyGroup(
        userId: userId,
        name: name,
        description: description,
        avatarUrl: avatarUrl,
      );
      _currentFamily = family;
      _userFamilies.add(family);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Load user's families
  Future<void> loadUserFamilies() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final userId = getCurrentUserId();
      _userFamilies = await repository.getUserFamilyGroups(userId);
      if (_userFamilies.isNotEmpty) {
        _currentFamily = _userFamilies.first;
        await loadFamilyMembers(_currentFamily!.id);
      }
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Switch to a different family
  Future<void> switchFamily(String familyGroupId) async {
    try {
      final family = await repository.getFamilyGroup(familyGroupId);
      if (family != null) {
        _currentFamily = family;
        await loadFamilyMembers(familyGroupId);
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Load family members for current family
  Future<void> loadFamilyMembers(String familyGroupId) async {
    try {
      _familyMembers = await repository.getFamilyMembers(familyGroupId);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Update family group
  Future<bool> updateFamily(FamilyGroup family) async {
    try {
      await repository.updateFamilyGroup(family);
      _currentFamily = family;
      final index = _userFamilies.indexWhere((f) => f.id == family.id);
      if (index >= 0) {
        _userFamilies[index] = family;
      }
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Delete family group
  Future<bool> deleteFamily(String familyGroupId) async {
    try {
      await repository.deleteFamilyGroup(familyGroupId);
      _userFamilies.removeWhere((f) => f.id == familyGroupId);
      if (_currentFamily?.id == familyGroupId) {
        _currentFamily = _userFamilies.isNotEmpty ? _userFamilies.first : null;
        if (_currentFamily != null) {
          await loadFamilyMembers(_currentFamily!.id);
        }
      }
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Invite member to family
  Future<bool> inviteMember({
    required String familyGroupId,
    required String email,
    required String role,
  }) async {
    try {
      final userId = getCurrentUserId();
      await repository.sendInvitation(
        familyGroupId: familyGroupId,
        invitedEmail: email,
        invitedById: userId,
        role: role,
      );
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Load pending invitations for current user (requires email parameter)
  Future<void> loadPendingInvitations(String userEmail) async {
    try {
      _pendingInvitations = await repository.getPendingInvitations(userEmail);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Accept family invitation
  Future<bool> acceptInvitation(String invitationId) async {
    try {
      final userId = getCurrentUserId();
      await repository.acceptInvitation(invitationId, userId);
      _pendingInvitations.removeWhere((i) => i.id == invitationId);
      await loadUserFamilies();
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Reject family invitation
  Future<bool> rejectInvitation(String invitationId) async {
    try {
      await repository.rejectInvitation(invitationId);
      _pendingInvitations.removeWhere((i) => i.id == invitationId);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Change member role
  Future<bool> changeMemberRole(String userId, String newRole) async {
    try {
      if (_currentFamily == null) return false;
      await repository.updateMemberRole(
        _currentFamily!.id,
        userId,
        newRole,
      );
      await loadFamilyMembers(_currentFamily!.id);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Remove family member
  Future<bool> removeMember(String userId) async {
    try {
      if (_currentFamily == null) return false;
      await repository.removeFamilyMember(_currentFamily!.id, userId);
      _familyMembers.removeWhere((m) => m.userId == userId);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Clear all family data
  void clear() {
    _currentFamily = null;
    _userFamilies = [];
    _familyMembers = [];
    _pendingInvitations = [];
    _isLoading = false;
    _error = null;
    notifyListeners();
  }
}
