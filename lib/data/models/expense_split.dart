class ExpenseSplit {
  final int? id;
  final int expenseId;
  final int userId;
  final double amountOwed;

  const ExpenseSplit({
    this.id,
    required this.expenseId,
    required this.userId,
    required this.amountOwed,
  });

  factory ExpenseSplit.fromMap(Map<String, dynamic> map) {
    return ExpenseSplit(
      id: map['id'] as int?,
      expenseId: map['expense_id'] as int,
      userId: map['user_id'] as int,
      amountOwed: (map['amount_owed'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'expense_id': expenseId,
      'user_id': userId,
      'amount_owed': amountOwed,
    };
  }
}
