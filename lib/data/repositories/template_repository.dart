import '../database/database_helper.dart';
import '../models/expense_template.dart';

class TemplateRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<int> insertTemplate(ExpenseTemplate template) async {
    final db = await _dbHelper.database;
    return await db.insert('Expense_Templates', template.toMap());
  }

  Future<List<ExpenseTemplate>> getAllTemplates() async {
    final db = await _dbHelper.database;
    final maps = await db.query('Expense_Templates', orderBy: 'created_at DESC');
    return maps.map((map) => ExpenseTemplate.fromMap(map)).toList();
  }

  Future<int> updateTemplate(ExpenseTemplate template) async {
    final db = await _dbHelper.database;
    return await db.update(
      'Expense_Templates',
      template.toMap(),
      where: 'id = ?',
      whereArgs: [template.id],
    );
  }

  Future<int> deleteTemplate(int id) async {
    final db = await _dbHelper.database;
    return await db.delete(
      'Expense_Templates',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
