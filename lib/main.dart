import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:workmanager/workmanager.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:campus_quicksplit/data/database/database_helper.dart';
import 'package:campus_quicksplit/data/repositories/repositories.dart';
import 'package:campus_quicksplit/domain/providers/providers.dart';
import 'package:campus_quicksplit/domain/services/services.dart';
import 'package:campus_quicksplit/app.dart';
import 'package:campus_quicksplit/data/models/models.dart';

// ---------------------------------------------------------------------------
// GHOST SUBSCRIPTIONS — background task identifiers
// ---------------------------------------------------------------------------
const String kRecurringExpenseTaskName = 'com.campusquicksplit.recurringExpenseCheck';
const String kRecurringExpenseUniqueId = 'recurring-expense-check';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task != kRecurringExpenseTaskName) {
      return Future.value(true);
    }

    try {
      WidgetsFlutterBinding.ensureInitialized();

      final dbHelper = DatabaseHelper();
      await dbHelper.database;

      final expenseRepo = ExpenseRepository();
      final inserted = await _duplicateDueRecurringExpenses(expenseRepo);

      // Send a local push notification for each auto-logged expense
      if (inserted.isNotEmpty) {
        final notificationsPlugin = FlutterLocalNotificationsPlugin();
        const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
        await notificationsPlugin.initialize(
          const InitializationSettings(android: androidSettings),
        );

        for (int i = 0; i < inserted.length; i++) {
          final exp = inserted[i];
          await notificationsPlugin.show(
            i + 1000, // unique notification ID
            '💰 Recurring Expense Logged',
            '"${exp.title}" — ₹${exp.totalAmount.toStringAsFixed(2)} has been auto-logged.',
            const NotificationDetails(
              android: AndroidNotificationDetails(
                'ghost_subscriptions',
                'Ghost Subscriptions',
                channelDescription: 'Notifications for auto-logged recurring expenses',
                importance: Importance.defaultImportance,
                priority: Priority.defaultPriority,
              ),
            ),
          );
        }
      }

      return Future.value(true);
    } catch (e, st) {
      debugPrint('Ghost Subscriptions task failed: $e\n$st');
      return Future.value(false);
    }
  });
}

/// Returns the list of expenses that were duplicated.
Future<List<Expense>> _duplicateDueRecurringExpenses(ExpenseRepository expenseRepo) async {
  final recurringExpenses = await expenseRepo.getRecurringExpenses();
  final now = DateTime.now();
  final List<Expense> inserted = [];

  for (final expense in recurringExpenses) {
    final monthsElapsed = (now.year - expense.timestamp.year) * 12 +
        (now.month - expense.timestamp.month);

    if (monthsElapsed >= 1) {
      final duplicated = Expense(
        title: expense.title,
        totalAmount: expense.totalAmount,
        category: expense.category,
        timestamp: DateTime(now.year, now.month, expense.timestamp.day),
        isRecurring: true,
        isDeleted: false,
      );
      await expenseRepo.insertExpense(duplicated);
      inserted.add(duplicated);
    }
  }
  return inserted;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final dbHelper = DatabaseHelper();
  await dbHelper.database;

  final userRepo = UserRepository();
  final expenseRepo = ExpenseRepository();
  final auditRepo = AuditRepository();
  final templateRepo = TemplateRepository();
  final settingsRepo = SettingsRepository();

  final auditService = AuditService();
  final balanceService = BalanceService();

  final themeProvider = ThemeProvider(settingsRepo);
  await themeProvider.loadTheme();

  final userProvider = UserProvider(userRepo);
  await userProvider.loadUsers();
  await userProvider.loadCurrentUser(settingsRepo);

  final expenseProvider = ExpenseProvider(
    expenseRepo: expenseRepo,
    auditRepo: auditRepo,
    auditService: auditService,
  );
  await expenseProvider.loadExpenses();

  final balanceProvider = BalanceProvider(
    expenseRepo: expenseRepo,
    balanceService: balanceService,
    userRepo: userRepo,
  );
  await balanceProvider.recalculateBalances();

  final templateProvider = TemplateProvider(templateRepo);
  await templateProvider.loadTemplates();

  // ---------------------------------------------------------------------
  // GHOST SUBSCRIPTIONS — register the periodic background task.
  // Android enforces a minimum periodic interval of 15 minutes; we use
  // 12 hours since this only needs to catch a monthly rollover.
  // ---------------------------------------------------------------------
  await Workmanager().initialize(
    callbackDispatcher,
    isInDebugMode: false,
  );
  await Workmanager().registerPeriodicTask(
    kRecurringExpenseUniqueId,
    kRecurringExpenseTaskName,
    frequency: const Duration(hours: 12),
    constraints: Constraints(
      networkType: NetworkType.notRequired,
      requiresBatteryNotLow: true,
    ),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider.value(value: userProvider),
        ChangeNotifierProvider.value(value: expenseProvider),
        ChangeNotifierProvider.value(value: balanceProvider),
        ChangeNotifierProvider.value(value: templateProvider),
        Provider.value(value: auditService),
        Provider.value(value: balanceService),
        Provider.value(value: auditRepo),
        Provider.value(value: expenseRepo),
        Provider.value(value: userRepo),
        Provider.value(value: settingsRepo),
        Provider.value(value: templateRepo),
      ],
      child: const CampusQuickSplitApp(),
    ),
  );
}
