import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction_models.dart';
import '../models/goal.dart';
import 'category_service.dart';
import 'transaction_service.dart';
import 'api_service.dart';
import 'goal_service.dart';

class DemoDataService {
  static const String demoUserId = 'demo@user.com';

  static Future<void> initDemoMode() async {
    print('📦 Инициализация демо-режима...');

    final prefs = await SharedPreferences.getInstance();

    ApiService.currentUserId = demoUserId;
    await prefs.setString('current_user_id', demoUserId);
    await prefs.setString('user_email', demoUserId);

    final alreadyLoaded = prefs.getBool('demo_data_loaded');
    if (alreadyLoaded == true) {
      print('📦 Демо-данные уже загружены');
      return;
    }

    await _generateFullDemoData();
    await prefs.setBool('demo_data_loaded', true);
    print('✅ Демо-данные загружены');
  }

  static Future<void> _generateFullDemoData() async {
    // 1. СОЗДАЁМ КАТЕГОРИИ
    final categories = await _createCategories();
    await CategoryService.saveCategories(categories);

    // 2. СОЗДАЁМ СЧЕТА (все типы)
    final accounts = await _createAccounts();
    await CategoryService.saveAccounts(accounts);

    // 3. СОЗДАЁМ ТРАНЗАКЦИИ ЗА 6 МЕСЯЦЕВ
    final transactions = await _createTransactions();
    await TransactionService.saveTransactions(transactions);

    // 4. СОЗДАЁМ ЦЕЛИ (с привязкой к счетам)
    final goals = await _createGoals(accounts);
    await GoalService.saveGoals(goals);

    print(
        '📦 Создано: ${categories.length} категорий, ${accounts.length} счетов, ${transactions.length} транзакций, ${goals.length} целей');
  }

  static Future<List<Category>> _createCategories() async {
    return [
      // РАСХОДЫ
      Category(
        id: 'exp_food',
        name: 'Продукты',
        icon: Icons.restaurant,
        color: Colors.orange,
        subCategories: [
          SubCategory(
              id: 'food_supermarket',
              name: 'Супермаркет',
              icon: Icons.shopping_cart,
              color: Colors.orange),
          SubCategory(
              id: 'food_cafe',
              name: 'Кафе и рестораны',
              icon: Icons.local_cafe,
              color: Colors.deepOrange),
        ],
      ),
      Category(
        id: 'exp_transport',
        name: 'Транспорт',
        icon: Icons.directions_car,
        color: Colors.blue,
        subCategories: [
          SubCategory(
              id: 'trans_public',
              name: 'Общественный транспорт',
              icon: Icons.directions_bus,
              color: Colors.blue),
          SubCategory(
              id: 'trans_taxi',
              name: 'Такси',
              icon: Icons.taxi_alert,
              color: Colors.lightBlue),
          SubCategory(
              id: 'trans_fuel',
              name: 'Топливо',
              icon: Icons.local_gas_station,
              color: Colors.cyan),
        ],
      ),
      Category(
        id: 'exp_entertainment',
        name: 'Развлечения',
        icon: Icons.movie,
        color: Colors.purple,
        subCategories: [
          SubCategory(
              id: 'ent_cinema',
              name: 'Кино',
              icon: Icons.movie,
              color: Colors.purple),
          SubCategory(
              id: 'ent_games',
              name: 'Игры',
              icon: Icons.games,
              color: Colors.deepPurple),
          SubCategory(
              id: 'ent_sports',
              name: 'Спорт',
              icon: Icons.fitness_center,
              color: Colors.indigo),
        ],
      ),
      Category(
        id: 'exp_utilities',
        name: 'Коммунальные платежи',
        icon: Icons.home,
        color: Colors.teal,
        subCategories: [
          SubCategory(
              id: 'util_electricity',
              name: 'Электричество',
              icon: Icons.electric_bolt,
              color: Colors.teal),
          SubCategory(
              id: 'util_water',
              name: 'Вода',
              icon: Icons.water_drop,
              color: Colors.cyan),
          SubCategory(
              id: 'util_gas',
              name: 'Газ',
              icon: Icons.fireplace,
              color: Colors.lightGreen),
        ],
      ),
      Category(
        id: 'exp_communication',
        name: 'Связь',
        icon: Icons.phone_android,
        color: Colors.amber,
        subCategories: [
          SubCategory(
              id: 'comm_mobile',
              name: 'Мобильная связь',
              icon: Icons.phone_android,
              color: Colors.amber),
          SubCategory(
              id: 'comm_internet',
              name: 'Домашний интернет',
              icon: Icons.wifi,
              color: Colors.orange),
        ],
      ),
      Category(
        id: 'exp_health',
        name: 'Здоровье',
        icon: Icons.health_and_safety,
        color: Colors.red,
        subCategories: [
          SubCategory(
              id: 'health_pharmacy',
              name: 'Аптека',
              icon: Icons.local_pharmacy,
              color: Colors.red),
          SubCategory(
              id: 'health_doctor',
              name: 'Врачи',
              icon: Icons.medical_services,
              color: Colors.pink),
        ],
      ),
      Category(
        id: 'exp_shopping',
        name: 'Покупки',
        icon: Icons.shopping_bag,
        color: Colors.pink,
        subCategories: [
          SubCategory(
              id: 'shop_clothes',
              name: 'Одежда',
              icon: Icons.checkroom,
              color: Colors.pink),
          SubCategory(
              id: 'shop_electronics',
              name: 'Электроника',
              icon: Icons.laptop,
              color: Colors.purple),
          SubCategory(
              id: 'shop_home',
              name: 'Для дома',
              icon: Icons.home,
              color: Colors.brown),
        ],
      ),
      // ДОХОДЫ
      Category(
        id: 'inc_salary',
        name: 'Зарплата',
        icon: Icons.work,
        color: Colors.green,
        subCategories: [
          SubCategory(
              id: 'salary_main',
              name: 'Основная',
              icon: Icons.work,
              color: Colors.green),
          SubCategory(
              id: 'salary_bonus',
              name: 'Премия',
              icon: Icons.emoji_events,
              color: Colors.lightGreen),
        ],
      ),
      Category(
        id: 'inc_freelance',
        name: 'Фриланс',
        icon: Icons.computer,
        color: Colors.indigo,
        subCategories: [
          SubCategory(
              id: 'freelance_dev',
              name: 'Разработка',
              icon: Icons.code,
              color: Colors.indigo),
          SubCategory(
              id: 'freelance_design',
              name: 'Дизайн',
              icon: Icons.design_services,
              color: Colors.blue),
        ],
      ),
      Category(
        id: 'inc_investments',
        name: 'Инвестиции',
        icon: Icons.trending_up,
        color: Colors.cyan,
        subCategories: [
          SubCategory(
              id: 'inv_dividends',
              name: 'Дивиденды',
              icon: Icons.paid,
              color: Colors.cyan),
          SubCategory(
              id: 'inv_stocks',
              name: 'Акции',
              icon: Icons.show_chart,
              color: Colors.teal),
        ],
      ),
      Category(
        id: 'inc_interest',
        name: 'Проценты',
        icon: Icons.percent,
        color: Colors.orange,
        subCategories: [
          SubCategory(
              id: 'int_deposit',
              name: 'Проценты по вкладу',
              icon: Icons.account_balance,
              color: Colors.orange),
          SubCategory(
              id: 'int_savings',
              name: 'Проценты по накоплениям',
              icon: Icons.savings,
              color: Colors.green),
        ],
      ),
    ];
  }

  static Future<List<Account>> _createAccounts() async {
    return [
      Account(
        id: 'acc_cash',
        name: 'Наличные',
        balance: 45230.50,
        initialBalance: 50000,
        createdDate: DateTime(2026, 1, 1),
        currency: '₽',
        type: AccountType.cash,
        icon: Icons.money,
        color: Colors.green,
        showOnHomeScreen: true,
        isMain: true,
      ),
      Account(
        id: 'acc_card',
        name: 'Дебетовая карта',
        balance: 125000.75,
        initialBalance: 150000,
        createdDate: DateTime(2026, 1, 1),
        currency: '₽',
        type: AccountType.debitCard,
        icon: Icons.credit_card,
        color: Colors.blue,
        showOnHomeScreen: true,
        isMain: true,
      ),
      Account(
        id: 'acc_savings',
        name: 'Накопительный счёт',
        balance: 180000,
        initialBalance: 100000,
        createdDate: DateTime(2026, 1, 1),
        currency: '₽',
        type: AccountType.savings,
        icon: Icons.savings,
        color: Colors.teal,
        showOnHomeScreen: true,
        isMain: false,
        interestRate: 12.5,
        interestAccountId: 'acc_card',
        interestPeriod: 'month',
        interestCalculationType: 'actual',
      ),
      Account(
        id: 'acc_deposit',
        name: 'Вклад "Доходный"',
        balance: 350000,
        initialBalance: 350000,
        createdDate: DateTime(2026, 1, 1),
        currency: '₽',
        type: AccountType.deposit,
        icon: Icons.account_balance,
        color: Colors.purple,
        showOnHomeScreen: false,
        isMain: false,
        interestRate: 15.0,
        isCapitalized: true,
        capitalizationFrequency: 'month',
        depositEndDate: DateTime(2026, 12, 31),
        depositStartDate: DateTime(2026, 1, 1),
        depositTermYears: 1,
        closureAccountId: 'acc_card',
        allowDeposit: true,
        allowWithdraw: false,
      ),
      Account(
        id: 'acc_loan',
        name: 'Кредит наличными',
        balance: -762000,
        initialBalance: -1000000,
        createdDate: DateTime(2026, 1, 1),
        currency: '₽',
        type: AccountType.loan,
        icon: Icons.trending_down,
        color: Colors.red,
        showOnHomeScreen: true,
        isMain: false,
        interestRate: 17.0,
        principalAmount: 1000000,
        remainingPrincipal: 762000,
        monthlyPayment: 21000,
        remainingMonths: 38,
        loanTermMonths: 60,
        paymentType: 'annuity',
        paymentDay: 5,
      ),
      Account(
        id: 'acc_debt_me',
        name: 'Долг мне (Петров)',
        balance: -50000,
        initialBalance: -50000,
        createdDate: DateTime(2026, 1, 1),
        currency: '₽',
        type: AccountType.debtOwed,
        icon: Icons.assignment_return,
        color: Colors.amber,
        showOnHomeScreen: true,
        isMain: false,
      ),
      Account(
        id: 'acc_debt_i_owe',
        name: 'Должен я (Кредит от друзей)',
        balance: -30000,
        initialBalance: -30000,
        createdDate: DateTime(2026, 1, 1),
        currency: '₽',
        type: AccountType.debtToPay,
        icon: Icons.assignment_late,
        color: Colors.brown,
        showOnHomeScreen: true,
        isMain: false,
      ),
    ];
  }

  static Future<List<Transaction>> _createTransactions() async {
    final transactions = <Transaction>[];
    final now = DateTime.now();

    for (int i = 0; i < 6; i++) {
      final date = DateTime(now.year, now.month - i, 1);
      if (date.month < 1) continue;

      final month = date.month;
      final year = date.year;

      // ========== ДОХОДЫ ==========
      // Зарплата (на дебетовую карту)
      transactions.add(Transaction(
        id: 'salary_${year}_${month}',
        userId: demoUserId,
        title: 'Зарплата',
        amount: 125000.00,
        date: DateTime(year, month, 25),
        type: TransactionType.income,
        category: 'Зарплата',
        subCategory: 'Основная',
        accountId: 'acc_card',
      ));

      // Премия (раз в квартал)
      if (month == 3 || month == 6 || month == 9 || month == 12) {
        transactions.add(Transaction(
          id: 'bonus_${year}_${month}',
          userId: demoUserId,
          title: 'Премия',
          amount: 35000.00,
          date: DateTime(year, month, 28),
          type: TransactionType.income,
          category: 'Зарплата',
          subCategory: 'Премия',
          accountId: 'acc_card',
        ));
      }

      // Фриланс
      transactions.add(Transaction(
        id: 'freelance_${year}_${month}',
        userId: demoUserId,
        title: 'Фриланс',
        amount: 25000.00,
        date: DateTime(year, month, 20),
        type: TransactionType.income,
        category: 'Фриланс',
        subCategory: 'Разработка',
        accountId: 'acc_card',
      ));

      // ========== РАСХОДЫ ==========
      // Продукты (2 раза в месяц)
      transactions.addAll([
        Transaction(
          id: 'food1_${year}_${month}',
          userId: demoUserId,
          title: 'Продукты',
          amount: 8500.50,
          date: DateTime(year, month, 5),
          type: TransactionType.expense,
          category: 'Продукты',
          subCategory: 'Супермаркет',
          accountId: 'acc_card',
        ),
        Transaction(
          id: 'food2_${year}_${month}',
          userId: demoUserId,
          title: 'Продукты',
          amount: 7200.30,
          date: DateTime(year, month, 20),
          type: TransactionType.expense,
          category: 'Продукты',
          subCategory: 'Супермаркет',
          accountId: 'acc_card',
        ),
        Transaction(
          id: 'cafe_${year}_${month}',
          userId: demoUserId,
          title: 'Кафе',
          amount: 4500.00,
          date: DateTime(year, month, 15),
          type: TransactionType.expense,
          category: 'Продукты',
          subCategory: 'Кафе и рестораны',
          accountId: 'acc_card',
        ),
      ]);

      // Транспорт
      transactions.addAll([
        Transaction(
          id: 'transport_public_${year}_${month}',
          userId: demoUserId,
          title: 'Общественный транспорт',
          amount: 2500.00,
          date: DateTime(year, month, 10),
          type: TransactionType.expense,
          category: 'Транспорт',
          subCategory: 'Общественный транспорт',
          accountId: 'acc_card',
        ),
        Transaction(
          id: 'transport_taxi_${year}_${month}',
          userId: demoUserId,
          title: 'Такси',
          amount: 1800.00,
          date: DateTime(year, month, 25),
          type: TransactionType.expense,
          category: 'Транспорт',
          subCategory: 'Такси',
          accountId: 'acc_card',
        ),
      ]);

      // Развлечения
      transactions.addAll([
        Transaction(
          id: 'cinema_${year}_${month}',
          userId: demoUserId,
          title: 'Кино',
          amount: 1200.00,
          date: DateTime(year, month, 12),
          type: TransactionType.expense,
          category: 'Развлечения',
          subCategory: 'Кино',
          accountId: 'acc_card',
        ),
        Transaction(
          id: 'games_${year}_${month}',
          userId: demoUserId,
          title: 'Игры',
          amount: 3000.00,
          date: DateTime(year, month, 18),
          type: TransactionType.expense,
          category: 'Развлечения',
          subCategory: 'Игры',
          accountId: 'acc_card',
        ),
      ]);

      // Коммунальные
      transactions.add(Transaction(
        id: 'utilities_${year}_${month}',
        userId: demoUserId,
        title: 'Коммунальные',
        amount: 6200.00,
        date: DateTime(year, month, 10),
        type: TransactionType.expense,
        category: 'Коммунальные платежи',
        subCategory: 'Электричество',
        accountId: 'acc_card',
      ));

      // Связь
      transactions.addAll([
        Transaction(
          id: 'mobile_${year}_${month}',
          userId: demoUserId,
          title: 'Мобильная связь',
          amount: 650.00,
          date: DateTime(year, month, 8),
          type: TransactionType.expense,
          category: 'Связь',
          subCategory: 'Мобильная связь',
          accountId: 'acc_card',
        ),
        Transaction(
          id: 'internet_${year}_${month}',
          userId: demoUserId,
          title: 'Домашний интернет',
          amount: 750.00,
          date: DateTime(year, month, 8),
          type: TransactionType.expense,
          category: 'Связь',
          subCategory: 'Домашний интернет',
          accountId: 'acc_card',
        ),
      ]);

      // Здоровье
      transactions.add(Transaction(
        id: 'health_${year}_${month}',
        userId: demoUserId,
        title: 'Аптека',
        amount: 1800.00,
        date: DateTime(year, month, 22),
        type: TransactionType.expense,
        category: 'Здоровье',
        subCategory: 'Аптека',
        accountId: 'acc_card',
      ));

      // Покупки
      if (month == 3 || month == 9) {
        transactions.add(Transaction(
          id: 'shopping_${year}_${month}',
          userId: demoUserId,
          title: 'Одежда',
          amount: 12000.00,
          date: DateTime(year, month, 15),
          type: TransactionType.expense,
          category: 'Покупки',
          subCategory: 'Одежда',
          accountId: 'acc_card',
        ));
      }

      // ========== ПЕРЕВОДЫ ==========
      // Перевод на накопительный счёт
      transactions.add(Transaction(
        id: 'transfer_savings_${year}_${month}',
        userId: demoUserId,
        title: 'Перевод',
        amount: 15000.00,
        date: DateTime(year, month, 28),
        type: TransactionType.expense,
        category: 'Перевод',
        fromAccountId: 'acc_card',
        toAccountId: 'acc_savings',
      ));

      // Платёж по кредиту
      transactions.add(Transaction(
        id: 'loan_payment_${year}_${month}',
        userId: demoUserId,
        title: 'Платёж по кредиту',
        amount: 21000.00,
        date: DateTime(year, month, 5),
        type: TransactionType.expense,
        category: 'Перевод',
        fromAccountId: 'acc_card',
        toAccountId: 'acc_loan',
      ));

      // Возврат долга (мне должны)
      if (month % 3 == 0) {
        transactions.add(Transaction(
          id: 'debt_return_${year}_${month}',
          userId: demoUserId,
          title: 'Возврат долга',
          amount: 10000.00,
          date: DateTime(year, month, 20),
          type: TransactionType.expense,
          category: 'Перевод',
          fromAccountId: 'acc_debt_me',
          toAccountId: 'acc_card',
        ));
      }

      // Платёж по моему долгу
      if (month % 2 == 0) {
        transactions.add(Transaction(
          id: 'debt_payment_${year}_${month}',
          userId: demoUserId,
          title: 'Платеж по долгу',
          amount: 5000.00,
          date: DateTime(year, month, 15),
          type: TransactionType.expense,
          category: 'Перевод',
          fromAccountId: 'acc_card',
          toAccountId: 'acc_debt_i_owe',
        ));
      }

      // ========== РЕГУЛЯРНЫЕ ПЛАТЕЖИ (помечаем как регулярные) ==========
      if (i == 0) {
        // Помечаем некоторые транзакции как регулярные (для демонстрации)
        _markAsRecurring(transactions, 'food1_${year}_${month}', 'month', 1);
        _markAsRecurring(
            transactions, 'utilities_${year}_${month}', 'month', 1);
        _markAsRecurring(transactions, 'mobile_${year}_${month}', 'month', 1);
        _markAsRecurring(transactions, 'internet_${year}_${month}', 'month', 1);
        _markAsRecurring(
            transactions, 'loan_payment_${year}_${month}', 'month', 1);
        _markAsRecurring(
            transactions, 'transfer_savings_${year}_${month}', 'month', 1);
      }
    }

    // ========== АВТОМАТИЧЕСКИЕ НАЧИСЛЕНИЯ ПРОЦЕНТОВ ==========
    // Проценты по накопительному счету (каждый месяц)
    for (int i = 0; i < 6; i++) {
      final date = DateTime(now.year, now.month - i, 1);
      if (date.month < 1) continue;

      transactions.add(Transaction(
        id: 'savings_interest_${date.year}_${date.month}',
        userId: demoUserId,
        title: 'Проценты по накопительному счету',
        amount: 1250.00,
        date: DateTime(date.year, date.month, 1),
        type: TransactionType.income,
        category: 'Проценты',
        subCategory: 'Проценты по накоплениям',
        accountId: 'acc_savings',
      ));

      // Проценты по вкладу
      transactions.add(Transaction(
        id: 'deposit_interest_${date.year}_${date.month}',
        userId: demoUserId,
        title: 'Проценты по вкладу',
        amount: 4375.00,
        date: DateTime(date.year, date.month, 1),
        type: TransactionType.income,
        category: 'Проценты',
        subCategory: 'Проценты по вкладу',
        accountId: 'acc_deposit',
      ));
    }

    return transactions;
  }

  static void _markAsRecurring(List<Transaction> transactions, String id,
      String frequency, int interval) {
    final index = transactions.indexWhere((t) => t.id == id);
    if (index != -1) {
      transactions[index].isRecurring = true;
      transactions[index].recurringFrequency = frequency;
      transactions[index].recurringInterval = interval;
    }
  }

  static Future<List<Goal>> _createGoals(List<Account> accounts) async {
    final savingsAccount = accounts.firstWhere((a) => a.id == 'acc_savings');
    final cardAccount = accounts.firstWhere((a) => a.id == 'acc_card');

    return [
      Goal(
        id: 'goal_iphone',
        title: 'iPhone 15 Pro',
        targetAmount: 120000,
        currentAmount: 45000,
        targetDate: DateTime(2026, 12, 31),
        accountId: savingsAccount.id, // привязана к накопительному счету
        icon: Icons.phone_iphone,
        color: Colors.blue,
      ),
      Goal(
        id: 'goal_travel',
        title: 'Путешествие на море',
        targetAmount: 200000,
        currentAmount: 75000,
        targetDate: DateTime(2026, 7, 15),
        accountId: savingsAccount.id,
        icon: Icons.flight,
        color: Colors.teal,
      ),
      Goal(
        id: 'goal_laptop',
        title: 'Новый ноутбук',
        targetAmount: 90000,
        currentAmount: 30000,
        targetDate: DateTime(2026, 10, 1),
        accountId: cardAccount.id,
        icon: Icons.laptop,
        color: Colors.purple,
      ),
      Goal(
        id: 'goal_emergency',
        title: 'Подушка безопасности',
        targetAmount: 300000,
        currentAmount: 150000,
        targetDate: DateTime(2027, 1, 1),
        accountId: savingsAccount.id,
        icon: Icons.shield,
        color: Colors.green,
      ),
    ];
  }
}
