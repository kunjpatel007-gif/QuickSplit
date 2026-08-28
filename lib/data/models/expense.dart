class Expense {
  final int? id;
  final String title;
  final double totalAmount;
  final String category;
  final DateTime timestamp;
  final bool isRecurring;
  final bool isDeleted;

  const Expense({
    this.id,
    required this.title,
    required this.totalAmount,
    required this.category,
    required this.timestamp,
    this.isRecurring = false,
    this.isDeleted = false,
  });

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'] as int?,
      title: map['title'] as String,
      totalAmount: (map['total_amount'] as num).toDouble(),
      category: map['category'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
      isRecurring: (map['is_recurring'] as int?) == 1,
      isDeleted: (map['is_deleted'] as int?) == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'total_amount': totalAmount,
      'category': category,
      'timestamp': timestamp.toIso8601String(),
      'is_recurring': isRecurring ? 1 : 0,
      'is_deleted': isDeleted ? 1 : 0,
    };
  }

  Expense copyWith({
    int? id,
    String? title,
    double? totalAmount,
    String? category,
    DateTime? timestamp,
    bool? isRecurring,
    bool? isDeleted,
  }) {
    return Expense(
      id: id ?? this.id,
      title: title ?? this.title,
      totalAmount: totalAmount ?? this.totalAmount,
      category: category ?? this.category,
      timestamp: timestamp ?? this.timestamp,
      isRecurring: isRecurring ?? this.isRecurring,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}
