import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction_models.dart';
import '../services/transaction_service.dart';
import '../services/category_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BalanceSummaryScreen extends StatefulWidget {
  const BalanceSummaryScreen({super.key});

  @override
  State<BalanceSummaryScreen> createState() => _BalanceSummaryScreenState();
}

class _BalanceSummaryScreenState extends State<BalanceSummaryScreen> {
  List<Transaction> _transactions = [];
  List<Account> _accounts = [];
  bool _isLoading = true;
  Map<String, Map<String, dynamic>> _monthlyData = {};
  Map<String, String> _closedDepositNames = {};
  Map<String, DateTime?> _depositEndDates = {};
  Map<String, double> _depositInitialBalances =
      {}; // сохраняем начальный баланс

  @override
  void initState() {
    super.initState();
    _loadData();
    CategoryService.addAccountsListener(_onAccountsChanged);
  }

  void _onAccountsChanged() {
    _loadData();
  }

  @override
  void dispose() {
    CategoryService.removeAccountsListener(_onAccountsChanged);
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      _transactions = await TransactionService.loadTransactions();
      _accounts = await CategoryService.loadAccounts();

      final prefs = await SharedPreferences.getInstance();
      _closedDepositNames.clear();
      _depositEndDates.clear();
      _depositInitialBalances.clear();

      // 1. Загружаем названия закрытых вкладов из SharedPreferences
      for (var account in _accounts) {
        if (account.type == AccountType.deposit) {
          final savedName =
              prefs.getString('closed_deposit_name_${account.id}');
          if (savedName != null && savedName != account.name) {
            _closedDepositNames[account.id] = savedName;
            if (account.depositEndDate != null) {
              _depositEndDates[account.id] = account.depositEndDate;
            }
            _depositInitialBalances[account.id] = account.initialBalance;
            print(
                '📦 Загружен закрытый вклад: $savedName, дата закрытия: ${account.depositEndDate}');
          }
        }
      }

      // 2. Ищем закрытые вклады в транзакциях (которых уже нет в списке счетов)
      for (var t in _transactions) {
        if (t.title.contains('Закрытие вклада')) {
          final match = RegExp(r'"([^"]*)"').firstMatch(t.title);
          if (match != null) {
            final depositName = match.group(1)!;
            // Ищем id из fromAccountId или toAccountId
            if (t.fromAccountId != null &&
                !_closedDepositNames.containsKey(t.fromAccountId)) {
              _closedDepositNames[t.fromAccountId!] = depositName;
              _depositEndDates[t.fromAccountId!] = t.date;
              _depositInitialBalances[t.fromAccountId!] = 0;
              print(
                  '📦 Из транзакции найден закрытый вклад: $depositName, id: ${t.fromAccountId}, дата закрытия: ${t.date}');
            }
            if (t.toAccountId != null &&
                !_closedDepositNames.containsKey(t.toAccountId)) {
              _closedDepositNames[t.toAccountId!] = depositName;
              _depositEndDates[t.toAccountId!] = t.date;
              _depositInitialBalances[t.toAccountId!] = 0;
              print(
                  '📦 Из транзакции найден закрытый вклад: $depositName, id: ${t.toAccountId}, дата закрытия: ${t.date}');
            }
          }
        }
      }

      _calculateMonthlyData();
    } catch (e) {
      print('❌ Ошибка загрузки данных: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  double _getBalanceOnDateForClosedDeposit(
      String accountId, DateTime targetDate, double initialBalance) {
    double balance = initialBalance;

    final relevantTransactions = _transactions
        .where((t) =>
            (t.accountId == accountId ||
                t.fromAccountId == accountId ||
                t.toAccountId == accountId) &&
            t.date.isBefore(targetDate.add(const Duration(days: 1))))
        .toList();

    for (var t in relevantTransactions) {
      if (t.accountId == accountId) {
        if (t.type == TransactionType.income) {
          balance += t.amount;
        } else if (t.type == TransactionType.expense &&
            t.fromAccountId == null) {
          balance -= t.amount;
        }
      }
      if (t.fromAccountId == accountId) {
        balance -= t.amount;
      }
      if (t.toAccountId == accountId) {
        balance += t.amount;
      }
    }

    return balance;
  }

  double _getBalanceOnDate(Account account, DateTime targetDate) {
    double balance = account.initialBalance;

    final relevantTransactions = _transactions
        .where((t) =>
            (t.accountId == account.id ||
                t.fromAccountId == account.id ||
                t.toAccountId == account.id) &&
            t.date.isBefore(targetDate.add(const Duration(days: 1))))
        .toList();

    for (var t in relevantTransactions) {
      if (t.accountId == account.id) {
        if (t.type == TransactionType.income) {
          balance += t.amount;
        } else if (t.type == TransactionType.expense &&
            t.fromAccountId == null) {
          balance -= t.amount;
        }
      }
      if (t.fromAccountId == account.id) {
        balance -= t.amount;
      }
      if (t.toAccountId == account.id) {
        balance += t.amount;
      }
    }

    return balance;
  }

  // В методе _calculateMonthlyData, уберите весь код с закрытыми вкладами
  void _calculateMonthlyData() async {
    _monthlyData.clear();

    Set<String> monthsWithTransactions = {};
    for (var t in _transactions) {
      final monthKey = '${t.date.year}-${t.date.month}';
      monthsWithTransactions.add(monthKey);
    }

    final now = DateTime.now();
    monthsWithTransactions.add('${now.year}-${now.month}');
    final sortedMonths = monthsWithTransactions.toList()..sort();
    final prefs = await SharedPreferences.getInstance();

    for (var monthKey in sortedMonths) {
      final parts = monthKey.split('-');
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final endOfMonth = DateTime(year, month + 1, 0);

      double income = 0;
      double expense = 0;

      final monthTransactions = _transactions
          .where((t) => t.date.year == year && t.date.month == month)
          .toList();

      for (var t in monthTransactions) {
        if (t.type == TransactionType.income) {
          income += t.amount;
        } else if (t.type == TransactionType.expense &&
            t.fromAccountId == null) {
          expense += t.amount;
        }
      }

      List<Map<String, dynamic>> accountInfo = [];

      // ✅ ТОЛЬКО АКТИВНЫЕ СЧЕТА (без закрытых)
      for (var account in _accounts) {
        final showOnHomeScreen = prefs.getBool('show_${account.id}') ?? true;
        if (!showOnHomeScreen) continue;

        final balance = _getBalanceOnDate(account, endOfMonth);

        accountInfo.add({
          'id': account.id,
          'name': account.name,
          'balance': balance,
          'color': account.color,
          'icon': account.icon,
          'type': account.type.displayName,
        });
      }

      accountInfo
          .sort((a, b) => a['name'].toString().compareTo(b['name'].toString()));

      _monthlyData[monthKey] = {
        'income': income,
        'expense': expense,
        'balance': income - expense,
        'accounts': accountInfo,
        'year': year,
        'month': month,
      };
    }
  }

  String _formatAmount(double amount) {
    final formatted = amount.toStringAsFixed(2);
    final parts = formatted.split('.');
    final integerPart =
        NumberFormat('#,##0', 'ru_RU').format(int.parse(parts[0]));
    return '$integerPart.${parts[1]} ₽';
  }

  String _getMonthName(int month, int year) {
    return DateFormat('MMMM yyyy', 'ru_RU').format(DateTime(year, month));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final sortedMonths = _monthlyData.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Баланс по месяцам'),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : sortedMonths.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long, size: 60, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text('Нет данных о транзакциях'),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: sortedMonths.length,
                  itemBuilder: (context, index) {
                    final monthKey = sortedMonths[index];
                    final data = _monthlyData[monthKey]!;
                    final year = data['year'];
                    final month = data['month'];
                    final monthName = _getMonthName(month, year);
                    final income = data['income'] ?? 0.0;
                    final expense = data['expense'] ?? 0.0;
                    final balance = data['balance'] ?? 0.0;
                    final accountInfo =
                        data['accounts'] as List<Map<String, dynamic>>;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  monthName,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: balance >= 0
                                        ? Colors.green.withOpacity(0.1)
                                        : Colors.red.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    _formatAmount(balance),
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: balance >= 0
                                          ? Colors.green
                                          : Colors.red,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 24),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Доход',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _formatAmount(income),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.green,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Расход',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _formatAmount(expense),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.red,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            if (accountInfo.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              const Divider(),
                              const SizedBox(height: 12),
                              const Text(
                                'Счета',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: accountInfo.map((account) {
                                  final color = account['color'] as Color;
                                  final icon = account['icon'] as IconData;
                                  final name = account['name'] as String;
                                  final balanceValue =
                                      account['balance'] as double;
                                  final isClosedDeposit =
                                      account['isClosedDeposit'] == true;

                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: color.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: color.withOpacity(0.3),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          icon,
                                          size: 14,
                                          color: color,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '$name: ${_formatAmount(balanceValue)}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: color,
                                          ),
                                        ),
                                        if (isClosedDeposit)
                                          Padding(
                                            padding:
                                                const EdgeInsets.only(left: 4),
                                            child: Icon(
                                              Icons.lock,
                                              size: 10,
                                              color: Colors.grey.shade500,
                                            ),
                                          ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
