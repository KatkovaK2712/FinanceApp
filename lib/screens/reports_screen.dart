import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction_models.dart';
import '../models/goal.dart';
import '../services/transaction_service.dart';
import '../services/category_service.dart';
import '../services/category_type_service.dart';
import '../services/goal_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import 'package:collection/collection.dart';
import 'dart:math';

enum PeriodType { day, week, month, year, custom }

enum ReportType { expense, income }

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late TabController _subTabController;
  Map<String, bool> _expandedCategories = {};
  PeriodType _selectedPeriod = PeriodType.month;
  ReportType _reportType = ReportType.expense;

  DateTime _selectedDate = DateTime.now();
  DateTimeRange? _customDateRange;

  List<Transaction> _transactions = [];
  List<Category> _expenseCategories = [];
  List<Account> _accounts = [];
  List<Goal> _goals = [];
  Map<String, Category> _categoryMap = {};
  Map<String, bool> _expandedBudgetCategories = {};
  double _totalDebtByInterest = 0.0;

  // ✅ Проверка, является ли транзакция закрытием вклада
  bool _isDepositClosure(Transaction t) {
    return t.category == 'Перевод' &&
        t.comment != null &&
        (t.comment!.contains('закрытие вклада') ||
            t.comment!.contains('Закрытие вклада')); // ← убрал t.title
  }

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('ru_RU', null);
    _tabController = TabController(length: 3, vsync: this);
    _subTabController = TabController(length: 2, vsync: this);
    _loadData();

    CategoryService.addAccountsListener(_onAccountsChanged);

    for (var category in _expenseCategories) {
      _expandedCategories[category.id] = false;
    }
  }

  void _onAccountsChanged() {
    _loadData();
  }

  @override
  void dispose() {
    CategoryService.removeAccountsListener(_onAccountsChanged);
    _tabController.dispose();
    _subTabController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadData();
  }

  Future<void> _loadData() async {
    _transactions = await TransactionService.loadTransactions();
    final allCategories = await CategoryService.loadCategories();
    final categoryTypes = await CategoryTypeService.getCategoryTypes();
    _goals = await GoalService.loadGoals();

    for (var category in allCategories) {
      _categoryMap[category.name] = category;
    }

    _expenseCategories = [];

    for (var category in allCategories) {
      String? type = categoryTypes[category.id];
      if (type == null) {
        if (category.name.contains('Зарплата') ||
            category.name.contains('Заемные') ||
            category.name.contains('Оборотные') ||
            category.name.contains('Инвестиции') ||
            category.name.contains('Фриланс')) {
          type = 'income';
        } else {
          type = 'expense';
        }
      }

      if (type == 'expense') {
        _expenseCategories.add(category);
        _expandedCategories[category.id] = false;
      }
    }

    _accounts = await CategoryService.loadAccounts();

    // ✅ ВРЕМЕННО ОТКЛЮЧАЕМ ПЕРЕСЧЕТ
    // await _recalculateAllLoans();

    setState(() {});
  }

  Future<void> _recalculateAllLoans() async {
    print('🔄 Пересчет всех кредитов на основе транзакций');

    for (var account in _accounts.where((a) => a.type == AccountType.loan)) {
      // Найти все платежи по этому кредиту
      final payments = _transactions
          .where((t) => t.category == 'Перевод' && t.toAccountId == account.id)
          .toList();

      double totalPaid = payments.fold(0.0, (sum, t) => sum + t.amount);
      double principal = (account.principalAmount ?? 0).abs();
      double remainingPrincipal = principal - totalPaid;
      if (remainingPrincipal < 0) remainingPrincipal = 0;

      account.remainingPrincipal = remainingPrincipal;
      account.balance = -remainingPrincipal;

      // ✅ НЕ ПЕРЕСЧИТЫВАЕМ remainingMonths, если monthlyPayment уже есть
      if (account.monthlyPayment != null && account.monthlyPayment! > 0) {
        if (remainingPrincipal > 0) {
          account.remainingMonths =
              (remainingPrincipal / account.monthlyPayment!).ceil();
        } else {
          account.remainingMonths = 0;
        }
      } else {
        // Если платежа нет, оставляем общий срок
        account.remainingMonths =
            account.loanTermMonths ?? ((account.loanTermYears ?? 0) * 12);
      }

      // ✅ ДЛЯ НОВОГО КРЕДИТА БЕЗ ПЛАТЕЖЕЙ - срок равен общему
      if (totalPaid == 0 &&
          account.monthlyPayment != null &&
          account.monthlyPayment! > 0) {
        account.remainingMonths =
            account.loanTermMonths ?? ((account.loanTermYears ?? 0) * 12);
      }

      print(
          '   Кредит ${account.name}: остаток = $remainingPrincipal, платеж = ${account.monthlyPayment}, месяцев = ${account.remainingMonths}');
    }
  }

  String _formatDepositTerm(Account account) {
    int years = account.depositTermYears ?? 0;
    int months = account.depositTermMonths ?? 0;
    int days = account.depositTermDays ?? 0;

    if (account.termMonths != null && account.termMonths! > 0) {
      years = (account.termMonths! / 12).floor();
      months = account.termMonths! % 12;
      days = 0;
    }

    List<String> parts = [];
    if (years > 0) parts.add('$years ${_getYearWord(years)}');
    if (months > 0) parts.add('$months ${_getMonthWord(months)}');
    if (days > 0) parts.add('$days ${_getDayWord(days)}');

    return parts.isEmpty ? '—' : parts.join(' ');
  }

  double _calculateTotalInterest(Account account) {
    final monthlyPayment = account.monthlyPayment ?? 0;
    final months = account.loanTermMonths ?? 0;
    final principal = account.principalAmount?.abs() ?? 0;

    if (monthlyPayment > 0 && months > 0) {
      return (monthlyPayment * months) - principal;
    }
    return 0;
  }

  void _navigatePeriod(int direction) {
    setState(() {
      switch (_selectedPeriod) {
        case PeriodType.day:
          _selectedDate = _selectedDate.add(Duration(days: direction));
          break;
        case PeriodType.week:
          _selectedDate = _selectedDate.add(Duration(days: 7 * direction));
          break;
        case PeriodType.month:
          _selectedDate =
              DateTime(_selectedDate.year, _selectedDate.month + direction, 1);
          break;
        case PeriodType.year:
          _selectedDate = DateTime(_selectedDate.year + direction, 1, 1);
          break;
        case PeriodType.custom:
          if (_customDateRange != null) {
            final duration =
                _customDateRange!.end.difference(_customDateRange!.start);
            _customDateRange = DateTimeRange(
              start: _customDateRange!.start
                  .add(Duration(days: direction * (duration.inDays + 1))),
              end: _customDateRange!.end
                  .add(Duration(days: direction * (duration.inDays + 1))),
            );
          }
          break;
      }
    });
  }

  String _getDepositEndDate(Account account) {
    if (account.depositEndDate == null) return '—';
    final day = account.depositEndDate!.day.toString().padLeft(2, '0');
    final month = account.depositEndDate!.month.toString().padLeft(2, '0');
    return '$day.$month.${account.depositEndDate!.year}';
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

  String _getDayWord(int days) {
    if (days % 10 == 1 && days % 100 != 11) return 'день';
    if (days % 10 >= 2 &&
        days % 10 <= 4 &&
        (days % 100 < 10 || days % 100 >= 20)) return 'дня';
    return 'дней';
  }

  double _calculateSavingsFromAccounts(DateTime startDate, DateTime endDate) {
    double savings = 0.0;

    final savingsAccounts = _accounts
        .where((a) =>
            a.type == AccountType.deposit ||
            a.type == AccountType.savings ||
            a.type == AccountType.investment)
        .toList();

    print(
        '📊 Сберегательные счета: ${savingsAccounts.map((a) => a.name).toList()}');

    for (var account in savingsAccounts) {
      final incomeTransactions = _transactions
          .where((t) =>
              t.accountId == account.id &&
              t.type == TransactionType.income &&
              t.date.isAfter(startDate.subtract(const Duration(days: 1))) &&
              t.date.isBefore(endDate.add(const Duration(days: 1))))
          .toList();

      double incomeSum =
          incomeTransactions.fold(0.0, (sum, t) => sum + t.amount);
      print('   📈 ${account.name}: доходы (пополнения/проценты) = $incomeSum');

      final transferToTransactions = _transactions
          .where((t) =>
              t.toAccountId == account.id &&
              t.type == TransactionType.expense &&
              t.date.isAfter(startDate.subtract(const Duration(days: 1))) &&
              t.date.isBefore(endDate.add(const Duration(days: 1))))
          .toList();

      double transferToSum =
          transferToTransactions.fold(0.0, (sum, t) => sum + t.amount);
      print('   🔄 ${account.name}: переводы на счет = $transferToSum');

      final expenseTransactions = _transactions
          .where((t) =>
              t.accountId == account.id &&
              t.type == TransactionType.expense &&
              t.fromAccountId == null &&
              t.date.isAfter(startDate.subtract(const Duration(days: 1))) &&
              t.date.isBefore(endDate.add(const Duration(days: 1))))
          .toList();

      double expenseSum =
          expenseTransactions.fold(0.0, (sum, t) => sum + t.amount);
      print('   💸 ${account.name}: снятия = $expenseSum');

      final transferFromTransactions = _transactions
          .where((t) =>
              t.fromAccountId == account.id &&
              t.type == TransactionType.expense &&
              t.date.isAfter(startDate.subtract(const Duration(days: 1))) &&
              t.date.isBefore(endDate.add(const Duration(days: 1))))
          .toList();

      double transferFromSum =
          transferFromTransactions.fold(0.0, (sum, t) => sum + t.amount);
      print('   🔄 ${account.name}: переводы со счета = $transferFromSum');

      double accountSavings =
          incomeSum + transferToSum - expenseSum - transferFromSum;
      print('   💰 ${account.name}: ИТОГО приход = $accountSavings');

      savings += accountSavings;
    }

    print('📊 ОБЩИЕ СБЕРЕЖЕНИЯ за период: $savings');
    return savings;
  }

  List<Transaction> _getFilteredTransactions() {
    DateTime startDate;
    DateTime endDate;

    switch (_selectedPeriod) {
      case PeriodType.day:
        startDate = DateTime(
            _selectedDate.year, _selectedDate.month, _selectedDate.day);
        endDate = startDate;
        break;
      case PeriodType.week:
        final startOfWeek =
            _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));
        startDate =
            DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
        endDate = startDate.add(const Duration(days: 6));
        break;
      case PeriodType.month:
        startDate = DateTime(_selectedDate.year, _selectedDate.month, 1);
        endDate = DateTime(_selectedDate.year, _selectedDate.month + 1, 0);
        break;
      case PeriodType.year:
        startDate = DateTime(_selectedDate.year, 1, 1);
        endDate = DateTime(_selectedDate.year, 12, 31);
        break;
      case PeriodType.custom:
        if (_customDateRange == null) return [];
        startDate = _customDateRange!.start;
        endDate = _customDateRange!.end;
        break;
    }

    // ✅ ИСКЛЮЧАЕМ ЗАКРЫТИЕ ВКЛАДА ИЗ ДОХОДОВ
    final filtered = _transactions
        .where((t) =>
                t.date.isAfter(startDate.subtract(const Duration(days: 1))) &&
                t.date.isBefore(endDate.add(const Duration(days: 1))) &&
                ((_reportType == ReportType.expense &&
                        t.type == TransactionType.expense) ||
                    (_reportType == ReportType.income &&
                        t.type == TransactionType.income &&
                        t.category != 'Закрытие вклада')) // ← ИСКЛЮЧАЕМ
            )
        .toList();

    return filtered;
  }

  Map<String, double> _getCategoryTotals() {
    Map<String, double> result = {};

    final allTransactions = _transactions
        .where((t) =>
            t.date.isAfter(_getCurrentPeriodStartDate()
                .subtract(const Duration(days: 1))) &&
            t.date.isBefore(
                _getCurrentPeriodEndDate().add(const Duration(days: 1))))
        .toList();

    for (var transaction in allTransactions) {
      // ✅ ПОЛНОСТЬЮ ПРОПУСКАЕМ ЗАКРЫТИЕ ВКЛАДА
      if (transaction.category == 'Закрытие вклада') {
        continue; // НЕ добавляем никуда
      }

      final isFromDebt = transaction.fromAccountId != null &&
          _isDebtAccount(transaction.fromAccountId!);
      final isToLoan = transaction.toAccountId != null &&
          _isLoanAccount(transaction.toAccountId!);

      // ✅ ПЕРЕВОД С ДОЛГА НА КРЕДИТ
      if (transaction.category == 'Перевод' && isFromDebt && isToLoan) {
        if (_reportType == ReportType.income) {
          result['Долг мне'] = (result['Долг мне'] ?? 0) + transaction.amount;
        }
        if (_reportType == ReportType.expense) {
          result['Платеж по кредиту'] =
              (result['Платеж по кредиту'] ?? 0) + transaction.amount;
        }
        continue;
      }

      // Обычные переводы на кредит (только расход)
      if (transaction.category == 'Перевод' && isToLoan && !isFromDebt) {
        if (_reportType == ReportType.expense) {
          result['Платеж по кредиту'] =
              (result['Платеж по кредиту'] ?? 0) + transaction.amount;
        }
        continue;
      }

      // Обычные переводы с долга (только доход)
      if (transaction.category == 'Перевод' && isFromDebt && !isToLoan) {
        if (_reportType == ReportType.income) {
          result['Долг мне'] = (result['Долг мне'] ?? 0) + transaction.amount;
        }
        continue;
      }

      if (transaction.category == 'Перевод') continue;

      if (_reportType == ReportType.expense &&
          transaction.type != TransactionType.expense) continue;
      if (_reportType == ReportType.income &&
          transaction.type != TransactionType.income) continue;

      String categoryName = transaction.category;
      if (categoryName.isEmpty) {
        categoryName = 'Проценты';
      }

      result[categoryName] = (result[categoryName] ?? 0) + transaction.amount;
    }

    final sortedEntries = result.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    print(
        '📊 ИТОГОВЫЙ result для ${_reportType == ReportType.expense ? "расходов" : "доходов"}: $result');
    return Map.fromEntries(sortedEntries);
  }

  Map<String, Map<String, double>> _getDetailedTotals() {
    Map<String, Map<String, double>> result = {};
    final filtered = _getFilteredTransactions();

    for (var transaction in filtered) {
      if (_isDepositClosure(transaction)) continue;

      // ✅ ПЕРЕВОД С ДОЛГА НА КРЕДИТ - и доход, и расход
      if (transaction.category == 'Перевод' &&
          transaction.fromAccountId != null &&
          transaction.toAccountId != null &&
          _isDebtAccount(transaction.fromAccountId!) &&
          _isLoanAccount(transaction.toAccountId!)) {
        // Доход - возврат долга
        result.putIfAbsent('Долг мне', () => {});
        final fromAccountName = _getAccountName(transaction.fromAccountId);
        result['Долг мне']![fromAccountName] =
            (result['Долг мне']![fromAccountName] ?? 0) + transaction.amount;
        // Расход - платеж по кредиту
        result.putIfAbsent('Платеж по кредиту', () => {});
        result['Платеж по кредиту']![''] =
            (result['Платеж по кредиту']![''] ?? 0) + transaction.amount;
        continue;
      }

      // Перевод на кредит
      if (transaction.category == 'Перевод' &&
          transaction.toAccountId != null &&
          _isLoanAccount(transaction.toAccountId!)) {
        result.putIfAbsent('Платеж по кредиту', () => {});
        final fromAccountName = _getAccountName(transaction.fromAccountId);
        result['Платеж по кредиту']![fromAccountName] =
            (result['Платеж по кредиту']![fromAccountName] ?? 0) +
                transaction.amount;
        continue;
      }

      // Перевод с долга
      if (transaction.category == 'Перевод' &&
          transaction.fromAccountId != null &&
          _isDebtAccount(transaction.fromAccountId!)) {
        result.putIfAbsent('Долг мне', () => {});
        final fromAccountName = _getAccountName(transaction.fromAccountId);
        result['Долг мне']![fromAccountName] =
            (result['Долг мне']![fromAccountName] ?? 0) + transaction.amount;
        continue;
      }

      if (transaction.category == 'Перевод') continue;

      if (transaction.category == 'Долг мне' &&
          transaction.type != TransactionType.income) continue;
      if (transaction.category == 'Должен я' &&
          transaction.type != TransactionType.expense) continue;

      String categoryName = transaction.category;
      if (categoryName.isEmpty) {
        categoryName = 'Проценты';
      }

      // НОВЫЙ КОД (исправленный):
      result.putIfAbsent(categoryName, () => {});

      if (transaction.subCategory != null &&
          transaction.subCategory!.isNotEmpty) {
        // Если есть подкатегория - добавляем в подкатегорию
        result[categoryName]![transaction.subCategory!] =
            (result[categoryName]![transaction.subCategory!] ?? 0) +
                transaction.amount;
      } else {
        // ✅ Если подкатегории нет - добавляем в пустую строку (основная категория)
        result[categoryName]![''] =
            (result[categoryName]![''] ?? 0) + transaction.amount;
      }
    }

    return result;
  }

  bool _isLoanAccount(String accountId) {
    try {
      final account = _accounts.firstWhere((a) => a.id == accountId);
      print('   _isLoanAccount: ${account.name} -> type=${account.type}');
      return account.type == AccountType.loan;
    } catch (e) {
      print('   _isLoanAccount: счет не найден');
      return false;
    }
  }

  double _getTotal() {
    final filtered = _getFilteredTransactions();

    // Суммируем только то, что уже отфильтровано
    // (закрытие вклада уже исключено в _getFilteredTransactions)
    return filtered.fold(0, (sum, t) => sum + t.amount);
  }

  bool _isDebtAccount(String accountId) {
    try {
      final account = _accounts.firstWhere((a) => a.id == accountId);
      print('   _isDebtAccount: ${account.name} -> type=${account.type}');
      return account.type == AccountType.debtOwed ||
          account.type == AccountType.debtToPay;
    } catch (e) {
      print('   _isDebtAccount: счет не найден');
      return false;
    }
  }

  String _getAccountName(String? accountId) {
    if (accountId == null) return 'неизвестный счет';
    final account = _accounts.firstWhereOrNull((a) => a.id == accountId);
    return account?.name ?? 'неизвестный счет';
  }

  double _getInterestForPeriod(
      Account account, DateTime startDate, DateTime endDate) {
    double total = 0;
    for (var t in _transactions) {
      if (t.accountId == account.id &&
          t.title.contains('Проценты') &&
          t.date.isAfter(startDate.subtract(const Duration(days: 1))) &&
          t.date.isBefore(endDate.add(const Duration(days: 1)))) {
        total += t.amount;
      }
    }
    return total;
  }

  double _getTotalInterestAllTime(Account account) {
    double total = 0;
    for (var t in _transactions) {
      if (t.accountId == account.id && t.title.contains('Проценты')) {
        total += t.amount;
      }
    }
    return total;
  }

  double _getIncomeForPeriod(
      Account account, DateTime startDate, DateTime endDate) {
    double total = 0;
    for (var t in _transactions) {
      // Доходы: обычные доходы + переводы на счет
      if (t.accountId == account.id &&
          t.type == TransactionType.income &&
          t.date.isAfter(startDate.subtract(const Duration(days: 1))) &&
          t.date.isBefore(endDate.add(const Duration(days: 1)))) {
        total += t.amount;
      }
      // Переводы на счет
      if (t.toAccountId == account.id &&
          t.date.isAfter(startDate.subtract(const Duration(days: 1))) &&
          t.date.isBefore(endDate.add(const Duration(days: 1)))) {
        total += t.amount;
      }
    }
    return total;
  }

  double _getExpenseForPeriod(
      Account account, DateTime startDate, DateTime endDate) {
    double total = 0;
    for (var t in _transactions) {
      // Расходы: снятия со счета
      if (t.accountId == account.id &&
          t.type == TransactionType.expense &&
          t.fromAccountId == null &&
          t.date.isAfter(startDate.subtract(const Duration(days: 1))) &&
          t.date.isBefore(endDate.add(const Duration(days: 1)))) {
        total += t.amount;
      }
      // Переводы со счета
      if (t.fromAccountId == account.id &&
          t.date.isAfter(startDate.subtract(const Duration(days: 1))) &&
          t.date.isBefore(endDate.add(const Duration(days: 1)))) {
        total += t.amount;
      }
    }
    return total;
  }

  String _getPeriodTitle() {
    switch (_selectedPeriod) {
      case PeriodType.day:
        return DateFormat('dd MMMM yyyy', 'ru_RU').format(_selectedDate);
      case PeriodType.week:
        final startOfWeek =
            _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));
        final endOfWeek = startOfWeek.add(const Duration(days: 6));
        return '${DateFormat('dd MMM', 'ru_RU').format(startOfWeek)} - ${DateFormat('dd MMM yyyy', 'ru_RU').format(endOfWeek)}';
      case PeriodType.month:
        return DateFormat('MMMM yyyy', 'ru_RU').format(_selectedDate);
      case PeriodType.year:
        return _selectedDate.year.toString();
      case PeriodType.custom:
        if (_customDateRange != null) {
          return '${DateFormat('dd.MM.yyyy').format(_customDateRange!.start)} - ${DateFormat('dd.MM.yyyy').format(_customDateRange!.end)}';
        }
        return 'Выберите период';
    }
  }

  Future<void> _selectCustomPeriod() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: null,
    );

    if (picked != null) {
      setState(() {
        _customDateRange = picked;
        _selectedPeriod = PeriodType.custom;
      });
    }
  }

  void _showPeriodPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Выберите период',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _buildPeriodOption(PeriodType.day, 'День'),
              _buildPeriodOption(PeriodType.week, 'Неделя'),
              _buildPeriodOption(PeriodType.month, 'Месяц'),
              _buildPeriodOption(PeriodType.year, 'Год'),
              _buildPeriodOption(PeriodType.custom, 'Произвольный'),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPeriodOption(PeriodType type, String title) {
    return ListTile(
      leading: Radio<PeriodType>(
        value: type,
        groupValue: _selectedPeriod,
        onChanged: (value) {
          setState(() {
            _selectedPeriod = value!;
          });
          Navigator.pop(context);
          if (type == PeriodType.custom) {
            _selectCustomPeriod();
          }
        },
      ),
      title: Text(title),
      onTap: () {
        setState(() {
          _selectedPeriod = type;
        });
        Navigator.pop(context);
        if (type == PeriodType.custom) {
          _selectCustomPeriod();
        }
      },
    );
  }

  String _formatAmount(double amount) {
    return '${NumberFormat('#,##0.00', 'ru_RU').format(amount)} ₽';
  }

  String _getBudgetTypeName(String? type) {
    switch (type) {
      case 'needs':
        return 'Обязательные нужды';
      case 'wants':
        return 'Желания';
      case 'emergency':
        return 'Непредвиденные';
      default:
        return '';
    }
  }

  Color _getBudgetTypeColor(String? type) {
    switch (type) {
      case 'needs':
        return Colors.blue;
      case 'wants':
        return Colors.orange;
      case 'emergency':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final primaryColor =
        settingsProvider.primaryColor; // 👈 выбранный пользователем цвет

    final categoryTotals = _getCategoryTotals();
    final detailedTotals = _getDetailedTotals();
    final total = _getTotal();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Отчеты'),
        elevation: 0,
        backgroundColor: Colors.transparent, // 👈 прозрачный фон
        bottom: TabBar(
          controller: _tabController,
          labelColor: primaryColor, // 👈 цвет текста выбранной вкладки
          unselectedLabelColor: Colors.grey, // 👈 серый для невыбранных
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal),
          indicatorColor: primaryColor, // 👈 линия индикатора = выбранный цвет
          tabs: const [
            Tab(text: 'Категории'),
            Tab(text: 'Цели и счета'),
            Tab(text: 'Бюджет'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCategoriesTab(categoryTotals, detailedTotals, total),
          _buildGoalsAndAccountsTab(),
          _buildBudgetTab(),
        ],
      ),
    );
  }

  Widget _buildCategoriesTab(Map<String, double> categoryTotals,
      Map<String, Map<String, double>> detailedTotals, double total) {
    final colorScheme = Theme.of(context).colorScheme;

    final sortedCategories = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final topCategories = sortedCategories.take(5).toList();
    final otherTotal =
        sortedCategories.skip(5).fold(0.0, (sum, entry) => sum + entry.value);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.light
                ? Colors.white
                : Colors.grey.shade900,
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: SegmentedButton<ReportType>(
                      segments: const [
                        ButtonSegment(
                            value: ReportType.expense,
                            label: Text('📉 Расходы')),
                        ButtonSegment(
                            value: ReportType.income, label: Text('📈 Доходы')),
                      ],
                      selected: {_reportType},
                      onSelectionChanged: (Set<ReportType> selection) {
                        setState(() => _reportType = selection.first);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.chevron_left, color: colorScheme.primary),
                    onPressed: () => _navigatePeriod(-1),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        _showPeriodPicker();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.calendar_today,
                                size: 20, color: colorScheme.primary),
                            const SizedBox(width: 8),
                            Text(_getPeriodTitle()),
                            const SizedBox(width: 8),
                            Icon(Icons.arrow_drop_down,
                                size: 20, color: colorScheme.primary),
                          ],
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.chevron_right, color: colorScheme.primary),
                    onPressed: () => _navigatePeriod(1),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxWidth: 300),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _reportType == ReportType.expense
                              ? Colors.red.shade400
                              : Colors.green.shade400,
                          _reportType == ReportType.expense
                              ? Colors.red.shade700
                              : Colors.green.shade700,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        Text(
                          _reportType == ReportType.expense
                              ? 'Общий расход'
                              : 'Общий доход',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _formatAmount(total),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
                Consumer<SettingsProvider>(
                  builder: (context, settingsProvider, child) {
                    final methodPercentages = _getMethodPercentages();
                    final actualPercentages =
                        _getActualPercentages(categoryTotals, total);

                    if (settingsProvider.showMethodCard &&
                        _reportType == ReportType.expense &&
                        methodPercentages.isNotEmpty &&
                        actualPercentages.isNotEmpty &&
                        total > 0) {
                      return _buildMethodCard(
                          methodPercentages, actualPercentages, total);
                    }
                    return const SizedBox.shrink();
                  },
                ),
                const SizedBox(height: 24),
                if (categoryTotals.isNotEmpty) ...[
                  const Text('Распределение по категориям',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 280,
                    child: PieChart(
                      PieChartData(
                        sections: _buildPieSections(categoryTotals),
                        centerSpaceRadius: 50,
                        sectionsSpace: 3,
                        borderData: FlBorderData(show: false),
                        startDegreeOffset: -90,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.light
                          ? Colors.grey.shade50
                          : Colors.grey.shade800,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 20,
                      runSpacing: 8,
                      children: [
                        ...topCategories.asMap().entries.map((entry) {
                          final categoryName = entry.value.key;
                          final amount = entry.value.value;
                          final percentage = (amount / total * 100);

                          Color color;
                          if (categoryName == 'Долг мне') {
                            color = Colors.orange;
                          } else if (categoryName == 'Должен я') {
                            color = Colors.red;
                          } else if (categoryName == 'Проценты') {
                            color = Colors.teal; // мятный цвет
                          } else if (categoryName == 'Платеж по кредиту') {
                            color = Colors.deepOrange.shade900; // бордовый
                          } else {
                            final category = _categoryMap[categoryName];
                            color = category?.color ?? Colors.blue;
                          }

                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '$categoryName ${percentage.toStringAsFixed(1)}%',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).brightness ==
                                          Brightness.light
                                      ? Colors.grey.shade800
                                      : Colors.grey.shade300,
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                        if (otherTotal > 0)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: Colors.grey,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Остальное ${(otherTotal / total * 100).toStringAsFixed(1)}%',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).brightness ==
                                          Brightness.light
                                      ? Colors.grey.shade800
                                      : Colors.grey.shade300,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                const Text('Детализация',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                if (categoryTotals.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child:
                        Center(child: Text('Нет данных за выбранный период')),
                  )
                else
                  ..._buildDetailedList(detailedTotals, total),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildDetailedList(
      Map<String, Map<String, double>> detailedTotals, double total) {
    final List<Widget> widgets = [];

    final Map<String, double> categoryTotals = {};
    for (var entry in detailedTotals.entries) {
      final sum = entry.value.values.fold(0.0, (sum, val) => sum + val);
      categoryTotals[entry.key] = sum;
    }

    final sortedCategories = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    for (var catEntry in sortedCategories) {
      final catName = catEntry.key;

      if (catName == 'Перевод') continue;

      final categoryTotal = catEntry.value;
      final category = _categoryMap[catName];

      Color catColor;
      if (catName == 'Долг мне') {
        catColor = Colors.orange;
      } else if (catName == 'Должен я') {
        catColor = Colors.red;
      } else if (catName == 'Проценты') {
        catColor = Colors.teal;
      } else if (catName == 'Платеж по кредиту') {
        catColor = Colors.deepOrange.shade900;
      } else if (_reportType == ReportType.expense) {
        catColor = category?.color ?? Colors.red;
      } else {
        catColor = category?.color ?? Colors.green;
      }

      final catIcon = category?.icon ?? Icons.category;
      final subcategories = detailedTotals[catName] ?? {};

      String amountText;
      if (catName == 'Долг мне') {
        amountText = '${_formatAmount(categoryTotal)}';
      } else if (catName == 'Должен я') {
        amountText = '${_formatAmount(categoryTotal)}';
      } else if (_reportType == ReportType.expense) {
        amountText = '${_formatAmount(categoryTotal)}';
      } else {
        amountText = '${_formatAmount(categoryTotal)}';
      }

      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 8),
          child: Row(
            children: [
              const SizedBox(width: 24),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: catColor.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(catIcon, color: catColor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(catName,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    amountText,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: catColor),
                  ),
                  Text(
                    '${(categoryTotal / total * 100).toStringAsFixed(1)}%',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
        ),
      );

      widgets.add(
        Padding(
          padding: const EdgeInsets.only(left: 44, bottom: 8),
          child: LinearProgressIndicator(
            value: categoryTotal / total,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation(catColor),
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      );

      if (subcategories.isNotEmpty) {
        final sortedSubs = subcategories.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        for (var subEntry in sortedSubs) {
          final subName = subEntry.key;
          final subAmount = subEntry.value;
          final subPercentage = (subAmount / total * 100);

          IconData subIcon = Icons.subdirectory_arrow_right;
          Color subColor = catColor;

          if (category != null) {
            for (var sub in category.subCategories) {
              if (sub.name == subName) {
                subIcon = sub.icon;
                subColor = sub.color;
                break;
              }
            }
          }

          if (subName == 'Возврат долга') {
            subColor = Colors.deepOrange.shade700;
          } else if (subName == 'Погашение долга') {
            subColor = Colors.red;
          }

          String subAmountText;
          if (subName == 'Возврат долга') {
            subAmountText = '+${_formatAmount(subAmount)}';
          } else if (subName == 'Погашение долга') {
            subAmountText = '-${_formatAmount(subAmount)}';
          } else {
            subAmountText = _formatAmount(subAmount);
          }

          widgets.add(
            Padding(
              padding: const EdgeInsets.only(left: 56, top: 4, bottom: 4),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: subColor.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(subIcon, color: subColor, size: 16),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(subName, style: const TextStyle(fontSize: 14)),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        subAmountText,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: subColor),
                      ),
                      Text(
                        '${subPercentage.toStringAsFixed(1)}%',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }
      }

      if (subcategories.containsKey('') && subcategories['']! > 0) {
        final noSubAmount = subcategories['']!;
        final noSubPercentage = (noSubAmount / total * 100);
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(left: 56, top: 4, bottom: 4),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: catColor.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.category, color: catColor, size: 16),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Без подкатегории',
                      style: const TextStyle(fontSize: 14)),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatAmount(noSubAmount),
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: catColor),
                    ),
                    Text(
                      '${noSubPercentage.toStringAsFixed(1)}%',
                      style:
                          TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }
    } // ← ЗАКРЫВАЕТ for (var catEntry in sortedCategories)

    return widgets;
  } // ← ЗАКРЫВАЕТ метод _buildDetailedList

  List<PieChartSectionData> _buildPieSections(Map<String, double> data) {
    final total = data.values.fold(0.0, (sum, val) => sum + val);
    final List<MapEntry<String, double>> sortedEntries = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final topEntries = sortedEntries.take(5).toList();
    final otherTotal =
        sortedEntries.skip(5).fold(0.0, (sum, entry) => sum + entry.value);

    final List<MapEntry<String, double>> sections = [];
    sections.addAll(topEntries);
    if (otherTotal > 0) {
      sections.add(MapEntry('Остальное', otherTotal));
    }

    return sections.asMap().entries.map((entry) {
      final categoryName = entry.value.key;
      final amount = entry.value.value;
      final percentage = (amount / total * 100);

      Color color;
      if (categoryName == 'Проценты') {
        color = Colors.teal; // мятный/teal цвет
      } else if (categoryName == 'Платеж по кредиту') {
        color = Colors.deepOrange.shade900; // бордовый
      } else if (categoryName == 'Остальное') {
        color = Colors.grey;
      } else if (categoryName == 'Долг мне') {
        color = Colors.orange;
      } else if (categoryName == 'Должен я') {
        color = Colors.red;
      } else if (_reportType == ReportType.expense) {
        final category = _categoryMap[categoryName];
        color = category?.color ?? Colors.red;
      } else {
        final category = _categoryMap[categoryName];
        color = category?.color ?? Colors.green;
      }

      String title = '';
      if (percentage > 5) {
        if (categoryName.length > 12) {
          title =
              '${categoryName.substring(0, 10)}..\n${percentage.toStringAsFixed(0)}%';
        } else {
          title = '$categoryName\n${percentage.toStringAsFixed(0)}%';
        }
      } else if (percentage > 3) {
        title = '${percentage.toStringAsFixed(0)}%';
      }

      return PieChartSectionData(
        value: amount,
        title: title,
        radius: 100,
        titleStyle: TextStyle(
          fontSize: percentage > 8 ? 12 : 10,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        color: color,
        titlePositionPercentageOffset: 0.6,
        showTitle: percentage > 3,
      );
    }).toList();
  }

  Widget _buildBudgetTab() {
    final colorScheme = Theme.of(context).colorScheme;
    final settings = Provider.of<SettingsProvider>(context);

    DateTime startDate;
    DateTime endDate;

    switch (_selectedPeriod) {
      case PeriodType.day:
        startDate = DateTime(
            _selectedDate.year, _selectedDate.month, _selectedDate.day);
        endDate = startDate;
        break;
      case PeriodType.week:
        final startOfWeek =
            _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));
        startDate =
            DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
        endDate = startDate.add(const Duration(days: 6));
        break;
      case PeriodType.month:
        startDate = DateTime(_selectedDate.year, _selectedDate.month, 1);
        endDate = DateTime(_selectedDate.year, _selectedDate.month + 1, 0);
        break;
      case PeriodType.year:
        startDate = DateTime(_selectedDate.year, 1, 1);
        endDate = DateTime(_selectedDate.year, 12, 31);
        break;
      case PeriodType.custom:
        if (_customDateRange == null)
          return const Center(child: Text('Выберите период'));
        startDate = _customDateRange!.start;
        endDate = _customDateRange!.end;
        break;
    }

    final expenseTransactions = _transactions
        .where((t) =>
            t.type == TransactionType.expense &&
            t.fromAccountId == null &&
            t.date.isAfter(startDate.subtract(const Duration(days: 1))) &&
            t.date.isBefore(endDate.add(const Duration(days: 1))))
        .toList();

    return FutureBuilder<Map<String, double>>(
      future: _loadBudgets(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final budgets = snapshot.data!;

        Map<String, double> actualByCategory = {};
        Map<String, Map<String, double>> actualBySubcategory = {};

        for (var t in expenseTransactions) {
          actualByCategory[t.category] =
              (actualByCategory[t.category] ?? 0) + t.amount;
          if (t.subCategory != null && t.subCategory!.isNotEmpty) {
            actualBySubcategory.putIfAbsent(t.category, () => {});
            actualBySubcategory[t.category]![t.subCategory!] =
                (actualBySubcategory[t.category]![t.subCategory!] ?? 0) +
                    t.amount;
          }
        }

        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.light
                    ? Colors.white
                    : Colors.grey.shade900,
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.05), blurRadius: 4)
                ],
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.chevron_left, color: colorScheme.primary),
                    onPressed: () => _navigatePeriod(-1),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () => _showPeriodPicker(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.calendar_today,
                                size: 20, color: colorScheme.primary),
                            const SizedBox(width: 8),
                            Text(_getPeriodTitle()),
                            const SizedBox(width: 8),
                            Icon(Icons.arrow_drop_down,
                                size: 20, color: colorScheme.primary),
                          ],
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.chevron_right, color: colorScheme.primary),
                    onPressed: () => _navigatePeriod(1),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (settings.showMethodCard)
                      _buildBudgetSummaryCard(
                          budgets, actualByCategory, actualBySubcategory),
                    const SizedBox(height: 24),
                    const Text(
                      '📊 Бюджет по категориям',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    if (_expenseCategories.isEmpty)
                      const Center(child: Text('Нет категорий расходов'))
                    else
                      ..._expenseCategories
                          .map((category) => _buildBudgetCategoryWithSubs(
                                category,
                                budgets,
                                actualByCategory,
                                actualBySubcategory,
                                settings.showMethodCard,
                              )),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<Map<String, double>> _loadBudgets() async {
    final prefs = await SharedPreferences.getInstance();
    final String? budgetsJson = prefs.getString('budgets');
    if (budgetsJson == null) {
      return {};
    }

    final Map<String, dynamic> decoded = jsonDecode(budgetsJson);
    Map<String, double> result = {};

    for (var entry in decoded.entries) {
      result[entry.key] = (entry.value as num).toDouble();
    }

    return result;
  }

  Widget _buildBudgetSummaryCard(
    Map<String, double> budgets,
    Map<String, double> actualExpenses,
    Map<String, Map<String, double>> actualBySubcategory,
  ) {
    double totalBudget = 0;
    double totalActual = 0;

    List<String> overBudgetCategories = [];

    for (var category in _expenseCategories) {
      bool hasSubBudgets = false;
      double subBudgetsTotal = 0;
      double subActualTotal = 0;

      for (var sub in category.subCategories) {
        final subBudget = budgets['sub_${sub.id}'] ?? 0;
        if (subBudget > 0) {
          hasSubBudgets = true;
          subBudgetsTotal += subBudget;
          final subActual = actualBySubcategory[category.name]?[sub.name] ?? 0;
          subActualTotal += subActual;
        }
      }

      if (hasSubBudgets) {
        totalBudget += subBudgetsTotal;
        totalActual += subActualTotal;

        if (subBudgetsTotal - subActualTotal < 0) {
          overBudgetCategories.add(category.name);
        }
      } else {
        final catBudget = budgets['cat_${category.id}'] ?? 0;
        final catActual = actualExpenses[category.name] ?? 0;

        totalBudget += catBudget;
        totalActual += catActual;

        if (catBudget - catActual < 0) {
          overBudgetCategories.add(category.name);
        }
      }
    }

    final remaining = totalBudget - totalActual;
    final isOverBudget = remaining < 0;

    double percentSpent = 0.0;
    if (totalBudget > 0) {
      percentSpent = (totalActual / totalBudget * 100);
    } else if (totalActual > 0) {
      percentSpent = 100.0;
    }

    double percentValueForBar = (percentSpent / 100).clamp(0.0, 1.0);

    String statusText;
    IconData statusIcon;
    Color statusColor;

    if (isOverBudget) {
      statusText = 'Перерасход';
      statusIcon = Icons.sentiment_very_dissatisfied;
      statusColor = Colors.redAccent;
    } else if (percentSpent >= 90) {
      statusText = 'На грани';
      statusIcon = Icons.sentiment_neutral;
      statusColor = Colors.deepOrange;
    } else if (percentSpent >= 50) {
      statusText = 'Нормально';
      statusIcon = Icons.sentiment_satisfied;
      statusColor = Colors.orange;
    } else {
      statusText = 'Отлично!';
      statusIcon = Icons.sentiment_very_satisfied;
      statusColor = Colors.greenAccent;
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isOverBudget
                ? [Colors.red.shade400, Colors.red.shade700]
                : [Colors.green.shade400, Colors.green.shade700],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(statusIcon, color: statusColor, size: 28),
                  const SizedBox(width: 8),
                  Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text('Общий бюджет',
                  style: TextStyle(color: Colors.white, fontSize: 14)),
              const SizedBox(height: 8),
              Text(
                _formatAmount(totalBudget),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: percentValueForBar),
                duration: const Duration(milliseconds: 500),
                builder: (context, value, child) {
                  return LinearProgressIndicator(
                    value: value,
                    backgroundColor: Colors.white.withOpacity(0.3),
                    valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                    minHeight: 10,
                    borderRadius: BorderRadius.circular(5),
                  );
                },
              ),
              const SizedBox(height: 8),
              Text(
                '${percentSpent.toStringAsFixed(1)}% использовано',
                style: TextStyle(
                  color: isOverBudget
                      ? Colors.redAccent
                      : Colors.white.withOpacity(0.8),
                  fontSize: 12,
                  fontWeight:
                      isOverBudget ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    children: [
                      Text('Потрачено',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 12)),
                      const SizedBox(height: 4),
                      Text(
                        _formatAmount(totalActual),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Container(
                      width: 1,
                      height: 40,
                      color: Colors.white.withOpacity(0.3)),
                  Column(
                    children: [
                      Text(
                        isOverBudget ? 'Перерасход' : 'Осталось',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.8), fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatAmount(remaining.abs()),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
              if (overBudgetCategories.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning, color: Colors.red, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Перерасход: ${overBudgetCategories.take(2).join(", ")}${overBudgetCategories.length > 2 ? " и еще ${overBudgetCategories.length - 2}" : ""}',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBudgetCategoryWithSubs(
    Category category,
    Map<String, double> budgets,
    Map<String, double> actualByCategory,
    Map<String, Map<String, double>> actualBySubcategory,
    bool showMethodCard,
  ) {
    final categoryBudget = budgets['cat_${category.id}'] ?? 0;
    final categoryActual = actualByCategory[category.name] ?? 0;
    final remaining = categoryBudget - categoryActual;
    final isOverBudget = remaining < 0;
    final percentage = categoryBudget > 0
        ? (categoryActual / categoryBudget * 100).clamp(0.0, 150.0)
        : 0.0;
    final hasSubCategories = category.subCategories.isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SizedBox(width: 24),
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: category.color.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(category.icon, color: category.color, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    category.name,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Бюджет: ${_formatAmount(categoryBudget)}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    Text(
                      'Факт: ${_formatAmount(categoryActual)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isOverBudget ? Colors.red : Colors.green,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: percentage / 100,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation(
                  isOverBudget ? Colors.red : category.color),
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${percentage.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 11,
                    color: isOverBudget ? Colors.red : Colors.grey.shade600,
                  ),
                ),
                Text(
                  isOverBudget
                      ? 'Перерасход: ${_formatAmount(remaining.abs())}'
                      : 'Осталось: ${_formatAmount(remaining)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: isOverBudget ? Colors.red : Colors.green,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            if (hasSubCategories) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              ...category.subCategories
                  .map((sub) => _buildBudgetSubcategoryCard(
                        sub,
                        category,
                        budgets,
                        actualBySubcategory,
                        showMethodCard,
                      )),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBudgetSubcategoryCard(
    SubCategory sub,
    Category category,
    Map<String, double> budgets,
    Map<String, Map<String, double>> actualBySubcategory,
    bool showMethodCard,
  ) {
    final subBudget = budgets['sub_${sub.id}'] ?? 0;
    final subActual = actualBySubcategory[category.name]?[sub.name] ?? 0;
    final subRemaining = subBudget - subActual;
    final subIsOverBudget = subRemaining < 0;
    final subPercentage =
        subBudget > 0 ? (subActual / subBudget * 100).clamp(0.0, 150.0) : 0.0;

    return Padding(
      padding: const EdgeInsets.only(left: 32, top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: sub.color.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(sub.icon, color: sub.color, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  sub.name,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Бюджет: ${_formatAmount(subBudget)}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  Text(
                    'Факт: ${_formatAmount(subActual)}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: subIsOverBudget ? Colors.red : Colors.green,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: subPercentage / 100,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation(
                subIsOverBudget ? Colors.red : sub.color),
            minHeight: 4,
            borderRadius: BorderRadius.circular(2),
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${subPercentage.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 10,
                  color: subIsOverBudget ? Colors.red : Colors.grey.shade600,
                ),
              ),
              Text(
                subIsOverBudget
                    ? 'Перерасход: ${_formatAmount(subRemaining.abs())}'
                    : 'Осталось: ${_formatAmount(subRemaining)}',
                style: TextStyle(
                  fontSize: 10,
                  color: subIsOverBudget ? Colors.red : Colors.green,
                ),
              ),
            ],
          ),
          if (showMethodCard &&
              sub.budgetType != null &&
              sub.budgetType!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _getBudgetTypeColor(sub.budgetType).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _getBudgetTypeName(sub.budgetType),
                style: TextStyle(
                  fontSize: 9,
                  color: _getBudgetTypeColor(sub.budgetType),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGoalsAndAccountsTab() {
    final colorScheme = Theme.of(context).colorScheme;
    final filteredTransactions = _getFilteredTransactions();

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.light
                ? Colors.white
                : Colors.grey.shade900,
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)
            ],
          ),
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.chevron_left, color: colorScheme.primary),
                onPressed: () => _navigatePeriod(-1),
              ),
              Expanded(
                child: InkWell(
                  onTap: () {
                    _showPeriodPicker();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.calendar_today,
                            size: 20, color: colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(_getPeriodTitle()),
                        const SizedBox(width: 8),
                        Icon(Icons.arrow_drop_down,
                            size: 20, color: colorScheme.primary),
                      ],
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.chevron_right, color: colorScheme.primary),
                onPressed: () => _navigatePeriod(1),
              ),
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300, width: 1),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                children: [
                  _buildSubTabButton('🎯 Цели', 0,
                      isFirst: true, isLast: false),
                  Container(width: 1, height: 40, color: Colors.grey.shade300),
                  _buildSubTabButton('💰 Счета', 1,
                      isFirst: false, isLast: true),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: TabBarView(
            controller: _subTabController,
            children: [
              _buildGoalsTab(filteredTransactions),
              _buildAccountsTabInternal(filteredTransactions),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSubTabButton(String title, int index,
      {required bool isFirst, required bool isLast}) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSelected = _subTabController.index == index;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          _subTabController.animateTo(index);
          setState(() {});
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? colorScheme.primary : Colors.transparent,
            borderRadius: BorderRadius.only(
              topLeft: isFirst ? Radius.circular(30) : Radius.zero,
              bottomLeft: isFirst ? Radius.circular(30) : Radius.zero,
              topRight: isLast ? Radius.circular(30) : Radius.zero,
              bottomRight: isLast ? Radius.circular(30) : Radius.zero,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isSelected)
                const Icon(
                  Icons.check,
                  size: 16,
                  color: Colors.white,
                ),
              if (isSelected) const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? Colors.white : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGoalsTab(List<Transaction> filteredTransactions) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (_goals.isEmpty)
            const Center(child: Text('Нет целей'))
          else
            ..._goals.map((goal) => _buildGoalCard(goal, filteredTransactions)),
        ],
      ),
    );
  }

  Widget _buildAccountsTabInternal(List<Transaction> filteredTransactions) {
    Map<String, double> accountIncome = {};
    Map<String, double> accountExpense = {};

    for (var t in filteredTransactions) {
      // Обычные доходы/расходы
      if (t.accountId != null) {
        if (t.type == TransactionType.income) {
          accountIncome[t.accountId!] =
              (accountIncome[t.accountId!] ?? 0) + t.amount;
        } else if (t.type == TransactionType.expense &&
            t.fromAccountId == null) {
          accountExpense[t.accountId!] =
              (accountExpense[t.accountId!] ?? 0) + t.amount;
        }
      }
      // Переводы: списание
      if (t.fromAccountId != null) {
        accountExpense[t.fromAccountId!] =
            (accountExpense[t.fromAccountId!] ?? 0) + t.amount;
      }
      // Переводы: зачисление
      if (t.toAccountId != null) {
        accountIncome[t.toAccountId!] =
            (accountIncome[t.toAccountId!] ?? 0) + t.amount;
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (_accounts.isEmpty)
            const Center(child: Text('Нет счетов'))
          else
            ..._accounts.map((account) => _buildAccountCard(
                  account,
                  accountIncome[account.id] ?? 0,
                  accountExpense[account.id] ?? 0,
                )),
        ],
      ),
    );
  }

  Widget _buildAccountCard(Account account, double income, double expense) {
    // ==================== КРЕДИТ ====================
    if (account.type == AccountType.loan) {
      final principal = (account.principalAmount ?? 0).abs();
      final rate = account.interestRate ?? 0;

      // Срок в месяцах
      int totalMonths = account.loanTermMonths ?? 0;
      if (totalMonths == 0 && account.loanTermYears != null) {
        totalMonths = account.loanTermYears! * 12;
      }
      if (totalMonths == 0) totalMonths = 60;

      // ✅ РАСЧЁТ ЕЖЕМЕСЯЧНОГО ПЛАТЕЖА И ПРОЦЕНТОВ (аннуитет)
      double monthlyPayment = account.monthlyPayment ?? 0;
      double totalInterestForWholeTerm = 0;

      if (principal > 0 && rate > 0 && totalMonths > 0) {
        final monthlyRate = rate / 100 / 12;
        if (monthlyRate > 0) {
          final powResult = pow(1 + monthlyRate, totalMonths).toDouble();
          final annuityFactor = (monthlyRate * powResult) / (powResult - 1);
          monthlyPayment = principal * annuityFactor;

          // ✅ ОКРУГЛЯЕМ ЕЖЕМЕСЯЧНЫЙ ПЛАТЁЖ ДО ЦЕЛЫХ РУБЛЕЙ
          monthlyPayment = monthlyPayment.roundToDouble();

          final totalPayments = monthlyPayment * totalMonths;
          totalInterestForWholeTerm = totalPayments - principal;
          // ✅ ОКРУГЛЯЕМ ДО ЦЕЛЫХ
          totalInterestForWholeTerm = totalInterestForWholeTerm.roundToDouble();
          if (totalInterestForWholeTerm < 0) totalInterestForWholeTerm = 0;
        } else {
          monthlyPayment = principal / totalMonths;
          monthlyPayment = monthlyPayment.roundToDouble();
        }
      }

      // ✅ ОСТАТОК ОСНОВНОГО ДОЛГА (на основе платежей)
      double remainingPrincipal = principal;

      // Находим все платежи по этому кредиту
      final loanPayments = _transactions
          .where((t) => t.toAccountId == account.id && t.category == 'Перевод')
          .toList();

      double totalPaid = 0;
      for (var payment in loanPayments) {
        totalPaid += payment.amount;
      }

      remainingPrincipal = principal - totalPaid;
      if (remainingPrincipal < 0) remainingPrincipal = 0;
      remainingPrincipal = remainingPrincipal.roundToDouble();

      // ✅ ОСТАВШИЕСЯ ПРОЦЕНТЫ (пропорционально остатку)
      double remainingInterest = 0;
      if (principal > 0 &&
          totalInterestForWholeTerm > 0 &&
          remainingPrincipal > 0) {
        remainingInterest =
            totalInterestForWholeTerm * (remainingPrincipal / principal);
        remainingInterest = remainingInterest.roundToDouble();
        if (remainingInterest < 0) remainingInterest = 0;
      }

      // ✅ ОБЩИЙ ОСТАТОК ДОЛГА
      final totalRemainingDebt = remainingPrincipal + remainingInterest;

      // ✅ ОСТАВШИЙСЯ СРОК
      int remainingMonths = account.remainingMonths ?? totalMonths;

      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                account.color.withOpacity(0.15),
                account.color.withOpacity(0.05)
              ],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: account.color.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(account.icon, color: account.color, size: 28),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            account.name,
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: account.color),
                          ),
                          Text(
                            account.type.displayName,
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Остаток долга',
                            style: TextStyle(fontSize: 12, color: Colors.grey)),
                        Text(
                          _formatAmount(totalRemainingDebt),
                          style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.red),
                        ),
                      ],
                    ),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Text('Ставка',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade600)),
                          const SizedBox(height: 4),
                          Text('$rate%',
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Text('Ежемесячный платеж',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade600)),
                          const SizedBox(height: 4),
                          Text(
                            _formatAmount(monthlyPayment),
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
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
                          Text('Основной долг (всего)',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade600)),
                          const SizedBox(height: 4),
                          Text(_formatAmount(principal),
                              style: const TextStyle(fontSize: 14)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Text('Остаток основного долга',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade600)),
                          const SizedBox(height: 4),
                          Text(_formatAmount(remainingPrincipal),
                              style: const TextStyle(fontSize: 14)),
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
                          Text('Долг по процентам (всего)',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade600)),
                          const SizedBox(height: 4),
                          Text(
                            _formatAmount(totalInterestForWholeTerm),
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.orange),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Text('Остаток процентов',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade600)),
                          const SizedBox(height: 4),
                          Text(
                            _formatAmount(remainingInterest),
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.orange),
                          ),
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
                          Text('Срок / Осталось',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade600)),
                          const SizedBox(height: 4),
                          Text(
                              '$totalMonths / ${remainingMonths > 0 ? remainingMonths : 0} мес',
                              style: const TextStyle(fontSize: 14)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    // ==================== НАКОПИТЕЛЬНЫЙ СЧЕТ ====================
    if (account.type == AccountType.savings) {
      final startDate = _getCurrentPeriodStartDate();
      final endDate = _getCurrentPeriodEndDate();

      final interestForPeriod =
          _getInterestForPeriod(account, startDate, endDate);
      final totalInterestAllTime = _getTotalInterestAllTime(account);
      final periodIncome = _getIncomeForPeriod(account, startDate, endDate);
      final periodExpense = _getExpenseForPeriod(account, startDate, endDate);

      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                account.color.withOpacity(0.15),
                account.color.withOpacity(0.05)
              ],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: account.color.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(account.icon, color: account.color, size: 28),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            account.name,
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: account.color),
                          ),
                          Text(
                            '${account.type.displayName} • ${account.interestRate}%',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Баланс',
                            style: TextStyle(fontSize: 12, color: Colors.grey)),
                        Text(
                          _formatAmount(account.balance),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: account.balance >= 0
                                ? Colors.green
                                : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Text('Ставка',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade600)),
                          const SizedBox(height: 4),
                          Text('${account.interestRate}%',
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Text('Накоплено % за период',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade600)),
                          const SizedBox(height: 4),
                          Text(
                            _formatAmount(interestForPeriod),
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.green),
                          ),
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
                          Text('Всего накоплено %',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade600)),
                          const SizedBox(height: 4),
                          Text(
                            _formatAmount(totalInterestAllTime),
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.green),
                          ),
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
                          Text('Доход за период',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade600)),
                          const SizedBox(height: 4),
                          Text(_formatAmount(periodIncome),
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Text('Расход за период',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade600)),
                          const SizedBox(height: 4),
                          Text(_formatAmount(periodExpense),
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    // ==================== ВКЛАД ====================
    if (account.type == AccountType.deposit) {
      final startDate = _getCurrentPeriodStartDate();
      final endDate = _getCurrentPeriodEndDate();

      String depositEndDate = '—';
      if (account.depositEndDate != null) {
        depositEndDate =
            '${account.depositEndDate!.day}.${account.depositEndDate!.month}.${account.depositEndDate!.year}';
      }

      // Используем те же методы, что и для накопительного счета
      final interestForPeriod =
          _getInterestForPeriod(account, startDate, endDate);
      final totalInterestAllTime = _getTotalInterestAllTime(account);
      final periodIncome = _getIncomeForPeriod(account, startDate, endDate);
      final periodExpense = _getExpenseForPeriod(account, startDate, endDate);

      // Показываем расход только если разрешено снятие
      final showExpense = account.allowWithdraw == true;

      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                account.color.withOpacity(0.15),
                account.color.withOpacity(0.05)
              ],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: account.color.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(account.icon, color: account.color, size: 28),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            account.name,
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: account.color),
                          ),
                          Text(
                            '${account.type.displayName} • ${account.interestRate}%',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Баланс',
                            style: TextStyle(fontSize: 12, color: Colors.grey)),
                        Text(
                          _formatAmount(account.balance),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: account.balance >= 0
                                ? Colors.green
                                : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const Divider(height: 24),

                // Ставка и срок
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Text('Ставка',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade600)),
                          const SizedBox(height: 4),
                          Text('${account.interestRate}%',
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Text('Срок',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade600)),
                          const SizedBox(height: 4),
                          Text(_formatDepositTerm(account),
                              style: const TextStyle(fontSize: 14)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Капитализация и дата закрытия
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Text('Капитализация',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade600)),
                          const SizedBox(height: 4),
                          Text(account.isCapitalized == true ? 'Да' : 'Нет',
                              style: const TextStyle(fontSize: 14)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Text('Дата закрытия',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade600)),
                          const SizedBox(height: 4),
                          Text(depositEndDate,
                              style: const TextStyle(fontSize: 14)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Накоплено % за период
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Text('Накоплено % за период',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade600)),
                          const SizedBox(height: 4),
                          Text(
                            _formatAmount(interestForPeriod),
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.green),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Text('Всего накоплено %',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade600)),
                          const SizedBox(height: 4),
                          Text(
                            _formatAmount(totalInterestAllTime),
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.green),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Доход и расход за период
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Text('Доход за период',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade600)),
                          const SizedBox(height: 4),
                          Text(
                            _formatAmount(periodIncome),
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.green),
                          ),
                        ],
                      ),
                    ),
                    if (showExpense)
                      Expanded(
                        child: Column(
                          children: [
                            Text('Расход за период',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey.shade600)),
                            const SizedBox(height: 4),
                            Text(
                              _formatAmount(periodExpense),
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    // ==================== ОБЫЧНЫЕ СЧЕТА ====================
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              account.color.withOpacity(0.15),
              account.color.withOpacity(0.05)
            ],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: account.color.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(account.icon, color: account.color, size: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          account.name,
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: account.color),
                        ),
                        Text(
                          account.type.displayName,
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('Баланс',
                          style: TextStyle(fontSize: 12, color: Colors.grey)),
                      Text(
                        _formatAmount(account.balance),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color:
                              account.balance >= 0 ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Text('Доход за период',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade600)),
                        Text(_formatAmount(income),
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.green)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text('Расход за период',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade600)),
                        Text(_formatAmount(expense),
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  DateTime _getCurrentPeriodStartDate() {
    switch (_selectedPeriod) {
      case PeriodType.day:
        return _selectedDate;
      case PeriodType.week:
        return _selectedDate
            .subtract(Duration(days: _selectedDate.weekday - 1));
      case PeriodType.month:
        return DateTime(_selectedDate.year, _selectedDate.month, 1);
      case PeriodType.year:
        return DateTime(_selectedDate.year, 1, 1);
      case PeriodType.custom:
        return _customDateRange?.start ?? DateTime.now();
    }
  }

  DateTime _getCurrentPeriodEndDate() {
    switch (_selectedPeriod) {
      case PeriodType.day:
        return _selectedDate;
      case PeriodType.week:
        final start =
            _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));
        return start.add(const Duration(days: 6));
      case PeriodType.month:
        return DateTime(_selectedDate.year, _selectedDate.month + 1, 0);
      case PeriodType.year:
        return DateTime(_selectedDate.year, 12, 31);
      case PeriodType.custom:
        return _customDateRange?.end ?? DateTime.now();
    }
  }

  Widget _buildGoalCard(Goal goal, List<Transaction> filteredTransactions) {
    double periodAmount = 0;

    // ✅ Если цель привязана к счету
    if (goal.accountId != null && goal.accountId != 'none') {
      double incomeForPeriod = 0;
      double expenseForPeriod = 0;

      for (var t in filteredTransactions) {
        // Доходы на счёт цели
        if (t.accountId == goal.accountId && t.type == TransactionType.income) {
          incomeForPeriod += t.amount;
        }
        // Переводы на счёт цели
        if (t.toAccountId == goal.accountId) {
          incomeForPeriod += t.amount;
        }
        // Расходы со счёта цели
        if (t.accountId == goal.accountId &&
            t.type == TransactionType.expense) {
          expenseForPeriod += t.amount;
        }
        // Переводы со счёта цели
        if (t.fromAccountId == goal.accountId) {
          expenseForPeriod += t.amount;
        }
      }

      // ✅ Накоплено за период = поступления - траты
      periodAmount = incomeForPeriod - expenseForPeriod;
      if (periodAmount < 0) periodAmount = 0;
    } else {
      // ✅ Если цели не привязаны к счету - ищем по категории
      for (var t in filteredTransactions) {
        if (t.category == 'Пополнение цели' && t.subCategory == goal.title) {
          periodAmount += t.amount;
        }
        if (t.subCategory == goal.title || t.category == goal.title) {
          periodAmount += t.amount;
        }
      }
    }

    final totalProgress = goal.currentAmount / goal.targetAmount;
    final remaining = goal.targetAmount - goal.currentAmount;
    final periodProgress = periodAmount / goal.targetAmount;

    Account? linkedAccount;
    if (goal.accountId != null) {
      try {
        linkedAccount = _accounts.firstWhere((a) => a.id == goal.accountId);
      } catch (e) {
        linkedAccount = null;
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              goal.color.withOpacity(0.15),
              goal.color.withOpacity(0.05)
            ],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                        color: goal.color.withOpacity(0.2),
                        shape: BoxShape.circle),
                    child: Icon(goal.icon, color: goal.color, size: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(goal.title,
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: goal.color)),
                        if (linkedAccount != null)
                          Text(
                              'Счет: ${linkedAccount.name} (${linkedAccount.type.displayName})',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade600)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Накоплено всего:', style: TextStyle(fontSize: 13)),
                Text(_formatAmount(goal.currentAmount),
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.bold))
              ]),
              const SizedBox(height: 4),
              LinearProgressIndicator(
                  value: totalProgress.clamp(0.0, 1.0),
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation(goal.color),
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(3)),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('${(totalProgress * 100).toStringAsFixed(1)}%',
                    style:
                        TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                Text('Осталось: ${_formatAmount(remaining)}',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600))
              ]),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Накоплено за период:',
                    style: TextStyle(fontSize: 13)),
                Text(
                  _formatAmount(periodAmount),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: periodAmount >= 0 ? Colors.green : Colors.red,
                  ),
                ),
              ]),
              const SizedBox(height: 4),
              LinearProgressIndicator(
                  value: periodProgress.clamp(0.0, 1.0),
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation(goal.color),
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(3)),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                Text('${(periodProgress * 100).toStringAsFixed(1)}% от цели',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600))
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Map<String, double> _getMethodPercentages() {
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: true);
    final method = settingsProvider.budgetMethod;

    switch (method) {
      case '50/30/20':
        return {
          'needs': 50.0,
          'wants': 30.0,
          'savings': 20.0,
          'emergency': 0.0
        };
      case '20/30/50':
        return {
          'needs': 20.0,
          'wants': 30.0,
          'savings': 50.0,
          'emergency': 0.0
        };
      case '30/30/30/10':
        return {
          'needs': 30.0,
          'wants': 30.0,
          'savings': 30.0,
          'emergency': 10.0
        };
      default:
        return {
          'needs': 50.0,
          'wants': 30.0,
          'savings': 20.0,
          'emergency': 0.0
        };
    }
  }

  String _getCategoryTypeByFallback(String categoryName) {
    if (categoryName.contains('Продукты') ||
        categoryName.contains('Транспорт') ||
        categoryName.contains('Здоровье') ||
        categoryName.contains('Связь') ||
        categoryName.contains('Коммунальные') ||
        categoryName.contains('ЖКХ') ||
        categoryName.contains('Образование') ||
        categoryName.contains('Аптека')) {
      return 'needs';
    } else if (categoryName.contains('Развлечения') ||
        categoryName.contains('Рестораны') ||
        categoryName.contains('Подарки') ||
        categoryName.contains('Одежда') ||
        categoryName.contains('Хобби') ||
        categoryName.contains('Путешествия')) {
      return 'wants';
    } else if (categoryName.contains('Инвестиции') ||
        categoryName.contains('Сбережения') ||
        categoryName.contains('Накопления') ||
        categoryName.contains('Вклад')) {
      return 'savings';
    } else if (categoryName.contains('Непредвиденные') ||
        categoryName.contains('Резерв')) {
      return 'emergency';
    }
    return 'needs';
  }

  Map<String, double> _getActualPercentages(
      Map<String, double> categoryTotals, double total) {
    double needsTotal = 0.0;
    double wantsTotal = 0.0;
    double savingsTotal = 0.0;
    double emergencyTotal = 0.0;

    DateTime startDate;
    DateTime endDate;
    switch (_selectedPeriod) {
      case PeriodType.day:
        startDate = DateTime(
            _selectedDate.year, _selectedDate.month, _selectedDate.day);
        endDate = startDate;
        break;
      case PeriodType.week:
        final startOfWeek =
            _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));
        startDate =
            DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
        endDate = startDate.add(const Duration(days: 6));
        break;
      case PeriodType.month:
        startDate = DateTime(_selectedDate.year, _selectedDate.month, 1);
        endDate = DateTime(_selectedDate.year, _selectedDate.month + 1, 0);
        break;
      case PeriodType.year:
        startDate = DateTime(_selectedDate.year, 1, 1);
        endDate = DateTime(_selectedDate.year, 12, 31);
        break;
      case PeriodType.custom:
        if (_customDateRange == null)
          return {'needs': 0.0, 'wants': 0.0, 'savings': 0.0, 'emergency': 0.0};
        startDate = _customDateRange!.start;
        endDate = _customDateRange!.end;
        break;
    }

    Map<String, String> subBudgetTypes = {};
    for (var category in _expenseCategories) {
      for (var sub in category.subCategories) {
        if (sub.budgetType != null && sub.budgetType!.isNotEmpty) {
          subBudgetTypes[sub.name] = sub.budgetType!;
        }
      }
    }

    final expenseTransactions = _transactions
        .where((t) =>
            t.type == TransactionType.expense &&
            t.fromAccountId == null &&
            t.date.isAfter(startDate.subtract(const Duration(days: 1))) &&
            t.date.isBefore(endDate.add(const Duration(days: 1))))
        .toList();

    print(
        '📊 РАСЧЕТ ПРОЦЕНТОВ: Найдено расходных транзакций: ${expenseTransactions.length}');

    for (var transaction in expenseTransactions) {
      double amount = transaction.amount;
      String? budgetType;

      if (transaction.subCategory != null &&
          transaction.subCategory!.isNotEmpty) {
        budgetType = subBudgetTypes[transaction.subCategory];
        print(
            '   Подкатегория: ${transaction.subCategory} -> тип: $budgetType, сумма: $amount');
      }

      if (budgetType == null) {
        final category = _categoryMap[transaction.category];
        if (category != null && category.budgetType != null) {
          budgetType = category.budgetType;
          print(
              '   Категория: ${transaction.category} -> тип: $budgetType, сумма: $amount');
        }
      }

      if (budgetType == null) {
        budgetType = _getCategoryTypeByFallback(transaction.category);
        print(
            '   Fallback: ${transaction.category} -> тип: $budgetType, сумма: $amount');
      }

      switch (budgetType) {
        case 'needs':
          needsTotal += amount;
          break;
        case 'wants':
          wantsTotal += amount;
          break;
        case 'savings':
          savingsTotal += amount;
          break;
        case 'emergency':
          emergencyTotal += amount;
          break;
        default:
          needsTotal += amount;
          break;
      }
    }

    final savingsFromAccounts =
        _calculateSavingsFromAccounts(startDate, endDate);
    savingsTotal += savingsFromAccounts;

    final actualTotal = needsTotal + wantsTotal + savingsTotal + emergencyTotal;
    if (actualTotal == 0)
      return {'needs': 0.0, 'wants': 0.0, 'savings': 0.0, 'emergency': 0.0};

    return {
      'needs': (needsTotal / actualTotal * 100),
      'wants': (wantsTotal / actualTotal * 100),
      'savings': (savingsTotal / actualTotal * 100),
      'emergency': (emergencyTotal / actualTotal * 100),
    };
  }

  Widget _buildMethodCard(
      Map<String, double> method, Map<String, double> actual, double total) {
    final colorScheme = Theme.of(context).colorScheme;
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: true);
    final methodName = settingsProvider.budgetMethod;

    final needsColor = Colors.blue;
    final wantsColor = Colors.orange;
    final savingsColor = Colors.green;
    final emergencyColor = Colors.purple;

    final actualNeeds = actual['needs'] ?? 0.0;
    final actualWants = actual['wants'] ?? 0.0;
    final actualSavings = actual['savings'] ?? 0.0;
    final actualEmergency = actual['emergency'] ?? 0.0;

    final isFourTypeMethod = methodName == '30/30/30/10';

    double actualSavingsCombined = actualSavings + actualEmergency;
    double methodSavingsCombined =
        (method['savings'] ?? 0) + (method['emergency'] ?? 0);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.pie_chart, color: colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Метод учета: $methodName',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.close,
                    size: 18,
                    color: Colors.grey,
                  ),
                  onPressed: () {
                    settingsProvider.toggleShowMethodCard();
                  },
                  tooltip: 'Скрыть карточку',
                ),
              ],
            ),
            const Divider(height: 24),
            _buildMethodRow('Обязательные нужды', method['needs'] ?? 0,
                actualNeeds, needsColor, total),
            const SizedBox(height: 12),
            _buildMethodRow('Желания и развлечения', method['wants'] ?? 0,
                actualWants, wantsColor, total),
            const SizedBox(height: 12),
            if (isFourTypeMethod) ...[
              _buildMethodRow('Сбережения и инвестиции', method['savings'] ?? 0,
                  actualSavings, savingsColor, total),
              const SizedBox(height: 12),
              _buildMethodRow(
                  'Непредвиденные расходы',
                  method['emergency'] ?? 0,
                  actualEmergency,
                  emergencyColor,
                  total),
            ] else ...[
              _buildMethodRow('Сбережения и резерв', methodSavingsCombined,
                  actualSavingsCombined, savingsColor, total),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMethodRow(String title, double planned, double actual,
      Color color, double totalAmount) {
    final difference = actual - planned;
    final isOverBudget = difference > 5;
    final isUnderBudget = difference < -5;

    final actualValue = (actual / 100).clamp(0.0, 1.0);
    final spentAmount = totalAmount * (actual / 100);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            Row(
              children: [
                Text(
                  'План: ${planned.toStringAsFixed(0)}%',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(width: 8),
                Text(
                  'Факт: ${actual.toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: actualValue,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 8,
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (isOverBudget)
              Row(
                children: [
                  Icon(Icons.trending_up, size: 12, color: Colors.red),
                  const SizedBox(width: 4),
                  Text(
                    'Превышение на ${difference.toStringAsFixed(0)}%',
                    style: const TextStyle(fontSize: 10, color: Colors.red),
                  ),
                ],
              )
            else if (isUnderBudget)
              Row(
                children: [
                  Icon(Icons.trending_down, size: 12, color: Colors.green),
                  const SizedBox(width: 4),
                  Text(
                    'Экономия ${(-difference).toStringAsFixed(0)}%',
                    style: const TextStyle(fontSize: 10, color: Colors.green),
                  ),
                ],
              )
            else
              const SizedBox(width: 1),
            Text(
              '${_formatAmount(spentAmount)}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
