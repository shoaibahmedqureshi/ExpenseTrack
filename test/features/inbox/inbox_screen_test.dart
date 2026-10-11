import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outlay/features/inbox/data/inbox_repository.dart';
import 'package:outlay/features/inbox/domain/inbox_item.dart';
import 'package:outlay/features/inbox/presentation/providers/inbox_provider.dart';
import 'package:outlay/features/inbox/presentation/screens/inbox_screen.dart';
import 'package:provider/provider.dart';

class _Repo implements InboxRepository {
  Object? error;
  List<InboxItem> items = [];
  final marked = <int>[];

  @override
  Future<List<InboxItem>> list({int limit = 100}) async {
    if (error != null) throw error!;
    return items;
  }

  @override
  Future<void> markRead(int id) async => marked.add(id);

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

InboxItem _item(int id, String type, {bool read = false}) => InboxItem(
      id: id,
      type: type,
      title: 'Title $id',
      body: 'Body $id',
      data: const {},
      createdAt: DateTime.now(),
      readAt: read ? DateTime.now() : null,
    );

/// Opens the inbox the way the dashboard does and returns whatever target it pops with.
Future<String?> _open(WidgetTester t, _Repo repo,
    {bool tapFirst = false}) async {
  final provider =
      InboxProvider(repository: repo, getCurrentUserId: () => 'u1');
  String? result;
  await t.pumpWidget(ChangeNotifierProvider<InboxProvider>.value(
    value: provider,
    child: MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async => result = await Navigator.push<String>(
                context,
                MaterialPageRoute(builder: (_) => const InboxScreen())),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  ));
  await t.tap(find.text('open'));
  await t.pumpAndSettle();
  if (tapFirst) {
    await t.tap(find.text('Title 1'));
    await t.pumpAndSettle();
  }
  return result;
}

void main() {
  testWidgets('an empty inbox says you are caught up', (t) async {
    await _open(t, _Repo());
    expect(find.text("You're all caught up"), findsOneWidget);
  });

  testWidgets('a failed load says so instead of "all caught up"', (t) async {
    await _open(t, _Repo()..error = Exception('offline'));
    expect(find.text('Could not load notifications'), findsOneWidget);
    expect(find.text("You're all caught up"), findsNothing);
  });

  testWidgets('Try again recovers once the connection is back', (t) async {
    final repo = _Repo()..error = Exception('offline');
    await _open(t, repo);
    repo.error = null;
    repo.items = [_item(1, 'creator_application')];
    await t.tap(find.text('Try again'));
    await t.pumpAndSettle();
    expect(find.text('Title 1'), findsOneWidget);
    expect(find.text('Could not load notifications'), findsNothing);
  });

  testWidgets('a failed refresh keeps the notifications and offers a retry',
      (t) async {
    final repo = _Repo()..items = [_item(1, 'split_added')];
    await _open(t, repo);
    repo.error = Exception('offline');
    final ctx = t.element(find.byType(InboxScreen));
    await ctx.read<InboxProvider>().load(silent: true);
    await t.pumpAndSettle();
    expect(find.text('Title 1'), findsOneWidget);
    expect(find.text('Could not refresh notifications.'), findsOneWidget);
  });

  testWidgets('tapping a creator application marks it read and opens Growth',
      (t) async {
    final repo = _Repo()..items = [_item(1, 'creator_application')];
    String? popped;
    final provider =
        InboxProvider(repository: repo, getCurrentUserId: () => 'u1');
    await t.pumpWidget(ChangeNotifierProvider<InboxProvider>.value(
      value: provider,
      child: MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => popped = await Navigator.push<String>(
                context,
                MaterialPageRoute(builder: (_) => const InboxScreen())),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    await t.tap(find.text('Title 1'));
    await t.pumpAndSettle();
    expect(popped, 'growth');
    expect(repo.marked, [1]);
  });

  test('notification types map to their destinations', () {
    expect(_item(1, 'creator_application').target, 'growth');
    expect(_item(1, 'split_added').target, 'splits');
    expect(_item(1, 'family_invite').target, 'invites');
    expect(_item(1, 'member_joined').target, 'family');
    expect(_item(1, 'something_new').target, '');
  });
}
