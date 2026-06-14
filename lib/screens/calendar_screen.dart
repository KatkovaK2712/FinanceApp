import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction_models.dart';
import '../services/transaction_service.dart';
import 'add_transaction_sheet.dart'; // ДОБАВИТЬ ЭТУ СТРОКУ
import '../utils/snackbar_utils.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _selectedMonth = DateTime.now();
  List<Transaction> _transactions = [];
  Map<DateTime, Map<String, double>> _dailySummary = {};

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    try {
      final transactions = await TransactionService.loadTransactions();
      setState(() {
        _transactions = transactions;
        _calculateDailySummary();
      });
    } catch (e) {
      print('❌ Ошибка загрузки транзакций: $e');
    }
  }

  void _calculateDailySummary() {
    _dailySummary.clear();

    for (var transaction in _transactions) {
      if (transaction.date.year != _selectedMonth.year ||
          transaction.date.month != _selectedMonth.month) {
        continue;
      }

      final date = DateTime(
          transaction.date.year, transaction.date.month, transaction.date.day);

      if (!_dailySummary.containsKey(date)) {
        _dailySummary[date] = {'income': 0.0, 'expense': 0.0};
      }

      if (transaction.type == TransactionType.income) {
        _dailySummary[date]!['income'] =
            (_dailySummary[date]!['income'] ?? 0) + transaction.amount;
      } else if (transaction.type == TransactionType.expense) {
        _dailySummary[date]!['expense'] =
            (_dailySummary[date]!['expense'] ?? 0) + transaction.amount;
      }
    }
  }

  void _previousMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
      _calculateDailySummary();
    });
  }

  void _nextMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
      _calculateDailySummary();
    });
  }

  void _showMonthPicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          height: 300,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Text(
                'Выберите месяц',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 2,
                  ),
                  itemCount: 12,
                  itemBuilder: (context, index) {
                    final month = index + 1;
                    final monthName = DateFormat('MMMM', 'ru_RU')
                        .format(DateTime(2024, month));
                    final isSelected = _selectedMonth.month == month;

                    return Padding(
                      padding: const EdgeInsets.all(4),
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _selectedMonth =
                                DateTime(_selectedMonth.year, month);
                            _calculateDailySummary();
                          });
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : null,
                        ),
                        child: Text(monthName),
                      ),
                    );
                  },
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        setState(() {
                          _selectedMonth = DateTime.now();
                          _calculateDailySummary();
                        });
                        Navigator.pop(context);
                      },
                      child: const Text('Текущий месяц'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAddTransactionDialog(DateTime date) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddTransactionSheet(
        onTransactionAdded: (transaction) {
          _loadTransactions();
          SnackbarUtils.showSuccess(context, 'Транзакция добавлена');
        },
      ),
    );
  }

  String _formatAmount(double amount) {
    final formatter = NumberFormat('#,##0.00', 'ru_RU');
    return formatter.format(amount);
  }

  List<DateTime> getDaysInMonth() {
    final first = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final last = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);

    int firstWeekday = first.weekday;

    List<DateTime> days = [];

    for (int i = 1; i < firstWeekday; i++) {
      days.add(DateTime(_selectedMonth.year, _selectedMonth.month, 1 - i));
    }

    for (int i = 1; i <= last.day; i++) {
      days.add(DateTime(_selectedMonth.year, _selectedMonth.month, i));
    }

    return days;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final days = getDaysInMonth();
    final weekDays = ['П', 'В', 'С', 'Ч', 'П', 'С', 'В'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Календарь'),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Выбор месяца
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left, size: 24),
                  onPressed: _previousMonth,
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
                GestureDetector(
                  onTap: _showMonthPicker,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Text(
                          DateFormat('MMMM yyyy', 'ru_RU')
                              .format(_selectedMonth),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_drop_down,
                            size: 18, color: colorScheme.primary),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right, size: 24),
                  onPressed: _nextMonth,
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ),

          // Дни недели
          Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: weekDays.map((day) {
                return Expanded(
                  child: Text(
                    day,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // Календарь
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(2),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 0.85,
              ),
              itemCount: days.length,
              itemBuilder: (context, index) {
                final date = days[index];
                final isCurrentMonth = date.month == _selectedMonth.month;
                final isToday = date.year == DateTime.now().year &&
                    date.month == DateTime.now().month &&
                    date.day == DateTime.now().day;

                final summary = _dailySummary[date];
                final income = summary?['income'] ?? 0;
                final expense = summary?['expense'] ?? 0;

                Color numberColor;
                if (!isCurrentMonth) {
                  numberColor =
                      isDark ? Colors.grey.shade600 : Colors.grey.shade400;
                } else if (isToday) {
                  numberColor = colorScheme.primary;
                } else {
                  numberColor = isDark ? Colors.white70 : Colors.black87;
                }

                return GestureDetector(
                  onTap: () => _showAddTransactionDialog(date),
                  child: Container(
                    margin: const EdgeInsets.all(1),
                    decoration: BoxDecoration(
                      color: isToday
                          ? colorScheme.primary.withOpacity(0.15)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isCurrentMonth
                            ? (isToday
                                ? colorScheme.primary
                                : Colors.grey.shade300)
                            : Colors.grey.shade200,
                        width: isToday ? 1 : 0.5,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          date.day.toString(),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight:
                                isToday ? FontWeight.bold : FontWeight.normal,
                            color: numberColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        if (income > 0)
                          Text(
                            '+${_formatAmount(income)}',
                            style: const TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w500,
                              color: Colors.green,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        if (expense > 0)
                          Text(
                            '-${_formatAmount(expense)}',
                            style: const TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w500,
                              color: Colors.red,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        if (income == 0 && expense == 0 && isCurrentMonth)
                          const SizedBox(height: 18),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddTransactionDialog(DateTime.now()),
        backgroundColor: colorScheme.primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}
