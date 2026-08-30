import 'package:flutter/material.dart';
import 'package:campus_quicksplit/data/models/models.dart';
import 'package:campus_quicksplit/data/repositories/repositories.dart';
import 'package:campus_quicksplit/domain/services/services.dart';
import 'package:campus_quicksplit/core/constants/app_constants.dart';

class ExpenseProvider extends ChangeNotifier {
  final ExpenseRepository _expenseRepository;
  final AuditRepository _auditRepository;
  final AuditService _auditService;

  List<Expense> _expenses = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentOffset = 0;

  ExpenseProvider({
    required ExpenseRepository expenseRepo,
    required AuditRepository auditRepo,
    required AuditService auditService,
  })  : _expenseRepository = expenseRepo,
        _auditRepository = auditRepo,
        _auditService = auditService;

  List<Expense> get expenses => List.unmodifiable(_expenses);
  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;
  int get currentOffset => _currentOffset;

  Future<void> loadExpenses() async {
    _isLoading = true;
    _currentOffset = 0;
    notifyListeners();

    _expenses = await _expenseRepository.getAllActiveExpenses(
      limit: AppConstants.defaultPageSize,
      offset: _currentOffset,
    );
    _hasMore = _expenses.length == AppConstants.defaultPageSize;
    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadMoreExpenses() async {
    if (_isLoading || !_hasMore) return;

    _isLoading = true;
    _currentOffset += AppConstants.defaultPageSize;
    notifyListeners();

    final newExpenses = await _expenseRepository.getAllActiveExpenses(
      limit: AppConstants.defaultPageSize,
      offset: _currentOffset,
    );

    _expenses = List.from(_expenses)..addAll(newExpenses);
    _hasMore = newExpenses.length == AppConstants.defaultPageSize;
    _isLoading = false;
    notifyListeners();
  }

  Future<int> addExpense({
    required Expense expense,
    required List<ExpensePayer> payers,
    required List<ExpenseSplit> splits,
  }) async {
    final exists = await _expenseRepository.doesExpenseTitleExist(expense.title);
    if (exists) {
      return -1; // Duplicate title, skip silently
    }

    final expenseId = await _expenseRepository.insertExpense(expense);

    for (var payer in payers) {
      final newPayer = ExpensePayer(
        expenseId: expenseId,
        userId: payer.userId,
        amountPaid: payer.amountPaid,
      );
      await _expenseRepository.insertExpensePayer(newPayer);
    }
    for (var split in splits) {
      final newSplit = ExpenseSplit(
        expenseId: expenseId,
        userId: split.userId,
        amountOwed: split.amountOwed,
      );
      await _expenseRepository.insertExpenseSplit(newSplit);
    }

    final auditEntry = await _auditService.createAuditEntry(
      expenseId: expenseId,
      actionType: 'CREATED',
      newAmount: expense.totalAmount,
      auditRepo: _auditRepository,
    );
    await _auditRepository.insertAuditLog(auditEntry);

    await loadExpenses();
    return expenseId;
  }

  Future<void> softDeleteExpense(int id) async {
    final expense = await _expenseRepository.getExpenseById(id);
    await _expenseRepository.softDeleteExpense(id);
    final auditEntry = await _auditService.createAuditEntry(
      expenseId: id,
      actionType: 'MOVED_TO_BIN',
      previousAmount: expense?.totalAmount,
      auditRepo: _auditRepository,
    );
    await _auditRepository.insertAuditLog(auditEntry);
    await loadExpenses();
  }

  Future<void> restoreExpense(int id) async {
    final expense = await _expenseRepository.getExpenseById(id);
    await _expenseRepository.restoreExpense(id);
    final auditEntry = await _auditService.createAuditEntry(
      expenseId: id,
      actionType: 'RESTORED',
      newAmount: expense?.totalAmount,
      auditRepo: _auditRepository,
    );
    await _auditRepository.insertAuditLog(auditEntry);
    await loadExpenses();
  }

  Future<void> updateExpense({
    required Expense expense,
    required List<ExpensePayer> payers,
    required List<ExpenseSplit> splits,
    required double previousAmount,
  }) async {
    await _expenseRepository.updateExpense(expense);

    // Clear old payers and splits correctly using the new repository methods
    await _expenseRepository.deleteExpensePayers(expense.id!);
    await _expenseRepository.deleteExpenseSplits(expense.id!);

    for (var payer in payers) {
      final newPayer = ExpensePayer(
        expenseId: expense.id!,
        userId: payer.userId,
        amountPaid: payer.amountPaid,
      );
      await _expenseRepository.insertExpensePayer(newPayer);
    }
    for (var split in splits) {
      final newSplit = ExpenseSplit(
        expenseId: expense.id!,
        userId: split.userId,
        amountOwed: split.amountOwed,
      );
      await _expenseRepository.insertExpenseSplit(newSplit);
    }

    final auditEntry = await _auditService.createAuditEntry(
      expenseId: expense.id!,
      actionType: 'UPDATED',
      previousAmount: previousAmount,
      newAmount: expense.totalAmount,
      auditRepo: _auditRepository,
    );
    await _auditRepository.insertAuditLog(auditEntry);

    await loadExpenses();
  }

  Future<void> permanentlyDeleteExpense(int id, {bool reload = true}) async {
    final expense = await _expenseRepository.getExpenseById(id);
    await _expenseRepository.permanentlyDeleteExpense(id);
    
    // Log the permanent deletion in the audit trail before the expense is gone forever
    if (expense != null) {
      final auditEntry = await _auditService.createAuditEntry(
        expenseId: id,
        actionType: 'PERMANENTLY_DELETED',
        previousAmount: expense.totalAmount,
        auditRepo: _auditRepository,
      );
      await _auditRepository.insertAuditLog(auditEntry);
    }
    
    if (reload) {
      await loadExpenses();
    }
  }
}
