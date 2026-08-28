class TableDefinitions {
  static const String createUsersTable = '''
    CREATE TABLE Users (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      sync_id TEXT UNIQUE,
      name TEXT NOT NULL,
      upi_id TEXT,
      phone_number TEXT,
      created_at TEXT NOT NULL
    )
  ''';

  static const String createExpensesTable = '''
    CREATE TABLE Expenses (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      title TEXT NOT NULL,
      total_amount REAL NOT NULL,
      category TEXT NOT NULL,
      timestamp TEXT NOT NULL,
      is_recurring INTEGER NOT NULL DEFAULT 0,
      is_deleted INTEGER NOT NULL DEFAULT 0
    )
  ''';

  static const String createExpensePayersTable = '''
    CREATE TABLE Expense_Payers (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      expense_id INTEGER NOT NULL,
      user_id INTEGER NOT NULL,
      amount_paid REAL NOT NULL,
      FOREIGN KEY (expense_id) REFERENCES Expenses(id) ON DELETE CASCADE,
      FOREIGN KEY (user_id) REFERENCES Users(id)
    )
  ''';

  static const String createExpenseSplitsTable = '''
    CREATE TABLE Expense_Splits (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      expense_id INTEGER NOT NULL,
      user_id INTEGER NOT NULL,
      amount_owed REAL NOT NULL,
      FOREIGN KEY (expense_id) REFERENCES Expenses(id) ON DELETE CASCADE,
      FOREIGN KEY (user_id) REFERENCES Users(id)
    )
  ''';

  static const String createAuditLogTable = '''
    CREATE TABLE Audit_Log (
      log_id INTEGER PRIMARY KEY AUTOINCREMENT,
      expense_id INTEGER NOT NULL,
      action_type TEXT NOT NULL,
      previous_amount REAL,
      new_amount REAL,
      timestamp TEXT NOT NULL,
      previous_hash TEXT NOT NULL,
      current_hash TEXT NOT NULL
    )
  ''';

  static const String createExpenseTemplatesTable = '''
    CREATE TABLE Expense_Templates (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      title TEXT NOT NULL,
      amount REAL NOT NULL,
      category TEXT NOT NULL,
      payers_json TEXT NOT NULL,
      splits_json TEXT NOT NULL,
      created_at TEXT NOT NULL
    )
  ''';

  static const String createSettingsTable = '''
    CREATE TABLE Settings (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL
    )
  ''';
}
