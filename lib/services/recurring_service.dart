import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/transaction_models.dart';
import '../models/notification_model.dart';
import 'transaction_service.dart';
import 'category_service.dart';
import 'account_interest_service.dart';
import 'interest_calculation_service.dart';
import 'api_service.dart'; // 👈 ДОБАВИТЬ

class RecurringService {
  static String? get _userId => ApiService.currentUserId;

  static Future<String> _getUserIdSafe() async {
    final userId = _userId;
    if (userId == null || userId.isEmpty) {
      return 'default_user';
    }
    return userId;
  }

  static Future<void> processRecurringPayments() async {
    print('🔄 НАЧАЛО ОБРАБОТКИ РЕГУЛЯРНЫХ ПЛАТЕЖЕЙ');

    final userId = await _getUserIdSafe();
    print('👤 Пользователь: $userId');

    final allTransactions = await TransactionService.loadTransactions();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final templates = allTransactions.where((t) => t.isRecurring).toList();
    print('📋 Найдено шаблонов: ${templates.length}');

    for (var template in templates) {
      print(
          '📝 Обработка: ${template.title}, интервал: ${template.recurringInterval} ${template.recurringFrequency}');

      final allNonRecurring =
          allTransactions.where((t) => !t.isRecurring).toList();

      final matchingTransactions = allNonRecurring
          .where((t) =>
              t.title == template.title &&
              t.category == template.category &&
              t.amount == template.amount)
          .toList();

      DateTime? lastDate;
      if (matchingTransactions.isNotEmpty) {
        matchingTransactions.sort((a, b) => b.date.compareTo(a.date));
        lastDate = matchingTransactions.first.date;
        print(
            '   Последняя созданная транзакция: ${lastDate.day}.${lastDate.month}.${lastDate.year}');
      }

      DateTime nextDate;
      if (lastDate == null) {
        final templateDate = DateTime(
            template.date.year, template.date.month, template.date.day);
        if (templateDate.isBefore(today)) {
          nextDate = today;
          print(
              '   Первая транзакция, дата шаблона в прошлом, создаем на сегодня: ${nextDate.day}.${nextDate.month}.${nextDate.year}');
        } else {
          nextDate = templateDate;
          print(
              '   Первая транзакция, дата шаблона: ${nextDate.day}.${nextDate.month}.${nextDate.year}');
        }
      } else {
        nextDate = _addInterval(
            lastDate,
            template.recurringFrequency ?? 'month',
            template.recurringInterval ?? 1);
        print(
            '   Следующая дата от ${lastDate.day}.${lastDate.month}.${lastDate.year}: ${nextDate.day}.${nextDate.month}.${nextDate.year}');
      }

      final nextDateOnly =
          DateTime(nextDate.year, nextDate.month, nextDate.day);

      if (nextDateOnly.isBefore(today) ||
          nextDateOnly.isAtSameMomentAs(today)) {
        print('   ✅ НУЖНО СОЗДАТЬ!');
        await _createRecurringTransaction(template, nextDateOnly);
      } else {
        print('   ⏳ Ещё не время');
      }
    }

    await _processMonthlyInterest(now);
  }

  static DateTime _addInterval(DateTime date, String frequency, int interval) {
    switch (frequency) {
      case 'day':
        return DateTime(date.year, date.month, date.day + interval);
      case 'week':
        return DateTime(date.year, date.month, date.day + (7 * interval));
      case 'month':
        int newMonth = date.month + interval;
        int newYear = date.year;
        while (newMonth > 12) {
          newMonth -= 12;
          newYear++;
        }
        while (newMonth < 1) {
          newMonth += 12;
          newYear--;
        }
        int newDay = date.day;
        final lastDay = DateTime(newYear, newMonth + 1, 0).day;
        if (newDay > lastDay) newDay = lastDay;
        return DateTime(newYear, newMonth, newDay);
      case 'year':
        return DateTime(date.year + interval, date.month, date.day);
      default:
        return DateTime(date.year, date.month + 1, date.day);
    }
  }

  static Future<void> _createRecurringTransaction(
      Transaction template, DateTime date) async {
    print(
        '🔥 СОЗДАНИЕ РЕГУЛЯРНОГО ПЛАТЕЖА: ${template.title} на ${date.day}.${date.month}.${date.year}');

    final existing = await TransactionService.loadTransactions();
    final exists = existing.any((t) =>
        t.title == template.title &&
        t.category == template.category &&
        t.amount == template.amount &&
        t.date.year == date.year &&
        t.date.month == date.month &&
        t.date.day == date.day);

    if (exists) {
      print('   ⚠️ Транзакция уже существует, пропускаем');
      return;
    }

    if (template.accountId != null) {
      final accounts = await CategoryService.loadAccounts();
      final accountIndex =
          accounts.indexWhere((a) => a.id == template.accountId);
      if (accountIndex != -1) {
        if (template.type == TransactionType.income) {
          accounts[accountIndex].balance += template.amount;
        } else {
          accounts[accountIndex].balance -= template.amount;
        }
        await CategoryService.saveAccounts(accounts);
        print('   💰 Баланс счета обновлен');
      }
    }

    final newTransaction = Transaction(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: template.userId,
      title: template.title,
      amount: template.amount,
      date: date,
      type: template.type,
      category: template.category,
      subCategory: template.subCategory,
      accountId: template.accountId,
      fromAccountId: template.fromAccountId,
      toAccountId: template.toAccountId,
      comment: 'Автоматический платеж (регулярный)',
      isRecurring: false,
      recurringFrequency: null,
      recurringInterval: null,
    );

    await TransactionService.addTransaction(newTransaction);

    // Добавляем уведомление о создании регулярного платежа
    await _addRecurringPaymentNotification(template, date);

    print(
        '✅ Авто-платеж создан: ${template.title} на ${date.day}.${date.month}.${date.year}');
  }

  static Future<void> _addRecurringPaymentNotification(
      Transaction template, DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    final notificationsKey = 'notifications_${await _getUserIdSafe()}';
    final notificationsJson = prefs.getString(notificationsKey);
    List<dynamic> notifications = [];
    if (notificationsJson != null) {
      notifications = jsonDecode(notificationsJson);
    }

    final typeText =
        template.type == TransactionType.income ? 'Доход' : 'Расход';
    final amountText = '${template.amount.toStringAsFixed(2)} ₽';
    final frequencyText = _getFrequencyText(
        template.recurringFrequency ?? 'month',
        template.recurringInterval ?? 1);

    final newNotification = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'title': '🔄 Регулярный платеж создан',
      'message':
          '$typeText "${template.title}" на сумму $amountText создан $frequencyText',
      'date': DateTime.now().toIso8601String(),
      'isRead': false,
    };

    notifications.insert(0, newNotification);
    await prefs.setString(notificationsKey, jsonEncode(notifications));
  }

  static String _getFrequencyText(String frequency, int interval) {
    switch (frequency) {
      case 'day':
        return interval == 1 ? 'каждый день' : 'каждые $interval дня';
      case 'week':
        return interval == 1 ? 'каждую неделю' : 'каждые $interval недели';
      case 'month':
        return interval == 1 ? 'каждый месяц' : 'каждые $interval месяца';
      case 'year':
        return interval == 1 ? 'каждый год' : 'каждые $interval года';
      default:
        return 'каждый месяц';
    }
  }

  static Future<void> _processMonthlyInterest(DateTime now) async {
    print('💰 НАЧАЛО НАЧИСЛЕНИЯ ПРОЦЕНТОВ ЗА ${now.month}.${now.year}');

    final userId = await _getUserIdSafe();
    final prefs = await SharedPreferences.getInstance();
    final lastInterestKey = 'last_interest_month_$userId';
    final lastInterestMonth = prefs.getString(lastInterestKey);
    final currentMonth = '${now.year}-${now.month}';

    if (lastInterestMonth == currentMonth) {
      print('   ⏳ Проценты за этот месяц уже начислены');
      return;
    }

    final accounts = await CategoryService.loadAccounts();
    print('   Загружено счетов: ${accounts.length}');

    final interestService = InterestCalculationService();

    for (var account in accounts) {
      if (account.type == AccountType.savings) {
        print('   Обработка накопительного счета: ${account.name}');
        await interestService.processSavingsInterest(account, now);
      } else if (account.type == AccountType.deposit) {
        print('   Обработка вклада: ${account.name}');
        await interestService.processDepositInterest(account, now);
        await interestService.checkAndCloseDeposit(account, now);
      } else if (account.type == AccountType.loan) {
        await _checkLoanPayment(account, now);
      }
    }

    await prefs.setString(lastInterestKey, currentMonth);
    print('💰 Проценты за ${currentMonth} обработаны');
  }

  static Future<void> _checkLoanPayment(Account loan, DateTime now) async {
    final userId = await _getUserIdSafe();
    final paymentDay = loan.paymentDay ?? 1;
    final currentDay = now.day;

    if (currentDay != paymentDay) return;

    final prefs = await SharedPreferences.getInstance();
    final lastNotificationKey =
        'last_loan_notification_${loan.id}_${now.year}_${now.month}_$userId';
    final lastNotification = prefs.getString(lastNotificationKey);

    if (lastNotification != null) return;

    final monthlyPayment = loan.monthlyPayment ?? 0;
    if (monthlyPayment <= 0) return;

    await _addLoanPaymentNotification(loan.name, monthlyPayment, paymentDay);

    await prefs.setString(lastNotificationKey, now.toIso8601String());

    print(
        '💳 Отправлено уведомление о платеже по кредиту "${loan.name}" на сумму $monthlyPayment');
  }

  static Future<void> _addLoanPaymentNotification(
      String loanName, double amount, int paymentDay) async {
    final prefs = await SharedPreferences.getInstance();
    final notificationsKey = 'notifications_${await _getUserIdSafe()}';
    final notificationsJson = prefs.getString(notificationsKey);
    List<dynamic> notifications = [];
    if (notificationsJson != null) {
      notifications = jsonDecode(notificationsJson);
    }

    final amountText = '${amount.toStringAsFixed(2)} ₽';

    final newNotification = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'title': '💳 Напоминание о платеже по кредиту',
      'message':
          'Сегодня $paymentDay-е число. Не забудьте внести платеж по кредиту "$loanName" в размере $amountText',
      'date': DateTime.now().toIso8601String(),
      'isRead': false,
    };

    notifications.insert(0, newNotification);
    await prefs.setString(notificationsKey, jsonEncode(notifications));
  }
}
