import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction_models.dart';
import 'transaction_service.dart';
import 'category_service.dart';
import 'api_service.dart'; // 👈 ДОБАВИТЬ

class AccountInterestService {
  static String? get _userId => ApiService.currentUserId;

  /// Начисляет проценты по вкладу за месяц
  static Future<void> processDepositInterest(
      Account account, DateTime date) async {
    final userId = _userId;
    if (userId == null) {
      print('⚠️ Пользователь не авторизован, проценты не начислены');
      return;
    }

    if (account.type != AccountType.deposit) return;
    if (account.interestRate == null || account.interestRate == 0) return;

    print('💰 Начисление процентов по вкладу: ${account.name}');

    // Получаем баланс на начало месяца
    final startOfMonth = DateTime(date.year, date.month, 1);
    final balanceOnStart = await _getBalanceOnDate(account, startOfMonth);

    if (balanceOnStart <= 0) {
      print('   Баланс на начало месяца: 0, проценты не начислены');
      return;
    }

    // Расчёт процентов за месяц
    double monthlyRate = account.interestRate! / 100 / 12;
    double interest = balanceOnStart * monthlyRate;

    if (interest <= 0) return;

    print(
        '   Ставка: ${account.interestRate}%, баланс: $balanceOnStart, проценты: $interest');

    // Проверяем, не начисляли ли уже проценты за этот месяц
    final prefs = await SharedPreferences.getInstance();
    final lastInterestKey = 'last_interest_deposit_${account.id}_$userId';
    final lastInterestMonth = prefs.getString(lastInterestKey);
    final currentMonth = '${date.year}-${date.month}';

    if (lastInterestMonth == currentMonth) {
      print('   Проценты за этот месяц уже начислены, пропускаем');
      return;
    }

    // Если есть капитализация — добавляем к балансу
    if (account.isCapitalized == true) {
      // Обновляем баланс счета
      final accounts = await CategoryService.loadAccounts();
      final index = accounts.indexWhere((a) => a.id == account.id);
      if (index != -1) {
        accounts[index].balance += interest;
        await CategoryService.saveAccounts(accounts);
        print('   Баланс счета увеличен на $interest');
      }
    }

    // Создаём транзакцию начисления процентов
    final interestTransaction = Transaction(
      id: 'deposit_interest_${account.id}_${DateTime.now().millisecondsSinceEpoch}',
      userId: userId,
      title: 'Проценты по вкладу "${account.name}"',
      amount: interest,
      date: date,
      type: TransactionType.income,
      category: 'Проценты',
      subCategory: 'Вклад',
      accountId: account.id,
      comment: 'Автоматическое начисление процентов за ${_getMonthName(date)}',
      isRecurring: false,
    );

    await TransactionService.addTransaction(interestTransaction);

    // Сохраняем отметку, что проценты за этот месяц начислены
    await prefs.setString(lastInterestKey, currentMonth);

    print('✅ Проценты по вкладу ${account.name} начислены: $interest');
  }

  /// Начисляет проценты по накопительному счету
  static Future<void> processSavingsInterest(
      Account account, DateTime date) async {
    final userId = _userId;
    if (userId == null) {
      print('⚠️ Пользователь не авторизован, проценты не начислены');
      return;
    }

    if (account.type != AccountType.savings) return;
    if (account.interestRate == null || account.interestRate == 0) return;

    print('💰 Начисление процентов по накопительному счету: ${account.name}');

    // Получаем минимальный остаток за месяц
    final balance = await _getMinimumBalanceForMonth(account, date);

    if (balance <= 0) {
      print('   Минимальный баланс за месяц: 0, проценты не начислены');
      return;
    }

    double monthlyRate = account.interestRate! / 100 / 12;
    double interest = balance * monthlyRate;

    if (interest <= 0) return;

    print(
        '   Ставка: ${account.interestRate}%, мин.баланс: $balance, проценты: $interest');

    // Проверяем, не начисляли ли уже проценты за этот месяц
    final prefs = await SharedPreferences.getInstance();
    final lastInterestKey = 'last_interest_savings_${account.id}_$userId';
    final lastInterestMonth = prefs.getString(lastInterestKey);
    final currentMonth = '${date.year}-${date.month}';

    if (lastInterestMonth == currentMonth) {
      print('   Проценты за этот месяц уже начислены, пропускаем');
      return;
    }

    final interestTransaction = Transaction(
      id: 'savings_interest_${account.id}_${DateTime.now().millisecondsSinceEpoch}',
      userId: userId,
      title: 'Проценты по накопительному счету "${account.name}"',
      amount: interest,
      date: date,
      type: TransactionType.income,
      category: 'Проценты',
      subCategory: 'Накопления',
      accountId: account.id,
      comment: 'Автоматическое начисление процентов за ${_getMonthName(date)}',
      isRecurring: false,
    );

    await TransactionService.addTransaction(interestTransaction);

    // Сохраняем отметку, что проценты за этот месяц начислены
    await prefs.setString(lastInterestKey, currentMonth);

    print(
        '✅ Проценты по накопительному счету ${account.name} начислены: $interest');
  }

  /// Начисляет проценты по кредиту
  static Future<void> processLoanInterest(
      Account account, DateTime date) async {
    final userId = _userId;
    if (userId == null) {
      print('⚠️ Пользователь не авторизован, проценты не начислены');
      return;
    }

    if (account.type != AccountType.loan) return;
    if (account.interestRate == null || account.interestRate == 0) return;

    final remainingPrincipal =
        (account.remainingPrincipal ?? account.balance.abs()).abs();

    if (remainingPrincipal <= 0) return;

    print('💰 Начисление процентов по кредиту: ${account.name}');

    double monthlyRate = account.interestRate! / 100 / 12;
    double interest = remainingPrincipal * monthlyRate;

    if (interest <= 0) return;

    // Проверяем, не начисляли ли уже проценты за этот месяц
    final prefs = await SharedPreferences.getInstance();
    final lastInterestKey = 'last_interest_loan_${account.id}_$userId';
    final lastInterestMonth = prefs.getString(lastInterestKey);
    final currentMonth = '${date.year}-${date.month}';

    if (lastInterestMonth == currentMonth) {
      print('   Проценты за этот месяц уже начислены, пропускаем');
      return;
    }

    final interestTransaction = Transaction(
      id: 'loan_interest_${account.id}_${DateTime.now().millisecondsSinceEpoch}',
      userId: userId,
      title: 'Проценты по кредиту "${account.name}"',
      amount: interest,
      date: date,
      type: TransactionType.expense,
      category: 'Проценты',
      subCategory: 'Кредит',
      accountId: account.id,
      comment: 'Автоматическое начисление процентов за ${_getMonthName(date)}',
      isRecurring: false,
    );

    await TransactionService.addTransaction(interestTransaction);

    // Сохраняем отметку, что проценты за этот месяц начислены
    await prefs.setString(lastInterestKey, currentMonth);

    print('✅ Проценты по кредиту ${account.name} начислены: $interest');
  }

  /// Рассчитывает остаток по кредиту
  static Future<double> getLoanRemainingBalance(Account account) async {
    if (account.type != AccountType.loan) return 0;

    // Получаем начальную сумму кредита
    double principal = account.principalAmount?.abs() ?? 0;
    double paid = await _getTotalPaidForLoan(account);

    double remaining = principal - paid;
    return remaining < 0 ? 0 : remaining;
  }

  /// Получает баланс на дату
  static Future<double> _getBalanceOnDate(
      Account account, DateTime date) async {
    final transactions = await TransactionService.loadTransactions();
    double balance = 0;

    for (var t in transactions) {
      if (t.accountId == account.id &&
          t.date.isBefore(date.add(const Duration(days: 1)))) {
        if (t.type == TransactionType.income) {
          balance += t.amount;
        } else if (t.type == TransactionType.expense &&
            t.fromAccountId == null) {
          balance -= t.amount;
        }
      }
    }
    return balance;
  }

  /// Получает минимальный остаток за месяц
  static Future<double> _getMinimumBalanceForMonth(
      Account account, DateTime date) async {
    final transactions = await TransactionService.loadTransactions();
    final startOfMonth = DateTime(date.year, date.month, 1);
    final endOfMonth = DateTime(date.year, date.month + 1, 0);

    double balance = await _getBalanceOnDate(account, startOfMonth);
    double minBalance = balance;

    // Сортируем транзакции по дате
    final monthTransactions = transactions
        .where((t) =>
            t.accountId == account.id &&
            t.date.isAfter(startOfMonth.subtract(const Duration(days: 1))) &&
            t.date.isBefore(endOfMonth.add(const Duration(days: 1))))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    for (var t in monthTransactions) {
      if (t.type == TransactionType.income) {
        balance += t.amount;
      } else if (t.type == TransactionType.expense && t.fromAccountId == null) {
        balance -= t.amount;
      }
      if (balance < minBalance) minBalance = balance;
    }

    return minBalance;
  }

  /// Получает общую сумму выплат по кредиту
  static Future<double> _getTotalPaidForLoan(Account account) async {
    final transactions = await TransactionService.loadTransactions();
    double paid = 0;

    for (var t in transactions) {
      // Платежи по кредиту (расходы на счет кредита ИЛИ переводы на кредит)
      if ((t.accountId == account.id && t.type == TransactionType.expense) ||
          (t.toAccountId == account.id)) {
        paid += t.amount;
      }
    }
    return paid;
  }

  static String _getMonthName(DateTime date) {
    const months = [
      'январь',
      'февраль',
      'март',
      'апрель',
      'май',
      'июнь',
      'июль',
      'август',
      'сентябрь',
      'октябрь',
      'ноябрь',
      'декабрь'
    ];
    return '${months[date.month - 1]} ${date.year}';
  }
}
