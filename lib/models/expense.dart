class Expense {
  final String id;
  final double amount;
  final String currency;
  final String category;
  final String? memo;
  final DateTime? createdAt;

  const Expense({
    required this.id,
    required this.amount,
    required this.currency,
    required this.category,
    this.memo,
    this.createdAt,
  });

  factory Expense.fromJson(Map<String, dynamic> json) => Expense(
    id: json['id'] as String,
    amount: (json['amount'] as num?)?.toDouble() ?? 0,
    currency: json['currency'] as String? ?? 'KRW',
    category: json['category'] as String? ?? '기타',
    memo: json['memo'] as String?,
    createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'] as String) : null,
  );
}
