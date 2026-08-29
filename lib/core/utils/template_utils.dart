import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:campus_quicksplit/data/models/models.dart';
import 'package:campus_quicksplit/domain/providers/expense_provider.dart';
import 'package:campus_quicksplit/domain/providers/user_provider.dart';
import 'package:campus_quicksplit/domain/providers/balance_provider.dart';

class TemplateUtils {
  /// Applies a template, creates an expense, and logs it into the database.
  static Future<void> applyTemplate(BuildContext context, ExpenseTemplate template) async {
    final expense = Expense(
      title: template.title,
      totalAmount: template.amount,
      category: template.category,
      timestamp: DateTime.now(),
      isRecurring: false,
      isDeleted: false,
    );

    final List<dynamic> parsedPayers = jsonDecode(template.payersJson);
    final List<dynamic> parsedSplits = jsonDecode(template.splitsJson);

    final payers = parsedPayers.map((e) => ExpensePayer(
      expenseId: 0,
      userId: e['userId'] as int,
      amountPaid: (e['amountPaid'] as num).toDouble(),
    )).toList();

    final splits = parsedSplits.map((e) => ExpenseSplit(
      expenseId: 0,
      userId: e['userId'] as int,
      amountOwed: (e['amountOwed'] as num).toDouble(),
    )).toList();

    final userProv = context.read<UserProvider>();
    final currentUserId = userProv.currentUser?.id ?? 0;

    await context.read<ExpenseProvider>().addExpense(
      expense: expense,
      payers: payers.isEmpty
          ? [ExpensePayer(expenseId: 0, userId: currentUserId, amountPaid: template.amount)]
          : payers,
      splits: splits.isEmpty
          ? [ExpenseSplit(expenseId: 0, userId: currentUserId, amountOwed: template.amount)]
          : splits,
    );
    await context.read<BalanceProvider>().recalculateBalances();
  }
}
