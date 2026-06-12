import 'package:flutter/material.dart';

// ========== ТИПЫ ТРАНЗАКЦИЙ ==========
enum TransactionType { income, expense }

// ========== МОДЕЛЬ ТРАНЗАКЦИИ ==========
class Transaction {
  final String id;
  final String userId;
  String title;
  double amount;
  DateTime date;
  TransactionType type;
  String category;
  String? subCategory;
  String? accountId;
  String? comment;
  bool isRecurring;
  int? recurringInterval;
  String? recurringFrequency;

  // Для переводов
  final String? fromAccountId;
  final String? toAccountId;

  Transaction({
    required this.id,
    required this.userId,
    required this.title,
    required this.amount,
    required this.date,
    required this.type,
    required this.category,
    this.subCategory,
    this.accountId,
    this.comment,
    this.isRecurring = false,
    this.recurringInterval,
    this.recurringFrequency,
    this.fromAccountId,
    this.toAccountId,
  });

  // Сериализация в JSON
  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'title': title,
        'amount': amount,
        'date': date.toIso8601String(),
        'type': type == TransactionType.income ? 'income' : 'expense',
        'category': category,
        'subCategory': subCategory,
        'accountId': accountId,
        'comment': comment,
        'isRecurring': isRecurring,
        'recurringInterval': recurringInterval,
        'recurringFrequency': recurringFrequency,
        'fromAccountId': fromAccountId,
        'toAccountId': toAccountId,
      };

  // Десериализация из JSON
  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'],
      userId: json['userId'] ?? 'default_user',
      title: json['title'],
      amount: json['amount'].toDouble(),
      date: DateTime.parse(json['date']),
      type: json['type'] == 'income'
          ? TransactionType.income
          : TransactionType.expense,
      category: json['category'],
      subCategory: json['subCategory'],
      accountId: json['accountId'],
      comment: json['comment'],
      isRecurring: json['isRecurring'] ?? false,
      recurringInterval: json['recurringInterval'],
      recurringFrequency: json['recurringFrequency'],
      fromAccountId: json['fromAccountId'],
      toAccountId: json['toAccountId'],
    );
  }

  // Фабричный метод для создания перевода
  factory Transaction.createTransfer({
    required String id,
    required String userId,
    required double amount,
    required String fromAccountId,
    required String toAccountId,
    String? comment,
    DateTime? date,
    bool isRecurring = false,
    int? recurringInterval,
    String? recurringFrequency,
  }) {
    return Transaction(
      id: id,
      userId: userId,
      title: 'Перевод',
      amount: amount,
      date: date ?? DateTime.now(),
      type: TransactionType.expense,
      category: 'Перевод',
      subCategory: null,
      accountId: null,
      comment: comment,
      isRecurring: isRecurring,
      recurringInterval: recurringInterval,
      recurringFrequency: recurringFrequency,
      fromAccountId: fromAccountId,
      toAccountId: toAccountId,
    );
  }
}

// ========== ВСПОМОГАТЕЛЬНЫЕ ДАННЫЕ ДЛЯ UI ==========

// База доступных иконок
class IconDataInfo {
  final IconData icon;
  final String name;
  const IconDataInfo(this.icon, this.name);
}

// ✅ ИСПРАВЛЕНО: делаем константными
const List<IconDataInfo> availableIcons = [
  IconDataInfo(Icons.money, 'Наличные'),
  IconDataInfo(Icons.directions_car, 'Транспорт'),
  IconDataInfo(Icons.health_and_safety, 'Здоровье'),
  IconDataInfo(Icons.card_giftcard, 'Подарки'),
  IconDataInfo(Icons.phone_android, 'Связь'),
  IconDataInfo(Icons.shopping_cart, 'Продукты'),
  IconDataInfo(Icons.movie, 'Развлечения'),
  IconDataInfo(Icons.work, 'Работа'),
  IconDataInfo(Icons.assignment_return, 'Долги'),
  IconDataInfo(Icons.autorenew, 'Оборотные'),
  IconDataInfo(Icons.trending_up, 'Инвестиции'),
  IconDataInfo(Icons.restaurant, 'Рестораны'),
  IconDataInfo(Icons.fitness_center, 'Спорт'),
  IconDataInfo(Icons.school, 'Образование'),
  IconDataInfo(Icons.pets, 'Животные'),
  IconDataInfo(Icons.home, 'Дом'),
  IconDataInfo(Icons.shopping_bag, 'Покупки'),
  IconDataInfo(Icons.flight, 'Путешествия'),
  IconDataInfo(Icons.local_hospital, 'Аптека'),
  IconDataInfo(Icons.child_care, 'Дети'),
  IconDataInfo(Icons.credit_card, 'Карта'),
];

// ✅ ИСПРАВЛЕНО: делаем константными
const List<Color> availableColors = [
  Colors.red,
  Colors.pink,
  Colors.purple,
  Colors.deepPurple,
  Colors.indigo,
  Colors.blue,
  Colors.lightBlue,
  Colors.cyan,
  Colors.teal,
  Colors.green,
  Colors.lightGreen,
  Colors.lime,
  Colors.yellow,
  Colors.amber,
  Colors.orange,
  Colors.deepOrange,
  Colors.brown,
  Colors.grey,
  Colors.blueGrey,
];

// ========== МОДЕЛЬ КАТЕГОРИИ ==========
class Category {
  final String id;
  String name;
  IconData icon;
  Color color;
  final List<SubCategory> subCategories;
  bool isHidden;
  String? budgetType;

  Category({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.subCategories,
    this.isHidden = false,
    this.budgetType,
  });

  // Сериализация в JSON
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'iconIndex': availableIcons
            .indexWhere((i) => i.icon == icon)
            .clamp(0, availableIcons.length - 1),
        'colorValue': color.value,
        'subCategories': subCategories.map((s) => s.toJson()).toList(),
        'isHidden': isHidden,
        'budgetType': budgetType,
      };

  // Десериализация из JSON
  factory Category.fromJson(Map<String, dynamic> json) {
    Color categoryColor;
    if (json.containsKey('colorValue')) {
      categoryColor = Color(json['colorValue']);
    } else {
      int colorIndex = json['colorIndex'] ?? 0;
      if (colorIndex < 0 || colorIndex >= availableColors.length)
        colorIndex = 0;
      categoryColor = availableColors[colorIndex];
    }

    return Category(
      id: json['id'],
      name: json['name'],
      icon: availableIcons[json['iconIndex']].icon,
      color: categoryColor,
      subCategories: (json['subCategories'] as List)
          .map((s) => SubCategory.fromJson(s))
          .toList(),
      isHidden: json['isHidden'] ?? false,
      budgetType: json['budgetType'],
    );
  }
}

class SubCategory {
  final String id;
  String name;
  IconData icon;
  Color color;
  bool isHidden;
  String? budgetType;
  String? type;

  SubCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    this.isHidden = false,
    this.budgetType,
    this.type,
  });

  // Сериализация в JSON
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'iconIndex': availableIcons
            .indexWhere((i) => i.icon == icon)
            .clamp(0, availableIcons.length - 1),
        'colorValue': color.value,
        'isHidden': isHidden,
        'budgetType': budgetType,
        'type': type,
      };

  // Десериализация из JSON
  factory SubCategory.fromJson(Map<String, dynamic> json) {
    Color subColor;
    if (json.containsKey('colorValue')) {
      subColor = Color(json['colorValue']);
    } else {
      int colorIndex = json['colorIndex'] ?? 0;
      if (colorIndex < 0 || colorIndex >= availableColors.length)
        colorIndex = 0;
      subColor = availableColors[colorIndex];
    }

    return SubCategory(
      id: json['id'],
      name: json['name'],
      icon: availableIcons[json['iconIndex']].icon,
      color: subColor,
      isHidden: json['isHidden'] ?? false,
      budgetType: json['budgetType'],
      type: json['type'],
    );
  }
}

// ========== МОДЕЛЬ СЧЕТА ==========
enum AccountType {
  cash,
  debitCard,
  creditCard,
  deposit,
  savings,
  loan,
  investment,
  debtOwed,
  debtToPay,
  other
}

extension AccountTypeExtension on AccountType {
  String get displayName {
    switch (this) {
      case AccountType.cash:
        return '💰 Наличные';
      case AccountType.debitCard:
        return '💳 Дебетовая карта';
      case AccountType.creditCard:
        return '💳 Кредитная карта';
      case AccountType.deposit:
        return '🏦 Вклад';
      case AccountType.savings:
        return '🏦 Накопительный счет';
      case AccountType.loan:
        return '📉 Кредит';
      case AccountType.investment:
        return '📈 Инвестиции';
      case AccountType.debtOwed:
        return '🤝 Должны мне';
      case AccountType.debtToPay:
        return '💸 Должен я';
      case AccountType.other:
        return '📦 Другое';
    }
  }

  IconData get defaultIcon {
    switch (this) {
      case AccountType.cash:
        return Icons.money;
      case AccountType.debitCard:
        return Icons.credit_card;
      case AccountType.creditCard:
        return Icons.credit_card;
      case AccountType.deposit:
        return Icons.account_balance;
      case AccountType.savings:
        return Icons.savings;
      case AccountType.loan:
        return Icons.trending_down;
      case AccountType.investment:
        return Icons.trending_up;
      case AccountType.debtOwed:
        return Icons.assignment_return;
      case AccountType.debtToPay:
        return Icons.assignment_late;
      case AccountType.other:
        return Icons.account_balance_wallet;
    }
  }
}

class Account {
  final String id;
  final String name;
  double balance;
  final String currency;
  final AccountType type;
  final IconData icon;
  final Color color;
  bool showOnHomeScreen;
  bool isMain;
  final double initialBalance;
  final DateTime createdDate;
  final DateTime? interestPaymentDate;

  // Общие параметры для процентов
  final double? interestRate;
  final String? interestAccountId;

  // Для накопительного счета
  final String? interestPeriod;
  final String? interestCalculationType;
  final String? interestCalculationDate;
  final DateTime? lastInterestCalculationDate;
  double? accruedInterestThisPeriod;
  double? totalInterestAccrued;

  // Для вклада
  final bool? isCapitalized;
  final String? capitalizationFrequency;
  final DateTime? depositEndDate;
  final String? closureAccountId;
  final bool? allowDeposit;
  final bool? allowWithdraw;
  final int? termMonths;
  final DateTime? depositStartDate;
  final int? depositTermYears;
  final int? depositTermMonths;
  final int? depositTermDays;

  // Для кредита
  final String? loanPaymentType;
  final double? principalAmount;
  double? remainingPrincipal;
  double? originalMonthlyPayment;
  DateTime? nextPaymentDate;
  final int? loanTermYears;
  final int? loanTermMonths;
  final int? loanTermDays;
  int? remainingMonths;
  double? monthlyPayment;
  double? totalLoanInterest;
  double? paidInterest;
  final int? paymentDay;

  // Для долга
  final DateTime? repaymentDate;

  // Старые поля (для совместимости)
  final double? creditLimit;
  final double? minPayment;
  final double? commission;
  final double? interestRateCredit;
  final DateTime? billingDate;
  final int? gracePeriodDays;
  final String? paymentType;

  Account({
    required this.id,
    required this.name,
    required this.balance,
    required this.currency,
    required this.type,
    required this.icon,
    required this.color,
    required this.initialBalance,
    required this.createdDate,
    this.interestPaymentDate,
    this.showOnHomeScreen = true,
    this.isMain = false,
    this.interestRate,
    this.interestAccountId,
    this.interestPeriod,
    this.interestCalculationType,
    this.interestCalculationDate,
    this.lastInterestCalculationDate,
    this.accruedInterestThisPeriod,
    this.totalInterestAccrued,
    this.isCapitalized,
    this.capitalizationFrequency,
    this.depositEndDate,
    this.closureAccountId,
    this.allowDeposit,
    this.allowWithdraw,
    this.termMonths,
    this.depositStartDate,
    this.depositTermYears,
    this.depositTermMonths,
    this.depositTermDays,
    this.loanPaymentType,
    this.principalAmount,
    this.remainingPrincipal,
    this.originalMonthlyPayment,
    this.nextPaymentDate,
    this.loanTermYears,
    this.loanTermMonths,
    this.loanTermDays,
    this.remainingMonths,
    this.monthlyPayment,
    this.totalLoanInterest,
    this.paidInterest,
    this.paymentDay,
    this.repaymentDate,
    this.creditLimit,
    this.minPayment,
    this.commission,
    this.interestRateCredit,
    this.billingDate,
    this.gracePeriodDays,
    this.paymentType,
  });

  // Десериализация из JSON
  factory Account.fromJson(Map<String, dynamic> json) {
    final typeStr = json['type'] as String? ?? 'cash';
    final colorValue = json['color'] as int;
    AccountType accountType;
    switch (typeStr) {
      case 'cash':
        accountType = AccountType.cash;
        break;
      case 'debitCard':
        accountType = AccountType.debitCard;
        break;
      case 'creditCard':
        accountType = AccountType.creditCard;
        break;
      case 'deposit':
        accountType = AccountType.deposit;
        break;
      case 'savings':
        accountType = AccountType.savings;
        break;
      case 'loan':
        accountType = AccountType.loan;
        break;
      case 'investment':
        accountType = AccountType.investment;
        break;
      case 'debtOwed':
        accountType = AccountType.debtOwed;
        break;
      case 'debtToPay':
        accountType = AccountType.debtToPay;
        break;
      default:
        accountType = AccountType.cash;
    }

    return Account(
      id: json['id'],
      name: json['name'],
      balance: (json['balance'] as num).toDouble(),
      initialBalance: (json['initialBalance'] as num?)?.toDouble() ??
          (json['balance'] as num).toDouble(),
      createdDate: json['createdDate'] != null
          ? DateTime.parse(json['createdDate'])
          : DateTime.now(),
      currency: json['currency'] ?? '₽',
      type: accountType,
      icon: IconData(json['icon'], fontFamily: 'MaterialIcons'),
      color: Color(json['color']),
      showOnHomeScreen: json['showOnHomeScreen'] ?? true,
      isMain: json['isMain'] ?? false,
      interestRate: json['interestRate']?.toDouble(),
      interestAccountId: json['interestAccountId'],
      interestPeriod: json['interestPeriod'],
      interestCalculationType: json['interestCalculationType'],
      interestCalculationDate: json['interestCalculationDate'],
      lastInterestCalculationDate: json['lastInterestCalculationDate'] != null
          ? DateTime.parse(json['lastInterestCalculationDate'])
          : null,
      accruedInterestThisPeriod: json['accruedInterestThisPeriod']?.toDouble(),
      totalInterestAccrued: json['totalInterestAccrued']?.toDouble(),
      isCapitalized: json['isCapitalized'],
      capitalizationFrequency: json['capitalizationFrequency'],
      depositEndDate: json['depositEndDate'] != null
          ? DateTime.parse(json['depositEndDate'])
          : null,
      closureAccountId: json['closureAccountId'],
      allowDeposit: json['allowDeposit'],
      allowWithdraw: json['allowWithdraw'],
      termMonths: json['termMonths'],
      depositStartDate: json['depositStartDate'] != null
          ? DateTime.parse(json['depositStartDate'])
          : null,
      depositTermYears: json['depositTermYears'],
      depositTermMonths: json['depositTermMonths'],
      depositTermDays: json['depositTermDays'],
      loanPaymentType: json['loanPaymentType'],
      principalAmount: json['principalAmount']?.toDouble(),
      remainingPrincipal: json['remainingPrincipal']?.toDouble(),
      originalMonthlyPayment: json['originalMonthlyPayment']?.toDouble(),
      nextPaymentDate: json['nextPaymentDate'] != null
          ? DateTime.parse(json['nextPaymentDate'])
          : null,
      loanTermYears: json['loanTermYears'],
      loanTermMonths: json['loanTermMonths'],
      loanTermDays: json['loanTermDays'],
      remainingMonths: json['remainingMonths'],
      monthlyPayment: json['monthlyPayment']?.toDouble(),
      totalLoanInterest: json['totalLoanInterest']?.toDouble(),
      paidInterest: json['paidInterest']?.toDouble(),
      paymentDay: json['paymentDay'],
      repaymentDate: json['repaymentDate'] != null
          ? DateTime.parse(json['repaymentDate'])
          : null,
      creditLimit: json['creditLimit']?.toDouble(),
      minPayment: json['minPayment']?.toDouble(),
      commission: json['commission']?.toDouble(),
      interestRateCredit: json['interestRateCredit']?.toDouble(),
      billingDate: json['billingDate'] != null
          ? DateTime.parse(json['billingDate'])
          : null,
      gracePeriodDays: json['gracePeriodDays'],
      paymentType: json['paymentType'],
    );
  }

  // Сериализация в JSON
  Map<String, dynamic> toJson() {
    String typeStr;
    switch (type) {
      case AccountType.cash:
        typeStr = 'cash';
        break;
      case AccountType.debitCard:
        typeStr = 'debitCard';
        break;
      case AccountType.creditCard:
        typeStr = 'creditCard';
        break;
      case AccountType.deposit:
        typeStr = 'deposit';
        break;
      case AccountType.savings:
        typeStr = 'savings';
        break;
      case AccountType.loan:
        typeStr = 'loan';
        break;
      case AccountType.investment:
        typeStr = 'investment';
        break;
      case AccountType.debtOwed:
        typeStr = 'debtOwed';
        break;
      case AccountType.debtToPay:
        typeStr = 'debtToPay';
        break;
      default:
        typeStr = 'cash';
    }

    return {
      'id': id,
      'name': name,
      'balance': balance,
      'initialBalance': initialBalance,
      'createdDate': createdDate.toIso8601String(),
      'currency': currency,
      'type': typeStr,
      'icon': icon.codePoint,
      'color': color.value,
      'showOnHomeScreen': showOnHomeScreen,
      'isMain': isMain,
      'interestRate': interestRate,
      'interestAccountId': interestAccountId,
      'interestPeriod': interestPeriod,
      'interestCalculationType': interestCalculationType,
      'interestCalculationDate': interestCalculationDate,
      'lastInterestCalculationDate':
          lastInterestCalculationDate?.toIso8601String(),
      'accruedInterestThisPeriod': accruedInterestThisPeriod,
      'totalInterestAccrued': totalInterestAccrued,
      'isCapitalized': isCapitalized,
      'capitalizationFrequency': capitalizationFrequency,
      'depositEndDate': depositEndDate?.toIso8601String(),
      'closureAccountId': closureAccountId,
      'allowDeposit': allowDeposit,
      'allowWithdraw': allowWithdraw,
      'termMonths': termMonths,
      'depositStartDate': depositStartDate?.toIso8601String(),
      'depositTermYears': depositTermYears,
      'depositTermMonths': depositTermMonths,
      'depositTermDays': depositTermDays,
      'loanPaymentType': loanPaymentType,
      'principalAmount': principalAmount,
      'remainingPrincipal': remainingPrincipal,
      'originalMonthlyPayment': originalMonthlyPayment,
      'nextPaymentDate': nextPaymentDate?.toIso8601String(),
      'loanTermYears': loanTermYears,
      'loanTermMonths': loanTermMonths,
      'loanTermDays': loanTermDays,
      'remainingMonths': remainingMonths,
      'monthlyPayment': monthlyPayment,
      'totalLoanInterest': totalLoanInterest,
      'paidInterest': paidInterest,
      'paymentDay': paymentDay,
      'repaymentDate': repaymentDate?.toIso8601String(),
      'creditLimit': creditLimit,
      'minPayment': minPayment,
      'commission': commission,
      'interestRateCredit': interestRateCredit,
      'billingDate': billingDate?.toIso8601String(),
      'gracePeriodDays': gracePeriodDays,
      'paymentType': paymentType,
    };
  }
}
