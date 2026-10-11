import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:outlay/core/constants/app_constants.dart';
import 'package:outlay/features/auth/domain/entities/user_profile.dart';
import 'package:outlay/features/auth/domain/repositories/auth_repository.dart';
import 'package:outlay/features/auth/presentation/providers/auth_provider.dart';
import 'package:outlay/features/family_accounts/domain/repositories/family_repository.dart';
import 'package:outlay/features/family_accounts/presentation/providers/family_provider.dart';
import 'package:outlay/features/growth/data/growth_repository.dart';
import 'package:outlay/features/growth/domain/growth_models.dart';
import 'package:outlay/features/growth/presentation/providers/growth_provider.dart';
import 'package:outlay/features/settings/presentation/screens/account_settings_screen.dart';
import 'package:outlay/features/settings/presentation/screens/more_screen.dart';
import 'package:outlay/features/subscription/data/subscription_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Auth implements AuthRepository {
  int signOuts = 0;
  @override
  Stream<UserProfile?> get authStateChanges => const Stream.empty();
  @override
  Future<void> signOut() async => signOuts++;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Family implements FamilyRepository {
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Growth implements GrowthRepository {
  _Growth(this.admin);
  final bool admin;
  @override
  Future<bool> isAdmin() async => admin;
  @override
  Future<List<OutreachTask>> tasks() async => [];
  @override
  Future<List<CreatorApplication>> applications() async => [];
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

const _accountOnly = [
  'Privacy Policy',
  'Terms of Service',
  'Delete Account',
  'Sign Out',
];
const _featuresOnly = [
  'Accounts',
  'Transactions',
  'Budgets',
  'Reports',
  'Family sharing (MAX)',
  'Pending Invitations',
];

Future<void> _pumpMore(WidgetTester t, {bool admin = false}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final growth = GrowthProvider(repository: _Growth(admin));
  await growth.checkAdmin();
  t.view.physicalSize = const Size(390, 2400) * 2;
  t.view.devicePixelRatio = 2;
  addTearDown(t.view.reset);
  await t.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider<SubscriptionService>(
          create: (_) => SubscriptionService(prefs, debugProducts: const [])),
      ChangeNotifierProvider<FamilyProvider>(
          create: (_) => FamilyProvider(
              repository: _Family(), getCurrentUserId: () => 'me')),
      ChangeNotifierProvider<GrowthProvider>.value(value: growth),
    ],
    child: const MaterialApp(home: MoreScreen(userEmail: 'a@b.co')),
  ));
  await t.pumpAndSettle();
}

Future<_Auth> _pumpAccount(WidgetTester t) async {
  final repo = _Auth();
  t.view.physicalSize = const Size(390, 2400) * 2;
  t.view.devicePixelRatio = 2;
  addTearDown(t.view.reset);
  await t.pumpWidget(ChangeNotifierProvider<AuthProvider>(
    create: (_) => AuthProvider(repo),
    child: const MaterialApp(home: AccountSettingsScreen()),
  ));
  await t.pumpAndSettle();
  return repo;
}

void main() {
  group('More tab', () {
    testWidgets('is titled More and lists the features', (t) async {
      await _pumpMore(t);
      expect(find.text('More'), findsOneWidget);
      for (final f in _featuresOnly) {
        expect(find.text(f), findsOneWidget, reason: f);
      }
    });

    testWidgets('no longer holds app preferences or account actions',
        (t) async {
      await _pumpMore(t);
      for (final f in _accountOnly) {
        expect(find.text(f), findsNothing, reason: f);
      }
    });

    testWidgets('shows the Growth section only to admins', (t) async {
      await _pumpMore(t);
      expect(find.text('Creator outreach'), findsNothing);
      await _pumpMore(t, admin: true);
      expect(find.text('Creator outreach'), findsOneWidget);
    });
  });

  group('Settings under Profile', () {
    testWidgets(
        'holds the legal pages, version and account actions',
        (t) async {
      await _pumpAccount(t);
      expect(find.text('Settings'), findsOneWidget);
      for (final f in _accountOnly) {
        expect(find.text(f), findsOneWidget, reason: f);
      }
      expect(find.text(AppConstants.versionLabel), findsOneWidget);
    });

    testWidgets('hides Language and Theme until they do something', (t) async {
      await _pumpAccount(t);
      expect(find.text('Language'), findsNothing);
      expect(find.text('Theme'), findsNothing);
      expect(find.text('App'), findsNothing, reason: 'no empty App section');
    });

    testWidgets('does not list the feature screens', (t) async {
      await _pumpAccount(t);
      for (final f in _featuresOnly) {
        expect(find.text(f), findsNothing, reason: f);
      }
    });

    testWidgets('sign out asks first and does nothing if cancelled', (t) async {
      final repo = await _pumpAccount(t);
      await t.tap(find.widgetWithText(OutlinedButton, 'Sign Out'));
      await t.pumpAndSettle();
      expect(find.text('Are you sure you want to sign out?'), findsOneWidget);
      await t.tap(find.text('Cancel'));
      await t.pumpAndSettle();
      expect(repo.signOuts, 0);
    });

    testWidgets('sign out signs the user out once confirmed', (t) async {
      final repo = await _pumpAccount(t);
      await t.tap(find.widgetWithText(OutlinedButton, 'Sign Out'));
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(FilledButton, 'Sign Out'));
      await t.pumpAndSettle();
      expect(repo.signOuts, 1);
    });

    testWidgets('delete account asks for confirmation before anything happens',
        (t) async {
      await _pumpAccount(t);
      await t.tap(find.text('Delete Account'));
      await t.pumpAndSettle();
      expect(find.textContaining('permanently delete your account'),
          findsOneWidget);
      expect(find.text('Request Deletion'), findsOneWidget);
    });
  });
}
