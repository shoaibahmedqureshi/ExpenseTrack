import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import 'core/constants/app_constants.dart';
import 'core/database/database_helper.dart';
import 'core/supabase/supabase_config.dart';
import 'core/theme/app_theme.dart';

import 'features/auth/data/auth_repository_impl.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/auth/presentation/screens/login_screen.dart';

import 'features/categories/data/repositories/category_repository_impl.dart';
import 'features/categories/presentation/providers/category_provider.dart';

import 'features/expenses/data/datasources/expense_local_datasource.dart';
import 'features/expenses/data/repositories/expense_repository_impl.dart';
import 'features/expenses/domain/usecases/get_expenses_usecase.dart';
import 'features/expenses/domain/usecases/manage_expense_usecase.dart';
import 'features/expenses/presentation/providers/expense_provider.dart';

import 'features/budgets/data/datasources/budget_local_datasource.dart';
import 'features/budgets/data/repositories/budget_repository_impl.dart';
import 'features/budgets/domain/usecases/get_budgets_usecase.dart';
import 'features/budgets/domain/usecases/manage_budget_usecase.dart';
import 'features/budgets/presentation/providers/budget_provider.dart';

import 'features/onboarding/presentation/screens/onboarding_screen.dart';
import 'features/dashboard/presentation/screens/dashboard_screen.dart';
import 'features/reports/presentation/providers/reports_provider.dart';
import 'features/sync/sync_service.dart';
import 'features/subscription/data/subscription_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.anonKey,
  );

  final db = await DatabaseHelper.instance.database;
  final prefs = await SharedPreferences.getInstance();
  final onboardingDone = prefs.getBool(AppConstants.prefOnboardingDone) ?? false;

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider(
            AuthRepositoryImpl(Supabase.instance.client),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => SubscriptionService(prefs),
        ),
        ChangeNotifierProvider(
          create: (_) => CategoryProvider(CategoryRepositoryImpl(db)),
        ),
        ChangeNotifierProvider(
          create: (_) {
            final datasource = ExpenseLocalDatasource(db);
            final repo = ExpenseRepositoryImpl(datasource);
            return ExpenseProvider(
              getExpenses: GetExpensesUsecase(repo),
              manageExpense: ManageExpenseUsecase(repo),
            );
          },
        ),
        ChangeNotifierProvider(
          create: (_) {
            final datasource = ExpenseLocalDatasource(db);
            final repo = ExpenseRepositoryImpl(datasource);
            return ReportsProvider(getExpenses: GetExpensesUsecase(repo));
          },
        ),
        ChangeNotifierProvider(
          create: (_) {
            final budgetRepo = BudgetRepositoryImpl(BudgetLocalDatasource(db));
            final expenseRepo =
                ExpenseRepositoryImpl(ExpenseLocalDatasource(db));
            return BudgetProvider(
              getBudgets: GetBudgetsUsecase(budgetRepo),
              manageBudget: ManageBudgetUsecase(budgetRepo),
              getExpenses: GetExpensesUsecase(expenseRepo),
            );
          },
        ),
      ],
      child: OutlayApp(
        db: db,
        onboardingDone: onboardingDone,
      ),
    ),
  );
}

class OutlayApp extends StatefulWidget {
  const OutlayApp({
    super.key,
    required this.db,
    required this.onboardingDone,
  });

  final dynamic db;
  final bool onboardingDone;

  @override
  State<OutlayApp> createState() => _OutlayAppState();
}

class _OutlayAppState extends State<OutlayApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: _RootRouter(
        db: widget.db,
        onboardingDone: widget.onboardingDone,
      ),
    );
  }
}

/// Listens to auth state and routes to the correct first screen.
class _RootRouter extends StatefulWidget {
  const _RootRouter({required this.db, required this.onboardingDone});
  final dynamic db;
  final bool onboardingDone;

  @override
  State<_RootRouter> createState() => _RootRouterState();
}

class _RootRouterState extends State<_RootRouter> {
  late bool _onboardingDone;

  @override
  void initState() {
    super.initState();
    _onboardingDone = widget.onboardingDone;
    _listenConnectivity();
  }

  void _listenConnectivity() {
    Connectivity().onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (online) {
        SyncService(widget.db, Supabase.instance.client).run();
      }
    });
  }

  void _onOnboardingDone() {
    setState(() => _onboardingDone = true);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return switch (auth.status) {
      AuthStatus.unknown => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      AuthStatus.unauthenticated => _onboardingDone
          ? const LoginScreen()
          : OnboardingScreen(onDone: _onOnboardingDone),
      AuthStatus.authenticated => const DashboardScreen(),
    };
  }
}
