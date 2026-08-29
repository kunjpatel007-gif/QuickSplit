import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:campus_quicksplit/main.dart' as app;
import 'package:campus_quicksplit/core/utils/test_data_seeder.dart';
import 'package:campus_quicksplit/data/repositories/expense_repository.dart';
import 'package:campus_quicksplit/data/repositories/user_repository.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('End-to-End App Test', () {
    testWidgets('Seed Database and Verify App Does Not Crash Under Load', (tester) async {
      // Launch the app
      app.main();
      await tester.pumpAndSettle();

      // Wait for DB init
      await Future.delayed(const Duration(seconds: 2));

      // Retrieve repositories (assuming they are registered or we instantiate them directly)
      // Since they are Singletons or instantiated in main, we can create new instances for the seeder
      final userRepo = UserRepository();
      final expenseRepo = ExpenseRepository();
      
      // Seed 1,000 expenses and 20 edge-case users directly into the DB
      await TestDataSeeder.seedDatabase(userRepo, expenseRepo, expenseCount: 1000);

      // Trigger a hot reload / state refresh to load the new data
      // For testing, we tap the 'Analytics' tab and come back to force reload
      final analyticsTab = find.byIcon(Icons.pie_chart);
      if (analyticsTab.evaluate().isNotEmpty) {
        await tester.tap(analyticsTab);
        await tester.pumpAndSettle(const Duration(seconds: 2));
      }

      final homeTab = find.byIcon(Icons.dashboard);
      if (homeTab.evaluate().isNotEmpty) {
        await tester.tap(homeTab);
        await tester.pumpAndSettle(const Duration(seconds: 2));
      }

      // Verify the UI doesn't crash and renders the list
      expect(find.byType(ListView), findsWidgets);
      
      // Try scrolling to test pagination performance
      final listFinder = find.byType(ListView).first;
      await tester.fling(listFinder, const Offset(0, -500), 10000);
      await tester.pumpAndSettle();
      
      // Fling again to load more
      await tester.fling(listFinder, const Offset(0, -500), 10000);
      await tester.pumpAndSettle();

      // Verify a seeded expense is visible
      expect(find.textContaining('Seeded Expense'), findsWidgets);
    });
  });
}
