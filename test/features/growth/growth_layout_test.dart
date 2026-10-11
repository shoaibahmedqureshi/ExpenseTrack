import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../helpers/real_fonts.dart';
import 'package:outlay/features/growth/data/growth_repository.dart';
import 'package:outlay/features/growth/domain/growth_models.dart';
import 'package:outlay/features/growth/presentation/providers/growth_provider.dart';
import 'package:outlay/features/growth/presentation/screens/growth_screen.dart';
import 'package:provider/provider.dart';

const _long =
    'A very long creator name that keeps going and going to test wrapping';
final _task = OutreachTask(
  id: 1,
  creatorName: _long,
  platform: 'youtube',
  channel: OutreachChannel.youtubeEmail,
  status: TaskStatus.todo,
  dueAt: DateTime(2026, 1, 1),
  handle: '@a_really_long_handle_name_for_testing',
  profileUrl: 'https://youtube.com/@a_really_long_handle_name_for_testing',
  niche: 'photography and editing and travel and more topics',
  fitReason:
      'Teaches photo editing to beginners and explains every step carefully. ' *
          2,
  evidence: 'Channel description: photo editing tutorials ' * 3,
  draftMessage:
      'Hi there, we would love to give you a free year of our apps. ' * 6,
);
final _app = CreatorApplication(
  id: 1,
  name: _long,
  email: 'someone.with.a.very.long.address.for.testing@example-domain.com',
  platform: 'tiktok',
  handle: '@a_really_long_handle_name_for_testing',
  audienceBand: '10k_50k',
  niche: 'finance',
  status: ApplicationStatus.confirmed,
  createdAt: DateTime(2026, 1, 1),
  about: 'I make budgeting videos for students and would like to join. ' * 5,
  country: 'PK',
  profileUrl: 'https://tiktok.com/@a_really_long_handle_name_for_testing',
);

class _Repo implements GrowthRepository {
  @override
  Future<bool> isAdmin() async => true;
  @override
  Future<List<OutreachTask>> tasks() async => [_task];
  @override
  Future<List<CreatorApplication>> applications() async => [_app];
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

Future<void> _open(WidgetTester t,
    {required double scale, Brightness b = Brightness.light}) async {
  t.view.physicalSize = const Size(320, 568) * 2;
  t.view.devicePixelRatio = 2;
  addTearDown(t.view.reset);
  final provider = GrowthProvider(repository: _Repo());
  await provider.checkAdmin();
  await t.pumpWidget(MaterialApp(
    theme: ThemeData(brightness: b, fontFamily: 'Roboto'),
    builder: (c, child) => MediaQuery(
        data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!),
    home: ChangeNotifierProvider<GrowthProvider>.value(
        value: provider, child: const GrowthScreen()),
  ));
  await t.pumpAndSettle();
}

void main() {
  setUpAll(loadRealFonts);
  for (final scale in [1.0, 1.5, 2.0]) {
    for (final b in [Brightness.light, Brightness.dark]) {
      testWidgets('no overflow: small phone, text x$scale, $b', (t) async {
        await _open(t, scale: scale, b: b);
        expect(t.takeException(), isNull, reason: 'queue');

        await t.tap(find.textContaining('A very long').first);
        await t.pumpAndSettle();
        expect(t.takeException(), isNull, reason: 'task sheet');
        Navigator.of(t.element(find.byType(Scaffold).first)).pop();
        await t.pumpAndSettle();

        await t.tap(find.textContaining('Applications'));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull, reason: 'applications');
        await t.tap(find.textContaining('A very long').first);
        await t.pumpAndSettle();
        expect(t.takeException(), isNull, reason: 'application sheet');
        Navigator.of(t.element(find.byType(Scaffold).first)).pop();
        await t.pumpAndSettle();

        await t.tap(find.text('Queue'));
        await t.pumpAndSettle();
        await t.tap(find.text('Add creator'));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull, reason: 'add sheet');
      });
    }
  }
}
