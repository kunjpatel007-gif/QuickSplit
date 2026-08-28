class ExpensePayer {
  final int? id;
  final int expenseId;
  final int userId;
  final double amountPaid;

  const ExpensePayer({
    this.id,
    required this.expenseId,
    required this.userId,
    required this.amountPaid,
  });

  factory ExpensePayer.fromMap(Map<String, dynamic> map) {
    return ExpensePayer(
      id: map['id'] as int?,
      expenseId: map['expense_id'] as int,
      userId: map['user_id'] as int,
      amountPaid: (map['amount_paid'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'expense_id': expenseId,
      'user_id': userId,
      'amount_paid': amountPaid,
    };
  }
}
