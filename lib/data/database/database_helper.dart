import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'tables.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'campus_quicksplit.db');

    return await openDatabase(
      path,
      version: 2,
      onConfigure: _onConfigure,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute(TableDefinitions.createUsersTable);
    await db.execute(TableDefinitions.createExpensesTable);
    await db.execute(TableDefinitions.createExpensePayersTable);
    await db.execute(TableDefinitions.createExpenseSplitsTable);
    await db.execute(TableDefinitions.createAuditLogTable);
    await db.execute(TableDefinitions.createExpenseTemplatesTable);
    await db.execute(TableDefinitions.createSettingsTable);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add sync_id column to Users table (SQLite cannot add UNIQUE constraints via ALTER TABLE)
      await db.execute('ALTER TABLE Users ADD COLUMN sync_id TEXT');
      // Retroactively generate pseudo-UUIDs for existing users
      await db.execute(
        "UPDATE Users SET sync_id = lower(hex(randomblob(4))) || '-' || lower(hex(randomblob(2))) || '-4' || substr(lower(hex(randomblob(2))),2) || '-' || substr('89ab', abs(random()) % 4 + 1, 1) || substr(lower(hex(randomblob(2))),2) || '-' || lower(hex(randomblob(6))) WHERE sync_id IS NULL"
      );
    }
  }
}
