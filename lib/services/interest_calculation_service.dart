import 'dart:math';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction_models.dart';
import 'transaction_service.dart';
import 'category_service.dart';
import 'api_service.dart'; // 👈 ДОБАВИТЬ

class InterestCalculationService {
  static String? get _userId => ApiService.currentUserId;

  static Future<String> _getUserIdSafe() async {
    final userId = _userId;
    if (userId == null || userId.isEmpty) {
      print('⚠️ userId не найден, используем default_user');
      return 'default_user';
    }
    return userId;
  }

  // ========== РАСЧЕТ КРЕДИТА ==========

  double calculateAnnuityPayment(
      double principal, double annualRate, int months) {
    if (principal <= 0 || annualRate <= 0 || months <= 0) return 0;
    final monthlyRate = annualRate / 100 / 12;
    if (monthlyRate == 0) return principal / months;
    final factor = monthlyRate *
        pow(1 + monthlyRate, months) /
        (pow(1 + monthlyRate, months) - 1);
    return principal * factor;
  }

  Map<String, double> calculateDifferentiatedPayment(
      double principal, double annualRate, int totalMonths, int currentMonth) {
    if (principal <= 0 || annualRate <= 0 || totalMonths <= 0) {
      return {'principal': 0, 'interest': 0, 'total': 0};
    }
    final monthlyRate = annualRate / 100 / 12;
    final remainingPrincipal =
        principal * (1 - (currentMonth - 1) / totalMonths);
    final principalPortion = principal / totalMonths;
    final interestPortion = remainingPrincipal * monthlyRate;
    return {
      'principal': principalPortion,
      'interest': interestPortion,
      'total': principalPortion + interestPortion,
    };
  }

  Future<void> recalcLoanAfterEarlyPayment(
      Account account, double extraAmount) async {
    if (account.type != AccountType.loan) return;

    final remainingPrincipal =
        (account.remainingPrincipal ?? account.principalAmount!) - extraAmount;
    if (remainingPrincipal <= 0) {
      final accounts = await CategoryService.loadAccounts();
      accounts.removeWhere((a) => a.id == account.id);
      await CategoryService.saveAccounts(accounts);
      return;
    }

    final totalMonths = account.loanTermMonths ?? 36;

    if (account.loanPaymentType == 'annuity') {
      final newPayment = calculateAnnuityPayment(
          remainingPrincipal, account.interestRate!, totalMonths);
      final accounts = await CategoryService.loadAccounts();
      final index = accounts.indexWhere((a) => a.id == account.id);
      if (index != -1) {
        accounts[index].remainingPrincipal = remainingPrincipal;
        accounts[index].originalMonthlyPayment = newPayment;
        await CategoryService.saveAccounts(accounts);
      }
    } else {
      final newMonths =
          (remainingPrincipal / (account.principalAmount! / totalMonths))
              .ceil();
      final accounts = await CategoryService.loadAccounts();
      final index = accounts.indexWhere((a) => a.id == account.id);
      if (index != -1) {
        accounts[index].remainingPrincipal = remainingPrincipal;
        accounts[index].remainingMonths = newMonths;
        await CategoryService.saveAccounts(accounts);
      }
    }
  }

  // ========== НАКОПИТЕЛЬНЫЙ СЧЕТ ==========

  Future<void> processSavingsInterest(
      Account account, DateTime currentDate) async {
    final userId = await _getUserIdSafe();
    if (account.type != AccountType.savings) return;
    if (account.interestRate == null || account.interestRate == 0) return;

    double balance = account.balance;
    if (balance <= 0) return;

    double dailyRate = account.interestRate! / 100 / 365;
    double monthlyInterest = balance * dailyRate * 30;

    if (monthlyInterest <= 0) return;

    final transaction = Transaction(
      id: 'interest_${account.id}_${DateTime.now().millisecondsSinceEpoch}',
      userId: userId,
      title: 'Проценты по накопительному счету',
      amount: monthlyInterest,
      date: currentDate,
      type: TransactionType.income,
      category: 'Проценты',
      subCategory: account.name,
      accountId: account.id,
      comment: 'Автоматическое начисление процентов',
      isRecurring: false,
    );

    await TransactionService.addTransaction(transaction);

    final accounts = await CategoryService.loadAccounts();
    final index = accounts.indexWhere((a) => a.id == account.id);
    if (index != -1) {
      accounts[index].totalInterestAccrued =
          (accounts[index].totalInterestAccrued ?? 0) + monthlyInterest;
      accounts[index].accruedInterestThisPeriod =
          (accounts[index].accruedInterestThisPeriod ?? 0) + monthlyInterest;
      await CategoryService.saveAccounts(accounts);
    }

    await _addInterestNotification(
        account.name, monthlyInterest, 'накопительному счету');

    print(
        '💰 Начислены проценты ${monthlyInterest.toStringAsFixed(2)} ₽ на счет ${account.name}');
  }

  // ========== ВКЛАД ==========

  Future<void> processDepositInterest(
      Account account, DateTime currentDate) async {
    final userId = await _getUserIdSafe();
    if (account.type != AccountType.deposit) return;
    if (account.interestRate == null || account.interestRate == 0) return;

    final prefs = await SharedPreferences.getInstance();
    final lastCalcKey = 'last_deposit_interest_${account.id}_$userId';
    final lastDateStr = prefs.getString(lastCalcKey);

    DateTime lastDate = lastDateStr != null
        ? DateTime.parse(lastDateStr)
        : account.createdDate ??
            DateTime.now().subtract(const Duration(days: 30));

    if (lastDate.year == currentDate.year &&
        lastDate.month == currentDate.month) {
      return;
    }

    double balance = account.balance;
    if (balance <= 0) return;

    double monthlyRate = account.interestRate! / 100 / 12;
    double monthlyInterest = balance * monthlyRate;

    if (monthlyInterest <= 0) return;

    final transaction = Transaction(
      id: 'deposit_interest_${account.id}_${DateTime.now().millisecondsSinceEpoch}',
      userId: userId,
      title: 'Проценты по вкладу "${account.name}"',
      amount: monthlyInterest,
      date: currentDate,
      type: TransactionType.income,
      category: 'Проценты',
      subCategory: account.name,
      accountId: account.id,
      comment: 'Автоматическое начисление процентов',
      isRecurring: false,
    );

    await TransactionService.addTransaction(transaction);

    final accounts = await CategoryService.loadAccounts();
    final index = accounts.indexWhere((a) => a.id == account.id);
    if (index != -1) {
      accounts[index].accruedInterestThisPeriod =
          (accounts[index].accruedInterestThisPeriod ?? 0) + monthlyInterest;
      accounts[index].totalInterestAccrued =
          (accounts[index].totalInterestAccrued ?? 0) + monthlyInterest;
      await CategoryService.saveAccounts(accounts);
    }

    await prefs.setString(lastCalcKey, currentDate.toIso8601String());

    await _addInterestNotification(account.name, monthlyInterest, 'вкладу');

    print(
        '💰 Начислены проценты по вкладу ${monthlyInterest.toStringAsFixed(2)} ₽ на счет ${account.name}');
  }

  /// Проверка и закрытие вклада, если срок истек
  Future<void> checkAndCloseDeposit(
      Account account, DateTime currentDate) async {
    final userId = await _getUserIdSafe();

    print('🔍🔍🔍 checkAndCloseDeposit вызван для ${account.name}');
    print('   depositEndDate: ${account.depositEndDate}');
    print('   currentDate: $currentDate');

    if (account.type != AccountType.deposit) {
      print('   ❌ Не вклад, пропускаем');
      return;
    }
    if (account.depositEndDate == null) {
      print('   ❌ Нет даты закрытия, пропускаем');
      return;
    }

    final endDateOnly = DateTime(account.depositEndDate!.year,
        account.depositEndDate!.month, account.depositEndDate!.day);
    final currentDateOnly =
        DateTime(currentDate.year, currentDate.month, currentDate.day);

    if (currentDateOnly.isAfter(endDateOnly) ||
        currentDateOnly.isAtSameMomentAs(endDateOnly)) {
      print('   ✅ Вклад должен быть закрыт!');

      // ✅ 1. СНАЧАЛА начисляем проценты за последний месяц
      print('   📍 Шаг 1: Начисляем проценты...');
      await processDepositInterest(account, currentDate);

      // ✅ 2. ПОТОМ закрываем вклад
      print('   📍 Шаг 2: Закрываем вклад...');
      await _closeDeposit(account, currentDate, userId);

      print('   ✅ Вклад успешно закрыт');
    } else {
      print('   ⏳ Дата закрытия еще не наступила');
    }
  }

  Future<void> _closeDeposit(
      Account account, DateTime currentDate, String userId) async {
    print('🏦 НАЧАЛО ЗАКРЫТИЯ ВКЛАДА: ${account.name}');
    print('   closureAccountId: ${account.closureAccountId}');
    print('   balance: ${account.balance}');

    if (account.closureAccountId == null) {
      print('   ❌ Нет счета для закрытия!');
      return;
    }

    final accounts = await CategoryService.loadAccounts();

    final depositIndex = accounts.indexWhere((a) => a.id == account.id);
    final targetIndex =
        accounts.indexWhere((a) => a.id == account.closureAccountId);

    if (depositIndex != -1 && targetIndex != -1) {
      final depositName = accounts[depositIndex].name;
      final amount = accounts[depositIndex].balance;

      print('   Закрываем вклад "$depositName", сумма: $amount');

      // ✅ СОЗДАЕМ ТРАНЗАКЦИЮ КАК ДОХОД
      final transaction = Transaction(
        id: 'deposit_close_${account.id}_${DateTime.now().millisecondsSinceEpoch}',
        userId: userId,
        title: 'Закрытие вклада "$depositName"',
        amount: amount,
        date: currentDate,
        type: TransactionType.income,
        category: 'Закрытие вклада',
        subCategory: depositName,
        accountId: account.closureAccountId,
        comment: 'Автоматическое закрытие вклада по окончании срока',
        isRecurring: false,
        fromAccountId: null,
        toAccountId: null,
      );

      // ✅ ДОБАВЛЯЕМ ТРАНЗАКЦИЮ
      await TransactionService.addTransaction(transaction);
      print('   ✅ Транзакция закрытия создана и добавлена в список');

      // Сохраняем название закрытого вклада
      await _saveClosedDepositName(account.id, depositName);

      // Переводим деньги
      accounts[targetIndex].balance += amount;
      accounts.removeAt(depositIndex);

      await CategoryService.saveAccounts(accounts);
      await _addDepositClosureNotification(
          depositName, amount, account.closureAccountId!);

      print('🏦 Вклад "$depositName" закрыт, транзакция добавлена');
    }
  }

  // ✅ МЕТОД СОХРАНЕНИЯ НАЗВАНИЯ (ТОЛЬКО ОДИН РАЗ!)
  Future<void> _saveClosedDepositName(
      String accountId, String depositName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('closed_deposit_name_$accountId', depositName);
    print(
        '💾 Сохранено название закрытого вклада: $depositName для id $accountId');
  }

  // ========== ВСПОМОГАТЕЛЬНЫЕ МЕТОДЫ ==========

  Future<void> _addInterestNotification(
      String accountName, double amount, String accountType) async {
    final prefs = await SharedPreferences.getInstance();
    final notificationsJson = prefs.getString('notifications');
    List<dynamic> notifications = [];
    if (notificationsJson != null) {
      notifications = jsonDecode(notificationsJson);
    }

    final newNotification = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'title': '💰 Начислены проценты',
      'message':
          'На $accountType "$accountName" начислено ${_formatAmount(amount)}',
      'date': DateTime.now().toIso8601String(),
      'isRead': false,
    };

    notifications.insert(0, newNotification);
    await prefs.setString('notifications', jsonEncode(notifications));
  }

  Future<void> _addDepositClosureNotification(
      String accountName, double amount, String targetAccountId) async {
    final prefs = await SharedPreferences.getInstance();
    final notificationsJson = prefs.getString('notifications');
    List<dynamic> notifications = [];
    if (notificationsJson != null) {
      notifications = jsonDecode(notificationsJson);
    }

    String targetAccountName = 'неизвестный счет';
    try {
      final accounts = await CategoryService.loadAccounts();
      final targetAccount = accounts.firstWhere((a) => a.id == targetAccountId);
      targetAccountName = targetAccount.name;
    } catch (e) {
      print('❌ Не удалось найти счет для уведомления: $e');
    }

    final newNotification = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'title': '🏦 Вклад закрыт',
      'message':
          'Вклад "$accountName" закрыт. Сумма ${_formatAmount(amount)} переведена на счет "$targetAccountName"',
      'date': DateTime.now().toIso8601String(),
      'isRead': false,
    };

    notifications.insert(0, newNotification);
    await prefs.setString('notifications', jsonEncode(notifications));
  }

  String _formatAmount(double amount) {
    return '${amount.toStringAsFixed(2)} ₽';
  }

  // ❌ УДАЛИТЬ ЭТОТ МЕТОД (он в конце файла):
  // Future<String> ApiService.currentUserId async { ... }
}
