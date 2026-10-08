import 'package:flutter_test/flutter_test.dart';
import 'package:outlay/features/expense_split/domain/split_models.dart';
import 'package:outlay/features/expense_split/presentation/member_names.dart';
import 'package:outlay/features/split_groups/data/split_group_repository.dart';
import 'package:outlay/features/split_groups/domain/group_models.dart';
import 'package:outlay/features/split_groups/presentation/providers/split_group_provider.dart';

class _FakeRepo implements SplitGroupRepository {
  List<SplitGroup> groups = [];
  List<GroupInvitation> invitations = [];
  Map<int, List<LedgerMember>> memberLists = {};
  Object? failWith;
  final calls = <String>[];

  void _maybeFail() {
    if (failWith != null) throw failWith!;
  }

  @override
  Future<List<SplitGroup>> myGroups() async => groups;
  @override
  Future<List<GroupInvitation>> myInvitations() async => invitations;
  @override
  Future<List<GroupInvitation>> sentInvitations(int groupId) async => const [];
  @override
  @override
  Future<List<LedgerMember>> members(int groupId) async => memberLists[groupId] ?? const [];
  @override
  Future<int> create(String name) async {
    _maybeFail();
    calls.add('create:$name');
    groups = [...groups, SplitGroup(id: 7, name: name, isOwner: true)];
    return 7;
  }

  InviteEmailOutcome emailOutcome = InviteEmailOutcome.delivered;

  @override
  Future<int> invite(int groupId, String email) async {
    _maybeFail();
    calls.add('invite:$groupId:$email');
    return 42;
  }

  @override
  Future<InviteEmailOutcome> sendInviteEmail(int invitationId) async {
    calls.add('email:$invitationId');
    return emailOutcome;
  }

  @override
  Future<void> respond(int invitationId, bool accept) async {
    _maybeFail();
    calls.add('respond:$invitationId:$accept');
    invitations = invitations.where((i) => i.id != invitationId).toList();
    if (accept) groups = [...groups, const SplitGroup(id: 3, name: 'Trip', isOwner: false)];
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

GroupInvitation _inv(int id) =>
    GroupInvitation(id: id, groupId: 3, groupName: 'Trip', email: 'me@x.com', createdAt: DateTime(2026));

void main() {
  group('ledger choice', () {
    const family = Ledger(LedgerKind.family, 1, 'Home');
    final g1 = const SplitGroup(id: 1, name: 'Goa', isOwner: true);
    final g2 = const SplitGroup(id: 2, name: 'Flat', isOwner: false);

    test('lists the family first, then each group', () {
      final l = availableLedgers(family: family, groups: [g1, g2]);
      expect(l.map((e) => e.name), ['Home', 'Goa', 'Flat']);
    });
    test('a group and a family with the same id are different ledgers', () {
      expect(const Ledger(LedgerKind.family, 1, 'a') == const Ledger(LedgerKind.group, 1, 'a'), isFalse);
      expect(const Ledger(LedgerKind.group, 1, 'x') == const Ledger(LedgerKind.group, 1, 'y'), isTrue);
    });
    test('keeps the current ledger while it is still available', () {
      final l = availableLedgers(family: family, groups: [g1, g2]);
      expect(chooseLedger(l, g2.ledger), g2.ledger);
    });
    test('falls back to the first when the current one is gone, or none is chosen', () {
      final l = availableLedgers(family: null, groups: [g1]);
      expect(chooseLedger(l, g2.ledger), g1.ledger);
      expect(chooseLedger(l, null), g1.ledger);
    });
    test('no ledgers means no choice', () {
      expect(chooseLedger(const [], const Ledger(LedgerKind.group, 1, 'x')), isNull);
    });
  });

  group('invite email outcome', () {
    test('parses the server answer', () {
      expect(parseInviteEmailOutcome({'sent': true, 'delivered': true}), InviteEmailOutcome.delivered);
      expect(parseInviteEmailOutcome({'sent': true, 'delivered': false}), InviteEmailOutcome.notDelivered);
      expect(parseInviteEmailOutcome({'sent': false, 'reason': 'has_account'}), InviteEmailOutcome.hasAccount);
      expect(parseInviteEmailOutcome({'sent': false, 'reason': 'already_sent'}), InviteEmailOutcome.alreadySent);
      expect(parseInviteEmailOutcome({'sent': false, 'reason': 'recipient_limited'}), InviteEmailOutcome.recipientLimited);
      expect(parseInviteEmailOutcome({'sent': false, 'reason': 'sender_limited'}), InviteEmailOutcome.senderLimited);
      expect(parseInviteEmailOutcome({'sent': false, 'reason': 'send_failed'}), InviteEmailOutcome.failed);
      expect(parseInviteEmailOutcome(null), InviteEmailOutcome.failed);
    });
    test('every outcome has a message that mentions the address when they must sign up themselves', () {
      for (final o in [InviteEmailOutcome.notDelivered, InviteEmailOutcome.recipientLimited, InviteEmailOutcome.senderLimited, InviteEmailOutcome.failed]) {
        expect(describeInvite(o, 'a@b.com'), contains('a@b.com'));
      }
    });
  });

  group('models', () {
    test('a group split parses with no family id', () {
      final s = ExpenseSplit.fromJson({
        'id': 1, 'family_id': null, 'group_id': 4, 'paid_by': 'u1', 'created_by': 'u1',
        'description': 'Hotel', 'total_amount': 90.5, 'split_type': 'equal',
        'created_at': '2026-10-09T10:00:00Z',
        'expense_split_shares': [{'user_id': 'u2', 'amount': 45.25}],
      });
      expect(s.groupId, 4);
      expect(s.familyId, isNull);
      expect(s.totalCents, 9050);
      expect(s.shares.single.cents, 4525);
    });
    test('a family settlement still parses', () {
      final p = SplitSettlement.fromJson({
        'id': 2, 'family_id': 1, 'group_id': null, 'from_user': 'a', 'to_user': 'b', 'amount': 3,
        'created_by': 'a', 'created_at': '2026-10-09T10:00:00Z',
      });
      expect(p.familyId, 1);
      expect(p.groupId, isNull);
    });
    test('member names: you, profile name, email prefix, former member', () {
      final names = MemberNames(const [
        LedgerMember(userId: 'me', email: 'me@x.com'),
        LedgerMember(userId: 'a', email: 'ann@x.com', name: 'Ann Lee'),
        LedgerMember(userId: 'b', email: 'bob@x.com'),
      ], 'me');
      expect(names.of('me'), 'You');
      expect(names.of('a'), 'Ann Lee');
      expect(names.of('b'), 'bob');
      expect(names.of('gone'), 'Former member');
    });
  });

  group('SplitGroupProvider', () {
    test('create returns the new id and reloads the list', () async {
      final repo = _FakeRepo();
      final p = SplitGroupProvider(repository: repo);
      final id = await p.create('  Goa trip ');
      expect(id, 7);
      expect(repo.calls, ['create:Goa trip']);
      expect(p.groups.single.name, 'Goa trip');
    });

    test('a failed create reports the message and returns null', () async {
      final repo = _FakeRepo()..failWith = Exception('You have created the maximum of 20 groups');
      final p = SplitGroupProvider(repository: repo);
      expect(await p.create('x'), isNull);
      expect(p.error, 'You have created the maximum of 20 groups');
    });

    test('accepting an invitation moves it from invitations to groups', () async {
      final repo = _FakeRepo()..invitations = [_inv(5)];
      final p = SplitGroupProvider(repository: repo);
      await p.load();
      expect(p.invitations.length, 1);
      expect(await p.respond(p.invitations.single, true), isTrue);
      expect(p.invitations, isEmpty);
      expect(p.groups.map((g) => g.name), ['Trip']);
    });

    test('declining removes the invitation without adding a group', () async {
      final repo = _FakeRepo()..invitations = [_inv(5)];
      final p = SplitGroupProvider(repository: repo);
      await p.load();
      await p.respond(p.invitations.single, false);
      expect(p.invitations, isEmpty);
      expect(p.groups, isEmpty);
    });

    test('invite passes the trimmed email and surfaces a server error', () async {
      final repo = _FakeRepo()..groups = [const SplitGroup(id: 7, name: 'G', isOwner: true)];
      final p = SplitGroupProvider(repository: repo);
      await p.load();
      expect(await p.invite(7, ' a@b.com '), isTrue);
      expect(repo.calls, contains('invite:7:a@b.com'));
      repo.failWith = Exception('That person already has a pending invitation');
      expect(await p.invite(7, 'a@b.com'), isFalse);
      expect(p.error, 'That person already has a pending invitation');
    });

    test('inviting emails the invitation and says so', () async {
      final repo = _FakeRepo()..groups = [const SplitGroup(id: 7, name: 'G', isOwner: true)];
      final p = SplitGroupProvider(repository: repo);
      await p.load();
      expect(await p.invite(7, ' New@Person.com '), isTrue);
      expect(repo.calls, containsAllInOrder(['invite:7:New@Person.com', 'email:42']));
      expect(p.inviteNote, 'Invitation sent. We emailed new@person.com with how to join.');
    });

    test('a person who already has an account is told they will see it in the app', () async {
      final repo = _FakeRepo()..emailOutcome = InviteEmailOutcome.hasAccount;
      final p = SplitGroupProvider(repository: repo);
      await p.invite(7, 'a@b.com');
      expect(p.inviteNote, 'Invitation sent. They will see it in the app.');
    });

    test('a failed invite does not try to email anyone', () async {
      final repo = _FakeRepo()..failWith = Exception('That person already has a pending invitation');
      final p = SplitGroupProvider(repository: repo);
      expect(await p.invite(7, 'a@b.com'), isFalse);
      expect(repo.calls.where((c) => c.startsWith('email')), isEmpty);
      expect(p.inviteNote, isNull);
    });

    test('clear empties everything (sign-out)', () async {
      final repo = _FakeRepo()..invitations = [_inv(1)]..groups = [const SplitGroup(id: 1, name: 'G', isOwner: true)];
      final p = SplitGroupProvider(repository: repo);
      await p.load();
      p.clear();
      expect(p.groups, isEmpty);
      expect(p.invitations, isEmpty);
    });
  });
}
