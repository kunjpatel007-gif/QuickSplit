import 'dart:math';
import 'package:campus_quicksplit/data/models/models.dart';
import 'package:campus_quicksplit/data/repositories/expense_repository.dart';
import 'package:campus_quicksplit/data/repositories/user_repository.dart';

class TestDataSeeder {
  static final _random = Random();

  /// Seed the database with thousands of complex expenses and edge-case users
  static Future<void> seedDatabase(
    UserRepository userRepo,
    ExpenseRepository expenseRepo, {
    int expenseCount = 1000,
    int userCount = 20,
  }) async {
    // 1. Generate edge-case users
    final generatedUsers = <User>[];
    for (int i = 0; i < userCount; i++) {
      String name = 'TestUser$i';
      if (i == 0) name = 'Mr. Edge Case With An Extremely Long Name That Might Break The UI';
      if (i == 1) name = 'Emoji 😎 User';
      
      final u = User(
        name: name,
        syncId: 'sync-test-$i',
        upiId: 'test$i@okbank',
        createdAt: DateTime.now(),
      );
      final id = await userRepo.insertUser(u);
      generatedUsers.add(u.copyWith(id: id));
    }

    // 2. Generate Expenses
    for (int i = 0; i < expenseCount; i++) {
      final totalAmount = _random.nextDouble() * 5000 + 10;
      final e = Expense(
        title: 'Seeded Expense $i',
        totalAmount: totalAmount,
        category: 'Test Category',
        timestamp: DateTime.now().subtract(Duration(days: _random.nextInt(365))),
        isRecurring: _random.nextBool(),
        isDeleted: false,
      );

      // Generate random payers (1 to 3 payers)
      int numPayers = _random.nextInt(3) + 1;
      List<ExpensePayer> payers = [];
      double remainingPaid = totalAmount;
      for (int p = 0; p < numPayers; p++) {
        final u = generatedUsers[_random.nextInt(generatedUsers.length)];
        if (p == numPayers - 1) {
          payers.add(ExpensePayer(expenseId: 0, userId: u.id!, amountPaid: remainingPaid));
        } else {
          final amt = remainingPaid * _random.nextDouble() * 0.5;
          payers.add(ExpensePayer(expenseId: 0, userId: u.id!, amountPaid: amt));
          remainingPaid -= amt;
        }
      }

      // Generate random splits (2 to 15 people to test massive groups and rounding)
      int numSplits = _random.nextInt(14) + 2;
      List<ExpenseSplit> splits = [];
      double splitAmount = totalAmount / numSplits;
      
      // Intentional rounding edge case simulation
      final selectedUsers = (generatedUsers.toList()..shuffle()).take(numSplits).toList();
      for (int s = 0; s < numSplits; s++) {
        splits.add(ExpenseSplit(expenseId: 0, userId: selectedUsers[s].id!, amountOwed: splitAmount));
      }

      await expenseRepo.insertExpenseWithDetails(e, payers, splits);
    }
  }
}
