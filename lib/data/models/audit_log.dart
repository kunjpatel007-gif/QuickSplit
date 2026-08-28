class AuditLog {
  final int? logId;
  final int expenseId;
  final String actionType;
  final double? previousAmount;
  final double? newAmount;
  final DateTime timestamp;
  final String previousHash;
  final String currentHash;

  const AuditLog({
    this.logId,
    required this.expenseId,
    required this.actionType,
    this.previousAmount,
    this.newAmount,
    required this.timestamp,
    required this.previousHash,
    required this.currentHash,
  });

  factory AuditLog.fromMap(Map<String, dynamic> map) {
    return AuditLog(
      logId: map['log_id'] as int?,
      expenseId: map['expense_id'] as int,
      actionType: map['action_type'] as String,
      previousAmount: map['previous_amount'] != null ? (map['previous_amount'] as num).toDouble() : null,
      newAmount: map['new_amount'] != null ? (map['new_amount'] as num).toDouble() : null,
      timestamp: DateTime.parse(map['timestamp'] as String),
      previousHash: map['previous_hash'] as String,
      currentHash: map['current_hash'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'log_id': logId,
      'expense_id': expenseId,
      'action_type': actionType,
      'previous_amount': previousAmount,
      'new_amount': newAmount,
      'timestamp': timestamp.toIso8601String(),
      'previous_hash': previousHash,
      'current_hash': currentHash,
    };
  }
}
