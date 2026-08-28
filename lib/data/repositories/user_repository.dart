import 'package:uuid/uuid.dart';
import '../database/database_helper.dart';
import '../models/user.dart';

class UserRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<int> insertUser(User user) async {
    final db = await _dbHelper.database;
    final map = user.toMap();
    // Ensure a UUID is always generated
    if (map['sync_id'] == null || (map['sync_id'] as String).isEmpty) {
      map['sync_id'] = const Uuid().v4();
    }
    return await db.insert('Users', map);
  }

  Future<List<User>> getAllUsers() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('Users');
    return maps.map((map) => User.fromMap(map)).toList();
  }

  Future<User?> getUserById(int id) async {
    final db = await _dbHelper.database;
    final maps = await db.query('Users', where: 'id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) {
      return User.fromMap(maps.first);
    }
    return null;
  }

  Future<User?> getUserByName(String name) async {
    final db = await _dbHelper.database;
    final maps = await db.query('Users', where: 'name = ?', whereArgs: [name]);
    if (maps.isNotEmpty) {
      return User.fromMap(maps.first);
    }
    return null;
  }

  Future<User?> getUserBySyncId(String syncId) async {
    final db = await _dbHelper.database;
    final maps = await db.query('Users', where: 'sync_id = ?', whereArgs: [syncId]);
    if (maps.isNotEmpty) {
      return User.fromMap(maps.first);
    }
    return null;
  }

  Future<int> updateUser(User user) async {
    final db = await _dbHelper.database;
    return await db.update(
      'Users',
      user.toMap(),
      where: 'id = ?',
      whereArgs: [user.id],
    );
  }

  Future<int> deleteUser(int id) async {
    final db = await _dbHelper.database;
    return await db.delete(
      'Users',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
