class BudgetNotification {
  final String id;
  final String title;
  final String message;
  final DateTime date;
  final bool isRead;
  final String? categoryId;
  final double? budgetAmount;
  final double? spentAmount;

  BudgetNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.date,
    this.isRead = false,
    this.categoryId,
    this.budgetAmount,
    this.spentAmount,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'message': message,
    'date': date.toIso8601String(),
    'isRead': isRead,
    'categoryId': categoryId,
    'budgetAmount': budgetAmount,
    'spentAmount': spentAmount,
  };

  factory BudgetNotification.fromJson(Map<String, dynamic> json) {
    return BudgetNotification(
      id: json['id'],
      title: json['title'],
      message: json['message'],
      date: DateTime.parse(json['date']),
      isRead: json['isRead'] ?? false,
      categoryId: json['categoryId'],
      budgetAmount: json['budgetAmount']?.toDouble(),
      spentAmount: json['spentAmount']?.toDouble(),
    );
  }
}