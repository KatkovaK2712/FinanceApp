import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/category_service.dart';
import '../models/models.dart';
import '../utils/amount_formatter.dart';
import '../utils/snackbar_utils.dart';
import 'dart:math';
import 'package:intl/intl.dart';

const List<Color> availableColors = [
  Colors.red,
  Colors.pink,
  Colors.purple,
  Colors.deepPurple,
  Colors.indigo,
  Colors.blue,
  Colors.lightBlue,
  Colors.cyan,
  Colors.teal,
  Colors.green,
  Colors.lightGreen,
  Colors.lime,
  Colors.yellow,
  Colors.amber,
  Colors.orange,
  Colors.deepOrange,
  Colors.brown,
  Colors.grey,
  Colors.blueGrey,
];

class AddAccountSheet extends StatefulWidget {
  final Function(Account) onAccountAdded;
  final Account? accountToEdit;

  const AddAccountSheet({
    super.key,
    required this.onAccountAdded,
    this.accountToEdit,
  });

  @override
  State<AddAccountSheet> createState() => _AddAccountSheetState();
}

class _AddAccountSheetState extends State<AddAccountSheet> {
  final _nameController = TextEditingController();
  final _balanceController = TextEditingController();

  late AccountType _selectedType;
  late IconData _selectedIcon;
  late Color _selectedColor;

  bool _showOnHomeScreen = true;
  bool _isMainAccount = false;
  String? _validationError;

  // ========== ОБЩИЕ КОНТРОЛЛЕРЫ ==========
  final _rateController = TextEditingController();
  String? _selectedInterestAccountId;
  List<Account> _accounts = [];

  // ========== ДЛЯ ВКЛАДА (deposit) ==========
  bool _isCapitalization = false;
  String _selectedCapitalizationFrequency = 'month';
  final _termMonthsController = TextEditingController();
  String? _selectedClosureAccountId;
  bool _allowDeposit = true;
  bool _allowWithdraw = true;
  final _termController = TextEditingController();
  final _paymentDayController = TextEditingController();
  bool _hasWithdrawal = false;

  // ========== ДЛЯ НАКОПИТЕЛЬНОГО СЧЕТА (savings) ==========
  String _selectedInterestPeriod = 'month';
  String _selectedCalculationType = 'actual';
  String _selectedCalculationDate = 'last';

  // ========== ДЛЯ КРЕДИТА (loan) ==========
  bool _isAnnuity = true;
  final _loanAmountController = TextEditingController();
  final _loanTermYearsController = TextEditingController();
  final _loanTermMonthsController = TextEditingController();
  final _loanTermDaysController = TextEditingController();
  final _monthlyPaymentController = TextEditingController();
  int _selectedPaymentDay = 1;

  // ========== ДЛЯ ДОЛГОВ ==========
  final _debtorNameController = TextEditingController();
  final _repaymentDateController = TextEditingController();

  // ========== СТАРЫЕ КОНТРОЛЛЕРЫ ==========
  final _limitController = TextEditingController();
  final _statementDateController = TextEditingController();
  final _gracePeriodController = TextEditingController();
  final _minPaymentController = TextEditingController();
  final _commissionController = TextEditingController();

  // ========== НОВЫЕ КОНТРОЛЛЕРЫ ДЛЯ ВКЛАДА ==========
  final _depositStartDateController = TextEditingController();
  final _depositTermYearsController = TextEditingController();
  final _depositTermMonthsController = TextEditingController();
  final _depositTermDaysController = TextEditingController();

  Future<Color> _getAvailableColorForAccountType(AccountType type) async {
    final existingAccounts = await CategoryService.loadAccounts();
    return _getDefaultColorForType(type, existingAccounts);
  }

  @override
  void initState() {
    super.initState();
    _loadAccounts();

    if (widget.accountToEdit != null) {
      _loadExistingAccount();
    } else {
      _selectedType = AccountType.cash;
      _selectedIcon = _selectedType.defaultIcon;
      _selectedColor = Colors.green;
      _showOnHomeScreen = true;
      _isMainAccount = false;
      _getAvailableColorForAccountType(_selectedType).then((color) {
        if (mounted) setState(() => _selectedColor = color);
      });
    }
    CategoryService.addAccountsListener(_onAccountsChanged);
  }

  void _loadExistingAccount() {
    final a = widget.accountToEdit!;
    _nameController.text = a.name;
    _balanceController.text = AmountFormatter.formatNumber(a.balance);
    _selectedType = a.type;
    _selectedIcon = a.icon;
    _selectedColor = a.color;
    _showOnHomeScreen = a.showOnHomeScreen;
    _isMainAccount = a.isMain;

    _selectedInterestAccountId = a.interestAccountId;
    if (a.interestRate != null)
      _rateController.text = a.interestRate.toString();
    if (a.interestPeriod != null) _selectedInterestPeriod = a.interestPeriod!;
    if (a.interestCalculationType != null)
      _selectedCalculationType = a.interestCalculationType!;
    if (a.capitalizationFrequency != null)
      _selectedCapitalizationFrequency = a.capitalizationFrequency!;
    if (a.termMonths != null)
      _termMonthsController.text = a.termMonths.toString();
    _selectedClosureAccountId = a.closureAccountId;
    if (a.allowDeposit != null) _allowDeposit = a.allowDeposit!;
    if (a.allowWithdraw != null) _allowWithdraw = a.allowWithdraw!;
    if (a.loanTermDays != null)
      _loanTermDaysController.text = a.loanTermDays.toString();
    if (a.isCapitalized != null) _isCapitalization = a.isCapitalized!;
    if (a.interestPaymentDate != null) {
      _paymentDayController.text =
          '${a.interestPaymentDate!.day}.${a.interestPaymentDate!.month}';
      final day = a.interestPaymentDate!.day;
      final lastDay = DateTime(
        a.interestPaymentDate!.year,
        a.interestPaymentDate!.month + 1,
        0,
      ).day;
      _selectedCalculationDate = (day == lastDay) ? 'last' : 'first';
    }
    if (a.principalAmount != null)
      _loanAmountController.text = a.principalAmount.toString();
    if (a.loanTermYears != null)
      _loanTermYearsController.text = a.loanTermYears.toString();
    if (a.loanTermMonths != null)
      _loanTermMonthsController.text = a.loanTermMonths.toString();
    if (a.depositStartDate != null) {
      final day = a.depositStartDate!.day.toString().padLeft(2, '0');
      final month = a.depositStartDate!.month.toString().padLeft(2, '0');
      _depositStartDateController.text =
          '$day.$month.${a.depositStartDate!.year}';
    }
    if (a.depositStartDate != null) {
      _depositStartDateController.text =
          '${a.depositStartDate!.day}.${a.depositStartDate!.month}.${a.depositStartDate!.year}';
    }
    if (a.depositTermYears != null)
      _depositTermYearsController.text = a.depositTermYears.toString();
    if (a.depositTermMonths != null)
      _depositTermMonthsController.text = a.depositTermMonths.toString();
    if (a.depositTermDays != null)
      _depositTermDaysController.text = a.depositTermDays.toString();
  }

  Future<void> _loadAccounts() async {
    _accounts = await CategoryService.loadAccounts();
    setState(() {});
  }

  void _onAccountsChanged() {
    _loadAccounts();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    CategoryService.removeAccountsListener(_onAccountsChanged);
    _nameController.dispose();
    _balanceController.dispose();
    _rateController.dispose();
    _termMonthsController.dispose();
    _termController.dispose();
    _paymentDayController.dispose();
    _loanAmountController.dispose();
    _loanTermYearsController.dispose();
    _loanTermMonthsController.dispose();
    _loanTermDaysController.dispose();
    _monthlyPaymentController.dispose();
    _debtorNameController.dispose();
    _repaymentDateController.dispose();
    _limitController.dispose();
    _statementDateController.dispose();
    _gracePeriodController.dispose();
    _minPaymentController.dispose();
    _commissionController.dispose();
    _depositStartDateController.dispose();
    _depositTermYearsController.dispose();
    _depositTermMonthsController.dispose();
    _depositTermDaysController.dispose();
    _repaymentDateController.dispose();
    super.dispose();
  }

  // ========== РАСЧЕТ КРЕДИТА ==========
  double? _calculateMonthlyPayment() {
    final principal = double.tryParse(
      _loanAmountController.text.replaceAll(RegExp(r'[^\d.]'), ''),
    );
    final rate = double.tryParse(_rateController.text);

    if (principal == null || rate == null || principal <= 0 || rate <= 0)
      return null;

    int? months;
    if (_loanTermYearsController.text.isNotEmpty) {
      months = (int.tryParse(_loanTermYearsController.text) ?? 0) * 12;
    } else if (_loanTermMonthsController.text.isNotEmpty) {
      months = int.tryParse(_loanTermMonthsController.text);
    } else if (_loanTermDaysController.text.isNotEmpty) {
      final days = int.tryParse(_loanTermDaysController.text) ?? 0;
      months = days ~/ 30;
    }

    if (months == null || months <= 0) return null;

    final monthlyRate = rate / 100 / 12;

    double result;
    if (_isAnnuity) {
      if (monthlyRate == 0) {
        result = principal / months;
      } else {
        final factor =
            monthlyRate *
            pow(1 + monthlyRate, months) /
            (pow(1 + monthlyRate, months) - 1);
        result = principal * factor;
      }
    } else {
      final principalPortion = principal / months;
      final interestPortion = principal * monthlyRate;
      result = principalPortion + interestPortion;
    }

    // ✅ ОКРУГЛЯЕМ ДО ЦЕЛЫХ
    return result.roundToDouble();
  }

  String _formatCurrency(double value) {
    return '${NumberFormat('#,##0', 'ru_RU').format(value.round())} ₽';
  }

  String? _validateRequiredFields() {
    if (_selectedType == AccountType.deposit) {
      if (_rateController.text.isEmpty) {
        return 'Введите процентную ставку';
      }
      if (_depositStartDateController.text.isEmpty) {
        return 'Введите дату открытия вклада';
      }
      if (_depositTermYearsController.text.isEmpty &&
          _depositTermMonthsController.text.isEmpty &&
          _depositTermDaysController.text.isEmpty) {
        return 'Введите срок вклада';
      }
      if (_selectedClosureAccountId == null) {
        return 'Выберите счет при закрытии вклада';
      }
    }

    if (_selectedType == AccountType.savings) {
      if (_rateController.text.isEmpty) {
        return 'Введите процентную ставку';
      }
      if (_selectedInterestAccountId == null) {
        return 'Выберите счет для начисления процентов';
      }
      if (_selectedInterestPeriod == 'month' &&
          _selectedCalculationDate == null) {
        return 'Выберите дату расчетного периода';
      }
    }

    if (_selectedType == AccountType.loan) {
      if (_rateController.text.isEmpty) {
        return 'Введите процентную ставку';
      }
      if (_loanAmountController.text.isEmpty) {
        return 'Введите сумму основного долга';
      }
      final hasTerm =
          _loanTermYearsController.text.isNotEmpty ||
          _loanTermMonthsController.text.isNotEmpty ||
          _loanTermDaysController.text.isNotEmpty;
      if (!hasTerm) {
        return 'Введите срок кредита';
      }
    }
    return null;
  }

  Color _getDefaultColorForType(
    AccountType type,
    List<Account> existingAccounts,
  ) {
    final List<Color> allColorOptions = [
      Colors.red,
      Colors.redAccent,
      Colors.deepOrange,
      Colors.orange,
      Colors.amber,
      Colors.yellow,
      Colors.lime,
      Colors.lightGreen,
      Colors.green,
      Colors.teal,
      Colors.cyan,
      Colors.lightBlue,
      Colors.blue,
      Colors.indigo,
      Colors.deepPurple,
      Colors.purple,
      Colors.pink,
      Colors.pinkAccent,
      Colors.brown,
      Colors.grey,
      Colors.blueGrey,
    ];

    final Map<AccountType, List<Color>> preferredColors = {
      AccountType.cash: [Colors.green, Colors.lightGreen, Colors.teal],
      AccountType.debitCard: [Colors.blue, Colors.lightBlue, Colors.cyan],
      AccountType.creditCard: [Colors.red, Colors.deepOrange, Colors.orange],
      AccountType.deposit: [Colors.purple, Colors.deepPurple],
      AccountType.savings: [Colors.teal, Colors.cyan],
      AccountType.loan: [Colors.deepOrange, Colors.brown],
      AccountType.investment: [Colors.lightGreen, Colors.green],
      AccountType.debtOwed: [Colors.amber, Colors.yellow],
      AccountType.debtToPay: [Colors.brown, Colors.orange],
      AccountType.other: [Colors.grey, Colors.blueGrey],
    };

    final Set<Color> usedColors = existingAccounts.map((a) => a.color).toSet();
    final preferred = preferredColors[type] ?? allColorOptions;

    for (var color in preferred) {
      if (!usedColors.contains(color)) return color;
    }
    for (var color in allColorOptions) {
      if (!usedColors.contains(color)) return color;
    }
    return preferred.first;
  }

  DateTime? _parseDate(String dateString) {
    if (dateString.isEmpty) return null;
    try {
      final parts = dateString.split('.');
      if (parts.length == 3) {
        final day = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final year = int.parse(parts[2]);
        return DateTime(year, month, day);
      }
    } catch (e) {
      print('Ошибка парсинга даты: $e');
    }
    return null;
  }

  void _saveAccount() async {
    // Проверяем название счета
    if (_nameController.text.isEmpty) {
      setState(() {
        _validationError = 'Введите название счета';
      });
      return;
    }

    // Проверяем обязательные поля
    final error = _validateRequiredFields();
    if (error != null) {
      setState(() {
        _validationError = error;
      });
      return;
    }

    // Если всё заполнено — сбрасываем ошибку
    setState(() {
      _validationError = null;
    });

    // ========== ПАРСИНГ ДАТЫ ОТКРЫТИЯ ВКЛАДА (переменные на уровень выше) ==========
    DateTime? depositStartDate;
    int? depositTermYears;
    int? depositTermMonths;
    int? depositTermDays;
    DateTime? depositEndDate;

    if (_selectedType == AccountType.deposit) {
      final startDateParts = _depositStartDateController.text.split('.');
      if (startDateParts.length == 3) {
        final day = int.tryParse(startDateParts[0]);
        final month = int.tryParse(startDateParts[1]);
        final year = int.tryParse(startDateParts[2]);
        if (day != null && month != null && year != null) {
          depositStartDate = DateTime(year, month, day);
        }
      }

      depositTermYears = _depositTermYearsController.text.isNotEmpty
          ? int.tryParse(_depositTermYearsController.text)
          : null;
      depositTermMonths = _depositTermMonthsController.text.isNotEmpty
          ? int.tryParse(_depositTermMonthsController.text)
          : null;
      depositTermDays = _depositTermDaysController.text.isNotEmpty
          ? int.tryParse(_depositTermDaysController.text)
          : null;

      if (depositStartDate != null) {
        int years = depositTermYears ?? 0;
        int months = depositTermMonths ?? 0;
        int days = depositTermDays ?? 0;
        depositEndDate = DateTime(
          depositStartDate.year + years,
          depositStartDate.month + months,
          depositStartDate.day + days,
        );
        print('📅 depositEndDate = $depositEndDate');
      }
    }

    // ========== РАСЧЕТ ДЛЯ КРЕДИТА ==========
    double balance = 0;
    double? principalAmount;
    double? remainingPrincipal;
    double? calculatedMonthlyPayment;
    double? totalInterest;
    int? remainingMonths; // ← ✅ ОБЪЯВЛЯЕМ ПЕРЕМЕННУЮ

    if (_selectedType == AccountType.loan) {
      final principal = double.tryParse(
        _loanAmountController.text.replaceAll(RegExp(r'[^\d.]'), ''),
      );
      final rate = double.tryParse(_rateController.text);

      if (principal == null || rate == null || principal <= 0 || rate <= 0) {
        SnackbarUtils.showError(
          context,
          'Введите корректные данные для кредита',
        );
        return;
      }

      // Расчет срока в месяцах
      int? months;
      if (_loanTermYearsController.text.isNotEmpty) {
        months = (int.tryParse(_loanTermYearsController.text) ?? 0) * 12;
      } else if (_loanTermMonthsController.text.isNotEmpty) {
        months = int.tryParse(_loanTermMonthsController.text);
      } else if (_loanTermDaysController.text.isNotEmpty) {
        final days = int.tryParse(_loanTermDaysController.text) ?? 0;
        months = days ~/ 30;
      }

      if (months == null || months <= 0) {
        SnackbarUtils.showError(context, 'Введите срок кредита');
        return;
      }

      // ✅ СОХРАНЯЕМ ОСТАВШИЙСЯ СРОК (изначально равен общему сроку)
      remainingMonths = months;

      final monthlyRate = rate / 100 / 12;

      // Расчет ежемесячного платежа
      if (_isAnnuity) {
        if (monthlyRate == 0) {
          calculatedMonthlyPayment = principal / months;
        } else {
          final factor =
              monthlyRate *
              pow(1 + monthlyRate, months) /
              (pow(1 + monthlyRate, months) - 1);
          calculatedMonthlyPayment = principal * factor;
        }
      } else {
        final principalPortion = principal / months;
        final interestPortion = principal * monthlyRate;
        calculatedMonthlyPayment = principalPortion + interestPortion;
      }

      // ✅ ОКРУГЛЯЕМ ЕЖЕМЕСЯЧНЫЙ ПЛАТЁЖ ДО ЦЕЛЫХ РУБЛЕЙ
      calculatedMonthlyPayment = calculatedMonthlyPayment.roundToDouble();

      // Расчет общей суммы процентов за весь срок
      totalInterest = (calculatedMonthlyPayment * months) - principal;
      totalInterest = totalInterest.roundToDouble();

      balance = -(principal + totalInterest);
      principalAmount = principal;
      remainingPrincipal = principal;

      print(
        '📊 Кредит: основной долг = $principal, проценты = $totalInterest, ежемесячный платёж = $calculatedMonthlyPayment, баланс = $balance, срок = $months мес',
      );
    } else {
      String balanceRaw = _balanceController.text
          .replaceAll(' ', '')
          .replaceAll(',', '.');
      balance = double.tryParse(balanceRaw) ?? 0;
    }

    // ========== РАСЧЕТ ДАТЫ ДЛЯ НАКОПИТЕЛЬНОГО СЧЕТА ==========
    DateTime? paymentDate;
    if (_selectedType == AccountType.savings &&
        _selectedInterestPeriod == 'month') {
      final now = DateTime.now();
      if (_selectedCalculationDate == 'last') {
        paymentDate = DateTime(now.year, now.month + 1, 0);
      } else {
        paymentDate = DateTime(now.year, now.month, 1);
      }
    }

    // ========== СТАРЫЕ ПОЛЯ ==========
    DateTime? billingDate;
    if (_statementDateController.text.isNotEmpty) {
      try {
        final parts = _statementDateController.text.split('.');
        if (parts.length == 2) {
          billingDate = DateTime(
            2000,
            int.parse(parts[1]),
            int.parse(parts[0]),
          );
        }
      } catch (e) {
        print('Ошибка парсинга даты: $e');
      }
    }

    int? loanTermYears = _loanTermYearsController.text.isNotEmpty
        ? int.tryParse(_loanTermYearsController.text)
        : null;
    int? loanTermMonths = _loanTermMonthsController.text.isNotEmpty
        ? int.tryParse(_loanTermMonthsController.text)
        : null;
    int? loanTermDays = _loanTermDaysController.text.isNotEmpty
        ? int.tryParse(_loanTermDaysController.text)
        : null;

    int? termMonthsValue;
    if (_termMonthsController.text.isNotEmpty) {
      termMonthsValue = int.tryParse(_termMonthsController.text);
    }

    final accountId =
        widget.accountToEdit?.id ??
        'acc_${DateTime.now().millisecondsSinceEpoch}';

    final account = Account(
      id: accountId,
      name: _nameController.text,
      balance: balance,
      initialBalance: _selectedType == AccountType.loan ? balance : balance,
      createdDate: DateTime.now(),
      currency: '₽',
      type: _selectedType,
      icon: _selectedIcon,
      color: _selectedColor,
      showOnHomeScreen: _showOnHomeScreen,
      isMain: _isMainAccount,

      // Проценты
      interestRate: _rateController.text.isNotEmpty
          ? double.tryParse(_rateController.text)
          : null,
      interestAccountId: _selectedInterestAccountId,
      interestPeriod: _selectedType == AccountType.savings
          ? _selectedInterestPeriod
          : null,
      interestCalculationType: _selectedType == AccountType.savings
          ? _selectedCalculationType
          : null,
      interestPaymentDate: paymentDate,

      // Для вклада
      isCapitalized: _selectedType == AccountType.deposit
          ? _isCapitalization
          : null,
      capitalizationFrequency:
          _selectedType == AccountType.deposit && _isCapitalization
          ? _selectedCapitalizationFrequency
          : null,
      termMonths: _selectedType == AccountType.deposit ? termMonthsValue : null,
      closureAccountId: _selectedClosureAccountId,
      allowDeposit: _selectedType == AccountType.deposit ? _allowDeposit : null,
      allowWithdraw: _selectedType == AccountType.deposit
          ? _allowWithdraw
          : null,
      depositStartDate: depositStartDate,
      depositEndDate: depositEndDate,
      depositTermYears: depositTermYears,
      depositTermMonths: depositTermMonths,
      depositTermDays: depositTermDays,

      // Для кредита
      paymentType: _selectedType == AccountType.loan
          ? (_isAnnuity ? 'annuity' : 'differentiated')
          : null,
      principalAmount: principalAmount,
      remainingPrincipal: remainingPrincipal,
      monthlyPayment: calculatedMonthlyPayment,
      totalLoanInterest: totalInterest,
      loanTermYears: loanTermYears,
      loanTermMonths: loanTermMonths,
      loanTermDays: loanTermDays,
      remainingMonths: remainingMonths,
      nextPaymentDate: _selectedType == AccountType.loan
          ? DateTime.now().add(const Duration(days: 30))
          : null,
      paymentDay: _selectedPaymentDay,

      // Для долгов
      repaymentDate: _repaymentDateController.text.isNotEmpty
          ? _parseDate(_repaymentDateController.text)
          : null,

      // Старые поля
      creditLimit: null,
      minPayment: null,
      commission: null,
      interestRateCredit: null,
      billingDate: billingDate,
      gracePeriodDays: null,
    );

    List<Account> accounts = await CategoryService.loadAccounts();

    if (widget.accountToEdit != null) {
      final index = accounts.indexWhere((a) => a.id == account.id);
      if (index != -1)
        accounts[index] = account;
      else
        accounts.add(account);
    } else {
      accounts.add(account);
    }

    await CategoryService.saveAccounts(accounts);
    CategoryService.notifyAccountsListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_${account.id}', account.showOnHomeScreen);
    await prefs.setBool('main_${account.id}', account.isMain);

    widget.onAccountAdded(account);
    Navigator.pop(context);
    SnackbarUtils.showSuccess(
      context,
      widget.accountToEdit == null ? 'Счет создан' : 'Счет обновлен',
    );
  }

  Future<int> _getMainAccountsCount() async {
    final accounts = await CategoryService.loadAccounts();
    final prefs = await SharedPreferences.getInstance();
    int count = 0;
    for (var account in accounts) {
      if (prefs.getBool('main_${account.id}') ?? false) count++;
    }
    return count;
  }

  // ========== UI КОМПОНЕНТЫ ==========

  void _clearValidationError() {
    if (_validationError != null) {
      setState(() {
        _validationError = null;
      });
    }
  }

  void _onAmountChanged(TextEditingController controller) {
    String raw = controller.text.replaceAll(RegExp(r'[^\d,.]'), '');
    raw = raw.replaceAll(',', '.');

    // Ограничиваем количество знаков после запятой (максимум 2)
    final parts = raw.split('.');
    if (parts.length > 2) {
      raw = parts[0] + '.' + parts[1].substring(0, 2);
    } else if (parts.length == 2 && parts[1].length > 2) {
      raw = parts[0] + '.' + parts[1].substring(0, 2);
    }

    if (raw.isNotEmpty && raw != '.') {
      final number = double.tryParse(raw);
      if (number != null) {
        // Форматируем с 2 десятичными знаками
        controller.text = NumberFormat('#,##0.00', 'ru_RU').format(number);
        controller.selection = TextSelection.fromPosition(
          TextPosition(offset: controller.text.length),
        );
        return;
      }
    }
    controller.text = raw;
    controller.selection = TextSelection.fromPosition(
      TextPosition(offset: controller.text.length),
    );
  }

  Widget _buildInfoButton(String message, {String? imagePath}) {
    final colorScheme = Theme.of(context).colorScheme;
    return IconButton(
      icon: Icon(Icons.help_outline, size: 18, color: Colors.grey),
      onPressed: () {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (imagePath != null)
                  ColorFiltered(
                    colorFilter: ColorFilter.mode(
                      colorScheme.primary,
                      BlendMode.srcIn,
                    ),
                    child: Image.asset(imagePath, height: 80),
                  ),
                const SizedBox(height: 12),
                Text(message, textAlign: TextAlign.center),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Понятно'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    String? hint,
    IconData? prefixIcon,
    bool isNumber = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          onChanged: (value) {
            _clearValidationError();
            if (isNumber) {
              //_onAmountChanged(controller);
            }
          },
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  Widget _buildSmallTextField(
    String label,
    TextEditingController controller, {
    bool isNumber = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      onChanged: isNumber ? (v) => _onAmountChanged(controller) : null,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }

  Widget _buildDateField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'дд.мм.гггг',
            prefixIcon: const Icon(Icons.calendar_today),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime(2030),
            );
            if (date != null) {
              final day = date.day.toString().padLeft(2, '0');
              final month = date.month.toString().padLeft(2, '0');
              controller.text = '$day.$month.${date.year}';
            }
          },
        ),
      ],
    );
  }

  Widget _buildDropdown<T>(
    String label,
    T? value,
    List<DropdownMenuItem<T>> items,
    Function(T?) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) ...[
          Text(
            label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
        ],
        DropdownButtonFormField<T>(
          value: value,
          isExpanded: true,
          items: items,
          onChanged: (newValue) {
            _clearValidationError();
            onChanged(newValue);
          },
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAccountDropdown(
    String label,
    String? value,
    Function(String?) onChanged, {
    bool includeCurrentAccount = false,
  }) {
    List<Account> availableAccounts = List.from(_accounts);
    if (includeCurrentAccount && _nameController.text.isNotEmpty) {
      final tempAccount = Account(
        id: 'temp',
        name: _nameController.text,
        balance: 0,
        initialBalance: 0,
        createdDate: DateTime.now(),
        currency: '₽',
        type: _selectedType,
        icon: _selectedIcon,
        color: _selectedColor,
        showOnHomeScreen: true,
        isMain: false,
      );
      availableAccounts.add(tempAccount);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          value: value,
          isExpanded: true,
          hint: Text('Выберите $label'),
          items: availableAccounts
              .map((a) => DropdownMenuItem(value: a.id, child: Text(a.name)))
              .toList(),
          onChanged: (newValue) {
            _clearValidationError();
            onChanged(newValue);
          },
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSwitchTile(String title, bool value, Function(bool) onChanged) {
    return Row(
      children: [
        Switch(
          value: value,
          onChanged: (newValue) {
            _clearValidationError();
            onChanged(newValue);
          },
          activeColor: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(title, style: const TextStyle(fontSize: 16))),
      ],
    );
  }

  String _getFrequencyName(String f) {
    switch (f) {
      case 'day':
        return 'Каждый день';
      case 'week':
        return 'Каждую неделю';
      case 'month':
        return 'Каждый месяц';
      case 'quarter':
        return 'Каждый квартал';
      default:
        return 'Каждый месяц';
    }
  }

  // ========== ВКЛАД ==========
  Widget _buildDepositFields() {
    final capitalizationFrequencies = ['day', 'week', 'month', 'quarter']
        .map(
          (f) => DropdownMenuItem(value: f, child: Text(_getFrequencyName(f))),
        )
        .toList();

    return Column(
      children: [
        const Divider(),
        const Text(
          'Параметры вклада',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        if (_validationError != null)
          Container(
            margin: const EdgeInsets.only(top: 8, bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.shade300),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _validationError!,
                    style: TextStyle(color: Colors.red.shade700, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),
        _buildTextField(
          'Процентная ставка (%)',
          _rateController,
          isNumber: true,
        ),
        const SizedBox(height: 12),
        _buildDateField('Дата открытия вклада', _depositStartDateController),
        const SizedBox(height: 12),
        const Text(
          'Срок вклада (на текущий момент)',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: _buildSmallTextField(
                'лет',
                _depositTermYearsController,
                isNumber: true,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildSmallTextField(
                'мес',
                _depositTermMonthsController,
                isNumber: true,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildSmallTextField(
                'дн',
                _depositTermDaysController,
                isNumber: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildSwitchTile(
                'Капитализация процентов',
                _isCapitalization,
                (v) => setState(() => _isCapitalization = v),
              ),
            ),
            _buildInfoButton(
              'Капитализация процентов — это прибавление начисленных процентов к сумме вклада.',
              imagePath: 'assets/images/neko.png',
            ),
          ],
        ),
        if (_isCapitalization) ...[
          const SizedBox(height: 12),
          _buildDropdown(
            'Частота капитализации',
            _selectedCapitalizationFrequency,
            capitalizationFrequencies,
            (v) => setState(() => _selectedCapitalizationFrequency = v!),
          ),
          const SizedBox(height: 12),
          _buildAccountDropdown(
            'Счет для начисления процентов',
            _selectedInterestAccountId,
            (v) => setState(() => _selectedInterestAccountId = v),
            includeCurrentAccount: true,
          ),
        ],
        const SizedBox(height: 12),
        _buildAccountDropdown(
          'Счет при закрытии вклада',
          _selectedClosureAccountId,
          (v) => setState(() => _selectedClosureAccountId = v),
        ),
        const SizedBox(height: 12),
        _buildSwitchTile(
          'Возможность пополнения',
          _allowDeposit,
          (v) => setState(() => _allowDeposit = v),
        ),
        const SizedBox(height: 12),
        _buildSwitchTile(
          'Возможность снятия',
          _allowWithdraw,
          (v) => setState(() => _allowWithdraw = v),
        ),
      ],
    );
  }

  // ========== НАКОПИТЕЛЬНЫЙ СЧЕТ ==========
  Widget _buildSavingsFields() {
    final periodOptions = ['day', 'month']
        .map(
          (p) => DropdownMenuItem(
            value: p,
            child: Text(p == 'day' ? 'День' : 'Месяц'),
          ),
        )
        .toList();

    final calculationOptions = ['minimal', 'actual']
        .map(
          (c) => DropdownMenuItem(
            value: c,
            child: Text(
              c == 'minimal'
                  ? 'На минимальный остаток'
                  : 'На фактический остаток',
            ),
          ),
        )
        .toList();

    final dateOptions = ['last', 'first']
        .map(
          (d) => DropdownMenuItem(
            value: d,
            child: Text(
              d == 'last' ? 'Последнее число месяца' : 'Первое число месяца',
            ),
          ),
        )
        .toList();

    return Column(
      children: [
        const Divider(),
        const Text(
          'Параметры накопительного счета',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        if (_validationError != null)
          Container(
            margin: const EdgeInsets.only(top: 8, bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.shade300),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _validationError!,
                    style: TextStyle(color: Colors.red.shade700, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),
        _buildTextField(
          'Процентная ставка (%)',
          _rateController,
          isNumber: true,
        ),
        const SizedBox(height: 12),
        _buildAccountDropdown(
          'Счет для начисления процентов',
          _selectedInterestAccountId,
          (v) => setState(() => _selectedInterestAccountId = v),
          includeCurrentAccount: true,
        ),
        const SizedBox(height: 12),
        _buildDropdown(
          'Расчетный период',
          _selectedInterestPeriod,
          periodOptions,
          (v) => setState(() => _selectedInterestPeriod = v!),
        ),
        if (_selectedInterestPeriod == 'month') ...[
          const SizedBox(height: 12),
          _buildDropdown(
            'Дата расчетного периода',
            _selectedCalculationDate,
            dateOptions,
            (v) => setState(() => _selectedCalculationDate = v!),
          ),
        ],
        const SizedBox(height: 12),
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Начисление процентов',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildDropdown(
                '',
                _selectedCalculationType,
                calculationOptions,
                (v) => setState(() => _selectedCalculationType = v!),
              ),
            ),
            _buildInfoButton(
              'На минимальный остаток: проценты считаются от самой маленькой суммы на счете за период.\n\nНа фактический остаток: проценты считаются от ежедневного остатка.',
              imagePath: 'assets/images/neko.png',
            ),
          ],
        ),
      ],
    );
  }

  // ========== КРЕДИТ ==========
  Widget _buildLoanFields() {
    final paymentTypes = [true, false]
        .map(
          (t) => DropdownMenuItem(
            value: t,
            child: Text(t ? 'Аннуитентный' : 'Дифференцированный'),
          ),
        )
        .toList();

    return Column(
      children: [
        const Divider(),
        const Text(
          'Параметры кредита',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        if (_validationError != null)
          Container(
            margin: const EdgeInsets.only(top: 8, bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.shade300),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _validationError!,
                    style: TextStyle(color: Colors.red.shade700, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),
        _buildTextField(
          'Процентная ставка (%)',
          _rateController,
          isNumber: true,
        ),
        const SizedBox(height: 12),
        _buildDropdown(
          'Вид платежа',
          _isAnnuity,
          paymentTypes,
          (v) => setState(() => _isAnnuity = v!),
        ),

        // ДЕНЬ ПЛАТЕЖА
        const SizedBox(height: 12),
        const Text(
          'День платежа',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<int>(
                value: _selectedPaymentDay,
                items: List.generate(
                  31,
                  (i) => DropdownMenuItem(
                    value: i + 1,
                    child: Text('${i + 1}-е число'),
                  ),
                ),
                onChanged: (value) =>
                    setState(() => _selectedPaymentDay = value!),
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            _buildInfoButton(
              'В этот день каждого месяца будет приходить напоминание о необходимости внести платёж по кредиту.',
            ),
          ],
        ),

        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.shade300),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Вписывайте актуальные данные на текущий момент: остаток основного долга и оставшийся срок кредита.',
                  style: TextStyle(color: Colors.blue.shade700, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _buildTextField(
          'Сумма основного долга',
          _loanAmountController,
          isNumber: true,
          prefixIcon: Icons.attach_money,
        ),
        const SizedBox(height: 12),
        const Text(
          'Срок кредита',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildSmallTextField(
                'лет',
                _loanTermYearsController,
                isNumber: true,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildSmallTextField(
                'мес',
                _loanTermMonthsController,
                isNumber: true,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildSmallTextField(
                'дн',
                _loanTermDaysController,
                isNumber: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // ✅ ИСПРАВЛЕННЫЙ КОНТЕЙНЕР для ежемесячного платежа - теперь двухстрочный
        // ✅ ИСПРАВЛЕННЫЙ КОНТЕЙНЕР для ежемесячного платежа
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Примерный',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Text(
                      'ежемесячный платеж:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  _calculateMonthlyPayment() != null
                      ? _formatCurrency(
                          _calculateMonthlyPayment()!.roundToDouble(),
                        ) // ✅ ОКРУГЛЕНИЕ
                      : '—',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ========== ДОЛГИ ==========
  Widget _buildDebtFields() {
    final TextEditingController _repaymentDateController =
        TextEditingController();

    // Если редактируем существующий долг, загружаем дату
    if (widget.accountToEdit != null &&
        widget.accountToEdit!.repaymentDate != null) {
      final date = widget.accountToEdit!.repaymentDate!;
      _repaymentDateController.text =
          '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
    }

    return Column(
      children: [
        const Divider(),
        Text(
          _selectedType == AccountType.debtOwed
              ? 'Параметры долга (должны мне)'
              : 'Параметры долга (должен я)',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  // ========== ОБЩИЕ НАСТРОЙКИ ==========
  Widget _buildMainAccountSwitch() {
    return FutureBuilder<int>(
      future: _getMainAccountsCount(),
      builder: (context, snapshot) {
        final mainCount = snapshot.data ?? 0;
        final isLimitReached = mainCount >= 8 && !_isMainAccount;
        if (isLimitReached) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.shade300),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.warning_amber,
                  color: Colors.orange.shade800,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Достигнут лимит основных счетов (максимум 8).',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.orange.shade900,
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        return _buildSwitchTile(
          'Основной счет (баланс в шапке)',
          _isMainAccount,
          (v) => setState(() => _isMainAccount = v),
        );
      },
    );
  }

  Widget _buildTypeDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Тип счета',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<AccountType>(
          value: _selectedType,
          items: AccountType.values
              .map(
                (type) => DropdownMenuItem(
                  value: type,
                  child: Text(type.displayName),
                ),
              )
              .toList(),
          onChanged: (value) async {
            _clearValidationError();
            setState(() {
              _selectedType = value!;
              _selectedIcon = value.defaultIcon;
            });
            final existingAccounts = await CategoryService.loadAccounts();
            setState(
              () => _selectedColor = _getDefaultColorForType(
                _selectedType,
                existingAccounts,
              ),
            );
          },
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  Widget _buildColorPicker() {
    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: availableColors.length,
        itemBuilder: (context, index) {
          final color = availableColors[index];
          final isSelected = _selectedColor == color;
          return GestureDetector(
            onTap: () => setState(() => _selectedColor = color),
            child: Container(
              width: 40,
              height: 40,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: isSelected
                    ? Border.all(color: Colors.white, width: 3)
                    : null,
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildIconGrid() {
    return SizedBox(
      height: 100,
      child: GridView.builder(
        shrinkWrap: true,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 5,
          childAspectRatio: 1,
        ),
        itemCount: availableIcons.length,
        itemBuilder: (context, index) {
          final iconInfo = availableIcons[index];
          final isSelected = _selectedIcon == iconInfo.icon;
          return GestureDetector(
            onTap: () => setState(() => _selectedIcon = iconInfo.icon),
            child: Container(
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isSelected
                    ? _selectedColor.withOpacity(0.2)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: isSelected
                    ? Border.all(color: _selectedColor, width: 2)
                    : null,
              ),
              child: Icon(
                iconInfo.icon,
                color: isSelected ? _selectedColor : Colors.grey,
                size: 28,
              ),
            ),
          );
        },
      ),
    );
  }

  // ========== BUILD ==========
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final viewInsets = MediaQuery.of(context).viewInsets;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade900 : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              widget.accountToEdit == null
                  ? 'Новый счет'
                  : 'Редактировать счет',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: viewInsets.bottom + 80,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTextField(
                    'Название',
                    _nameController,
                    hint: 'Название счета',
                  ),
                  const SizedBox(height: 20),
                  _buildTypeDropdown(),
                  const SizedBox(height: 20),
                  if (_selectedType != AccountType.loan)
                    _buildTextField(
                      'Начальный баланс',
                      _balanceController,
                      hint: '0',
                      prefixIcon: Icons.attach_money,
                      isNumber: true,
                    ),
                  const SizedBox(height: 20),
                  if (_selectedType == AccountType.deposit)
                    _buildDepositFields(),
                  if (_selectedType == AccountType.savings)
                    _buildSavingsFields(),
                  if (_selectedType == AccountType.loan) _buildLoanFields(),
                  if (_selectedType == AccountType.debtOwed ||
                      _selectedType == AccountType.debtToPay)
                    _buildDebtFields(),
                  if (_selectedType != AccountType.debtOwed &&
                      _selectedType != AccountType.debtToPay) ...[
                    const SizedBox(height: 20),
                    _buildSwitchTile(
                      'Показывать на главном экране',
                      _showOnHomeScreen,
                      (v) => setState(() => _showOnHomeScreen = v),
                    ),
                    const SizedBox(height: 12),
                    _buildMainAccountSwitch(),
                  ],
                  const SizedBox(height: 20),
                  const Divider(),
                  const Text('Цвет счета:'),
                  const SizedBox(height: 8),
                  _buildColorPicker(),
                  const SizedBox(height: 20),
                  const Divider(),
                  const Text(
                    'Иконка счета',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  _buildIconGrid(),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + viewInsets.bottom),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade900 : Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _saveAccount,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    widget.accountToEdit == null ? 'Создать счет' : 'Сохранить',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
