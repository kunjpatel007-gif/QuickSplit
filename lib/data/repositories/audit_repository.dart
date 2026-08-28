import '../database/database_helper.dart';
import '../models/audit_log.dart';

class AuditRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<int> insertAuditLog(AuditLog log) async {
    final db = await _dbHelper.database;
    return await db.insert('Audit_Log', log.toMap());
  }

  Future<List<AuditLog>> getAllAuditLogs() async {
    final db = await _dbHelper.database;
    final maps = await db.query('Audit_Log', orderBy: 'timestamp DESC');
    return maps.map((map) => AuditLog.fromMap(map)).toList();
  }

  Future<String?> getLatestHash() async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'Audit_Log',
      orderBy: 'log_id DESC',
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return maps.first['current_hash'] as String?;
    }
    return null;
  }

  Future<List<AuditLog>> getAuditLogsForExpense(int expenseId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'Audit_Log',
      where: 'expense_id = ?',
      whereArgs: [expenseId],
      orderBy: 'timestamp DESC',
    );
    return maps.map((map) => AuditLog.fromMap(map)).toList();
  }
}
