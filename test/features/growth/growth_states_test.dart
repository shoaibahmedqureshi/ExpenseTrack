import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outlay/features/growth/data/growth_repository.dart';
import 'package:outlay/features/growth/domain/growth_models.dart';
import 'package:outlay/features/growth/presentation/providers/growth_provider.dart';
import 'package:outlay/features/growth/presentation/screens/growth_screen.dart';
import 'package:provider/provider.dart';

class _Repo implements GrowthRepository {
  bool admin = true;
  Object? loadError;
  Completer<void>? gate;
  Object? writeError;
  Object? draftError;
  Object? approveError;
  final calls = <String>[];
  List<OutreachTask> tasksList = [];
  List<CreatorApplication> appsList = [];

  @override
  Future<bool> isAdmin() async => admin;
  @override
  Future<List<OutreachTask>> tasks() async {
    await gate?.future;
    if (loadError != null) throw loadError!;
    return tasksList;
  }

  @override
  Future<List<CreatorApplication>> applications() async {
    if (loadError != null) throw loadError!;
    return appsList;
  }

  @override
  Future<void> updateTask(int id, Map<String, dynamic> fields) async {
    if (writeError != null) throw writeError!;
  }

  @override
  Future<DraftResult> draft({
    required String creatorName,
    required String platform,
    required OutreachChannel channel,
    String? handle,
    String? profileUrl,
    String? creatorInfo,
  }) async {
    if (draftError != null) throw draftError!;
    return const DraftResult(
        niche: 'finance',
        fits: true,
        fitReason: 'ok',
        evidence: 'e',
        draft: 'Hello there');
  }

  @override
  Future<void> approveApplication({
    required int id,
    String? notes,
    required String draftMessage,
    required String taskNotes,
  }) async {
    calls.add('approve:$id');
    if (approveError != null) throw approveError!;
  }

  @override
  Future<void> decide(int id, ApplicationStatus status, String? notes) async =>
      calls.add('decide:$id');

  @override
  Future<void> addTask({
    required String creatorName,
    required String platform,
    required OutreachChannel channel,
    String? handle,
    String? profileUrl,
    String? niche,
    String? fitReason,
    String? evidence,
    String? draftMessage,
    String? notes,
    String source = 'manual',
    int? applicationId,
  }) async =>
      calls.add('addTask');

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

final _task = OutreachTask(
  id: 1,
  creatorName: 'Jane',
  platform: 'youtube',
  channel: OutreachChannel.youtubeEmail,
  status: TaskStatus.todo,
  dueAt: DateTime(2026, 1, 1),
);

Future<GrowthProvider> _pump(WidgetTester t, _Repo repo,
    {bool settle = true, bool check = true}) async {
  final provider = GrowthProvider(repository: repo);
  if (check) await provider.checkAdmin();
  await t.pumpWidget(MaterialApp(
    home: ChangeNotifierProvider<GrowthProvider>.value(
        value: provider, child: const GrowthScreen()),
  ));
  if (settle) {
    await t.pumpAndSettle();
  } else {
    await t.pump();
  }
  return provider;
}

void main() {
  testWidgets('a non-admin sees "Admins only" and no actions', (t) async {
    await _pump(t, _Repo()..admin = false);
    expect(find.text('Admins only'), findsOneWidget);
    expect(find.text('Add creator'), findsNothing);
    expect(find.text('Queue'), findsNothing);
  });

  testWidgets('shows a spinner while the first load is running', (t) async {
    final repo = _Repo()..gate = Completer<void>();
    await _pump(t, repo, settle: false, check: false);
    await t.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    repo.gate!.complete();
    await t.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('empty queue and empty applications say so', (t) async {
    await _pump(t, _Repo());
    expect(find.textContaining('Nothing queued'), findsOneWidget);
    await t.tap(find.text('Applications'));
    await t.pumpAndSettle();
    expect(find.textContaining('No applications yet'), findsOneWidget);
  });

  testWidgets('a failed load is shown on both tabs, not as "empty"', (t) async {
    await _pump(t, _Repo()..loadError = Exception('network down'));
    expect(find.textContaining('network down'), findsOneWidget);
    await t.tap(find.text('Applications'));
    await t.pumpAndSettle();
    expect(find.textContaining('network down'), findsOneWidget);
    expect(find.textContaining('No applications yet'), findsNothing);
  });

  testWidgets('a failed save keeps the sheet open and says why', (t) async {
    final repo = _Repo()..tasksList = [_task];
    await _pump(t, repo);
    repo.writeError = Exception('permission denied');
    await t.tap(find.text('Jane'));
    await t.pumpAndSettle();
    await t.tap(find.text('Mark sent'));
    await t.pumpAndSettle();
    expect(find.textContaining('permission denied'), findsOneWidget);
    expect(find.text('Mark sent'), findsOneWidget, reason: 'sheet stays open');
  });

  testWidgets('a failed AI draft says why and the form stays usable',
      (t) async {
    final repo = _Repo()..draftError = Exception('AI is unavailable');
    await _pump(t, repo);
    await t.tap(find.text('Add creator'));
    await t.pumpAndSettle();
    await t.enterText(find.widgetWithText(TextField, 'Name'), 'Sam');
    await t.enterText(
        find.widgetWithText(TextField, 'Paste their bio / recent video titles'),
        'Makes budgeting videos');
    await t.ensureVisible(find.text('Draft with AI'));
    await t.tap(find.text('Draft with AI'));
    await t.pumpAndSettle();
    expect(find.textContaining('AI is unavailable'), findsOneWidget);
    final button = t.widget<OutlinedButton>(find.ancestor(
        of: find.text('Draft with AI'), matching: find.byType(OutlinedButton)));
    expect(button.onPressed, isNotNull, reason: 'button usable again');
  });

  testWidgets('adding without a name tells you what is missing', (t) async {
    await _pump(t, _Repo());
    await t.tap(find.text('Add creator'));
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Add to queue'));
    await t.tap(find.text('Add to queue'));
    await t.pumpAndSettle();
    expect(find.textContaining('Enter the creator'), findsOneWidget);
    expect(find.text('Add to queue'), findsOneWidget,
        reason: 'sheet stays open');
  });

  testWidgets('a failed refresh keeps the data and shows a retry banner',
      (t) async {
    final repo = _Repo()..tasksList = [_task];
    final p = await _pump(t, repo);
    repo.loadError = Exception('offline');
    await p.load();
    await t.pumpAndSettle();
    expect(find.text('Jane'), findsOneWidget);
    expect(find.textContaining('Could not refresh: offline'), findsOneWidget);
    repo.loadError = null;
    await t.tap(find.text('Try again'));
    await t.pumpAndSettle();
    expect(find.textContaining('Could not refresh'), findsNothing);
  });

  testWidgets('an action failure does not masquerade as a refresh failure',
      (t) async {
    final repo = _Repo()..tasksList = [_task];
    await _pump(t, repo);
    repo.writeError = Exception('permission denied');
    await t.tap(find.text('Jane'));
    await t.pumpAndSettle();
    await t.tap(find.text('Mark sent'));
    await t.pumpAndSettle();
    expect(find.textContaining('Could not refresh'), findsNothing);
  });

  group('approving an application', () {
    final app = CreatorApplication(
      id: 7,
      name: 'Sam Lee',
      email: 'sam@example.com',
      platform: 'tiktok',
      handle: '@sam',
      audienceBand: '10k_50k',
      niche: 'finance',
      status: ApplicationStatus.confirmed,
      createdAt: DateTime(2026, 1, 1),
    );

    test('is a single repository call, never decide plus addTask', () async {
      final repo = _Repo();
      final p = GrowthProvider(repository: repo);
      expect(await p.approve(app, 'good fit'), isTrue);
      expect(repo.calls.where((c) => c != 'approve:7'), isEmpty);
      expect(repo.calls, contains('approve:7'));
    });

    test('a failure reports the error and changes nothing else', () async {
      final repo = _Repo()..approveError = Exception('could not queue');
      final p = GrowthProvider(repository: repo);
      expect(await p.approve(app, null), isFalse);
      expect(p.error, 'could not queue');
      expect(repo.calls, ['approve:7']);
    });
  });
}
