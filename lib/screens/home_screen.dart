import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/avatar_provider.dart';
import '../services/avatar_service.dart';
import 'add_transaction_sheet.dart';
import 'edit_transaction_sheet.dart';
import '../services/transaction_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'calendar_screen.dart';
import 'balance_summary_screen.dart';
import 'profile_screen.dart';
import 'reports_screen.dart';
import 'planning_screen.dart';
import '../models/transaction_models.dart';
import '../services/category_service.dart';
import '../services/recurring_service.dart';
import '../services/goal_service.dart';
import '../models/goal.dart';
import 'setup_budget_screen.dart';
import '../providers/notification_provider.dart';
import 'notifications_screen.dart';
import '../utils/snackbar_utils.dart';
import 'dart:math';
import 'package:collection/collection.dart';
import '../services/interest_calculation_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  bool _isHeaderExpanded = false;
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;

  DateTime _selectedMonth = DateTime.now();
  List<Account> _accounts = [];
  List<Account> _mainAccountsToShow = [];
  List<Transaction> _transactions = [];
  List<Transaction> _allTransactions = []; // все транзакции для истории
  List<Goal> _goals = [];
  String? _deletedTransactionId;
  Map<String, Map<int, double>> _historicalBalances = {}; // кэш балансов

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    _loadAllData().then((_) {
      _updateBalancesForSelectedMonth();
    });
    _loadGoals();
    CategoryService.addAccountsListener(_onAccountsChanged);
    CategoryService.addListener(_onTransactionsChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      Provider.of<AvatarProvider>(context, listen: false).loadAvatar();
      await _processRecurringPayments();
      await _checkDepositsClosure();
    });
  }

  // ==================== МЕТОДЫ ДЛЯ КЭШИРОВАНИЯ БАЛАНСОВ ====================

  void _invalidateBalanceCache() {
    _historicalBalances.clear();
    print('🔄 Кэш балансов сброшен');
  }

  double _getBalanceOnDate(Account account, DateTime targetDate) {
    final yearMonth = targetDate.year * 12 + targetDate.month;

    final lastDayOfMonth = DateTime(targetDate.year, targetDate.month + 1, 0);
    final today = DateTime.now();
    final isMonthFinished = lastDayOfMonth.isBefore(today) ||
        (lastDayOfMonth.year == today.year &&
            lastDayOfMonth.month == today.month &&
            today.day > lastDayOfMonth.day);

    if (isMonthFinished &&
        _historicalBalances[account.id]?.containsKey(yearMonth) == true) {
      print(
          '📦 Кэш для ${account.name}: ${_historicalBalances[account.id]![yearMonth]}');
      return _historicalBalances[account.id]![yearMonth]!;
    }

    print(
        '🔄 Расчет баланса для ${account.name} на ${targetDate.day}.${targetDate.month}.${targetDate.year}');

    double balance = account.initialBalance;

    final relevantTransactions = _allTransactions
        .where((t) =>
            (t.accountId == account.id ||
                t.fromAccountId == account.id ||
                t.toAccountId == account.id) &&
            t.date.isBefore(targetDate.add(const Duration(days: 1))))
        .toList();

    final sortedTransactions = List<Transaction>.from(relevantTransactions)
      ..sort((a, b) => a.date.compareTo(b.date));

    for (var t in sortedTransactions) {
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

    if (isMonthFinished) {
      _historicalBalances.putIfAbsent(account.id, () => {});
      _historicalBalances[account.id]![yearMonth] = balance;
      print(
          '💾 Кэширован баланс ${account.name} на ${targetDate.month}.${targetDate.year}: $balance');
    }

    return balance;
  }

  // ==================== ОСНОВНЫЕ МЕТОДЫ ====================

  // В методе _checkDepositsClosure, после закрытия вклада:
  Future<void> _checkDepositsClosure() async {
    final accounts = await CategoryService.loadAccounts();
    final interestService = InterestCalculationService();
    final now = DateTime.now();

    bool needRefresh = false;

    for (var account in accounts) {
      if (account.type == AccountType.deposit) {
        await interestService.checkAndCloseDeposit(account, now);
        needRefresh = true;
      }
    }

    if (needRefresh) {
      // Обновляем списки транзакций и счетов
      await _loadAllTransactions();
      await _loadTransactionsForMonth();
      await _loadAccounts();
      await _updateBalancesForSelectedMonth();
      if (mounted) setState(() {});
    }
  }

  void _onTransactionsChanged() {
    print('🔄 Получено уведомление об изменении транзакций');
    _invalidateBalanceCache();
    _loadAllTransactions();
    _loadTransactionsForMonth();
    _updateBalancesForSelectedMonth();
    setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadAccounts();
  }

  @override
  void dispose() {
    _animationController.dispose();
    CategoryService.removeAccountsListener(_onAccountsChanged);
    CategoryService.removeListener(_onTransactionsChanged);
    super.dispose();
  }

  Future<String> _getAccountName(String accountId) async {
    print('🔍 _getAccountName: ищу счет с id = "$accountId"');

    final accounts = await CategoryService.loadAccounts();
    for (var account in accounts) {
      if (account.id == accountId) {
        print('🔍 _getAccountName: НАШЕЛ в активных! ${account.name}');
        return account.name;
      }
    }

    final prefs = await SharedPreferences.getInstance();
    final closedDepositName = prefs.getString('closed_deposit_name_$accountId');
    if (closedDepositName != null) {
      print(
          '🔍 _getAccountName: НАШЕЛ среди закрытых вкладов! $closedDepositName');
      return closedDepositName;
    }

    for (var t in _allTransactions) {
      if (t.title.contains(accountId)) {
        final match = RegExp(r'"([^"]*)"').firstMatch(t.title);
        if (match != null) {
          print('🔍 _getAccountName: НАШЕЛ в транзакции! ${match.group(1)}');
          return match.group(1)!;
        }
      }
    }

    print('🔍 _getAccountName: НЕ НАШЕЛ счет с id "$accountId"');
    return accountId;
  }

  Future<String> _getClosedDepositName(String accountId) async {
    final prefs = await SharedPreferences.getInstance();
    final savedName = prefs.getString('closed_deposit_name_$accountId');
    return savedName ?? accountId;
  }

  Future<void> _loadAllTransactions() async {
    _allTransactions = await TransactionService.loadTransactions();
    print('📊 Загружено ВСЕХ транзакций: ${_allTransactions.length}');
  }

  Future<void> _loadGoals() async {
    _goals = await GoalService.loadGoals();
    print('🎯 Загружено целей: ${_goals.length}');

    for (var goal in _goals) {
      if (goal.accountId != null && goal.accountId != 'none') {
        final account = _accounts.firstWhere(
          (a) => a.id == goal.accountId,
          orElse: () => null as Account,
        );
        if (goal.currentAmount != account.balance) {
          goal.currentAmount = account.balance;
          await GoalService.saveGoals(_goals);
        }
      }
    }

    if (mounted) setState(() {});
  }

  void _onAccountsChanged() {
    print('🔄 Получено уведомление об изменении счетов');
    _invalidateBalanceCache();
    _loadAccounts();
    setState(() {});
  }

  Future<void> _processRecurringPayments() async {
    try {
      await RecurringService.processRecurringPayments();
      await _loadAllData();
      if (mounted) setState(() {});
    } catch (e) {
      print('❌ Ошибка обработки регулярных платежей: $e');
    }
  }

  Widget _buildGoalsList() {
    print('🎯 _buildGoalsList: целей = ${_goals.length}');
    if (_goals.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 60,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _goals.length,
        itemBuilder: (context, index) {
          final goal = _goals[index];
          final progress = goal.currentAmount / goal.targetAmount;

          return Container(
            width: 200,
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: goal.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: goal.color.withOpacity(0.3)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Icon(goal.icon, color: goal.color, size: 12),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        goal.title,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: goal.color,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      'До: ${_formatDate(goal.targetDate)}',
                      style:
                          TextStyle(fontSize: 8, color: Colors.grey.shade500),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation(goal.color),
                  minHeight: 3,
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_formatAmount(goal.currentAmount)} / ${_formatAmount(goal.targetAmount)}',
                      style: TextStyle(fontSize: 8, color: Colors.white),
                    ),
                    Text(
                      '${(progress * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        color: goal.color,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _loadAccounts() async {
    print('🔍 _loadAccounts НАЧАЛ');
    try {
      final accounts = await CategoryService.loadAccounts();
      final prefs = await SharedPreferences.getInstance();

      // 1. Счета для отображения на главном экране (только активные, не закрытые)
      final shownAccounts =
          accounts.where((a) => prefs.getBool('show_${a.id}') ?? true).toList();

      // 2. ТОЛЬКО основные счета для шапки (активные, не закрытые)
      final List<Account> mainAccountsForHeader = [];
      for (var account in accounts) {
        final isMain = prefs.getBool('main_${account.id}') ?? false;

        // Проверяем, закрыт ли вклад
        final isClosedDeposit = await _isClosedDeposit(account.id);

        // Добавляем в шапку ТОЛЬКО если:
        // - это основной счет
        // - не долг
        // - НЕ закрытый вклад
        if (isMain &&
            account.type != AccountType.debtOwed &&
            account.type != AccountType.debtToPay &&
            !isClosedDeposit) {
          mainAccountsForHeader.add(account);
          print(
              '⭐ Основной счет в шапке: ${account.name} - баланс: ${account.balance}');
        }
      }

      // 3. НЕ добавляем закрытые вклады в шапку!
      // Убираем этот блок - он добавляет виртуальные счета в шапку
      // final allTransactionAccountIds = <String>{};
      // for (var t in _allTransactions) {
      //   if (t.fromAccountId != null) allTransactionAccountIds.add(t.fromAccountId!);
      //   if (t.toAccountId != null) allTransactionAccountIds.add(t.toAccountId!);
      // }
      //
      // for (var accountId in allTransactionAccountIds) {
      //   final exists = mainAccountsForHeader.any((a) => a.id == accountId);
      //   if (!exists) {
      //     final closedName = await _getClosedDepositName(accountId);
      //     if (closedName != accountId) {
      //       final virtualAccount = Account(
      //         id: accountId,
      //         name: closedName,
      //         balance: 0,
      //         initialBalance: 0,
      //         createdDate: DateTime.now(),
      //         currency: '₽',
      //         type: AccountType.deposit,
      //         icon: Icons.account_balance,
      //         color: Colors.grey,
      //         showOnHomeScreen: false,
      //         isMain: false,
      //       );
      //       mainAccountsForHeader.add(virtualAccount);
      //       print('📜 Добавлен закрытый вклад в историю: $closedName');
      //     }
      //   }
      // }

      final mainAccountsToShow = mainAccountsForHeader.take(8).toList();

      setState(() {
        _accounts = shownAccounts;
        _mainAccountsToShow = mainAccountsToShow;
      });
    } catch (e) {
      print('❌ Ошибка загрузки счетов: $e');
    }
  }

  Future<bool> _isClosedDeposit(String accountId) async {
    final prefs = await SharedPreferences.getInstance();
    final closedName = prefs.getString('closed_deposit_name_$accountId');
    return closedName != null;
  }

  // В методе _updateBalancesForSelectedMonth также фильтруем закрытые вклады
  Future<void> _updateBalancesForSelectedMonth() async {
    final lastDayOfMonth =
        DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);
    print(
        '🔍 _updateBalancesForSelectedMonth: lastDayOfMonth = $lastDayOfMonth');

    // Получаем список ID закрытых вкладов
    final prefs = await SharedPreferences.getInstance();
    final Set<String> closedDepositIds = {};
    for (var account in _accounts) {
      if (account.type == AccountType.deposit) {
        final closedName = prefs.getString('closed_deposit_name_${account.id}');
        if (closedName != null) {
          closedDepositIds.add(account.id);
        }
      }
    }

    final List<Account> validMainAccounts = [];
    for (var i = 0; i < _mainAccountsToShow.length; i++) {
      final account = _mainAccountsToShow[i];

      // Пропускаем закрытые вклады
      if (closedDepositIds.contains(account.id)) continue;

      final balanceOnDate = _getBalanceOnDate(account, lastDayOfMonth);
      account.balance = balanceOnDate;
      validMainAccounts.add(account);
    }

    setState(() {
      _mainAccountsToShow = validMainAccounts;
    });
    print(
        '✅ Балансы обновлены для ${_selectedMonth.month}.${_selectedMonth.year}, отображается ${_mainAccountsToShow.length} счетов');
  }

  void _previousMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
    });
    _loadTransactionsForMonth();
    _updateBalancesForSelectedMonth();
  }

  void _nextMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
    });
    _loadTransactionsForMonth();
    _updateBalancesForSelectedMonth();
  }

  Future<void> _loadTransactionsForMonth() async {
    try {
      final filteredTransactions = _allTransactions
          .where((t) =>
              t.date.year == _selectedMonth.year &&
              t.date.month == _selectedMonth.month)
          .toList();

      setState(() {
        _transactions = filteredTransactions;
      });

      print(
          '📊 Загружено ${_transactions.length} транзакций за ${_selectedMonth.month}.${_selectedMonth.year}');
    } catch (e) {
      print('❌ Ошибка загрузки транзакций: $e');
    }
  }

  Future<void> _loadAllData() async {
    await _loadAccounts();
    await _loadAllTransactions();
    await _loadTransactionsForMonth();
    await _updateBalancesForSelectedMonth();
    setState(() {});
  }

  Future<double> _getDebtOwedTotal() async {
    double total = 0;
    final accounts = await CategoryService.loadAccounts();

    for (var account in accounts) {
      if (account.type == AccountType.debtOwed) {
        total += account.balance;
      }
    }
    return total;
  }

  Future<double> _getDebtToPayTotal() async {
    double total = 0;
    final accounts = await CategoryService.loadAccounts();

    for (var account in accounts) {
      if (account.type == AccountType.debtToPay) {
        total += account.balance;
      }
    }
    return total;
  }

  void _showCalendar() {
    Navigator.push(context,
        MaterialPageRoute(builder: (context) => const CalendarScreen()));
  }

  void _showBalanceSummary() {
    Navigator.push(context,
        MaterialPageRoute(builder: (context) => const BalanceSummaryScreen()));
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
              const Text('Выберите месяц',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3, childAspectRatio: 2),
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
                          setState(() => _selectedMonth =
                              DateTime(_selectedMonth.year, month));
                          Navigator.pop(context);
                          _loadTransactionsForMonth();
                          _updateBalancesForSelectedMonth();
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
              TextButton(
                onPressed: () {
                  setState(() => _selectedMonth = DateTime.now());
                  Navigator.pop(context);
                  _loadTransactionsForMonth();
                  _updateBalancesForSelectedMonth();
                },
                child: const Text('Текущий месяц'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _saveTransactions() async {
    await TransactionService.saveTransactions(_allTransactions);
  }

  void _toggleHeader() {
    setState(() {
      _isHeaderExpanded = !_isHeaderExpanded;
      if (_isHeaderExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  void _addTransaction(Transaction transaction) async {
    print('🔍 _addTransaction ВЫЗВАН, id: ${transaction.id}');

    final exists = _allTransactions.any((t) => t.id == transaction.id);
    if (exists) {
      print(
          '⚠️ Транзакция с id ${transaction.id} уже есть в списке, пропускаем');
      return;
    }

    _allTransactions.add(transaction);
    _transactions.add(transaction);

    await _saveTransactions();
    await _loadGoals();
    await _loadAccounts();

    _invalidateBalanceCache();

    await _loadTransactionsForMonth();
    await _updateBalancesForSelectedMonth();

    if (mounted) setState(() {});
  }

  void _updateTransaction(Transaction updatedTransaction) async {
    final index =
        _transactions.indexWhere((t) => t.id == updatedTransaction.id);
    final allIndex =
        _allTransactions.indexWhere((t) => t.id == updatedTransaction.id);

    if (index != -1 && allIndex != -1) {
      _transactions[index] = updatedTransaction;
      _allTransactions[allIndex] = updatedTransaction;
      await _saveTransactions();

      _invalidateBalanceCache();

      await _loadAccounts();
      await _loadGoals();
      await _updateBalancesForSelectedMonth();
      if (mounted) setState(() {});
    }
  }

  void _deleteTransaction(String id) async {
    _deletedTransactionId = id;

    Transaction? transactionToDelete;
    try {
      transactionToDelete = _transactions.firstWhere((t) => t.id == id);
    } catch (e) {
      print('⚠️ Транзакция с id $id не найдена');
      _deletedTransactionId = null;
      return;
    }

    await _revertBalanceForTransaction(transactionToDelete);

    _transactions.removeWhere((t) => t.id == id);
    _allTransactions.removeWhere((t) => t.id == id);
    await _saveTransactions();

    _invalidateBalanceCache();

    await _loadAccounts();
    await _loadGoals();
    await _updateBalancesForSelectedMonth();
    if (mounted) setState(() {});

    _deletedTransactionId = null;

    SnackbarUtils.showWarning(context, 'Транзакция удалена');
  }

  // ==================== МЕТОДЫ ДЛЯ КРЕДИТА ====================

  Future<void> _revertBalanceForTransaction(Transaction transaction) async {
    print(
        '🔄 Откат транзакции: ${transaction.title}, сумма: ${transaction.amount}');

    final accounts = await CategoryService.loadAccounts();

    if (transaction.fromAccountId != null && transaction.toAccountId != null) {
      final toAccount = accounts.firstWhere(
        (a) => a.id == transaction.toAccountId,
        orElse: () => null as Account,
      );

      if (toAccount.type == AccountType.loan) {
        final allTransactions = await TransactionService.loadTransactions();
        final loanPayments = allTransactions
            .where((t) =>
                t.toAccountId == transaction.toAccountId &&
                t.id != transaction.id)
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));

        await _recalculateLoanFromScratch(toAccount, loanPayments);

        final fromIndex =
            accounts.indexWhere((a) => a.id == transaction.fromAccountId);
        if (fromIndex != -1) {
          accounts[fromIndex].balance += transaction.amount;
        }
        await CategoryService.saveAccounts(accounts);
      } else {
        final fromIndex =
            accounts.indexWhere((a) => a.id == transaction.fromAccountId);
        final toIndex =
            accounts.indexWhere((a) => a.id == transaction.toAccountId);

        if (fromIndex != -1 && toIndex != -1) {
          accounts[fromIndex].balance += transaction.amount;
          accounts[toIndex].balance -= transaction.amount;
          await CategoryService.saveAccounts(accounts);
        }
      }
      return;
    }

    if (transaction.accountId != null) {
      final accountIndex =
          accounts.indexWhere((a) => a.id == transaction.accountId);
      if (accountIndex != -1) {
        if (transaction.type == TransactionType.income) {
          accounts[accountIndex].balance -= transaction.amount;
        } else {
          accounts[accountIndex].balance += transaction.amount;
        }
        await CategoryService.saveAccounts(accounts);
      }
    }
  }

  Future<void> _recalculateLoanFromScratch(
      Account loan, List<Transaction> payments) async {
    print('🔄 ПЕРЕСЧЁТ КРЕДИТА С НУЛЯ: ${loan.name}');
    print('   Всего платежей для пересчёта: ${payments.length}');

    final accounts = await CategoryService.loadAccounts();
    final loanIndex = accounts.indexWhere((a) => a.id == loan.id);

    if (loanIndex == -1) {
      print('❌ Кредит не найден');
      return;
    }

    final principal = (loan.principalAmount ?? 0).abs();
    final rate = loan.interestRate ?? 0;
    final isAnnuity = loan.paymentType == 'annuity';
    final totalMonths = loan.loanTermMonths ??
        ((loan.loanTermYears ?? 0) * 12) + ((loan.loanTermDays ?? 0) ~/ 30);

    if (principal == 0 || rate == 0 || totalMonths == 0) {
      print('❌ Некорректные параметры кредита');
      return;
    }

    final monthlyRate = rate / 100 / 12;

    double monthlyPayment = loan.monthlyPayment ?? 0;
    if (isAnnuity && monthlyPayment == 0) {
      if (monthlyRate == 0) {
        monthlyPayment = principal / totalMonths;
      } else {
        final factor = monthlyRate *
            pow(1 + monthlyRate, totalMonths) /
            (pow(1 + monthlyRate, totalMonths) - 1);
        monthlyPayment = principal * factor;
      }
    }

    double remainingPrincipal = principal;
    double totalInterestPaid = 0;
    int monthsPassed = 0;

    for (var payment in payments) {
      if (payment.amount <= 0) continue;

      double interestForMonth = remainingPrincipal * monthlyRate;

      if (isAnnuity) {
        double principalForMonth = monthlyPayment - interestForMonth;
        if (principalForMonth < 0) principalForMonth = 0;
        if (principalForMonth > remainingPrincipal)
          principalForMonth = remainingPrincipal;

        double paymentAmount = payment.amount;

        if (paymentAmount >= monthlyPayment) {
          totalInterestPaid += interestForMonth;
          remainingPrincipal -= principalForMonth;
          paymentAmount -= monthlyPayment;
          monthsPassed++;

          if (paymentAmount > 0) {
            double extraPrincipal = paymentAmount;
            if (extraPrincipal > remainingPrincipal)
              extraPrincipal = remainingPrincipal;
            remainingPrincipal -= extraPrincipal;
            print(
                '   Досрочное погашение: +${extraPrincipal.toStringAsFixed(2)} на основной долг');
          }
        } else {
          final ratio = paymentAmount / monthlyPayment;
          totalInterestPaid += interestForMonth * ratio;
          remainingPrincipal -= principalForMonth * ratio;
        }
      } else {
        final monthlyPrincipalPortion = principal / totalMonths;
        double principalForMonth = monthlyPrincipalPortion;
        if (principalForMonth > remainingPrincipal)
          principalForMonth = remainingPrincipal;

        double expectedPayment = principalForMonth + interestForMonth;
        double paymentAmount = payment.amount;

        if (paymentAmount >= expectedPayment) {
          totalInterestPaid += interestForMonth;
          remainingPrincipal -= principalForMonth;
          paymentAmount -= expectedPayment;
          monthsPassed++;

          if (paymentAmount > 0) {
            double extraPrincipal = paymentAmount;
            if (extraPrincipal > remainingPrincipal)
              extraPrincipal = remainingPrincipal;
            remainingPrincipal -= extraPrincipal;
            print(
                '   Досрочное погашение: +${extraPrincipal.toStringAsFixed(2)} на основной долг');
          }
        } else {
          final ratio = paymentAmount / expectedPayment;
          totalInterestPaid += interestForMonth * ratio;
          remainingPrincipal -= principalForMonth * ratio;
        }
      }

      if (remainingPrincipal < 0) {
        remainingPrincipal = 0;
        break;
      }

      print(
          '   Месяц ${monthsPassed + 1}: платеж ${payment.amount}, остаток долга: ${remainingPrincipal.toStringAsFixed(2)}');
    }

    int remainingMonths = 0;
    double remainingInterest = 0;

    if (remainingPrincipal > 0) {
      if (isAnnuity && monthlyPayment > 0) {
        if (monthlyRate > 0 &&
            monthlyPayment > remainingPrincipal * monthlyRate) {
          final ratio = monthlyPayment /
              (monthlyPayment - remainingPrincipal * monthlyRate);
          remainingMonths = (log(ratio) / log(1 + monthlyRate)).ceil();
        } else {
          remainingMonths = (remainingPrincipal / monthlyPayment).ceil();
        }
        if (remainingMonths < 0) remainingMonths = 0;

        remainingInterest =
            (monthlyPayment * remainingMonths) - remainingPrincipal;
        if (remainingInterest < 0) remainingInterest = 0;
      } else if (!isAnnuity && monthlyRate > 0) {
        final monthlyPrincipalPortion = principal / totalMonths;
        if (monthlyPrincipalPortion > 0) {
          remainingMonths =
              (remainingPrincipal / monthlyPrincipalPortion).ceil();
        }
        remainingInterest =
            (remainingPrincipal * monthlyRate * (remainingMonths + 1)) / 2;
        if (remainingInterest < 0) remainingInterest = 0;
      }
    }

    final totalLoanInterest = totalInterestPaid + remainingInterest;
    final totalDebt = remainingPrincipal + remainingInterest;

    accounts[loanIndex].remainingPrincipal = remainingPrincipal;
    accounts[loanIndex].paidInterest = totalInterestPaid;
    accounts[loanIndex].remainingMonths = remainingMonths;
    accounts[loanIndex].totalLoanInterest = totalLoanInterest;
    accounts[loanIndex].balance = -totalDebt;

    if (isAnnuity) {
      accounts[loanIndex].monthlyPayment = monthlyPayment;
    }

    await CategoryService.saveAccounts(accounts);

    print('💰 КРЕДИТ ПЕРЕСЧИТАН:');
    print(
        '   Остаток основного долга: ${remainingPrincipal.toStringAsFixed(2)}');
    print('   Общий долг: ${totalDebt.toStringAsFixed(2)}');
    print('   Осталось месяцев: $remainingMonths');
  }

  Future<void> _revertAccountBalance(Transaction transaction) async {
    final accounts = await CategoryService.loadAccounts();
    final accountIndex =
        accounts.indexWhere((a) => a.id == transaction.accountId);
    if (accountIndex != -1) {
      if (transaction.type == TransactionType.income) {
        accounts[accountIndex].balance -= transaction.amount;
      } else if (transaction.type == TransactionType.expense) {
        accounts[accountIndex].balance += transaction.amount;
      }
      await CategoryService.saveAccounts(accounts);
    }
  }

  Future<void> _applyAccountBalance(Transaction transaction) async {
    final accounts = await CategoryService.loadAccounts();
    final accountIndex =
        accounts.indexWhere((a) => a.id == transaction.accountId);
    if (accountIndex != -1) {
      if (transaction.type == TransactionType.income) {
        accounts[accountIndex].balance += transaction.amount;
      } else if (transaction.type == TransactionType.expense) {
        accounts[accountIndex].balance -= transaction.amount;
      }
      await CategoryService.saveAccounts(accounts);
    }
  }

  // ==================== UI МЕТОДЫ ====================

  Widget _buildStatCard({
    required String title,
    required double amount,
    required Color color,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    final isZero = amount == 0;
    final displayColor = isZero ? Colors.grey : color;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: displayColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(icon, color: displayColor, size: 14),
                const SizedBox(width: 4),
                Text(title,
                    style: TextStyle(
                        fontSize: 11,
                        color: displayColor,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            _formatAmount(amount),
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.bold, color: displayColor),
          ),
        ],
      ),
    );
  }

  IconData _getTransactionIcon(Transaction t) {
    if (_isLoanPayment(t) || _isDebtToPay(t)) {
      return Icons.arrow_downward;
    }
    if (_isDebtOwed(t)) {
      return Icons.arrow_upward;
    }
    if (t.fromAccountId != null && t.toAccountId != null) {
      return Icons.swap_horiz;
    }
    return t.type == TransactionType.income
        ? Icons.arrow_upward
        : Icons.arrow_downward;
  }

  Color _getTransactionIconColor(Transaction t) {
    if (_isLoanPayment(t) || _isDebtToPay(t)) {
      return Colors.red;
    }
    if (_isDebtOwed(t)) {
      return Colors.green;
    }
    if (t.fromAccountId != null && t.toAccountId != null) {
      return Colors.orange;
    }
    return t.type == TransactionType.income ? Colors.green : Colors.red;
  }

  bool _isLoanPayment(Transaction t) {
    if (t.toAccountId == null) return false;
    final toAccount = _accounts.firstWhereOrNull((a) => a.id == t.toAccountId);
    return toAccount?.type == AccountType.loan;
  }

  bool _isDebtOwed(Transaction t) {
    if (t.fromAccountId == null) return false;
    final fromAccount =
        _accounts.firstWhereOrNull((a) => a.id == t.fromAccountId);
    return fromAccount?.type == AccountType.debtOwed;
  }

  bool _isDebtToPay(Transaction t) {
    if (t.toAccountId == null) return false;
    final toAccount = _accounts.firstWhereOrNull((a) => a.id == t.toAccountId);
    return toAccount?.type == AccountType.debtToPay;
  }

  Map<String, double> _calculateBalances() {
    double totalBalance = 0, totalIncome = 0, totalExpense = 0;
    final filteredTransactions = _transactions
        .where((t) =>
            t.date.year == _selectedMonth.year &&
            t.date.month == _selectedMonth.month)
        .toList();

    for (var t in filteredTransactions) {
      if (t.fromAccountId != null && t.toAccountId != null) {
        continue;
      }

      if (t.type == TransactionType.income) {
        totalBalance += t.amount;
        totalIncome += t.amount;
      } else if (t.type == TransactionType.expense) {
        totalBalance -= t.amount;
        totalExpense += t.amount;
      }
    }
    return {
      'balance': totalBalance,
      'income': totalIncome,
      'expense': totalExpense
    };
  }

  Map<DateTime, List<Transaction>> _groupByDate() {
    Map<DateTime, List<Transaction>> grouped = {};
    final filteredTransactions = _transactions
        .where((t) =>
            t.date.year == _selectedMonth.year &&
            t.date.month == _selectedMonth.month)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    for (var transaction in filteredTransactions) {
      final date = DateTime(
          transaction.date.year, transaction.date.month, transaction.date.day);
      grouped.putIfAbsent(date, () => []).add(transaction);
    }
    return grouped;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    if (date == today) return 'Сегодня';
    if (date == yesterday) return 'Вчера';
    return DateFormat('dd.MM.yyyy').format(date);
  }

  String _formatAmount(double amount) {
    return '${NumberFormat('#,##0.00', 'ru_RU').format(amount)} ₽';
  }

  double _sumByType(List<Transaction> transactions, TransactionType type) {
    return transactions
        .where((t) => t.type == type)
        .fold(0, (sum, t) => sum + t.amount);
  }

  void _showAddTransactionDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          AddTransactionSheet(onTransactionAdded: _addTransaction),
    );
  }

  void _showEditTransactionDialog(Transaction transaction) {
    if (transaction.toAccountId != null) {
      final toAccount =
          _accounts.firstWhereOrNull((a) => a.id == transaction.toAccountId);
      if (toAccount?.type == AccountType.loan) {
        SnackbarUtils.showInfo(
            context, 'Платежи по кредиту нельзя редактировать');
        return;
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EditTransactionSheet(
        transaction: transaction,
        onTransactionUpdated: _updateTransaction,
        onTransactionDeleted: _deleteTransaction,
      ),
    );
  }

  Future<void> _deleteZeroDebts() async {
    final accounts = await CategoryService.loadAccounts();
    bool needSave = false;

    for (var account in accounts) {
      if ((account.type == AccountType.debtOwed ||
              account.type == AccountType.debtToPay) &&
          account.balance <= 0) {
        accounts.remove(account);
        needSave = true;
      }
    }

    if (needSave) {
      await CategoryService.saveAccounts(accounts);
      CategoryService.notifyAccountsListeners();
      _loadAccounts();
    }
  }

  @override
  Widget build(BuildContext context) {
    final balances = _calculateBalances();
    final groupedTransactions = _groupByDate();
    final colorScheme = Theme.of(context).colorScheme;
    final iconColor = Theme.of(context).brightness == Brightness.light
        ? Colors.grey.shade700
        : Colors.grey.shade400;
    final textColor = Theme.of(context).brightness == Brightness.light
        ? Colors.grey.shade800
        : Colors.grey.shade300;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Личные финансы',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: textColor,
          ),
        ),
        leading: Consumer<NotificationProvider>(
          builder: (context, notificationProvider, child) {
            return Stack(
              children: [
                IconButton(
                  icon: Icon(Icons.notifications_none,
                      size: 22, color: iconColor),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const NotificationsScreen()),
                    );
                  },
                  tooltip: 'Уведомления',
                ),
                if (notificationProvider.unreadCount > 0)
                  Positioned(
                    right: 4,
                    top: 4,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        '${notificationProvider.unreadCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.pie_chart, size: 22, color: iconColor),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) =>
                        const SetupBudgetScreen(isFromRegistration: false)),
              );
            },
            tooltip: 'Бюджет',
          ),
          IconButton(
            icon: Icon(Icons.calendar_month, size: 22, color: iconColor),
            onPressed: _showCalendar,
            tooltip: 'Календарь',
          ),
        ],
      ),
      body: Column(
        children: [
          GestureDetector(
            onTap: _showBalanceSummary,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colorScheme.primary.withOpacity(0.15),
                    colorScheme.secondary.withOpacity(0.1)
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(Icons.chevron_left,
                                  color: colorScheme.primary, size: 20),
                              onPressed: _previousMonth,
                              constraints: const BoxConstraints(
                                  minWidth: 32, minHeight: 32),
                              padding: EdgeInsets.zero,
                            ),
                            GestureDetector(
                              onTap: _showMonthPicker,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: colorScheme.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      DateFormat('MMMM yyyy', 'ru_RU')
                                          .format(_selectedMonth),
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: colorScheme.primary),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(Icons.arrow_drop_down,
                                        size: 16, color: colorScheme.primary),
                                  ],
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.chevron_right,
                                  color: colorScheme.primary, size: 20),
                              onPressed: _nextMonth,
                              constraints: const BoxConstraints(
                                  minWidth: 32, minHeight: 32),
                              padding: EdgeInsets.zero,
                            ),
                          ],
                        ),
                        IconButton(
                          icon: Icon(Icons.settings,
                              size: 18, color: colorScheme.primary),
                          onPressed: () async {
                            final result = await Navigator.pushNamed(
                                context, '/home_settings');
                            if (result == true) {
                              _invalidateBalanceCache();
                              await _loadAccounts();
                              setState(() {});
                            }
                          },
                          constraints:
                              const BoxConstraints(minWidth: 32, minHeight: 32),
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ),
                  if (_mainAccountsToShow.length == 1)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        _formatAmount(_mainAccountsToShow.first.balance),
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: _mainAccountsToShow.first.balance >= 0
                              ? Colors.green
                              : Colors.red,
                        ),
                      ),
                    )
                  else if (_mainAccountsToShow.length <= 4)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      child: Column(
                        children: _mainAccountsToShow
                            .map((account) => Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: account.color.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: account.color.withOpacity(0.3)),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            width: 32,
                                            height: 32,
                                            decoration: BoxDecoration(
                                              color: account.color
                                                  .withOpacity(0.2),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(account.icon,
                                                color: account.color, size: 18),
                                          ),
                                          const SizedBox(width: 10),
                                          Text(
                                            account.name,
                                            style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                                color: account.color),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                      Text(
                                        _formatAmount(account.balance),
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: account.balance >= 0
                                              ? Colors.green
                                              : Colors.red,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ))
                            .toList(),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 2.6,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: _mainAccountsToShow.length,
                        itemBuilder: (context, index) {
                          final account = _mainAccountsToShow[index];
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 6),
                            decoration: BoxDecoration(
                              color: account.color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: account.color.withOpacity(0.3)),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color: account.color.withOpacity(0.2),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(account.icon,
                                          color: account.color, size: 14),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        account.name,
                                        style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                            color: account.color),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _formatAmount(account.balance),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: account.balance >= 0
                                        ? Colors.green
                                        : Colors.red,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.keyboard_arrow_down,
                                size: 16, color: colorScheme.primary),
                            Text(_isHeaderExpanded ? 'Свернуть' : 'Развернуть',
                                style: TextStyle(
                                    fontSize: 11, color: colorScheme.primary)),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildStatCard(
                              title: 'Доход',
                              amount: balances['income']!,
                              color: Colors.green,
                              icon: Icons.trending_up,
                              onTap: null,
                            ),
                            _buildStatCard(
                              title: 'Расход',
                              amount: balances['expense']!,
                              color: Colors.red,
                              icon: Icons.trending_down,
                              onTap: null,
                            ),
                            FutureBuilder<double>(
                              future: _getDebtOwedTotal(),
                              builder: (context, snapshot) {
                                final amount = snapshot.data ?? 0;
                                return _buildStatCard(
                                  title: 'Долг мне',
                                  amount: amount,
                                  color: Colors.amber,
                                  icon: Icons.assignment_return,
                                  onTap: null,
                                );
                              },
                            ),
                            FutureBuilder<double>(
                              future: _getDebtToPayTotal(),
                              builder: (context, snapshot) {
                                final amount = snapshot.data ?? 0;
                                return _buildStatCard(
                                  title: 'Должен я',
                                  amount: amount,
                                  color: Colors.deepOrange,
                                  icon: Icons.assignment_late,
                                  onTap: null,
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizeTransition(
                    sizeFactor: _expandAnimation,
                    axisAlignment: -1.0,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          const Divider(),
                          const SizedBox(height: 8),
                          Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Доход:'),
                                Text(_formatAmount(balances['income']!),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Colors.green)),
                              ]),
                          const SizedBox(height: 4),
                          Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Расход:'),
                                Text(_formatAmount(balances['expense']!),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Colors.red)),
                              ]),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Итоговый баланс:',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500)),
                                Text(_formatAmount(balances['balance']!),
                                    style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: colorScheme.primary)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_goals.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildGoalsList(),
          ],
          const SizedBox(height: 8),
          Expanded(
            child: groupedTransactions.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long,
                            size: 60,
                            color: colorScheme.primary.withOpacity(0.3)),
                        const SizedBox(height: 12),
                        Text(
                          'Нет транзакций за ${DateFormat('MMMM yyyy', 'ru_RU').format(_selectedMonth)}',
                          style: TextStyle(
                              fontSize: 16,
                              color: colorScheme.onSurface.withOpacity(0.5)),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: () => _showAddTransactionDialog(context),
                          icon: const Icon(Icons.add),
                          label: const Text('Добавить транзакцию'),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: colorScheme.primary),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(
                        top: 8, left: 16, right: 16, bottom: 100),
                    itemCount: groupedTransactions.length,
                    itemBuilder: (context, index) {
                      final date = groupedTransactions.keys.elementAt(index);
                      final dayTransactions = groupedTransactions[date]!;
                      final dayIncome =
                          _sumByType(dayTransactions, TransactionType.income);
                      final dayExpense =
                          _sumByType(dayTransactions, TransactionType.expense);
                      return Column(
                        children: [
                          Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Text(_formatDate(date),
                                    style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: colorScheme.primary)),
                                const Spacer(),
                                if (dayIncome > 0)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: Text('+${_formatAmount(dayIncome)}',
                                        style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontWeight: FontWeight.w400,
                                            fontSize: 13)),
                                  ),
                                if (dayExpense > 0)
                                  Text('-${_formatAmount(dayExpense)}',
                                      style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontWeight: FontWeight.w400,
                                          fontSize: 13)),
                              ],
                            ),
                          ),
                          Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              height: 1,
                              color: colorScheme.primary.withOpacity(0.3)),
                          ...dayTransactions.map((t) {
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              elevation: 2,
                              child: InkWell(
                                onTap: () => _showEditTransactionDialog(t),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: _getTransactionIconColor(t)
                                              .withOpacity(0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          _getTransactionIcon(t),
                                          color: _getTransactionIconColor(t),
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            if (t.fromAccountId != null &&
                                                t.toAccountId != null)
                                              FutureBuilder<String>(
                                                future: _getAccountName(
                                                    t.fromAccountId!),
                                                builder:
                                                    (context, fromSnapshot) {
                                                  return FutureBuilder<String>(
                                                    future: _getAccountName(
                                                        t.toAccountId!),
                                                    builder:
                                                        (context, toSnapshot) {
                                                      final fromName =
                                                          fromSnapshot.data ??
                                                              '...';
                                                      final toName =
                                                          toSnapshot.data ??
                                                              '...';
                                                      return Text(
                                                        '$fromName → $toName',
                                                        style: const TextStyle(
                                                            fontSize: 16,
                                                            fontWeight:
                                                                FontWeight
                                                                    .bold),
                                                      );
                                                    },
                                                  );
                                                },
                                              )
                                            else
                                              Text(
                                                t.category +
                                                    (t.subCategory != null
                                                        ? ' → ${t.subCategory}'
                                                        : ''),
                                                style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight:
                                                        FontWeight.bold),
                                              ),
                                            if (t.comment != null &&
                                                t.comment!.isNotEmpty)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                    top: 4),
                                                child: Text(t.comment!,
                                                    style: TextStyle(
                                                        fontSize: 14,
                                                        color: Colors
                                                            .grey.shade700)),
                                              ),
                                            if (t.isRecurring)
                                              Text('🔄 Регулярный',
                                                  style: TextStyle(
                                                      fontSize: 10,
                                                      color: Colors
                                                          .blue.shade700)),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          if (t.category == 'Долг мне')
                                            Text(
                                              '+${_formatAmount(t.amount)}',
                                              style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.green),
                                            )
                                          else if (t.category == 'Должен я')
                                            Text(
                                              '-${_formatAmount(t.amount)}',
                                              style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.red),
                                            )
                                          else if (t.category == 'Перевод' &&
                                              t.fromAccountId != null &&
                                              t.toAccountId != null)
                                            Text(
                                              _formatAmount(t.amount),
                                              style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.orange),
                                            )
                                          else
                                            Text(
                                              '${t.type == TransactionType.income ? '+' : '-'}${_formatAmount(t.amount)}',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                                color: t.type ==
                                                        TransactionType.income
                                                    ? Colors.green
                                                    : Colors.red,
                                              ),
                                            ),
                                          const SizedBox(height: 4),
                                          if (!(t.toAccountId != null &&
                                              _accounts.any((a) =>
                                                  a.id == t.toAccountId &&
                                                  a.type == AccountType.loan)))
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                IconButton(
                                                  icon: Icon(Icons.edit,
                                                      size: 18,
                                                      color:
                                                          Colors.grey.shade600),
                                                  onPressed: () =>
                                                      _showEditTransactionDialog(
                                                          t),
                                                  padding: EdgeInsets.zero,
                                                  constraints:
                                                      const BoxConstraints(),
                                                ),
                                                const SizedBox(width: 8),
                                                IconButton(
                                                  icon: Icon(Icons.delete,
                                                      size: 18,
                                                      color:
                                                          Colors.red.shade300),
                                                  onPressed: () {
                                                    showDialog(
                                                      context: context,
                                                      builder: (context) =>
                                                          AlertDialog(
                                                        title: const Text(
                                                            'Удалить транзакцию'),
                                                        content: const Text(
                                                            'Вы уверены?'),
                                                        actions: [
                                                          TextButton(
                                                            onPressed: () =>
                                                                Navigator.pop(
                                                                    context),
                                                            child: const Text(
                                                                'Отмена'),
                                                          ),
                                                          TextButton(
                                                            onPressed: () {
                                                              _deleteTransaction(
                                                                  t.id);
                                                              Navigator.pop(
                                                                  context);
                                                            },
                                                            style: TextButton
                                                                .styleFrom(
                                                                    foregroundColor:
                                                                        Colors
                                                                            .red),
                                                            child: const Text(
                                                                'Удалить'),
                                                          ),
                                                        ],
                                                      ),
                                                    );
                                                  },
                                                  padding: EdgeInsets.zero,
                                                  constraints:
                                                      const BoxConstraints(),
                                                ),
                                              ],
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                          const SizedBox(height: 12),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Theme.of(context).brightness == Brightness.light
            ? Colors.white
            : Colors.grey.shade900,
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: iconColor,
        currentIndex: 0,
        onTap: (index) {
          if (index == 0) return;
          if (index == 1) {
            Navigator.push(context,
                MaterialPageRoute(builder: (context) => const ReportsScreen()));
          } else if (index == 2) {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const PlanningScreen()));
          } else if (index == 3) {
            Navigator.pushNamed(context, '/profile');
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Главная'),
          BottomNavigationBarItem(icon: Icon(Icons.pie_chart), label: 'Отчеты'),
          BottomNavigationBarItem(
              icon: Icon(Icons.calendar_month), label: 'Планирование'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Профиль'),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddTransactionDialog(context),
        backgroundColor: colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}
