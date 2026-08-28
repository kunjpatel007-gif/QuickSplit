import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';

class SettingsRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<void> setSetting(String key, String value) async {
    final db = await _dbHelper.database;
    await db.insert(
      'Settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> getSetting(String key) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'Settings',
      where: 'key = ?',
      whereArgs: [key],
    );
    if (maps.isNotEmpty) {
      return maps.first['value'] as String?;
    }
    return null;
  }

  Future<String?> getThemeMode() async {
    return await getSetting('theme_mode');
  }

  Future<void> setThemeMode(String mode) async {
    await setSetting('theme_mode', mode);
  }
}
