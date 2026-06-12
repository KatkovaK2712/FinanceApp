// lib/services/test_data.dart
import 'package:flutter/material.dart';
import '../models/transaction_models.dart';
import '../models/goal.dart';
import 'transaction_service.dart';
import 'category_service.dart';
import 'goal_service.dart';
import 'api_service.dart';

class TestDataGenerator {
  static Future<void> generateTestData() async {
    print('🚀 НАЧАЛО ГЕНЕРАЦИИ ТЕСТОВЫХ ДАННЫХ');

    final userId = ApiService.currentUserId;
    if (userId == null) {
      print('❌ Пользователь не авторизован, тестовые данные не созданы');
      return;
    }

    // Проверяем, есть ли уже транзакции
    final existingTransactions = await TransactionService.loadTransactions();
    if (existingTransactions.isNotEmpty) {
      print('⚠️ Транзакции уже существуют, тестовые данные не созданы');
      return;
    }

    // ==================== СОЗДАНИЕ СЧЕТОВ ====================

    final accounts = [
      // 1. Основной дебетовый счет
      Account(
        id: 'acc_main_${DateTime.now().millisecondsSinceEpoch}',
        name: 'Основной счет',
        balance: 185000,
        initialBalance: 150000,
        createdDate: DateTime(2026, 1, 1),
        currency: '₽',
        type: AccountType.debitCard,
        icon: Icons.credit_card,
        color: Colors.blue,
        showOnHomeScreen: true,
        isMain: true,
      ),

      // 2. Накопительный счет (Savings)
      Account(
        id: 'acc_savings_${DateTime.now().millisecondsSinceEpoch}',
        name: 'Копилка на мечту',
        balance: 85000,
        initialBalance: 30000,
        createdDate: DateTime(2026, 1, 1),
        currency: '₽',
        type: AccountType.savings,
        icon: Icons.savings,
        color: Colors.green,
        interestRate: 6.0,
        showOnHomeScreen: true,
        isMain: false,
      ),

      // 3. Вклад (Deposit)
      Account(
        id: 'acc_deposit_${DateTime.now().millisecondsSinceEpoch}',
        name: 'Вклад "Доходный"',
        balance: 200000,
        initialBalance: 200000,
        createdDate: DateTime(2026, 1, 15),
        depositEndDate: DateTime(2026, 12, 15),
        currency: '₽',
        type: AccountType.deposit,
        icon: Icons.account_balance,
        color: Colors.purple,
        interestRate: 8.0,
        isCapitalized: true,
        allowWithdraw: false,
        allowDeposit: false,
        showOnHomeScreen: true,
        isMain: false,
      ),

      // 4. Кредит (Loan)
      Account(
        id: 'acc_loan_${DateTime.now().millisecondsSinceEpoch}',
        name: 'Потребительский кредит',
        balance: -240000,
        initialBalance: -300000,
        createdDate: DateTime(2026, 1, 10),
        currency: '₽',
        type: AccountType.loan,
        icon: Icons.credit_score,
        color: Colors.red,
        interestRate: 15.0,
        principalAmount: 300000,
        remainingPrincipal: 240000,
        monthlyPayment: 15000,
        loanTermMonths: 24,
        paymentDay: 15,
        paymentType: 'annuity',
        showOnHomeScreen: true,
        isMain: false,
      ),

      // 5. Долг мне (debtOwed)
      Account(
        id: 'acc_debt_owed_${DateTime.now().millisecondsSinceEpoch}',
        name: 'Долг друга',
        balance: 15000,
        initialBalance: 15000,
        createdDate: DateTime(2026, 2, 20),
        currency: '₽',
        type: AccountType.debtOwed,
        icon: Icons.assignment_return,
        color: Colors.amber,
        showOnHomeScreen: false,
        isMain: false,
      ),

      // 6. Наличные
      Account(
        id: 'acc_cash_${DateTime.now().millisecondsSinceEpoch}',
        name: 'Наличные',
        balance: 25000,
        initialBalance: 20000,
        createdDate: DateTime(2026, 1, 1),
        currency: '₽',
        type: AccountType.cash,
        icon: Icons.money,
        color: Colors.lightGreen,
        showOnHomeScreen: true,
        isMain: false,
      ),
    ];

    await CategoryService.saveAccounts(accounts);
    print('✅ Создано ${accounts.length} счетов');

    // ==================== СОЗДАНИЕ ЦЕЛЕЙ ====================

    final goals = [
      Goal(
        id: 'goal_1_${DateTime.now().millisecondsSinceEpoch}',
        title: '🏖️ Отпуск на море',
        targetAmount: 100000,
        currentAmount: 45000,
        targetDate: DateTime(2026, 7, 15),
        icon: Icons.beach_access,
        color: Colors.cyan,
        accountId: accounts[1].id,
      ),
      Goal(
        id: 'goal_2_${DateTime.now().millisecondsSinceEpoch}',
        title: '💻 Новый ноутбук',
        targetAmount: 80000,
        currentAmount: 30000,
        targetDate: DateTime(2026, 9, 30),
        icon: Icons.computer,
        color: Colors.blue,
        accountId: accounts[0].id,
      ),
      Goal(
        id: 'goal_3_${DateTime.now().millisecondsSinceEpoch}',
        title: '🚗 Подушка безопасности',
        targetAmount: 200000,
        currentAmount: 85000,
        targetDate: DateTime(2026, 12, 31),
        icon: Icons.savings,
        color: Colors.green,
        accountId: accounts[1].id,
      ),
      Goal(
        id: 'goal_4_${DateTime.now().millisecondsSinceEpoch}',
        title: '🎓 Курсы по программированию',
        targetAmount: 50000,
        currentAmount: 10000,
        targetDate: DateTime(2026, 8, 1),
        icon: Icons.school,
        color: Colors.orange,
        accountId: accounts[0].id,
      ),
    ];

    await GoalService.saveGoals(goals);
    print('✅ Создано ${goals.length} целей');

    // ==================== СОЗДАНИЕ ТРАНЗАКЦИЙ ====================

    final transactions = <Transaction>[];
    int transactionId = 1;

    // ========== ДОХОДЫ ==========

    // Зарплата (ежемесячно)
    final salaryDates = [
      DateTime(2026, 1, 31, 10, 0),
      DateTime(2026, 2, 28, 10, 0),
      DateTime(2026, 3, 31, 10, 0),
      DateTime(2026, 4, 30, 10, 0),
      DateTime(2026, 5, 31, 10, 0),
    ];

    for (var date in salaryDates) {
      transactions.add(Transaction(
        id: '${transactionId++}',
        userId: userId,
        title: 'Зарплата',
        amount: 85000.0,
        date: date,
        type: TransactionType.income,
        category: 'Зарплата',
        subCategory: 'Основная',
        accountId: accounts[0].id,
        comment: 'Ежемесячная зарплата',
        isRecurring: true,
        recurringInterval: 1,
        recurringFrequency: 'month',
      ));
    }

    // Премия
    transactions.add(Transaction(
      id: '${transactionId++}',
      userId: userId,
      title: 'Премия',
      amount: 30000.0,
      date: DateTime(2026, 3, 31, 12, 0),
      type: TransactionType.income,
      category: 'Зарплата',
      subCategory: 'Премия',
      accountId: accounts[0].id,
      comment: 'Квартальная премия',
      isRecurring: false,
    ));

    // Фриланс (исправлено: .toDouble())
    final freelanceDates = [
      DateTime(2026, 2, 15, 14, 0),
      DateTime(2026, 4, 20, 15, 0),
      DateTime(2026, 6, 5, 16, 0),
    ];
    final freelanceAmounts = [15000, 12000, 18000];

    for (int i = 0; i < freelanceDates.length; i++) {
      transactions.add(Transaction(
        id: '${transactionId++}',
        userId: userId,
        title: 'Фриланс',
        amount: freelanceAmounts[i].toDouble(),
        date: freelanceDates[i],
        type: TransactionType.income,
        category: 'Фриланс',
        subCategory: null,
        accountId: accounts[0].id,
        comment: 'Проект',
        isRecurring: false,
      ));
    }

    // Возврат долга
    transactions.add(Transaction(
      id: '${transactionId++}',
      userId: userId,
      title: 'Возврат долга',
      amount: 5000.0,
      date: DateTime(2026, 4, 10, 11, 0),
      type: TransactionType.income,
      category: 'Долг мне',
      subCategory: 'Возврат долга',
      accountId: accounts[0].id,
      fromAccountId: accounts[4].id,
      comment: 'Друг вернул часть долга',
      isRecurring: false,
    ));

    // ========== ПРОЦЕНТЫ ПО НАКОПИТЕЛЬНОМУ СЧЕТУ ==========

    final savingsInterestDates = [
      DateTime(2026, 1, 31, 23, 59),
      DateTime(2026, 2, 28, 23, 59),
      DateTime(2026, 3, 31, 23, 59),
      DateTime(2026, 4, 30, 23, 59),
      DateTime(2026, 5, 31, 23, 59),
    ];

    for (int i = 0; i < savingsInterestDates.length; i++) {
      double balance = 30000 + i * 11000;
      double interest = balance * 0.06 / 12;
      transactions.add(Transaction(
        id: '${transactionId++}',
        userId: userId,
        title: 'Проценты по накопительному счету',
        amount: interest,
        date: savingsInterestDates[i],
        type: TransactionType.income,
        category: 'Проценты',
        subCategory: 'Накопления',
        accountId: accounts[1].id,
        comment: 'Начисление процентов за месяц',
        isRecurring: true,
      ));
    }

    // ========== ПРОЦЕНТЫ ПО ВКЛАДУ (капитализация) ==========

    final depositInterestDates = [
      DateTime(2026, 2, 15, 23, 59),
      DateTime(2026, 3, 15, 23, 59),
      DateTime(2026, 4, 15, 23, 59),
      DateTime(2026, 5, 15, 23, 59),
      DateTime(2026, 6, 15, 23, 59),
    ];

    double depositBalance = 200000;
    for (var date in depositInterestDates) {
      double interest = depositBalance * 0.08 / 12;
      depositBalance += interest;
      transactions.add(Transaction(
        id: '${transactionId++}',
        userId: userId,
        title: 'Проценты по вкладу',
        amount: interest,
        date: date,
        type: TransactionType.income,
        category: 'Проценты',
        subCategory: 'Вклад',
        accountId: accounts[2].id,
        comment: 'Капитализация процентов',
        isRecurring: true,
      ));
    }

    // ========== РАСХОДЫ ==========

    // Продукты (исправлено: .toDouble())
    final foodAmounts = [18000, 16500, 19000, 17500, 18500, 9500];
    for (int i = 0; i < foodAmounts.length; i++) {
      transactions.add(Transaction(
        id: '${transactionId++}',
        userId: userId,
        title: 'Продукты',
        amount: foodAmounts[i].toDouble(),
        date: DateTime(2026, i + 1, 15, 18, 30),
        type: TransactionType.expense,
        category: 'Продукты',
        subCategory: 'Супермаркет',
        accountId: accounts[0].id,
        comment: 'Покупка продуктов на месяц',
        isRecurring: false,
      ));
    }

    // Кафе и рестораны (исправлено: .toDouble())
    final cafeDates = [
      DateTime(2026, 1, 12, 19, 0),
      DateTime(2026, 1, 25, 20, 0),
      DateTime(2026, 2, 14, 19, 30),
      DateTime(2026, 2, 28, 18, 0),
      DateTime(2026, 3, 8, 20, 0),
      DateTime(2026, 3, 22, 19, 0),
      DateTime(2026, 4, 5, 18, 30),
      DateTime(2026, 4, 27, 20, 30),
      DateTime(2026, 5, 9, 19, 0),
      DateTime(2026, 5, 24, 18, 0),
      DateTime(2026, 6, 6, 20, 0),
    ];
    final cafeAmounts = [
      1200,
      2500,
      3500,
      800,
      1500,
      2200,
      1800,
      3000,
      1200,
      2500,
      1800
    ];

    for (int i = 0; i < cafeDates.length; i++) {
      transactions.add(Transaction(
        id: '${transactionId++}',
        userId: userId,
        title: 'Кафе/Ресторан',
        amount: cafeAmounts[i].toDouble(),
        date: cafeDates[i],
        type: TransactionType.expense,
        category: 'Развлечения',
        subCategory: 'Рестораны',
        accountId: accounts[0].id,
        comment: 'Обед/ужин',
        isRecurring: false,
      ));
    }

    // Транспорт
    final transportDates = [
      DateTime(2026, 1, 5, 8, 30),
      DateTime(2026, 1, 18, 17, 30),
      DateTime(2026, 2, 3, 8, 30),
      DateTime(2026, 2, 17, 17, 30),
      DateTime(2026, 3, 4, 8, 30),
      DateTime(2026, 3, 19, 17, 30),
      DateTime(2026, 4, 2, 8, 30),
      DateTime(2026, 4, 16, 17, 30),
      DateTime(2026, 5, 5, 8, 30),
      DateTime(2026, 5, 20, 17, 30),
      DateTime(2026, 6, 3, 8, 30),
    ];

    for (var date in transportDates) {
      transactions.add(Transaction(
        id: '${transactionId++}',
        userId: userId,
        title: 'Метро',
        amount: 62.0,
        date: date,
        type: TransactionType.expense,
        category: 'Транспорт',
        subCategory: 'Общественный',
        accountId: accounts[5].id,
        comment: 'Проезд',
        isRecurring: false,
      ));
    }

    // Такси
    final taxiDates = [
      DateTime(2026, 1, 31, 23, 0),
      DateTime(2026, 2, 14, 22, 30),
      DateTime(2026, 3, 8, 21, 0),
      DateTime(2026, 4, 30, 23, 30),
      DateTime(2026, 5, 20, 22, 0),
      DateTime(2026, 6, 7, 21, 30),
    ];

    for (var date in taxiDates) {
      transactions.add(Transaction(
        id: '${transactionId++}',
        userId: userId,
        title: 'Такси',
        amount: 500.0,
        date: date,
        type: TransactionType.expense,
        category: 'Транспорт',
        subCategory: 'Такси',
        accountId: accounts[0].id,
        comment: 'Поездка',
        isRecurring: false,
      ));
    }

    // Коммунальные платежи
    final utilitiesDates = [
      DateTime(2026, 1, 20, 12, 0),
      DateTime(2026, 2, 18, 12, 0),
      DateTime(2026, 3, 20, 12, 0),
      DateTime(2026, 4, 19, 12, 0),
      DateTime(2026, 5, 20, 12, 0),
    ];

    for (var date in utilitiesDates) {
      transactions.add(Transaction(
        id: '${transactionId++}',
        userId: userId,
        title: 'Коммунальные услуги',
        amount: 5200.0,
        date: date,
        type: TransactionType.expense,
        category: 'Коммунальные',
        subCategory: null,
        accountId: accounts[0].id,
        comment: 'Квартплата, свет, вода',
        isRecurring: true,
      ));
    }

    // Интернет и связь
    for (int i = 1; i <= 5; i++) {
      transactions.add(Transaction(
        id: '${transactionId++}',
        userId: userId,
        title: 'Домашний интернет',
        amount: 650.0,
        date: DateTime(2026, i, 5, 14, 0),
        type: TransactionType.expense,
        category: 'Связь',
        subCategory: 'Интернет',
        accountId: accounts[0].id,
        comment: 'Ростелеком',
        isRecurring: true,
      ));

      transactions.add(Transaction(
        id: '${transactionId++}',
        userId: userId,
        title: 'Мобильная связь',
        amount: 500.0,
        date: DateTime(2026, i, 10, 11, 0),
        type: TransactionType.expense,
        category: 'Связь',
        subCategory: 'Мобильная связь',
        accountId: accounts[0].id,
        comment: 'МТС',
        isRecurring: true,
      ));
    }

    // Здоровье (исправлено: .toDouble())
    final healthDates = [
      DateTime(2026, 2, 10, 16, 0),
      DateTime(2026, 3, 25, 15, 30),
      DateTime(2026, 5, 12, 17, 0),
    ];
    final healthAmounts = [850, 1200, 450];

    for (int i = 0; i < healthDates.length; i++) {
      transactions.add(Transaction(
        id: '${transactionId++}',
        userId: userId,
        title: 'Аптека',
        amount: healthAmounts[i].toDouble(),
        date: healthDates[i],
        type: TransactionType.expense,
        category: 'Здоровье',
        subCategory: 'Лекарства',
        accountId: accounts[0].id,
        comment: 'Лекарства',
        isRecurring: false,
      ));
    }

    // Одежда (исправлено: .toDouble())
    final clothesDates = [
      DateTime(2026, 2, 22, 15, 0),
      DateTime(2026, 4, 15, 14, 30),
      DateTime(2026, 5, 28, 16, 0),
    ];
    final clothesAmounts = [4500, 3200, 5800];

    for (int i = 0; i < clothesDates.length; i++) {
      transactions.add(Transaction(
        id: '${transactionId++}',
        userId: userId,
        title: 'Одежда',
        amount: clothesAmounts[i].toDouble(),
        date: clothesDates[i],
        type: TransactionType.expense,
        category: 'Одежда',
        subCategory: null,
        accountId: accounts[0].id,
        comment: 'Покупка одежды',
        isRecurring: false,
      ));
    }

    // Развлечения (кино, игры)
    final entertainmentDates = [
      DateTime(2026, 1, 17, 20, 0),
      DateTime(2026, 2, 21, 19, 0),
      DateTime(2026, 3, 14, 18, 30),
      DateTime(2026, 4, 18, 20, 0),
      DateTime(2026, 5, 16, 19, 30),
    ];

    for (var date in entertainmentDates) {
      transactions.add(Transaction(
        id: '${transactionId++}',
        userId: userId,
        title: 'Кино',
        amount: 600.0,
        date: date,
        type: TransactionType.expense,
        category: 'Развлечения',
        subCategory: 'Кино',
        accountId: accounts[0].id,
        comment: 'Билеты',
        isRecurring: false,
      ));
    }

    // Подписки
    for (int i = 1; i <= 6; i++) {
      transactions.add(Transaction(
        id: '${transactionId++}',
        userId: userId,
        title: 'Подписка Netflix',
        amount: 799.0,
        date: DateTime(2026, i, 1, 9, 0),
        type: TransactionType.expense,
        category: 'Развлечения',
        subCategory: null,
        accountId: accounts[0].id,
        comment: 'Ежемесячная подписка',
        isRecurring: true,
      ));
    }

    // ========== ПЛАТЕЖИ ПО КРЕДИТУ ==========

    for (int i = 1; i <= 5; i++) {
      transactions.add(Transaction(
        id: '${transactionId++}',
        userId: userId,
        title: 'Платеж по кредиту',
        amount: 15000.0,
        date: DateTime(2026, i, 15, 13, 0),
        type: TransactionType.expense,
        category: 'Перевод',
        subCategory: null,
        accountId: accounts[0].id,
        toAccountId: accounts[3].id,
        comment: 'Ежемесячный платеж',
        isRecurring: true,
        recurringInterval: 1,
        recurringFrequency: 'month',
      ));
    }

    // ========== ПЕРЕВОДЫ НА НАКОПИТЕЛЬНЫЙ СЧЕТ (исправлено: .toDouble()) ==========

    final transferAmounts = [15000, 10000, 12000, 8000, 10000, 0];
    for (int i = 0; i < transferAmounts.length; i++) {
      if (transferAmounts[i] > 0) {
        transactions.add(Transaction(
          id: '${transactionId++}',
          userId: userId,
          title: 'Перевод на накопления',
          amount: transferAmounts[i].toDouble(),
          date: DateTime(2026, i + 1, 28, 9, 0),
          type: TransactionType.expense,
          category: 'Перевод',
          subCategory: null,
          accountId: accounts[0].id,
          toAccountId: accounts[1].id,
          comment: 'Пополнение накопительного счета',
          isRecurring: false,
        ));
      }
    }

    // ========== ПУТЕШЕСТВИЯ ==========

    transactions.add(Transaction(
      id: '${transactionId++}',
      userId: userId,
      title: 'Билеты на поезд',
      amount: 8000.0,
      date: DateTime(2026, 4, 20, 10, 0),
      type: TransactionType.expense,
      category: 'Путешествия',
      subCategory: null,
      accountId: accounts[0].id,
      comment: 'Поездка в Питер',
      isRecurring: false,
    ));

    transactions.add(Transaction(
      id: '${transactionId++}',
      userId: userId,
      title: 'Отель',
      amount: 12000.0,
      date: DateTime(2026, 4, 25, 11, 0),
      type: TransactionType.expense,
      category: 'Путешествия',
      subCategory: null,
      accountId: accounts[0].id,
      comment: 'Проживание',
      isRecurring: false,
    ));

    // ========== ПОКУПКИ (исправлено: .toDouble()) ==========

    final shoppingDates = [
      DateTime(2026, 1, 10, 15, 0),
      DateTime(2026, 3, 5, 14, 0),
      DateTime(2026, 5, 10, 16, 0),
    ];
    final shoppingAmounts = [3500, 2800, 4200];

    for (int i = 0; i < shoppingDates.length; i++) {
      transactions.add(Transaction(
        id: '${transactionId++}',
        userId: userId,
        title: 'Бытовая техника',
        amount: shoppingAmounts[i].toDouble(),
        date: shoppingDates[i],
        type: TransactionType.expense,
        category: 'Покупки',
        subCategory: null,
        accountId: accounts[0].id,
        comment: 'Техника для дома',
        isRecurring: false,
      ));
    }

    // ========== КОСМЕТИКА ==========

    final beautyDates = [
      DateTime(2026, 2, 5, 13, 0),
      DateTime(2026, 4, 8, 12, 0),
      DateTime(2026, 6, 2, 14, 0),
    ];

    for (var date in beautyDates) {
      transactions.add(Transaction(
        id: '${transactionId++}',
        userId: userId,
        title: 'Косметика',
        amount: 2000.0,
        date: date,
        type: TransactionType.expense,
        category: 'Косметика',
        subCategory: null,
        accountId: accounts[0].id,
        comment: 'Уходовая косметика',
        isRecurring: false,
      ));
    }

    // Сохраняем транзакции
    for (var transaction in transactions) {
      await TransactionService.addTransaction(transaction);
    }

    print('✅ Создано ${transactions.length} транзакций');
    print('');
    print('📊 ИТОГОВЫЕ БАЛАНСЫ СЧЕТОВ:');
    print('   Основной счет: 185 000 ₽');
    print('   Накопительный счет "Копилка на мечту": 85 000 ₽');
    print('   Вклад "Доходный": ~212 000 ₽ (с процентами)');
    print('   Потребительский кредит: -240 000 ₽');
    print('   Долг друга: 15 000 ₽');
    print('   Наличные: 25 000 ₽');
    print('');
    print('🎯 ЦЕЛИ:');
    print('   🏖️ Отпуск на море: 45 000 / 100 000 ₽');
    print('   💻 Новый ноутбук: 30 000 / 80 000 ₽');
    print('   🚗 Подушка безопасности: 85 000 / 200 000 ₽');
    print('   🎓 Курсы по программированию: 10 000 / 50 000 ₽');
  }
}
