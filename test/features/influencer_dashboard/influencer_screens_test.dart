import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../helpers/real_fonts.dart';
import 'package:outlay/features/influencer_dashboard/domain/entities/influencer_revenue.dart';
import 'package:outlay/features/influencer_dashboard/domain/entities/revenue_report.dart';
import 'package:outlay/features/influencer_dashboard/domain/repositories/influencer_repository.dart';
import 'package:outlay/features/influencer_dashboard/presentation/providers/influencer_provider.dart';
import 'package:outlay/features/influencer_dashboard/presentation/screens/influencer_dashboard_screen.dart';
import 'package:outlay/features/influencer_dashboard/presentation/screens/revenue_details_screen.dart';
import 'package:provider/provider.dart';

class _Repo implements InfluencerRepository {
  Object? error;
  Completer<void>? gate;
  RevenueReport? report;
  List<InfluencerRevenue> revenues = [];
  final calls = <String>[];

  final starts = <DateTime?>[];

  @override
  Future<RevenueReport> generateReport(String userId,
      {DateTime? startDate, DateTime? endDate}) async {
    starts.add(startDate);
    calls.add('report:$userId:${startDate == null ? 'all' : 'range'}');
    await gate?.future;
    if (error != null) throw error!;
    return report!;
  }

  @override
  Future<List<InfluencerRevenue>> getRevenueByCode(String userId, String code,
      {DateTime? startDate, DateTime? endDate}) async {
    calls.add('code:$userId:$code');
    await gate?.future;
    if (error != null) throw error!;
    return revenues;
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

const _long = 'A_VERY_LONG_INFLUENCER_CODE_FOR_TESTING_WRAPPING_20';

CodeRevenue _code(String c, double total, {double usd = 0}) => CodeRevenue(
      code: c,
      totalsByCurrency: {'PKR': total, if (usd > 0) 'USD': usd},
      conversionsByCurrency: {'PKR': 12, if (usd > 0) 'USD': 2},
      subscriptionPlans: const ['pro_annual'],
      firstConversion: DateTime(2026, 1, 1),
      lastConversion: DateTime(2026, 2, 1),
    );

RevenueReport _report({List<CodeRevenue>? codes}) => RevenueReport(
      totalsByCurrency: {'PKR': 123456.78, 'USD': 41.5},
      conversionsByCurrency: {'PKR': 9, 'USD': 3},
      monthlyByCurrency: {'PKR': 4000},
      yearlyByCurrency: {'PKR': 99999.5, 'USD': 41.5},
      revenueByCode:
          codes ?? [_code('SARA20', 5000, usd: 30), _code(_long, 800)],
      monthlyTrends: const [],
      generatedAt: DateTime(2026, 10, 10),
    );

InfluencerRevenue _rev(int i, {String currency = 'PKR'}) => InfluencerRevenue(
      id: 'r$i',
      userId: 'u1',
      influencerCode: 'SARA20',
      subscriptionPlan: i.isEven ? 'expense_tracker_pro_annual' : 'monthly',
      revenueAmount: 100.0 * i,
      currency: currency,
      transactionDate: DateTime(2026, 10, i + 1),
      createdAt: DateTime(2026, 10, i + 1),
    );

Future<void> _pump(WidgetTester t, _Repo repo, Widget screen,
    {double scale = 1,
    Brightness b = Brightness.light,
    bool settle = true}) async {
  t.view.physicalSize = const Size(320, 568) * 2;
  t.view.devicePixelRatio = 2;
  addTearDown(t.view.reset);
  await t.pumpWidget(ChangeNotifierProvider(
    create: (_) => InfluencerProvider(repository: repo),
    child: MaterialApp(
      theme: ThemeData(brightness: b, fontFamily: 'Roboto'),
      builder: (c, child) => MediaQuery(
          data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!),
      home: screen,
    ),
  ));
  if (settle) {
    await t.pumpAndSettle();
  } else {
    await t.pump();
  }
}

void main() {
  setUpAll(loadRealFonts);
  group('InfluencerDashboardScreen', () {
    testWidgets('loads for the given user and shows the totals and codes',
        (t) async {
      final repo = _Repo()..report = _report();
      await _pump(t, repo, const InfluencerDashboardScreen(userId: 'u1'));
      expect(repo.calls, ['report:u1:all']);
      expect(find.text('PKR 123456.78'), findsOneWidget);
      expect(find.text('SARA20'), findsOneWidget);
      expect(find.text('Top Influencer Codes'), findsOneWidget);
    });

    testWidgets('shows each currency on its own line, never one mixed total',
        (t) async {
      final repo = _Repo()..report = _report();
      await _pump(t, repo, const InfluencerDashboardScreen(userId: 'u1'));
      expect(find.text('PKR 123456.78'), findsOneWidget);
      expect(find.text('USD 41.50'), findsWidgets);
      // The code row lists both of its currencies and per-currency averages.
      expect(find.textContaining('avg PKR'), findsWidgets);
      expect(find.textContaining('USD 15.00'), findsOneWidget);
    });

    testWidgets('shows a spinner while loading', (t) async {
      final repo = _Repo()
        ..report = _report()
        ..gate = Completer<void>();
      await _pump(t, repo, const InfluencerDashboardScreen(userId: 'u1'),
          settle: false);
      await t.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      repo.gate!.complete();
      await t.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('shows the error when loading fails', (t) async {
      final repo = _Repo()..error = Exception('offline');
      await _pump(t, repo, const InfluencerDashboardScreen(userId: 'u1'));
      expect(find.text('Error Loading Revenue'), findsOneWidget);
      expect(find.textContaining('offline'), findsOneWidget);
    });

    testWidgets('says so when there is no data for the period', (t) async {
      final repo = _Repo()..report = _report(codes: []);
      await _pump(t, repo, const InfluencerDashboardScreen(userId: 'u1'));
      expect(find.textContaining('No revenue data available'), findsOneWidget);
    });

    testWidgets('changing the period reloads with a date range', (t) async {
      final repo = _Repo()..report = _report();
      await _pump(t, repo, const InfluencerDashboardScreen(userId: 'u1'));
      await t.tap(find.widgetWithText(ElevatedButton, 'This Year'));
      await t.pumpAndSettle();
      expect(repo.calls.last, 'report:u1:range');
    });

    testWidgets('This Year and This Month start on calendar boundaries',
        (t) async {
      final repo = _Repo()..report = _report();
      await _pump(t, repo, const InfluencerDashboardScreen(userId: 'u1'));
      final now = DateTime.now();
      await t.tap(find.widgetWithText(ElevatedButton, 'This Year'));
      await t.pumpAndSettle();
      expect(repo.starts.last, DateTime(now.year, 1, 1));
      await t.tap(find.widgetWithText(ElevatedButton, 'This Month'));
      await t.pumpAndSettle();
      expect(repo.starts.last, DateTime(now.year, now.month, 1));
      await t.tap(find.widgetWithText(ElevatedButton, 'All Time'));
      await t.pumpAndSettle();
      expect(repo.starts.last, isNull);
    });

    testWidgets('opening a code shows its details for that code', (t) async {
      final repo = _Repo()
        ..report = _report()
        ..revenues = [_rev(1), _rev(2)];
      await _pump(t, repo, const InfluencerDashboardScreen(userId: 'u1'));
      await t.tap(find.text('SARA20'));
      await t.pumpAndSettle();
      expect(find.text('SARA20 Revenue'), findsOneWidget);
      expect(repo.calls, contains('code:u1:SARA20'));
    });
  });

  group('RevenueDetailsScreen', () {
    testWidgets('lists the transactions with a total and plan counts',
        (t) async {
      final repo = _Repo()..revenues = [_rev(1), _rev(2), _rev(3)];
      await _pump(t, repo,
          const RevenueDetailsScreen(influencerCode: 'SARA20', userId: 'u1'));
      expect(repo.calls, ['code:u1:SARA20']);
      expect(find.text('PKR 600.00'), findsOneWidget);
      expect(find.text('Recent Transactions'), findsOneWidget);
      expect(find.text('Conversions by Plan'), findsOneWidget);
    });

    testWidgets('keeps currencies apart in totals, averages and rows',
        (t) async {
      final repo = _Repo()
        ..revenues = [
          _rev(1),
          _rev(2),
          _rev(3, currency: 'USD'),
          _rev(4, currency: 'usd')
        ];
      await _pump(t, repo,
          const RevenueDetailsScreen(influencerCode: 'SARA20', userId: 'u1'));
      expect(find.text('PKR 300.00'), findsOneWidget); // 100 + 200
      expect(find.text('USD 700.00'),
          findsOneWidget); // 300 + 400, code case ignored
      expect(find.text('PKR 150.00'),
          findsOneWidget); // average of the two PKR rows
      expect(
          find.text('USD 350.00'), findsWidgets); // average of the two USD rows
      expect(find.text('PKR 1000.00'), findsNothing, reason: 'no mixed total');
    });

    testWidgets('shows a spinner, then the empty state', (t) async {
      final repo = _Repo()..gate = Completer<void>();
      await _pump(t, repo,
          const RevenueDetailsScreen(influencerCode: 'SARA20', userId: 'u1'),
          settle: false);
      await t.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      repo.gate!.complete();
      await t.pumpAndSettle();
      expect(find.text('No Data Available'), findsOneWidget);
    });

    testWidgets('shows the error when loading fails', (t) async {
      final repo = _Repo()..error = Exception('boom');
      await _pump(t, repo,
          const RevenueDetailsScreen(influencerCode: 'SARA20', userId: 'u1'));
      expect(find.textContaining('boom'), findsOneWidget);
    });

    testWidgets('export is announced as coming soon, not silently ignored',
        (t) async {
      final repo = _Repo()..revenues = [_rev(1)];
      await _pump(t, repo,
          const RevenueDetailsScreen(influencerCode: 'SARA20', userId: 'u1'));
      await t.ensureVisible(find.text('Export Data'));
      await t.tap(find.text('Export Data'));
      await t.pumpAndSettle();
      await t.tap(find.text('Export'));
      await t.pumpAndSettle();
      expect(find.text('Export feature coming soon'), findsOneWidget);
    });
  });

  for (final scale in [1.0, 1.5, 2.0]) {
    for (final b in [Brightness.light, Brightness.dark]) {
      testWidgets('no overflow on a small phone: text x$scale, $b', (t) async {
        final repo = _Repo()
          ..report = _report()
          ..revenues = List.generate(4, _rev);
        await _pump(t, repo, const InfluencerDashboardScreen(userId: 'u1'),
            scale: scale, b: b);
        expect(t.takeException(), isNull, reason: 'dashboard');
        await t.ensureVisible(find.text('SARA20'));
        await t.tap(find.text('SARA20'));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull, reason: 'details');
        Navigator.of(t.element(find.byType(Scaffold).last)).pop();
        await t.pumpAndSettle();
        await t.ensureVisible(find.text(_long));
        await t.tap(find.text(_long));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull, reason: 'details with a long code');
      });
    }
  }
}
