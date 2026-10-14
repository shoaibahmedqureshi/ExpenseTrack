import 'package:flutter_test/flutter_test.dart';
import 'package:outlay/features/family_accounts/domain/entities/family_access.dart';
import 'package:outlay/features/family_accounts/domain/entities/family_group.dart';
import 'package:outlay/features/family_accounts/domain/entities/family_member.dart';
import 'package:outlay/features/family_accounts/domain/repositories/family_repository.dart';
import 'package:outlay/features/family_accounts/presentation/providers/family_provider.dart';

class _Repo implements FamilyRepository {
  List<FamilyGroup> families = [];

  @override
  Future<List<FamilyGroup>> getUserFamilyGroups(String userId) async => families;

  @override
  Future<List<FamilyMember>> getFamilyMembers(String familyGroupId) async => [];

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

FamilyGroup _group() => FamilyGroup(
    id: '7',
    creatorId: 'admin',
    name: 'Home',
    memberCount: 3,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026));

FamilyProvider _provider(Future<FamilyAccess> Function(String)? loader) =>
    FamilyProvider(repository: _Repo()..families = [_group()], getCurrentUserId: () => 'u1', loadAccess: loader);

void main() {
  test('parses the server answer, including a missing expiry', () {
    final a = FamilyAccess.fromJson({'active': false, 'is_owner': true, 'admin_max_expires_at': '2026-11-01T00:00:00+00:00'});
    expect(a.active, isFalse);
    expect(a.isOwner, isTrue);
    expect(a.adminMaxExpiresAt, DateTime.utc(2026, 11, 1));
    final b = FamilyAccess.fromJson({'exists': true, 'active': true, 'is_owner': false, 'admin_max_expires_at': null});
    expect(b.active, isTrue);
    expect(b.adminMaxExpiresAt, isNull);
  });

  test('an active family is not locked', () async {
    final p = _provider((_) async => const FamilyAccess(active: true, isOwner: false));
    await p.loadUserFamilies();
    expect(p.isFamilyActive, isTrue);
    expect(p.isFamilyLocked, isFalse);
  });

  test('a member of a family whose admin lapsed is locked', () async {
    final asked = <String>[];
    final p = _provider((id) async {
      asked.add(id);
      return FamilyAccess(active: false, isOwner: false, adminMaxExpiresAt: DateTime(2026, 11, 1));
    });
    await p.loadUserFamilies();
    expect(asked, ['7']);
    expect(p.isFamilyActive, isFalse);
    expect(p.isFamilyLocked, isTrue);
    expect(p.adminMaxExpiresAt, DateTime(2026, 11, 1));
  });

  test('the admin of a lapsed family is not locked out of their own family', () async {
    final p = _provider((_) async => const FamilyAccess(active: false, isOwner: true));
    await p.loadUserFamilies();
    expect(p.isFamilyActive, isFalse, reason: 'inviting stays blocked');
    expect(p.isFamilyLocked, isFalse, reason: 'but they can still see and manage the family');
  });

  test('with no loader, or a failing one, the family counts as active', () async {
    final none = _provider(null);
    await none.loadUserFamilies();
    expect(none.isFamilyLocked, isFalse);
    expect(none.isFamilyActive, isTrue);

    final broken = _provider((_) async => throw Exception('offline'));
    await broken.loadUserFamilies();
    expect(broken.hasFamily, isTrue);
    expect(broken.isFamilyLocked, isFalse);
  });

  test('leaving every family clears the lock, and so does signing out', () async {
    final repo = _Repo()..families = [_group()];
    final p = FamilyProvider(
        repository: repo,
        getCurrentUserId: () => 'u1',
        loadAccess: (_) async => const FamilyAccess(active: false, isOwner: false));
    await p.loadUserFamilies();
    expect(p.isFamilyLocked, isTrue);

    repo.families = [];
    await p.loadUserFamilies();
    expect(p.isFamilyLocked, isFalse);

    repo.families = [_group()];
    await p.loadUserFamilies();
    expect(p.isFamilyLocked, isTrue);
    p.clear();
    expect(p.isFamilyLocked, isFalse);
  });
}
