import 'package:flutter/material.dart';
import 'package:campus_quicksplit/data/repositories/repositories.dart';
import 'package:campus_quicksplit/domain/services/services.dart';
import 'package:campus_quicksplit/domain/services/widget_service.dart';

class BalanceProvider extends ChangeNotifier {
  final ExpenseRepository _expenseRepository;
  final BalanceService _balanceService;

  Map<int, double> _balances = {};
  double _totalSpending = 0;

  BalanceProvider({
    required ExpenseRepository expenseRepo,
    required BalanceService balanceService,
  })  : _expenseRepository = expenseRepo,
        _balanceService = balanceService;

  Map<int, double> get balances => Map.unmodifiable(_balances);
  double get totalSpending => _totalSpending;

  Future<void> recalculateBalances() async {
    final allPayers = await _expenseRepository.getAllActivePayers();
    final allSplits = await _expenseRepository.getAllActiveSplits();
    final activeExpenses = await _expenseRepository.getAllActiveExpenses();

    _balances = _balanceService.calculateNetBalances(allPayers, allSplits);
    _totalSpending = _balanceService.getTotalGroupSpending(activeExpenses);

    // Update the Android Home Screen Widget with the current user's balance
    // (Assuming current user is ID 1 for now, or just the net sum)
    double myBalance = _balances[1] ?? 0.0;
    WidgetService.updateBalanceWidget(myBalance);

    notifyListeners();
  }

  double getBalanceForUser(int userId) {
    return _balances[userId] ?? 0.0;
  }
}
