import 'package:flutter_test/flutter_test.dart';
import 'package:outlay/features/family_accounts/domain/entities/family_group.dart';
import 'package:outlay/features/family_accounts/domain/entities/family_member.dart';
import 'package:outlay/features/family_accounts/domain/repositories/family_repository.dart';
import 'package:outlay/features/family_accounts/presentation/providers/family_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Repo implements FamilyRepository {
  List<FamilyGroup> families = [];
  Object? error;

  @override
  Future<List<FamilyGroup>> getUserFamilyGroups(String userId) async {
    if (error != null) throw error!;
    return families;
  }

  @override
  Future<List<FamilyMember>> getFamilyMembers(String familyGroupId) async => [];

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

FamilyGroup _group() => FamilyGroup(
    id: '1',
    creatorId: 'x',
    name: 'Home',
    memberCount: 2,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026));

Future<SharedPreferences> _prefs(
    [Map<String, Object> initial = const {}]) async {
  SharedPreferences.setMockInitialValues(initial);
  return SharedPreferences.getInstance();
}

FamilyProvider _provider(_Repo repo, SharedPreferences prefs,
        {String uid = 'u1'}) =>
    FamilyProvider(repository: repo, getCurrentUserId: () => uid, prefs: prefs);

void main() {
  test('before the first load it uses the last answer remembered for this user',
      () async {
    final p = _provider(_Repo(), await _prefs({'family_hint_u1': true}));
    expect(p.hasFamily, isFalse, reason: 'the real family is not loaded yet');
    expect(p.likelyHasFamily, isTrue);
  });

  test('with nothing remembered it says no family', () async {
    final p = _provider(_Repo(), await _prefs());
    expect(p.likelyHasFamily, isFalse);
  });

  test('the hint belongs to one user, not to whoever signs in next', () async {
    final prefs = await _prefs({'family_hint_u1': true});
    expect(_provider(_Repo(), prefs, uid: 'u2').likelyHasFamily, isFalse);
    expect(_provider(_Repo(), prefs, uid: '').likelyHasFamily, isFalse);
  });

  test(
      'a successful load replaces the hint with the real answer and remembers it',
      () async {
    final prefs = await _prefs({'family_hint_u1': true});
    final repo = _Repo(); // the user has since left their family
    final p = _provider(repo, prefs);
    await p.loadUserFamilies();
    expect(p.likelyHasFamily, isFalse);
    expect(prefs.getBool('family_hint_u1'), isFalse);

    repo.families = [_group()];
    await p.loadUserFamilies();
    expect(p.likelyHasFamily, isTrue);
    expect(p.hasFamily, isTrue);
    expect(prefs.getBool('family_hint_u1'), isTrue);
  });

  test('a failed load keeps showing the remembered answer', () async {
    final prefs = await _prefs({'family_hint_u1': true});
    final p = _provider(_Repo()..error = Exception('offline'), prefs);
    await p.loadUserFamilies();
    expect(p.likelyHasFamily, isTrue);
    expect(prefs.getBool('family_hint_u1'), isTrue,
        reason: 'an error must not erase it');
  });

  test('screens that need the family itself are not fooled by the hint',
      () async {
    final p = _provider(_Repo(), await _prefs({'family_hint_u1': true}));
    expect(p.currentFamily, isNull);
    expect(p.hasFamily, isFalse);
  });

  test('leaving the last family clears the old one instead of keeping it',
      () async {
    final repo = _Repo()..families = [_group()];
    final p = _provider(repo, await _prefs());
    await p.loadUserFamilies();
    expect(p.hasFamily, isTrue);
    repo.families = [];
    await p.loadUserFamilies();
    expect(p.hasFamily, isFalse);
    expect(p.currentFamily, isNull);
  });

  test('without storage it behaves as before', () async {
    final p = FamilyProvider(
        repository: _Repo()..families = [_group()],
        getCurrentUserId: () => 'u1');
    expect(p.likelyHasFamily, isFalse);
    await p.loadUserFamilies();
    expect(p.likelyHasFamily, isTrue);
  });

  test('signing out forgets that the family was loaded', () async {
    final prefs = await _prefs();
    final p = _provider(_Repo()..families = [_group()], prefs);
    await p.loadUserFamilies();
    p.clear();
    expect(p.hasFamily, isFalse);
    expect(p.likelyHasFamily, isTrue,
        reason: 'back to the remembered answer until the next load');
  });
}
