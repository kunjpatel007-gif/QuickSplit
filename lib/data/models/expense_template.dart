class ExpenseTemplate {
  final int? id;
  final String title;
  final double amount;
  final String category;
  final String payersJson;
  final String splitsJson;
  final DateTime createdAt;

  const ExpenseTemplate({
    this.id,
    required this.title,
    required this.amount,
    required this.category,
    required this.payersJson,
    required this.splitsJson,
    required this.createdAt,
  });

  factory ExpenseTemplate.fromMap(Map<String, dynamic> map) {
    return ExpenseTemplate(
      id: map['id'] as int?,
      title: map['title'] as String,
      amount: (map['amount'] as num).toDouble(),
      category: map['category'] as String,
      payersJson: map['payers_json'] as String,
      splitsJson: map['splits_json'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'category': category,
      'payers_json': payersJson,
      'splits_json': splitsJson,
      'created_at': createdAt.toIso8601String(),
    };
  }

  ExpenseTemplate copyWith({
    int? id,
    String? title,
    double? amount,
    String? category,
    String? payersJson,
    String? splitsJson,
    DateTime? createdAt,
  }) {
    return ExpenseTemplate(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      payersJson: payersJson ?? this.payersJson,
      splitsJson: splitsJson ?? this.splitsJson,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
