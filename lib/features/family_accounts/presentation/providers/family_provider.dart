import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;
import '../../domain/entities/family_access.dart';
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
    SharedPreferences? prefs,
    this.loadAccess,
  }) : _prefs = prefs;

  /// Asks the server whether a family currently works. Null (as in tests) means every family is treated as active.
  final Future<FamilyAccess> Function(String familyId)? loadAccess;
  FamilyAccess? _access;

  final SharedPreferences? _prefs;

  /// Whether the family list has been fetched since this provider started (or since sign-out).
  bool _loadedOnce = false;

  String get _hintKey => 'family_hint_${getCurrentUserId()}';

  String _msg(Object e) {
    if (e is PostgrestException) return e.message;
    return e.toString().replaceFirst('Exception: ', '');
  }

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

  /// False while the admin's MAX has lapsed. Unknown (not loaded, or the check failed) counts as active: the server
  /// enforces the rule, this only decides what to show.
  bool get isFamilyActive => _access?.active ?? true;

  /// A member (not the admin) of a family whose admin's MAX has lapsed: the family shows as paused for them.
  bool get isFamilyLocked => hasFamily && _access != null && !_access!.active && !_access!.isOwner;

  /// When the admin's MAX ends or ended, if known.
  DateTime? get adminMaxExpiresAt => _access?.adminMaxExpiresAt;

  Future<FamilyAccess?> _fetchAccess(String familyId) async {
    final load = loadAccess;
    if (load == null) return null;
    try {
      return await load(familyId);
    } catch (_) {
      return null;
    }
  }

  /// For deciding what to *show* (tabs, upsells) before the family has loaded: the last answer for this user,
  /// remembered on the device, instead of "no family" for the first second or two. Screens that need the family
  /// itself keep using [hasFamily] and [currentFamily], which are only set once it is really loaded.
  bool get likelyHasFamily {
    if (_loadedOnce) return hasFamily;
    final id = getCurrentUserId();
    if (id.isEmpty) return hasFamily;
    return _prefs?.getBool(_hintKey) ?? hasFamily;
  }

  bool get isFamilyAdmin {
    if (_currentFamily == null) return false;
    try {
      final currentMember = _familyMembers.firstWhere(
        (m) => m.userId == getCurrentUserId(),
      );
      return currentMember.isAdmin;
    } catch (e) {
      return false;
    }
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
      _error = _msg(e);
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
        _access = await _fetchAccess(_currentFamily!.id);
        await loadFamilyMembers(_currentFamily!.id);
      } else {
        // Left or removed from the last family: do not keep showing the old one.
        _currentFamily = null;
        _familyMembers = [];
        _access = null;
      }
      _loadedOnce = true;
      try {
        await _prefs?.setBool(_hintKey, _userFamilies.isNotEmpty);
      } catch (_) {
        // The hint is only a convenience.
      }
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = _msg(e);
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
        _access = await _fetchAccess(familyGroupId);
        await loadFamilyMembers(familyGroupId);
        notifyListeners();
      }
    } catch (e) {
      _error = _msg(e);
      notifyListeners();
    }
  }

  /// Load family members for current family
  Future<void> loadFamilyMembers(String familyGroupId) async {
    try {
      _familyMembers = await repository.getFamilyMembers(familyGroupId);
      notifyListeners();
    } catch (e) {
      _error = _msg(e);
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
      _error = _msg(e);
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
      _error = _msg(e);
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
      _error = _msg(e);
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
      _error = _msg(e);
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
      _error = _msg(e);
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
      _error = _msg(e);
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
      _error = _msg(e);
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
      _error = _msg(e);
      notifyListeners();
      return false;
    }
  }

  /// Leave the current family (non-admin members only; enforced by RLS too).
  Future<bool> leaveFamily() async {
    final family = _currentFamily;
    if (family == null) return false;
    try {
      await repository.removeFamilyMember(family.id, getCurrentUserId());
      _userFamilies.removeWhere((f) => f.id == family.id);
      _currentFamily = _userFamilies.isNotEmpty ? _userFamilies.first : null;
      _familyMembers = [];
      if (_currentFamily != null) {
        await loadFamilyMembers(_currentFamily!.id);
      }
      notifyListeners();
      return true;
    } catch (e) {
      _error = _msg(e);
      notifyListeners();
      return false;
    }
  }

  /// Clear all family data
  void clear() {
    _loadedOnce = false;
    _currentFamily = null;
    _access = null;
    _userFamilies = [];
    _familyMembers = [];
    _pendingInvitations = [];
    _isLoading = false;
    _error = null;
    notifyListeners();
  }
}
