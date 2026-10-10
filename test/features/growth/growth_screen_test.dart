import 'package:outlay/features/growth/data/growth_repository.dart';
import 'package:outlay/features/growth/domain/growth_models.dart';
import 'package:outlay/features/growth/presentation/providers/growth_provider.dart';
import 'package:outlay/features/growth/presentation/screens/growth_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _FakeRepo implements GrowthRepository {
  @override
  Future<bool> isAdmin() async => true;
  @override
  Future<List<OutreachTask>> tasks() async => [];
  @override
  Future<List<CreatorApplication>> applications() async => [];
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

Future<void> _pump(WidgetTester t) async {
  final provider = GrowthProvider(repository: _FakeRepo());
  await provider.checkAdmin();
  await t.pumpWidget(MaterialApp(
    home: ChangeNotifierProvider<GrowthProvider>.value(
        value: provider, child: const GrowthScreen()),
  ));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('Add creator is offered on the Queue tab', (t) async {
    await _pump(t);
    expect(find.text('Add creator'), findsOneWidget);
  });

  testWidgets('Add creator is hidden on the Applications tab and returns',
      (t) async {
    await _pump(t);
    await t.tap(find.text('Applications'));
    await t.pumpAndSettle();
    expect(find.text('Add creator'), findsNothing);

    await t.tap(find.text('Queue'));
    await t.pumpAndSettle();
    expect(find.text('Add creator'), findsOneWidget);
  });
}
