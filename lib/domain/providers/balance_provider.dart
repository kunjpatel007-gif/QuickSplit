import 'package:flutter/material.dart';
import 'package:campus_quicksplit/data/models/models.dart';
import 'package:campus_quicksplit/data/repositories/repositories.dart';
import 'package:campus_quicksplit/domain/services/services.dart';
import 'package:campus_quicksplit/domain/services/widget_service.dart';

class BalanceProvider extends ChangeNotifier {
  final ExpenseRepository _expenseRepository;
  final BalanceService _balanceService;
  final SettingsRepository _settingsRepository;

  Map<int, double> _balances = {};
  double _totalSpending = 0;
  List<ExpenseSplit> _allSplits = [];

  BalanceProvider({
    required ExpenseRepository expenseRepo,
    required BalanceService balanceService,
    required SettingsRepository settingsRepo,
  }) : _expenseRepository = expenseRepo,
       _balanceService = balanceService,
       _settingsRepository = settingsRepo;

  Map<int, double> get balances => Map.unmodifiable(_balances);
  double get totalSpending => _totalSpending;
  List<ExpenseSplit> get allSplits => List.unmodifiable(_allSplits);

  Future<void> recalculateBalances() async {
    final allPayers = await _expenseRepository.getAllActivePayers();
    final allSplits = await _expenseRepository.getAllActiveSplits();
    _allSplits = allSplits;
    final activeExpenses = await _expenseRepository.getAllActiveExpenses();

    _balances = _balanceService.calculateNetBalances(allPayers, allSplits);
    _totalSpending = _balanceService.getTotalGroupSpending(activeExpenses);

    // Update the Android Home Screen Widget with the current user's balance
    final currentUserIdStr = await _settingsRepository.getSetting('current_user_id');
    final currentUserId = currentUserIdStr != null ? int.tryParse(currentUserIdStr) ?? 1 : 1;
    double myBalance = _balances[currentUserId] ?? 0.0;
    WidgetService.updateBalanceWidget(myBalance);

    notifyListeners();
  }

  double getBalanceForUser(int userId) {
    return _balances[userId] ?? 0.0;
  }
}
