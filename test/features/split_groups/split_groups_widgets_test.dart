import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outlay/features/dashboard/presentation/widgets/splits_summary_card.dart';
import 'package:outlay/features/expense_split/data/expense_split_repository.dart';
import 'package:outlay/features/expense_split/domain/split_models.dart';
import 'package:outlay/features/expense_split/presentation/providers/expense_split_provider.dart';
import 'package:outlay/features/expense_split/presentation/screens/new_split_screen.dart';
import 'package:outlay/features/family_accounts/domain/entities/family_group.dart';
import 'package:outlay/features/family_accounts/domain/entities/family_member.dart';
import 'package:outlay/features/family_accounts/domain/repositories/family_repository.dart';
import 'package:outlay/features/family_accounts/presentation/providers/family_provider.dart';
import 'package:outlay/features/split_groups/data/split_group_repository.dart';
import 'package:outlay/features/split_groups/domain/group_models.dart';
import 'package:outlay/features/split_groups/presentation/providers/split_group_provider.dart';
import 'package:outlay/features/split_groups/presentation/screens/group_detail_screen.dart';
import 'package:outlay/features/splits/presentation/screens/splits_screen.dart';
import 'package:provider/provider.dart';

// ── Fakes ──────────────────────────────────────────────────────────────
class _FakeGroups implements SplitGroupRepository {
  List<SplitGroup> groups = [];
  List<GroupInvitation> invitations = [];
  Map<int, List<LedgerMember>> memberLists = {};
  Map<int, List<GroupInvitation>> sent = {};
  Object? failWith;
  InviteEmailOutcome emailOutcome = InviteEmailOutcome.delivered;
  final calls = <String>[];
  int nextId = 5;

  void _fail() {
    if (failWith != null) throw failWith!;
  }

  @override
  Future<List<SplitGroup>> myGroups() async => groups;
  @override
  Future<List<GroupInvitation>> myInvitations() async => invitations;
  @override
  Future<List<GroupInvitation>> sentInvitations(int groupId) async => sent[groupId] ?? const [];
  @override
  Future<List<LedgerMember>> members(int groupId) async => memberLists[groupId] ?? const [];

  @override
  Future<int> create(String name) async {
    _fail();
    calls.add('create:$name');
    final id = nextId++;
    groups = [...groups, SplitGroup(id: id, name: name, isOwner: true)];
    memberLists[id] = [const LedgerMember(userId: 'me', email: 'me@x.com', isOwner: true)];
    return id;
  }

  @override
  Future<int> invite(int groupId, String email) async {
    _fail();
    calls.add('invite:$groupId:$email');
    return 99;
  }

  @override
  Future<InviteEmailOutcome> sendInviteEmail(int invitationId) async => emailOutcome;

  @override
  Future<void> respond(int invitationId, bool accept) async {
    _fail();
    calls.add('respond:$invitationId:$accept');
    final inv = invitations.firstWhere((i) => i.id == invitationId);
    invitations = invitations.where((i) => i.id != invitationId).toList();
    if (accept) groups = [...groups, SplitGroup(id: inv.groupId, name: inv.groupName, isOwner: false)];
  }

  @override
  Future<void> cancelInvitation(int invitationId) async {
    _fail();
    calls.add('cancel:$invitationId');
    sent = {for (final e in sent.entries) e.key: e.value.where((i) => i.id != invitationId).toList()};
  }

  @override
  Future<void> leave(int groupId) async {
    _fail();
    calls.add('leave:$groupId');
    groups = groups.where((g) => g.id != groupId).toList();
  }

  @override
  Future<void> removeMember(int groupId, String userId) async {
    _fail();
    calls.add('remove:$groupId:$userId');
    memberLists[groupId] = memberLists[groupId]!.where((m) => m.userId != userId).toList();
  }

  @override
  Future<void> delete(int groupId) async {
    _fail();
    calls.add('delete:$groupId');
    groups = groups.where((g) => g.id != groupId).toList();
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _FakeSplits implements ExpenseSplitRepository {
  Map<String, List<ExpenseSplit>> splitsBy = {};
  Map<String, List<SplitSettlement>> paymentsBy = {};
  List<LedgerBalance> balances = [];
  final loaded = <String>[];
  final created = <Map<String, Object?>>[];

  String _k(Ledger l) => '${l.kind.key}:${l.id}';

  @override
  Future<List<ExpenseSplit>> splits(Ledger ledger) async {
    loaded.add(_k(ledger));
    return splitsBy[_k(ledger)] ?? const [];
  }

  @override
  Future<List<SplitSettlement>> settlements(Ledger ledger) async => paymentsBy[_k(ledger)] ?? const [];
  @override
  Future<List<LedgerBalance>> overview() async => balances;

  @override
  Future<void> createSplit({
    required Ledger ledger,
    required String paidBy,
    required String description,
    required int totalCents,
    required SplitType type,
    required Map<String, int> sharesCents,
    Map<String, double>? percents,
  }) async {
    created.add({'ledger': _k(ledger), 'paidBy': paidBy, 'description': description, 'total': totalCents, 'shares': sharesCents});
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _FakeFamily implements FamilyRepository {
  List<FamilyGroup> families = [];
  List<FamilyMember> members = [];

  @override
  Future<List<FamilyGroup>> getUserFamilyGroups(String userId) async => families;
  @override
  Future<List<FamilyMember>> getFamilyMembers(String familyGroupId) async => members;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

// ── Builders ───────────────────────────────────────────────────────────
const _me = LedgerMember(userId: 'me', email: 'me@x.com', isOwner: true);
const _ann = LedgerMember(userId: 'ann', email: 'ann@x.com', name: 'Ann Lee');

ExpenseSplit _split({
  int id = 1,
  int groupId = 5,
  String paidBy = 'me',
  String description = 'Hotel',
  double total = 120,
  Map<String, double> shares = const {'me': 60, 'ann': 60},
}) =>
    ExpenseSplit.fromJson({
      'id': id, 'family_id': null, 'group_id': groupId, 'paid_by': paidBy, 'created_by': paidBy,
      'description': description, 'total_amount': total, 'split_type': 'equal',
      'created_at': '2026-10-09T10:00:00Z',
      'expense_split_shares': [for (final e in shares.entries) {'user_id': e.key, 'amount': e.value}],
    });

FamilyGroup _family() => FamilyGroup(
    id: '1', creatorId: 'me', name: 'Home', memberCount: 2, createdAt: DateTime(2026), updatedAt: DateTime(2026));

FamilyMember _familyMember(String id, FamilyMemberRole role, {String? name}) => FamilyMember(
    id: id, familyGroupId: '1', userId: id, email: '$id@x.com', name: name, role: role, joinedAt: DateTime(2026));

GroupInvitation _invite(int id, {int groupId = 8, String group = 'Trip'}) =>
    GroupInvitation(id: id, groupId: groupId, groupName: group, email: 'me@x.com', createdAt: DateTime(2026));

LedgerBalance _bal(LedgerKind k, int id, String name, int net) =>
    LedgerBalance(ledger: Ledger(k, id, name), netCents: net, hasActivity: true);

class _H {
  _H({this.groups = const [], this.family});
  final List<SplitGroup> groups;
  final bool? family;

  final fakeGroups = _FakeGroups();
  final fakeSplits = _FakeSplits();
  final fakeFamily = _FakeFamily();
  late final SplitGroupProvider groupProvider = SplitGroupProvider(repository: fakeGroups);
  late final ExpenseSplitProvider splitProvider =
      ExpenseSplitProvider(repository: fakeSplits, getCurrentUserId: () => 'me');
  late final FamilyProvider familyProvider = FamilyProvider(repository: fakeFamily, getCurrentUserId: () => 'me');

  /// Mirrors what happens at sign-in.
  Future<void> load() async {
    await groupProvider.load();
    await familyProvider.loadUserFamilies();
    await splitProvider.loadOverview();
  }

  Widget app(Widget home) => MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: groupProvider),
          ChangeNotifierProvider.value(value: splitProvider),
          ChangeNotifierProvider.value(value: familyProvider),
        ],
        child: MaterialApp(home: home),
      );
}

Future<void> _pump(WidgetTester t, _H h, Widget home) async {
  await t.runAsync(h.load);
  await t.pumpWidget(h.app(home));
  await t.pumpAndSettle();
}

void main() {
  // The default test surface is tall enough for these screens.
  group('SplitsScreen', () {
    testWidgets('with no family and no groups it invites you to create a group', (t) async {
      final h = _H();
      await _pump(t, h, const SplitsScreen());
      expect(find.text('Split costs with anyone'), findsOneWidget);
      expect(find.text('Create a group'), findsOneWidget);
    });

    testWidgets('a pending invitation can be joined, and says so', (t) async {
      final h = _H();
      h.fakeGroups.invitations = [_invite(3)];
      h.fakeGroups.memberLists[8] = [_me];
      await _pump(t, h, const SplitsScreen());
      expect(find.text('You are invited to "Trip"'), findsOneWidget);

      await t.tap(find.text('Join'));
      await t.pumpAndSettle();
      expect(h.fakeGroups.calls, contains('respond:3:true'));
      expect(find.text('You joined Trip'), findsOneWidget);
      expect(find.text('You are invited to "Trip"'), findsNothing);
    });

    testWidgets('declining removes the invitation without joining', (t) async {
      final h = _H();
      h.fakeGroups.invitations = [_invite(3)];
      await _pump(t, h, const SplitsScreen());
      await t.tap(find.text('Decline'));
      await t.pumpAndSettle();
      expect(h.fakeGroups.calls, contains('respond:3:false'));
      expect(h.groupProvider.groups, isEmpty);
    });

    testWidgets('a group shows its chips, balance and who owes whom', (t) async {
      final h = _H();
      h.fakeGroups.groups = [const SplitGroup(id: 5, name: 'Goa trip', isOwner: true)];
      h.fakeGroups.memberLists[5] = [_me, _ann];
      h.fakeSplits.splitsBy['group:5'] = [_split()];
      await _pump(t, h, const SplitsScreen());

      expect(find.widgetWithText(ChoiceChip, 'Goa trip'), findsOneWidget);
      expect(find.text('New group'), findsOneWidget);
      expect(find.text('You are owed'), findsOneWidget);
      expect(find.text('\$60.00'), findsWidgets);
      expect(find.text('Ann Lee owes you'), findsOneWidget);
      expect(find.text('Hotel'), findsOneWidget);
    });

    testWidgets('family and groups are separate chips, and switching loads that ledger', (t) async {
      final h = _H();
      h.fakeFamily.families = [_family()];
      h.fakeFamily.members = [_familyMember('me', FamilyMemberRole.admin), _familyMember('bob', FamilyMemberRole.member, name: 'Bob')];
      h.fakeGroups.groups = [const SplitGroup(id: 5, name: 'Goa trip', isOwner: true)];
      h.fakeGroups.memberLists[5] = [_me, _ann];
      h.fakeSplits.splitsBy['group:5'] = [_split()];
      await _pump(t, h, const SplitsScreen());

      expect(find.widgetWithText(ChoiceChip, 'Family'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Goa trip'), findsOneWidget);
      // The family is shown first.
      expect(h.fakeSplits.loaded.first, 'family:1');

      await t.tap(find.widgetWithText(ChoiceChip, 'Goa trip'));
      await t.pumpAndSettle();
      expect(h.fakeSplits.loaded, contains('group:5'));
      expect(find.text('Hotel'), findsOneWidget);
    });

    testWidgets('alone in a group, New split is disabled and points to inviting', (t) async {
      final h = _H();
      h.fakeGroups.groups = [const SplitGroup(id: 5, name: 'Solo', isOwner: true)];
      h.fakeGroups.memberLists[5] = [_me];
      await _pump(t, h, const SplitsScreen());

      final button = t.widget<FilledButton>(find.widgetWithText(FilledButton, 'New split'));
      expect(button.onPressed, isNull);
      expect(find.text('Invite someone to start splitting costs'), findsOneWidget);
    });

    testWidgets('creating a group opens it so people can be invited', (t) async {
      final h = _H();
      await _pump(t, h, const SplitsScreen());

      await t.tap(find.text('Create a group'));
      await t.pumpAndSettle();
      await t.tap(find.byType(TextField));
      await t.enterText(find.byType(TextField), 'Flat 4B');
      await t.tap(find.text('Save'));
      await t.pumpAndSettle();

      expect(h.fakeGroups.calls, contains('create:Flat 4B'));
      expect(find.widgetWithText(AppBar, 'Flat 4B'), findsOneWidget);
      expect(find.text('Invite someone'), findsOneWidget);
    });

    testWidgets('a server error when creating a group is shown and nothing opens', (t) async {
      final h = _H();
      h.fakeGroups.failWith = Exception('You have created the maximum of 20 groups');
      await _pump(t, h, const SplitsScreen());
      await t.tap(find.text('Create a group'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), 'One too many');
      await t.tap(find.text('Save'));
      await t.pumpAndSettle();
      expect(find.text('You have created the maximum of 20 groups'), findsOneWidget);
      expect(find.text('Invite someone'), findsNothing);
    });
  });

  group('GroupDetailScreen', () {
    Future<_H> open(WidgetTester t, {bool owner = true, List<LedgerMember>? members, int groupId = 5}) async {
      final h = _H();
      h.fakeGroups.groups = [SplitGroup(id: groupId, name: 'Goa trip', isOwner: owner)];
      h.fakeGroups.memberLists[groupId] = members ?? [_me, _ann];
      await _pump(t, h, GroupDetailScreen(groupId: groupId, myUserId: 'me'));
      return h;
    }

    testWidgets('lists members with the owner marked and the count', (t) async {
      await open(t);
      expect(find.text('Members (2/20)'), findsOneWidget);
      expect(find.textContaining('Owner'), findsOneWidget);
      expect(find.text('Ann Lee'), findsOneWidget);
      expect(find.textContaining('(you)'), findsOneWidget);
    });

    testWidgets('the owner can rename, remove people and delete; a member cannot', (t) async {
      await open(t, owner: true);
      expect(find.byTooltip('Rename'), findsOneWidget);
      expect(find.byTooltip('Remove'), findsOneWidget);
      expect(find.text('Delete group'), findsOneWidget);
      expect(find.text('Leave group'), findsOneWidget);
    });

    testWidgets('an ordinary member can only leave', (t) async {
      await open(t, owner: false, members: [const LedgerMember(userId: 'ann', email: 'ann@x.com', name: 'Ann Lee', isOwner: true), const LedgerMember(userId: 'me', email: 'me@x.com')]);
      expect(find.byTooltip('Rename'), findsNothing);
      expect(find.byTooltip('Remove'), findsNothing);
      expect(find.text('Delete group'), findsNothing);
      expect(find.text('Leave group'), findsOneWidget);
    });

    testWidgets('inviting sends the trimmed address, clears the box and reports the outcome', (t) async {
      final h = await open(t);
      await t.enterText(find.byType(TextField), '  new@person.com ');
      await t.tap(find.text('Invite'));
      await t.pumpAndSettle();
      expect(h.fakeGroups.calls, contains('invite:5:new@person.com'));
      expect(find.text('Invitation sent. We emailed new@person.com with how to join.'), findsOneWidget);
      expect(t.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
    });

    testWidgets('when email is switched off the inviter is told what to do instead', (t) async {
      final h = await open(t);
      h.fakeGroups.emailOutcome = InviteEmailOutcome.notDelivered;
      await t.enterText(find.byType(TextField), 'new@person.com');
      await t.tap(find.text('Invite'));
      await t.pumpAndSettle();
      expect(find.textContaining('Ask them to sign up with new@person.com'), findsOneWidget);
    });

    testWidgets('a server refusal is shown and the address stays in the box', (t) async {
      final h = await open(t);
      h.fakeGroups.failWith = Exception('That person already has a pending invitation');
      await t.enterText(find.byType(TextField), 'dup@person.com');
      await t.tap(find.text('Invite'));
      await t.pumpAndSettle();
      expect(find.text('That person already has a pending invitation'), findsOneWidget);
      expect(t.widget<TextField>(find.byType(TextField)).controller!.text, 'dup@person.com');
    });

    testWidgets('pending invitations are listed and can be cancelled', (t) async {
      final h = _H();
      h.fakeGroups.groups = [const SplitGroup(id: 5, name: 'Goa trip', isOwner: true)];
      h.fakeGroups.memberLists[5] = [_me];
      h.fakeGroups.sent[5] = [GroupInvitation(id: 12, groupId: 5, groupName: 'Goa trip', email: 'wait@x.com', createdAt: DateTime(2026))];
      await _pump(t, h, const GroupDetailScreen(groupId: 5, myUserId: 'me'));

      expect(find.text('Waiting to join'), findsOneWidget);
      expect(find.text('wait@x.com'), findsOneWidget);
      await t.tap(find.text('Cancel'));
      await t.pumpAndSettle();
      expect(h.fakeGroups.calls, contains('cancel:12'));
      expect(find.text('wait@x.com'), findsNothing);
    });

    testWidgets('a full group (20 with pending) cannot take more invitations', (t) async {
      final h = _H();
      h.fakeGroups.groups = [const SplitGroup(id: 5, name: 'Big', isOwner: true)];
      h.fakeGroups.memberLists[5] = [for (var i = 0; i < 20; i++) LedgerMember(userId: 'u$i', email: 'u$i@x.com', isOwner: i == 0)];
      await _pump(t, h, const GroupDetailScreen(groupId: 5, myUserId: 'u0'));
      expect(t.widget<TextField>(find.byType(TextField)).enabled, isFalse);
      expect(find.text('This group is full (20 people)'), findsOneWidget);
    });

    testWidgets('removing someone asks first, then removes them', (t) async {
      final h = await open(t);
      await t.tap(find.byTooltip('Remove'));
      await t.pumpAndSettle();
      expect(find.textContaining('Remove Ann Lee?'), findsOneWidget);
      await t.tap(find.widgetWithText(FilledButton, 'Remove'));
      await t.pumpAndSettle();
      expect(h.fakeGroups.calls, contains('remove:5:ann'));
      expect(find.text('Removed'), findsOneWidget);
    });

    testWidgets('cancelling the remove dialog changes nothing', (t) async {
      final h = await open(t);
      await t.tap(find.byTooltip('Remove'));
      await t.pumpAndSettle();
      await t.tap(find.text('Cancel').last);
      await t.pumpAndSettle();
      expect(h.fakeGroups.calls.where((c) => c.startsWith('remove')), isEmpty);
    });

    testWidgets('leaving asks first, leaves and goes back', (t) async {
      final h = _H();
      h.fakeGroups.groups = [const SplitGroup(id: 5, name: 'Goa trip', isOwner: true)];
      h.fakeGroups.memberLists[5] = [_me, _ann];
      await t.runAsync(h.load);
      await t.pumpWidget(h.app(Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GroupDetailScreen(groupId: 5, myUserId: 'me'))),
              child: const Text('open'),
            ),
          ),
        ),
      )));
      await t.tap(find.text('open'));
      await t.pumpAndSettle();

      await t.ensureVisible(find.text('Leave group'));
      await t.tap(find.text('Leave group'));
      await t.pumpAndSettle();
      expect(find.text('Leave Goa trip?'), findsOneWidget);
      await t.tap(find.widgetWithText(FilledButton, 'Leave'));
      await t.pumpAndSettle();
      expect(h.fakeGroups.calls, contains('leave:5'));
      expect(find.text('open'), findsOneWidget); // back on the previous screen
    });

    testWidgets('leaving with an unsettled balance shows the server message and stays', (t) async {
      final h = await open(t);
      h.fakeGroups.failWith = Exception('Settle up first: this person still has an unsettled balance in the group');
      await t.ensureVisible(find.text('Leave group'));
      await t.tap(find.text('Leave group'));
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(FilledButton, 'Leave'));
      await t.pumpAndSettle();
      expect(find.textContaining('Settle up first'), findsOneWidget);
      expect(find.widgetWithText(AppBar, 'Goa trip'), findsOneWidget);
    });

    testWidgets('a group that no longer exists shows a message instead of crashing', (t) async {
      final h = _H();
      await _pump(t, h, const GroupDetailScreen(groupId: 404, myUserId: 'me'));
      expect(find.text('This group is no longer available'), findsOneWidget);
    });
  });

  group('SplitsSummaryCard', () {
    Future<_H> card(WidgetTester t, List<LedgerBalance> balances, {VoidCallback? onTap}) async {
      final h = _H();
      h.fakeSplits.balances = balances;
      await _pump(t, h, Scaffold(body: SplitsSummaryCard(onTap: onTap ?? () {})));
      return h;
    }

    testWidgets('is hidden until something has been split or paid', (t) async {
      await card(t, []);
      expect(find.text('Shared expenses'), findsNothing);
      await card(t, [const LedgerBalance(ledger: Ledger(LedgerKind.group, 1, 'Trip'), netCents: 0, hasActivity: false)]);
      expect(find.text('Shared expenses'), findsNothing);
    });

    testWidgets('totals what you owe and are owed across ledgers, with a line per ledger', (t) async {
      await card(t, [
        _bal(LedgerKind.group, 1, 'Trip', 6000),
        _bal(LedgerKind.group, 2, 'Flat', -4500),
        _bal(LedgerKind.family, 9, 'Home', 0),
      ]);
      expect(find.text('Shared expenses'), findsOneWidget);
      expect(find.text('You owe'), findsOneWidget);
      expect(find.text('\$45.00'), findsWidgets);
      expect(find.text('\$60.00'), findsWidgets);
      expect(find.text('owed \$60.00'), findsOneWidget);
      expect(find.text('you owe \$45.00'), findsOneWidget);
      expect(find.text('Trip'), findsOneWidget);
      expect(find.text('Flat'), findsOneWidget);
      expect(find.text('Home'), findsNothing); // a settled ledger is not listed
    });

    testWidgets('the family row is labelled "Family", whatever it is called', (t) async {
      await card(t, [_bal(LedgerKind.family, 9, 'ABCD', 1000)]);
      expect(find.text('Family'), findsOneWidget);
      expect(find.text('ABCD'), findsNothing);
    });

    testWidgets('everything settled says so', (t) async {
      await card(t, [_bal(LedgerKind.group, 1, 'Trip', 0)]);
      expect(find.text("You're all settled up"), findsOneWidget);
    });

    testWidgets('only the three biggest balances are listed, with a count of the rest', (t) async {
      await card(t, [
        _bal(LedgerKind.group, 1, 'A', 100),
        _bal(LedgerKind.group, 2, 'B', 500),
        _bal(LedgerKind.group, 3, 'C', -300),
        _bal(LedgerKind.group, 4, 'D', 200),
        _bal(LedgerKind.group, 5, 'E', 50),
      ]);
      expect(find.text('B'), findsOneWidget);
      expect(find.text('C'), findsOneWidget);
      expect(find.text('D'), findsOneWidget);
      expect(find.text('A'), findsNothing);
      expect(find.text('+ 2 more'), findsOneWidget);
    });

    testWidgets('tapping a row opens that ledger, tapping the card opens the Splits tab', (t) async {
      var opened = 0;
      final h = await card(t, [_bal(LedgerKind.group, 2, 'Flat', -4500)], onTap: () => opened++);
      await t.tap(find.text('Flat'));
      await t.pumpAndSettle();
      expect(h.splitProvider.ledger, const Ledger(LedgerKind.group, 2, 'Flat'));
      expect(opened, 1);

      await t.tap(find.text('Shared expenses'));
      await t.pumpAndSettle();
      expect(opened, 2);
    });
  });

  group('NewSplitScreen', () {
    testWidgets('splits equally between the members of the group it was opened for', (t) async {
      final h = _H();
      await t.runAsync(h.load);
      await t.runAsync(() => h.splitProvider.load(const Ledger(LedgerKind.group, 5, 'Goa trip')));
      await t.pumpWidget(h.app(const NewSplitScreen(members: [_me, _ann])));
      await t.pumpAndSettle();

      expect(find.text('You'), findsWidgets);
      expect(find.text('Ann Lee'), findsWidgets);

      await t.enterText(find.widgetWithText(TextField, 'What was it for?'), 'Dinner');
      await t.enterText(find.widgetWithText(TextField, 'Total amount'), '90');
      await t.pumpAndSettle();
      await t.tap(find.text('Save split'));
      await t.pumpAndSettle();

      expect(h.fakeSplits.created, hasLength(1));
      final c = h.fakeSplits.created.single;
      expect(c['ledger'], 'group:5');
      expect(c['description'], 'Dinner');
      expect(c['total'], 9000);
      expect(c['paidBy'], 'me');
      expect(c['shares'], {'me': 4500, 'ann': 4500});
    });

    testWidgets('refuses to save without a description or total', (t) async {
      final h = _H();
      await t.runAsync(h.load);
      await t.runAsync(() => h.splitProvider.load(const Ledger(LedgerKind.group, 5, 'Goa trip')));
      await t.pumpWidget(h.app(const NewSplitScreen(members: [_me, _ann])));
      await t.pumpAndSettle();
      await t.tap(find.text('Save split'));
      await t.pumpAndSettle();
      expect(h.fakeSplits.created, isEmpty);
    });
  });
}
