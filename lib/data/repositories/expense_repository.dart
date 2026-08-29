import '../database/database_helper.dart';
import '../models/expense.dart';
import '../models/expense_payer.dart';
import '../models/expense_split.dart';

class ExpenseRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<int> insertExpense(Expense expense) async {
    final db = await _dbHelper.database;
    return await db.insert('Expenses', expense.toMap());
  }

  Future<List<Expense>> getAllActiveExpenses({
    int limit = 20,
    int offset = 0,
  }) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'Expenses',
      where: 'is_deleted = ?',
      whereArgs: [0],
      orderBy: 'timestamp DESC',
      limit: limit,
      offset: offset,
    );
    return maps.map((map) => Expense.fromMap(map)).toList();
  }

  Future<List<Expense>> getAllExpensesHistorical() async {
    final db = await _dbHelper.database;
    final maps = await db.query('Expenses', orderBy: 'timestamp DESC');
    return maps.map((map) => Expense.fromMap(map)).toList();
  }

  Future<List<Expense>> getDeletedExpenses() async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'Expenses',
      where: 'is_deleted = ?',
      whereArgs: [1],
      orderBy: 'timestamp DESC',
    );
    return maps.map((map) => Expense.fromMap(map)).toList();
  }

  Future<List<Expense>> getRecurringExpenses() async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'Expenses',
      where: 'is_recurring = ? AND is_deleted = ?',
      whereArgs: [1, 0],
      orderBy: 'timestamp DESC',
    );
    return maps.map((map) => Expense.fromMap(map)).toList();
  }

  Future<int> updateExpense(Expense expense) async {
    final db = await _dbHelper.database;
    return await db.update(
      'Expenses',
      expense.toMap(),
      where: 'id = ?',
      whereArgs: [expense.id],
    );
  }

  Future<int> softDeleteExpense(int id) async {
    final db = await _dbHelper.database;
    return await db.rawUpdate(
      'UPDATE Expenses SET is_deleted = 1 WHERE id = ?',
      [id],
    );
  }

  Future<int> restoreExpense(int id) async {
    final db = await _dbHelper.database;
    return await db.rawUpdate(
      'UPDATE Expenses SET is_deleted = 0 WHERE id = ?',
      [id],
    );
  }

  Future<int> permanentlyDeleteExpense(int id) async {
    final db = await _dbHelper.database;
    return await db.delete('Expenses', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteExpensePayers(int expenseId) async {
    final db = await _dbHelper.database;
    return await db.delete('ExpensePayers', where: 'expense_id = ?', whereArgs: [expenseId]);
  }

  Future<int> deleteExpenseSplits(int expenseId) async {
    final db = await _dbHelper.database;
    return await db.delete('ExpenseSplits', where: 'expense_id = ?', whereArgs: [expenseId]);
  }

  Future<Expense?> getExpenseById(int id) async {
    final db = await _dbHelper.database;
    final maps = await db.query('Expenses', where: 'id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) {
      return Expense.fromMap(maps.first);
    }
    return null;
  }

  Future<bool> doesExpenseTitleExist(String title) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'Expenses',
      where: 'title = ? COLLATE NOCASE', // Case insensitive check
      whereArgs: [title],
      limit: 1,
    );
    return maps.isNotEmpty;
  }

  Future<int> insertExpensePayer(ExpensePayer payer) async {
    final db = await _dbHelper.database;
    return await db.insert('Expense_Payers', payer.toMap());
  }

  Future<List<ExpensePayer>> getPayersForExpense(int expenseId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'Expense_Payers',
      where: 'expense_id = ?',
      whereArgs: [expenseId],
    );
    return maps.map((map) => ExpensePayer.fromMap(map)).toList();
  }

  Future<int> insertExpenseSplit(ExpenseSplit split) async {
    final db = await _dbHelper.database;
    return await db.insert('Expense_Splits', split.toMap());
  }

  Future<List<ExpenseSplit>> getSplitsForExpense(int expenseId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'Expense_Splits',
      where: 'expense_id = ?',
      whereArgs: [expenseId],
    );
    return maps.map((map) => ExpenseSplit.fromMap(map)).toList();
  }

  Future<List<ExpenseSplit>> getAllActiveSplits() async {
    final db = await _dbHelper.database;
    final maps = await db.rawQuery('''
      SELECT es.* FROM Expense_Splits es
      INNER JOIN Expenses e ON es.expense_id = e.id
      WHERE e.is_deleted = 0
    ''');
    return maps.map((map) => ExpenseSplit.fromMap(map)).toList();
  }

  Future<List<ExpensePayer>> getAllActivePayers() async {
    final db = await _dbHelper.database;
    final maps = await db.rawQuery('''
      SELECT ep.* FROM Expense_Payers ep
      INNER JOIN Expenses e ON ep.expense_id = e.id
      WHERE e.is_deleted = 0
    ''');
    return maps.map((map) => ExpensePayer.fromMap(map)).toList();
  }
}
