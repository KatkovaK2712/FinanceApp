import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/transaction_service.dart';
import '../services/category_service.dart';
import '../services/goal_service.dart';
import '../providers/settings_provider.dart';
import 'package:provider/provider.dart';
import '../models/transaction_models.dart';
import '../models/goal.dart';
import 'dart:math';

class PlanningScreen extends StatefulWidget {
  const PlanningScreen({super.key});

  @override
  State<PlanningScreen> createState() => _PlanningScreenState();
}

class _PlanningScreenState extends State<PlanningScreen> {
  int _selectedYears = 3;
  late int _currentYear;
  late List<int> _forecastYears;
  bool _isLoading = true;

  List<Transaction> _transactions = [];
  List<Account> _accounts = [];
  List<Goal> _goals = [];

  Map<int, Map<int, Map<String, double>>> _monthlyData = {};
  Map<int, double> _yearlyIncome = {};
  Map<int, double> _yearlyExpense = {};
  Map<int, double> _yearlySavings = {};

  List<MonthlyForecast> _monthlyForecast = [];
  Map<String, dynamic> _accountsForecast = {};
  List<Map<String, dynamic>> _goalsForecast = [];

  double _totalForecastIncome = 0;
  double _totalForecastExpense = 0;

  @override
  void initState() {
    super.initState();
    _currentYear = DateTime.now().year;
    _updateForecastYears();
    _loadData();
  }

  void _updateForecastYears() {
    _forecastYears = [];
    for (int i = 1; i <= _selectedYears; i++) {
      _forecastYears.add(_currentYear + i);
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    _transactions = await TransactionService.loadTransactions();
    _accounts = await CategoryService.loadAccounts();
    _goals = await GoalService.loadGoals();

    _analyzeHistoricalData();
    _generateForecast();

    setState(() => _isLoading = false);
  }

  void _analyzeHistoricalData() {
    _monthlyData.clear();
    _yearlyIncome.clear();
    _yearlyExpense.clear();
    _yearlySavings.clear();

    final relevantTransactions =
        _transactions.where((t) => t.category != 'Перевод').toList();

    for (var t in relevantTransactions) {
      final year = t.date.year;
      final month = t.date.month;

      _monthlyData.putIfAbsent(year, () => {});
      _monthlyData[year]!
          .putIfAbsent(month, () => {'income': 0.0, 'expense': 0.0});

      if (t.type == TransactionType.income) {
        _monthlyData[year]![month]!['income'] =
            (_monthlyData[year]![month]!['income'] ?? 0) + t.amount;
        _yearlyIncome[year] = (_yearlyIncome[year] ?? 0) + t.amount;
      } else if (t.type == TransactionType.expense) {
        _monthlyData[year]![month]!['expense'] =
            (_monthlyData[year]![month]!['expense'] ?? 0) + t.amount;
        _yearlyExpense[year] = (_yearlyExpense[year] ?? 0) + t.amount;
      }
    }

    for (var year in _yearlyIncome.keys) {
      _yearlySavings[year] =
          (_yearlyIncome[year] ?? 0) - (_yearlyExpense[year] ?? 0);
    }
  }

  void _generateForecast() {
    _monthlyForecast.clear();
    _totalForecastIncome = 0;
    _totalForecastExpense = 0;

    Map<int, double> monthlyIncomeMultiplier = {};
    Map<int, double> monthlyExpenseMultiplier = {};

    final lastYears = _monthlyData.keys.toList()..sort();
    final recentYears = lastYears.length >= 3
        ? lastYears.sublist(lastYears.length - 3)
        : lastYears;

    for (int month = 1; month <= 12; month++) {
      double totalIncome = 0;
      double totalExpense = 0;
      int count = 0;

      for (var year in recentYears) {
        if (_monthlyData[year]?.containsKey(month) == true) {
          totalIncome += _monthlyData[year]![month]!['income'] ?? 0;
          totalExpense += _monthlyData[year]![month]!['expense'] ?? 0;
          count++;
        }
      }

      if (count > 0) {
        monthlyIncomeMultiplier[month] = totalIncome / count;
        monthlyExpenseMultiplier[month] = totalExpense / count;
      }
    }

    double incomeGrowthRate = 0.05;
    double expenseGrowthRate = 0.03;

    if (recentYears.length >= 2) {
      final firstYearIncome = _yearlyIncome[recentYears.first] ?? 0;
      final lastYearIncome = _yearlyIncome[recentYears.last] ?? 0;
      if (firstYearIncome > 0) {
        incomeGrowthRate = pow(lastYearIncome / firstYearIncome,
                    1.0 / (recentYears.length - 1))
                .toDouble() -
            1;
        if (incomeGrowthRate.isNaN) incomeGrowthRate = 0.05;
      }

      final firstYearExpense = _yearlyExpense[recentYears.first] ?? 0;
      final lastYearExpense = _yearlyExpense[recentYears.last] ?? 0;
      if (firstYearExpense > 0) {
        expenseGrowthRate = pow(lastYearExpense / firstYearExpense,
                    1.0 / (recentYears.length - 1))
                .toDouble() -
            1;
        if (expenseGrowthRate.isNaN) expenseGrowthRate = 0.03;
      }
    }

    double correctionFactor = 1.0;

    double lastYearIncome = _yearlyIncome[
            recentYears.isNotEmpty ? recentYears.last : _currentYear - 1] ??
        0;
    double lastYearExpense = _yearlyExpense[
            recentYears.isNotEmpty ? recentYears.last : _currentYear - 1] ??
        0;

    for (int yearIndex = 0; yearIndex < _forecastYears.length; yearIndex++) {
      final year = _forecastYears[yearIndex];
      final yearFactor = pow(1 + incomeGrowthRate, yearIndex + 1).toDouble();
      final yearExpenseFactor =
          pow(1 + expenseGrowthRate, yearIndex + 1).toDouble();

      double yearForecastIncome = 0;
      double yearForecastExpense = 0;

      for (int month = 1; month <= 12; month++) {
        double baseIncome =
            monthlyIncomeMultiplier[month] ?? (lastYearIncome / 12);
        double baseExpense =
            monthlyExpenseMultiplier[month] ?? (lastYearExpense / 12);

        double forecastIncome = baseIncome * yearFactor * correctionFactor;
        double forecastExpense = baseExpense * yearExpenseFactor;

        yearForecastIncome += forecastIncome;
        yearForecastExpense += forecastExpense;

        _monthlyForecast.add(MonthlyForecast(
          year: year,
          month: month,
          income: forecastIncome,
          expense: forecastExpense,
        ));
      }

      _totalForecastIncome += yearForecastIncome;
      _totalForecastExpense += yearForecastExpense;
    }

    _accountsForecast = _forecastAccounts();
    _goalsForecast = _forecastGoals();
  }

  Map<String, dynamic> _forecastAccounts() {
    Map<String, dynamic> result = {};

    // ✅ РАСЧЁТ СРЕДНЕМЕСЯЧНОГО ДОХОДА И РАСХОДА НА ОСНОВЕ ТРАНЗАКЦИЙ
    final recentTransactions =
        _transactions.where((t) => t.date.year >= _currentYear - 1).toList();

    double totalMonthlyIncome = 0;
    double totalMonthlyExpense = 0;
    int monthCount = 0;

    for (var t in recentTransactions) {
      if (t.type == TransactionType.income && t.category != 'Перевод') {
        totalMonthlyIncome += t.amount;
      } else if (t.type == TransactionType.expense && t.category != 'Перевод') {
        totalMonthlyExpense += t.amount;
      }
    }

    final monthsWithData = recentTransactions.map((t) => t.date).toSet().length;
    if (monthsWithData > 0) {
      totalMonthlyIncome /= monthsWithData;
      totalMonthlyExpense /= monthsWithData;
    }

    final avgMonthlyChange = totalMonthlyIncome - totalMonthlyExpense;

    // ✅ ПРОГНОЗ ДЛЯ ОБЫЧНЫХ СЧЕТОВ С УЧЁТОМ РАСХОДОВ
    for (var account in _accounts) {
      if (account.type == AccountType.debtOwed ||
          account.type == AccountType.debtToPay) {
        continue;
      }

      if (account.type == AccountType.deposit) {
        final rate = account.interestRate ?? 0;
        final balance = account.balance;
        final yearlyInterest = balance * (rate / 100);
        final totalInterest = yearlyInterest * _selectedYears;

        final depositEndDate = account.depositEndDate;
        bool willClose = false;
        DateTime? closeDate;

        if (depositEndDate != null) {
          final closeYear = depositEndDate.year;
          if (_forecastYears.contains(closeYear)) {
            willClose = true;
            closeDate = depositEndDate;
          }
        }

        result[account.id] = {
          'name': account.name,
          'type': 'deposit',
          'currentBalance': balance,
          'interestRate': rate,
          'yearlyInterest': yearlyInterest,
          'totalInterest': totalInterest,
          'willClose': willClose,
          'closeDate': closeDate,
          'closeBalance': willClose ? balance + totalInterest : null,
        };
      } else if (account.type == AccountType.savings) {
        final rate = account.interestRate ?? 0;
        final balance = account.balance;
        final yearlyInterest = balance * (rate / 100);
        final totalInterest = yearlyInterest * _selectedYears;

        result[account.id] = {
          'name': account.name,
          'type': 'savings',
          'currentBalance': balance,
          'interestRate': rate,
          'yearlyInterest': yearlyInterest,
          'totalInterest': totalInterest,
          'forecastBalance': balance +
              totalInterest +
              (avgMonthlyChange * 12 * _selectedYears),
        };
      } else if (account.type == AccountType.loan) {
        // ✅ ПЕРЕСЧЁТ КРЕДИТА НА ОСНОВЕ РЕАЛЬНЫХ ПЛАТЕЖЕЙ
        final loanPayments = _transactions
            .where((t) =>
                t.toAccountId == account.id &&
                t.category == 'Перевод' &&
                t.amount > 0)
            .toList();

        // Вычисляем средний месячный платёж из реальных транзакций
        double avgMonthlyPayment = 0;
        if (loanPayments.isNotEmpty) {
          final totalPaid = loanPayments.fold(0.0, (sum, t) => sum + t.amount);
          final monthsPassed =
              loanPayments.map((t) => t.date.month).toSet().length;
          avgMonthlyPayment = totalPaid / monthsPassed;
        } else {
          avgMonthlyPayment = account.monthlyPayment ?? 0;
        }

        final remainingPrincipal =
            (account.remainingPrincipal ?? account.principalAmount ?? 0).abs();

        // Сколько месяцев нужно, чтобы погасить оставшийся долг
        int monthsToPayoff = 0;
        if (avgMonthlyPayment > 0 && remainingPrincipal > 0) {
          monthsToPayoff = (remainingPrincipal / avgMonthlyPayment).ceil();
        }

        final remainingMonths = account.remainingMonths ?? monthsToPayoff;
        final forecastMonths = _selectedYears * 12;

        // ✅ РАСЧЁТ ДАТЫ ПОГАШЕНИЯ (НЕ РАНЬШЕ ДАТЫ ВЗЯТИЯ КРЕДИТА)
        final creditStartDate = account.createdDate ?? DateTime.now();
        final today = DateTime.now();
        final startDate =
            creditStartDate.isAfter(today) ? creditStartDate : today;

        int payoffYear = startDate.year;
        int payoffMonth = startDate.month + remainingMonths;
        while (payoffMonth > 12) {
          payoffMonth -= 12;
          payoffYear++;
        }

        int payoffDay = account.paymentDay ?? 1;
        final lastDayOfMonth = DateTime(payoffYear, payoffMonth + 1, 0).day;
        if (payoffDay > lastDayOfMonth) payoffDay = lastDayOfMonth;

        final payoffDate = DateTime(payoffYear, payoffMonth, payoffDay);
        final willBePaid = remainingMonths <= forecastMonths;

        result[account.id] = {
          'name': account.name,
          'type': 'loan',
          'currentPrincipal': remainingPrincipal,
          'monthlyPayment': avgMonthlyPayment,
          'remainingMonths': remainingMonths,
          'forecastRemainingMonths': max(0, remainingMonths - forecastMonths),
          'willBePaid': willBePaid,
          'payoffDate': payoffDate,
          'payoffDateString': '${payoffDay}.${payoffMonth}.${payoffYear}',
        };
      } else {
        // ✅ ОБЫЧНЫЙ СЧЁТ — прогноз с учётом расходов
        final forecastBalance =
            account.balance + (avgMonthlyChange * _selectedYears * 12);

        result[account.id] = {
          'name': account.name,
          'type': 'regular',
          'currentBalance': account.balance,
          'forecastBalance': forecastBalance,
          'monthlyIncome': totalMonthlyIncome,
          'monthlyExpense': totalMonthlyExpense,
          'monthlyChange': avgMonthlyChange,
        };
      }
    }

    return result;
  }

  List<Map<String, dynamic>> _forecastGoals() {
    List<Map<String, dynamic>> result = [];

    // Средние ежемесячные сбережения за последний год
    final lastYear = _currentYear - 1;
    double avgMonthlySavings = 0;
    if (_yearlySavings.containsKey(lastYear) && _yearlySavings[lastYear]! > 0) {
      avgMonthlySavings = _yearlySavings[lastYear]! / 12;
    } else {
      // Если нет данных о сбережениях, используем разницу между доходом и расходом
      final avgIncome = _totalForecastIncome / (_selectedYears * 12);
      final avgExpense = _totalForecastExpense / (_selectedYears * 12);
      avgMonthlySavings = avgIncome - avgExpense;
      if (avgMonthlySavings < 0) avgMonthlySavings = 0;
    }

    for (var goal in _goals) {
      final remaining = goal.targetAmount - goal.currentAmount;
      final monthsNeeded = avgMonthlySavings > 0
          ? remaining / avgMonthlySavings
          : double.infinity;
      final yearsNeeded = monthsNeeded / 12;
      DateTime? achievementDate;

      if (monthsNeeded != double.infinity && yearsNeeded <= _selectedYears) {
        final totalMonths = (monthsNeeded).ceil();
        final achievementYear = _currentYear + (totalMonths ~/ 12);
        int achievementMonth = (DateTime.now().month + totalMonths) % 12;
        if (achievementMonth == 0) achievementMonth = 12;
        achievementDate = DateTime(achievementYear, achievementMonth, 1);
      }

      result.add({
        'id': goal.id,
        'title': goal.title,
        'icon': goal.icon,
        'color': goal.color,
        'targetAmount': goal.targetAmount,
        'currentAmount': goal.currentAmount,
        'remaining': remaining,
        'avgMonthlySavings': avgMonthlySavings,
        'monthsNeeded': monthsNeeded,
        'yearsNeeded': yearsNeeded,
        'achievementDate': achievementDate,
        'willBeAchieved':
            monthsNeeded != double.infinity && yearsNeeded <= _selectedYears,
      });
    }

    return result;
  }

  String _formatAmount(double amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)} млн ₽';
    }
    return '${NumberFormat('#,##0', 'ru_RU').format(amount.round())} ₽';
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '—';
    return '${date.day}.${date.month}.${date.year}';
  }

  String _getMonthName(int month) {
    return DateFormat('MMM', 'ru_RU').format(DateTime(2000, month));
  }

  String _getYearWord(int years) {
    if (years % 10 == 1 && years % 100 != 11) return 'год';
    if (years % 10 >= 2 &&
        years % 10 <= 4 &&
        (years % 100 < 10 || years % 100 >= 20)) return 'года';
    return 'лет';
  }

  String _getMonthWord(int months) {
    if (months % 10 == 1 && months % 100 != 11) return 'месяц';
    if (months % 10 >= 2 &&
        months % 10 <= 4 &&
        (months % 100 < 10 || months % 100 >= 20)) return 'месяца';
    return 'месяцев';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Прогноз'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Выбор периода
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Прогноз на',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: colorScheme.primary,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: colorScheme.primary,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '$_selectedYears ${_getYearWord(_selectedYears)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Slider(
                          value: _selectedYears.toDouble(),
                          min: 1,
                          max: 5,
                          divisions: 4,
                          label:
                              '$_selectedYears ${_getYearWord(_selectedYears)}',
                          onChanged: (value) {
                            setState(() {
                              _selectedYears = value.round();
                              _updateForecastYears();
                              _generateForecast();
                            });
                          },
                          activeColor: colorScheme.primary,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Прогнозируемый период: ${_forecastYears.first} - ${_forecastYears.last}',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.primary.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // График
                  const Text(
                    'Прогноз доходов и расходов',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 300,
                    child: _monthlyForecast.isEmpty
                        ? const Center(
                            child: Text(
                                'Недостаточно данных для построения графика'))
                        : LineChart(
                            LineChartData(
                              gridData: const FlGridData(show: true),
                              titlesData: FlTitlesData(
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 60,
                                    getTitlesWidget: (value, meta) {
                                      return Text(
                                        _formatAmount(value),
                                        style: const TextStyle(fontSize: 10),
                                      );
                                    },
                                  ),
                                ),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    getTitlesWidget: (value, meta) {
                                      final index = value.toInt();
                                      if (index >= 0 &&
                                          index < _monthlyForecast.length &&
                                          index % 6 == 0) {
                                        final data = _monthlyForecast[index];
                                        return Text(
                                          '${_getMonthName(data.month)}\n${data.year}',
                                          style: const TextStyle(fontSize: 10),
                                          textAlign: TextAlign.center,
                                        );
                                      }
                                      return const Text('');
                                    },
                                    reservedSize: 40,
                                  ),
                                ),
                              ),
                              borderData: FlBorderData(show: true),
                              lineBarsData: [
                                LineChartBarData(
                                  spots: _monthlyForecast
                                      .asMap()
                                      .entries
                                      .map((e) => FlSpot(
                                          e.key.toDouble(), e.value.income))
                                      .toList(),
                                  isCurved: true,
                                  color: Colors.green,
                                  barWidth: 3,
                                  dotData: const FlDotData(show: false),
                                  belowBarData: BarAreaData(show: false),
                                ),
                                LineChartBarData(
                                  spots: _monthlyForecast
                                      .asMap()
                                      .entries
                                      .map((e) => FlSpot(
                                          e.key.toDouble(), e.value.expense))
                                      .toList(),
                                  isCurved: true,
                                  color: Colors.red,
                                  barWidth: 3,
                                  dotData: const FlDotData(show: false),
                                  belowBarData: BarAreaData(show: false),
                                ),
                              ],
                            ),
                          ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildLegend(Colors.green, 'Доход'),
                      const SizedBox(width: 16),
                      _buildLegend(Colors.red, 'Расход'),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Общие итоги
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: Colors.green.withOpacity(0.3)),
                          ),
                          child: Column(
                            children: [
                              const Text('Прогнозируемый доход',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey)),
                              const SizedBox(height: 4),
                              Text(
                                _formatAmount(_totalForecastIncome),
                                style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                            border:
                                Border.all(color: Colors.red.withOpacity(0.3)),
                          ),
                          child: Column(
                            children: [
                              const Text('Прогнозируемый расход',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey)),
                              const SizedBox(height: 4),
                              Text(
                                _formatAmount(_totalForecastExpense),
                                style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Прогноз по счетам
                  const Text(
                    'Прогноз по счетам',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  if (_accountsForecast.isEmpty)
                    const Center(child: Text('Нет счетов для прогноза'))
                  else
                    ...(_accountsForecast.values
                        .map((account) => _buildAccountForecastCard(account))
                        .toList()),

                  const SizedBox(height: 24),

                  // Прогноз по целям
                  const Text(
                    'Прогноз по целям',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  if (_goalsForecast.isEmpty)
                    const Center(child: Text('Нет целей для прогноза'))
                  else
                    ..._goalsForecast
                        .map((goal) => _buildGoalForecastCard(goal)),
                ],
              ),
            ),
    );
  }

  Widget _buildLegend(Color color, String title) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(title, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildAccountForecastCard(Map<String, dynamic> account) {
    final type = account['type'] as String;

    if (type == 'deposit') {
      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child:
                        const Icon(Icons.account_balance, color: Colors.purple),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          account['name'],
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Вклад • ${account['interestRate']}%',
                          style:
                              const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        const Text('Текущий баланс',
                            style: TextStyle(fontSize: 12, color: Colors.grey)),
                        Text(_formatAmount(account['currentBalance']),
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        const Text('Доход по % за период',
                            style: TextStyle(fontSize: 12, color: Colors.grey)),
                        Text(_formatAmount(account['totalInterest']),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green)),
                      ],
                    ),
                  ),
                ],
              ),
              if (account['willClose'] == true) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning, size: 16, color: Colors.orange),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Вклад закроется ${_formatDate(account['closeDate'])}. Баланс на момент закрытия: ${_formatAmount(account['closeBalance'])}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    if (type == 'savings') {
      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.teal.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.savings, color: Colors.teal),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          account['name'],
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Накопительный счет • ${account['interestRate']}%',
                          style:
                              const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        const Text('Текущий баланс',
                            style: TextStyle(fontSize: 12, color: Colors.grey)),
                        Text(_formatAmount(account['currentBalance']),
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        const Text('Прогнозируемый баланс',
                            style: TextStyle(fontSize: 12, color: Colors.grey)),
                        Text(_formatAmount(account['forecastBalance']),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.teal)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        const Text('Доход по % за год',
                            style: TextStyle(fontSize: 12, color: Colors.grey)),
                        Text(_formatAmount(account['yearlyInterest']),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        const Text('Всего % за период',
                            style: TextStyle(fontSize: 12, color: Colors.grey)),
                        Text(_formatAmount(account['totalInterest']),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    if (type == 'loan') {
      final willBePaid = account['willBePaid'] == true;
      final payoffDateString = account['payoffDateString'] ?? '—';

      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.trending_down, color: Colors.red),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          account['name'],
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const Text('Кредит',
                            style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        const Text('Остаток основного долга',
                            style: TextStyle(fontSize: 12, color: Colors.grey)),
                        Text(_formatAmount(account['currentPrincipal']),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.red)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        const Text('Средний ежемесячный платеж',
                            style: TextStyle(fontSize: 12, color: Colors.grey)),
                        Text(_formatAmount(account['monthlyPayment']),
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: willBePaid
                      ? Colors.green.withOpacity(0.1)
                      : Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          willBePaid ? Icons.check_circle : Icons.warning,
                          size: 16,
                          color: willBePaid ? Colors.green : Colors.orange,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            willBePaid
                                ? 'Кредит будет полностью погашен за период'
                                : 'Останется долг: ${_formatAmount(account['currentPrincipal'])} (ещё ${account['forecastRemainingMonths']} ${_getMonthWord(account['forecastRemainingMonths'])})',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    if (willBePaid) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today,
                              size: 12, color: Colors.green),
                          const SizedBox(width: 8),
                          Text(
                            'Примерная дата погашения: $payoffDateString',
                            style: const TextStyle(
                                fontSize: 11, color: Colors.green),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Обычный счет
    final monthlyChange = account['monthlyChange'] ?? 0;
    final isPositive = monthlyChange >= 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.account_balance_wallet,
                      color: Colors.blue),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        account['name'],
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Счет • Ежемесячное изменение: ${isPositive ? "+" : ""}${_formatAmount(monthlyChange)}',
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      const Text('Текущий баланс',
                          style: TextStyle(fontSize: 12, color: Colors.grey)),
                      Text(_formatAmount(account['currentBalance']),
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      const Text('Прогнозируемый баланс',
                          style: TextStyle(fontSize: 12, color: Colors.grey)),
                      Text(
                        _formatAmount(account['forecastBalance']),
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: account['forecastBalance'] >= 0
                                ? Colors.green
                                : Colors.red),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalForecastCard(Map<String, dynamic> goal) {
    final color = goal['color'] as Color;
    final willBeAchieved = goal['willBeAchieved'] as bool;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(goal['icon'], color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        goal['title'],
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: color),
                      ),
                      Text(
                        'Цель: ${_formatAmount(goal['targetAmount'])}',
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      const Text('Накоплено',
                          style: TextStyle(fontSize: 12, color: Colors.grey)),
                      Text(_formatAmount(goal['currentAmount']),
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      const Text('Осталось',
                          style: TextStyle(fontSize: 12, color: Colors.grey)),
                      Text(_formatAmount(goal['remaining']),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: willBeAchieved
                    ? Colors.green.withOpacity(0.1)
                    : Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    willBeAchieved ? Icons.flag : Icons.timer,
                    size: 16,
                    color: willBeAchieved ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      willBeAchieved
                          ? 'Цель будет достигнута ${_formatDate(goal['achievementDate'])}'
                          : 'Для достижения цели необходимо откладывать ≈ ${_formatAmount(goal['avgMonthlySavings'])} в месяц',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MonthlyForecast {
  final int year;
  final int month;
  final double income;
  final double expense;

  MonthlyForecast({
    required this.year,
    required this.month,
    required this.income,
    required this.expense,
  });
}
