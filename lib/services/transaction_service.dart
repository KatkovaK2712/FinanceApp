import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction_models.dart';
import 'category_service.dart';
import '../services/goal_service.dart';
import 'interest_calculation_service.dart';
import 'dart:math';
import 'api_service.dart';

class TransactionService {
  static String? get _userId => ApiService.currentUserId;

  static Future<void> saveTransactions(List<Transaction> transactions) async {
    try {
      final userId = _userId;
      if (userId == null) {
        print('⚠️ Пользователь не авторизован, транзакции не сохранены');
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final key = 'transactions_$userId';

      final uniqueTransactions = transactions
          .fold<Map<String, Transaction>>({}, (map, t) {
            map[t.id] = t;
            return map;
          })
          .values
          .toList();

      if (uniqueTransactions.length != transactions.length) {
        print(
            '⚠️ Обнаружены дубликаты! Было: ${transactions.length}, стало: ${uniqueTransactions.length}');
      }

      List<Map<String, dynamic>> transactionsJson = uniqueTransactions.map((t) {
        return {
          'id': t.id,
          'userId': t.userId,
          'title': t.title,
          'amount': t.amount,
          'date': t.date.toIso8601String(),
          'type': t.type == TransactionType.income ? 'income' : 'expense',
          'category': t.category,
          'subCategory': t.subCategory,
          'accountId': t.accountId,
          'comment': t.comment,
          'isRecurring': t.isRecurring,
          'recurringInterval': t.recurringInterval,
          'recurringFrequency': t.recurringFrequency,
          'fromAccountId': t.fromAccountId,
          'toAccountId': t.toAccountId,
        };
      }).toList();

      String jsonString = jsonEncode(transactionsJson);
      await prefs.setString(key, jsonString);
      print(
          '✅ Транзакции сохранены для пользователя $userId: ${uniqueTransactions.length} шт.');
      CategoryService.notifyListeners();
    } catch (e) {
      print('❌ Ошибка сохранения транзакций: $e');
    }
  }

  static Future<List<Transaction>> loadTransactions() async {
    try {
      final userId = _userId;
      if (userId == null) {
        print('⚠️ Пользователь не авторизован');
        return [];
      }

      final prefs = await SharedPreferences.getInstance();
      final key = 'transactions_$userId';

      String? jsonString = prefs.getString(key);
      if (jsonString == null || jsonString.isEmpty) {
        print('📭 Нет сохраненных транзакций для пользователя $userId');
        return [];
      }

      List<dynamic> transactionsJson = jsonDecode(jsonString);
      List<Transaction> transactions = transactionsJson.map((json) {
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
      }).toList();

      print(
          '✅ Транзакции загружены для пользователя $userId: ${transactions.length} шт.');
      return transactions;
    } catch (e) {
      print('❌ Ошибка загрузки транзакций: $e');
      return [];
    }
  }

  static Future<void> clearTransactions() async {
    final userId = _userId;
    if (userId == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('transactions_$userId');
    print('🗑️ Все транзакции удалены для пользователя $userId');
  }

  static Future<void> addTransaction(Transaction transaction) async {
    print('🔍 addTransaction ВЫЗВАН для id: ${transaction.id}');

    final userId = _userId;
    if (userId == null) {
      print('⚠️ Пользователь не авторизован, транзакция не добавлена');
      return;
    }

    // ✅ ЗАЩИТА ОТ ДВОЙНОЙ ОБРАБОТКИ
    final prefs = await SharedPreferences.getInstance();
    final processedKey = 'processed_transaction_${transaction.id}';
    if (prefs.getBool(processedKey) == true) {
      print('⚠️ Транзакция ${transaction.id} уже обработана, пропускаем');
      return;
    }
    await prefs.setBool(processedKey, true);

    final transactions = await loadTransactions();
    final exists = transactions.any((t) => t.id == transaction.id);
    if (exists) {
      print('⚠️ Транзакция с id ${transaction.id} уже существует, пропускаем');
      return;
    }
    transactions.add(transaction);
    await saveTransactions(transactions);
    await _updateAccountBalance(transaction);
    await GoalService.syncGoalsWithAccounts();

    // ✅ Уведомляем об изменениях (для мгновенного обновления UI)
    CategoryService.notifyListeners();
  }

  static Future<void> _updateAccountBalance(Transaction transaction) async {
    final accounts = await CategoryService.loadAccounts();
    print(
        '📊 Обновление балансов для транзакции: ${transaction.title}, сумма: ${transaction.amount}');

    if (transaction.fromAccountId != null && transaction.toAccountId != null) {
      final fromIndex =
          accounts.indexWhere((a) => a.id == transaction.fromAccountId);
      final toIndex =
          accounts.indexWhere((a) => a.id == transaction.toAccountId);
      final fromAccount = fromIndex != -1 ? accounts[fromIndex] : null;
      final toAccount = toIndex != -1 ? accounts[toIndex] : null;

      if (fromAccount != null && toAccount != null) {
        // Обработка долгов
        if (fromAccount.type == AccountType.debtOwed) {
          accounts[fromIndex].balance -= transaction.amount;
          accounts[toIndex].balance += transaction.amount;
        } else if (toAccount.type == AccountType.debtToPay) {
          accounts[fromIndex].balance -= transaction.amount;
          accounts[toIndex].balance -= transaction.amount;
        }
        // Обычный перевод между счетами
        else if (toAccount.type != AccountType.loan &&
            fromAccount.type != AccountType.loan) {
          accounts[fromIndex].balance -= transaction.amount;
          accounts[toIndex].balance += transaction.amount;
        }

        // ==================== ОБРАБОТКА ПЛАТЕЖА ПО КРЕДИТУ ====================
        if (toAccount.type == AccountType.loan && transaction.amount > 0) {
          final paymentAmount = transaction.amount;
          final rate = toAccount.interestRate ?? 0;
          final monthlyRate = rate / 100 / 12;

          double currentPrincipal = (toAccount.remainingPrincipal ?? 0).abs();
          double currentMonthlyPayment = toAccount.monthlyPayment ?? 0;

          // Если это первый платёж и платеж не задан - берём из транзакции
          if (currentMonthlyPayment == 0 && paymentAmount > 0) {
            currentMonthlyPayment = paymentAmount;
            accounts[toIndex].monthlyPayment = currentMonthlyPayment;
          }

          // Проценты за месяц
          double interest = (currentPrincipal * monthlyRate).roundToDouble();

          // Основной долг = платёж - проценты (НО НЕ БОЛЬШЕ ОСТАТКА)
          double principalPaid = paymentAmount - interest;
          if (principalPaid > currentPrincipal)
            principalPaid = currentPrincipal;
          if (principalPaid < 0) principalPaid = 0;

          // Новый остаток
          double newPrincipal = currentPrincipal - principalPaid;
          if (newPrincipal < 0) newPrincipal = 0;

          // ✅ ИСПРАВЛЕННАЯ ЛОГИКА РАСЧЕТА МЕСЯЦЕВ
          int currentRemainingMonths = toAccount.remainingMonths ?? 0;
          int newRemainingMonths = currentRemainingMonths;

          // Уменьшаем срок ТОЛЬКО ЕСЛИ:
          // 1. Платёж ПОЛНЫЙ (>= обычного платежа)
          // 2. И ОСНОВНОЙ ДОЛГ ЕЩЁ НЕ ПОГАШЕН
          // 3. И currentRemainingMonths БЫЛО > 0 (уже не обновляли)
          if (paymentAmount >= currentMonthlyPayment - 0.01 &&
              newPrincipal > 0 &&
              currentRemainingMonths > 0) {
            // ✅ УМЕНЬШАЕМ ТОЛЬКО НА 1
            newRemainingMonths = currentRemainingMonths - 1;
            if (newRemainingMonths < 0) newRemainingMonths = 0;
            print(
                '📉 Уменьшаем срок: $currentRemainingMonths → $newRemainingMonths');
          } else if (newPrincipal == 0) {
            newRemainingMonths = 0;
            print('✅ Кредит полностью погашен, срок = 0');
          } else {
            // Если платёж меньше обычного - НЕ уменьшаем срок
            if (paymentAmount < currentMonthlyPayment - 0.01) {
              print(
                  '⚠️ Платёж меньше обычного ($paymentAmount < $currentMonthlyPayment), срок НЕ уменьшается');
            }
          }

          // ✅ СОХРАНЯЕМ ВСЁ
          accounts[toIndex].remainingPrincipal = newPrincipal;
          accounts[toIndex].remainingMonths = newRemainingMonths;
          accounts[toIndex].paidInterest =
              (toAccount.paidInterest ?? 0) + interest;
          accounts[toIndex].balance = -newPrincipal;

          // Списываем со счета
          if (fromIndex != -1) {
            accounts[fromIndex].balance -= paymentAmount;
          }

          print(
              '💰 КРЕДИТ: платеж=$paymentAmount, проценты=$interest, погашено=$principalPaid, остаток=$newPrincipal, месяцев=$newRemainingMonths (было $currentRemainingMonths)');
        }
      }
    } else if (transaction.accountId != null) {
      final accountIndex =
          accounts.indexWhere((a) => a.id == transaction.accountId);
      if (accountIndex != -1) {
        if (transaction.type == TransactionType.income) {
          accounts[accountIndex].balance += transaction.amount;
        } else if (transaction.type == TransactionType.expense) {
          accounts[accountIndex].balance -= transaction.amount;
        }
      }
    }

    await CategoryService.saveAccounts(accounts);
    CategoryService.notifyAccountsListeners();
    await GoalService.syncGoalsWithAccounts();
    print('✅ Балансы сохранены');
  }
}
