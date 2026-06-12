import 'package:flutter/material.dart';

class Goal {
  final String id;
  String title;
  DateTime targetDate;
  double targetAmount;
  double currentAmount;
  String? accountId;
  bool showOnHomeScreen;
  Color color;
  late final IconData
      icon; // ← делаем late final и убираем значение по умолчанию

  Goal({
    required this.id,
    required this.title,
    required this.targetDate,
    required this.targetAmount,
    required this.currentAmount,
    this.accountId,
    this.showOnHomeScreen = true,
    this.color = Colors.blue,
    required this.icon, // ← теперь required, значение передаём при создании
  });

  double get progress => currentAmount / targetAmount;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'targetDate': targetDate.toIso8601String(),
        'targetAmount': targetAmount,
        'currentAmount': currentAmount,
        'accountId': accountId,
        'showOnHomeScreen': showOnHomeScreen,
        'colorValue': color.value,
        'iconCodePoint': icon.codePoint,
      };

  factory Goal.fromJson(Map<String, dynamic> json) {
    return Goal(
      id: json['id'],
      title: json['title'],
      targetDate: DateTime.parse(json['targetDate']),
      targetAmount: json['targetAmount'].toDouble(),
      currentAmount: json['currentAmount'].toDouble(),
      accountId: json['accountId'],
      showOnHomeScreen: json['showOnHomeScreen'] ?? true,
      color: Color(json['colorValue'] ?? Colors.blue.value),
      icon: IconData(
        json['iconCodePoint'] ?? Icons.flag.codePoint,
        fontFamily: 'MaterialIcons',
      ),
    );
  }
}
