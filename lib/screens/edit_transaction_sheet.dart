import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';
import '../models/transaction_models.dart';
import '../services/category_service.dart';
import '../services/transaction_service.dart';
import '../widgets/custom_date_picker.dart';
import '../utils/snackbar_utils.dart';

typedef TransactionUpdateCallback = void Function(Transaction transaction);
typedef TransactionDeleteCallback = void Function(String id);

class EditTransactionSheet extends StatefulWidget {
  final Transaction transaction;
  final TransactionUpdateCallback onTransactionUpdated;
  final TransactionDeleteCallback onTransactionDeleted;

  const EditTransactionSheet({
    super.key,
    required this.transaction,
    required this.onTransactionUpdated,
    required this.onTransactionDeleted,
  });

  @override
  State<EditTransactionSheet> createState() => _EditTransactionSheetState();
}

class _EditTransactionSheetState extends State<EditTransactionSheet> {
  late String _amount;
  late String _title;
  late DateTime _selectedDate;
  late TransactionType _type;
  late Category? _selectedCategory;
  late SubCategory? _selectedSubCategory;
  late Account? _selectedAccount;
  late Account? _selectedFromAccount;
  late Account? _selectedToAccount;
  late String _comment;
  late bool _isRecurring;
  int _recurringInterval = 1;
  String _recurringFrequency = 'month';

  late TextEditingController _amountController;
  late TextEditingController _titleController;
  late TextEditingController _commentController;

  String _operation = '';
  double _firstNumber = 0;
  bool _waitingForSecondNumber = false;

  List<Category> _expenseCategories = [];
  List<Category> _incomeCategories = [];
  List<Account> _accounts = [];
  List<Account> _targetAccounts = []; // Только счета для зачисления
  bool _isLoading = true;

  bool _isInterestTransaction = false;
  bool _isTransfer = false;
  bool _isDepositClosure = false; // ← ДОБАВЛЕНО

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final allCategories = await CategoryService.loadCategories();
    _expenseCategories = allCategories;
    _incomeCategories = allCategories;

    _accounts = await CategoryService.loadAccounts();

    _amount = widget.transaction.amount.toStringAsFixed(2);
    _title = widget.transaction.title;
    _selectedDate = widget.transaction.date;
    _type = widget.transaction.type;
    _comment = widget.transaction.comment ?? '';
    _isRecurring = widget.transaction.isRecurring;
    _recurringInterval = widget.transaction.recurringInterval ?? 1;
    _recurringFrequency = widget.transaction.recurringFrequency ?? 'month';

    // ✅ ОПРЕДЕЛЯЕМ ЗАКРЫТИЕ ВКЛАДА
    _isDepositClosure = widget.transaction.category == 'Закрытие вклада' ||
        (widget.transaction.title != null &&
            widget.transaction.title!.contains('Закрытие вклада'));

    // ✅ ОПРЕДЕЛЯЕМ ПЕРЕВОД
    _isTransfer = !_isDepositClosure &&
        widget.transaction.fromAccountId != null &&
        widget.transaction.toAccountId != null;

    if (_isTransfer) {
      _selectedFromAccount = _accounts
          .firstWhereOrNull((a) => a.id == widget.transaction.fromAccountId);
      _selectedToAccount = _accounts
          .firstWhereOrNull((a) => a.id == widget.transaction.toAccountId);
    }

    // ✅ ДЛЯ ЗАКРЫТИЯ ВКЛАДА - только счета для зачисления
    if (_isDepositClosure) {
      _targetAccounts = _accounts
          .where((a) =>
              a.type != AccountType.loan &&
              a.type != AccountType.debtOwed &&
              a.type != AccountType.debtToPay)
          .toList();
      _selectedAccount = _targetAccounts
          .firstWhereOrNull((a) => a.id == widget.transaction.accountId);
    }

    _isInterestTransaction = widget.transaction.title.contains('Проценты') ||
        widget.transaction.comment?.contains('процентов') == true ||
        widget.transaction.category.isEmpty;

    _selectedSubCategory = null;

    if (!_isInterestTransaction &&
        !_isTransfer &&
        !_isDepositClosure &&
        _expenseCategories.isNotEmpty) {
      final categories = _type == TransactionType.expense
          ? _expenseCategories
          : _incomeCategories;
      _selectedCategory = categories.firstWhere(
        (c) => c.name == widget.transaction.category,
        orElse: () => categories.first,
      );

      if (widget.transaction.subCategory != null &&
          widget.transaction.subCategory!.isNotEmpty &&
          _selectedCategory != null) {
        try {
          final found = _selectedCategory!.subCategories.firstWhere(
            (s) => s.name == widget.transaction.subCategory,
          );
          _selectedSubCategory = found;
        } catch (e) {
          _selectedSubCategory = null;
        }
      }
    } else {
      _selectedCategory = null;
      _selectedSubCategory = null;
    }

    if (_accounts.isNotEmpty && !_isTransfer && !_isDepositClosure) {
      try {
        final found = _accounts.firstWhere(
          (a) => a.id == (widget.transaction.accountId ?? ''),
        );
        _selectedAccount = found;
      } catch (e) {
        _selectedAccount = _accounts.first;
      }
    }

    _amountController = TextEditingController(text: _getDisplayAmount());
    _titleController = TextEditingController(text: _title ?? '');
    _commentController = TextEditingController(text: _comment ?? '');

    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _titleController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  String _getDisplayAmount() {
    if (_amount.isEmpty) return '0';
    try {
      if (_amount.contains('.')) return _amount.replaceAll('.', ',');
      String result = '';
      for (int i = 0; i < _amount.length; i++) {
        if (i > 0 && (_amount.length - i) % 3 == 0) result += ' ';
        result += _amount[i];
      }
      return result;
    } catch (e) {
      return _amount;
    }
  }

  void _addDigit(String digit) {
    setState(() {
      String currentAmount = _amount;
      String actualDigit = digit == ',' ? '.' : digit;

      if (actualDigit == '⌫') {
        if (currentAmount.isNotEmpty) {
          currentAmount = currentAmount.substring(0, currentAmount.length - 1);
        }
      } else if (actualDigit == 'C') {
        currentAmount = '';
        _operation = '';
        _firstNumber = 0;
        _waitingForSecondNumber = false;
      } else if (actualDigit == '+' || actualDigit == '-') {
        if (currentAmount.isNotEmpty) {
          _firstNumber = double.tryParse(currentAmount) ?? 0;
          _operation = actualDigit;
          currentAmount = '';
          _waitingForSecondNumber = true;
        }
      } else if (actualDigit == '=') {
        if (_operation.isNotEmpty && currentAmount.isNotEmpty) {
          double secondNumber = double.tryParse(currentAmount) ?? 0;
          double result = 0;
          if (_operation == '+')
            result = _firstNumber + secondNumber;
          else if (_operation == '-') result = _firstNumber - secondNumber;
          currentAmount = result.toString();
          _operation = '';
          _waitingForSecondNumber = false;
        }
      } else if (actualDigit == '.' && !currentAmount.contains('.')) {
        if (currentAmount.isEmpty) {
          currentAmount = '0.';
        } else {
          currentAmount += '.';
        }
      } else if (actualDigit != '.') {
        currentAmount += actualDigit;
      }

      _amount = currentAmount;
      _amountController.text = _getDisplayAmount();
    });
  }

  Widget _buildCalcButton(String text, ColorScheme colorScheme,
      {bool isSpecial = false}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Material(
          color: isSpecial
              ? colorScheme.primary.withOpacity(0.15)
              : colorScheme.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: () => _addDigit(text),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Center(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: isSpecial ? FontWeight.bold : FontWeight.normal,
                    color: colorScheme.primary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showFrequencyDialog() {
    int tempInterval = _recurringInterval;
    String tempFrequency = _recurringFrequency;
    final intervalController =
        TextEditingController(text: tempInterval.toString());

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Настройка регулярного платежа'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Text('Каждые'),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 60,
                        child: TextField(
                          controller: intervalController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 8, vertical: 8),
                          ),
                          onChanged: (value) {
                            setStateDialog(() {
                              tempInterval = int.tryParse(value) ?? 1;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      DropdownButton<String>(
                        value: tempFrequency,
                        items: const [
                          DropdownMenuItem(value: 'day', child: Text('день')),
                          DropdownMenuItem(
                              value: 'week', child: Text('неделю')),
                          DropdownMenuItem(
                              value: 'month', child: Text('месяц')),
                          DropdownMenuItem(value: 'year', child: Text('год')),
                        ],
                        onChanged: (value) {
                          setStateDialog(() {
                            tempFrequency = value!;
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Платеж будет повторяться каждые $tempInterval ${_getFrequencyTextFor(tempFrequency, tempInterval)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Отмена'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _isRecurring = true;
                      _recurringInterval = tempInterval;
                      _recurringFrequency = tempFrequency;
                    });
                    Navigator.pop(context);
                  },
                  child: const Text('Сохранить'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _getFrequencyTextFor(String frequency, int interval) {
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

  String _formatAmount(double amount) {
    return '${NumberFormat('#,##0.00', 'ru_RU').format(amount)} ₽';
  }

  // ==================== УТИЛИТЫ ====================

  // ==================== BUILD ====================

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final viewInsets = MediaQuery.of(context).viewInsets;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    if (_isLoading) {
      return Container(
        height: MediaQuery.of(context).size.height * 0.95,
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.light
              ? Colors.white
              : Colors.grey.shade900,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    // ✅ ДЛЯ ЗАКРЫТИЯ ВКЛАДА - ТОЛЬКО ПРОСМОТР (БЕЗ РЕДАКТИРОВАНИЯ И УДАЛЕНИЯ)
    // Замените блок для _isDepositClosure на этот:
    if (_isDepositClosure) {
      return Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.light
              ? Colors.white
              : Colors.grey.shade900,
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
                  borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'Закрытие вклада',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                // ← ДОБАВЛЯЕМ SCROLL
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.lock, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    Text(
                      'Это автоматическая транзакция закрытия вклада.',
                      style: TextStyle(color: Colors.grey.shade600),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _title,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w500),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade200,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Column(
                        children: [
                          const Text('Сумма',
                              style:
                                  TextStyle(fontSize: 14, color: Colors.grey)),
                          const SizedBox(height: 4),
                          Text(
                            _formatAmount(double.tryParse(_amount) ?? 0),
                            style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.green),
                          ),
                          const Divider(height: 20),
                          const Text('Дата',
                              style:
                                  TextStyle(fontSize: 14, color: Colors.grey)),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('dd.MM.yyyy').format(_selectedDate),
                            style: const TextStyle(fontSize: 16),
                          ),
                          const Divider(height: 20),
                          const Text('Счет зачисления',
                              style:
                                  TextStyle(fontSize: 14, color: Colors.grey)),
                          const SizedBox(height: 4),
                          Text(
                            _selectedAccount?.name ?? 'Неизвестный счет',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 12),
                      ),
                      child: const Text('Закрыть'),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    // ✅ ДЛЯ ПЕРЕВОДОВ
    if (_isTransfer) {
      return Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.light
              ? Colors.white
              : Colors.grey.shade900,
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
                  borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'Редактировать перевод',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                    left: 16, right: 16, top: 16, bottom: bottomPadding + 80),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Счет списания (только для просмотра при закрытии вклада, но для переводов редактируемый)
                    const Text('Списать с:',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 200),
                      child: ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _accounts
                            .where((a) => a.type != AccountType.loan)
                            .length,
                        itemBuilder: (context, index) {
                          final account = _accounts
                              .where((a) => a.type != AccountType.loan)
                              .toList()[index];
                          final isSelected =
                              _selectedFromAccount?.id == account.id;
                          return Card(
                            margin: const EdgeInsets.only(bottom: 4),
                            child: ListTile(
                              leading: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                    color: account.color.withOpacity(0.2),
                                    shape: BoxShape.circle),
                                child: Icon(account.icon,
                                    color: account.color, size: 20),
                              ),
                              title: Text(account.name),
                              subtitle: Text(
                                '${account.balance.toStringAsFixed(2)} ${account.currency}',
                                style: TextStyle(
                                    color: account.balance >= 0
                                        ? Colors.green
                                        : Colors.red),
                              ),
                              trailing: isSelected
                                  ? Icon(Icons.check_circle,
                                      color: Colors.green)
                                  : null,
                              onTap: () => setState(() {
                                _selectedFromAccount = account;
                                _selectedToAccount = null;
                              }),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Зачислить на:',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 200),
                      child: ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _accounts.length,
                        itemBuilder: (context, index) {
                          final account = _accounts[index];
                          final isSelected =
                              _selectedToAccount?.id == account.id;
                          return Card(
                            margin: const EdgeInsets.only(bottom: 4),
                            child: ListTile(
                              leading: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                    color: account.color.withOpacity(0.2),
                                    shape: BoxShape.circle),
                                child: Icon(account.icon,
                                    color: account.color, size: 20),
                              ),
                              title: Text(account.name),
                              subtitle: Text(
                                '${account.balance.toStringAsFixed(2)} ${account.currency}',
                                style: TextStyle(
                                    color: account.balance >= 0
                                        ? Colors.green
                                        : Colors.red),
                              ),
                              trailing: isSelected
                                  ? Icon(Icons.check_circle,
                                      color: Colors.green)
                                  : null,
                              onTap: () =>
                                  setState(() => _selectedToAccount = account),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text('Сумма',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: colorScheme.primary.withOpacity(0.3)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextField(
                        controller: _amountController,
                        readOnly: true,
                        style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary),
                        textAlign: TextAlign.center,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                          hintText: '0',
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: colorScheme.primary.withOpacity(0.2)),
                      ),
                      child: Column(
                        children: [
                          Row(children: [
                            _buildCalcButton('1', colorScheme),
                            _buildCalcButton('2', colorScheme),
                            _buildCalcButton('3', colorScheme),
                            _buildCalcButton('⌫', colorScheme, isSpecial: true),
                          ]),
                          const SizedBox(height: 8),
                          Row(children: [
                            _buildCalcButton('4', colorScheme),
                            _buildCalcButton('5', colorScheme),
                            _buildCalcButton('6', colorScheme),
                            _buildCalcButton('+', colorScheme, isSpecial: true),
                          ]),
                          const SizedBox(height: 8),
                          Row(children: [
                            _buildCalcButton('7', colorScheme),
                            _buildCalcButton('8', colorScheme),
                            _buildCalcButton('9', colorScheme),
                            _buildCalcButton('-', colorScheme, isSpecial: true),
                          ]),
                          const SizedBox(height: 8),
                          Row(children: [
                            _buildCalcButton(',', colorScheme, isSpecial: true),
                            _buildCalcButton('0', colorScheme),
                            _buildCalcButton('C', colorScheme, isSpecial: true),
                            _buildCalcButton('=', colorScheme, isSpecial: true),
                          ]),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (date != null) setState(() => _selectedDate = date);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 16),
                        decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(10)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.calendar_today,
                                color: colorScheme.primary, size: 20),
                            const SizedBox(width: 8),
                            Text(DateFormat('dd.MM.yyyy').format(_selectedDate),
                                style: const TextStyle(fontSize: 16)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Checkbox(
                          value: _isRecurring,
                          onChanged: (value) {
                            if (value == true) {
                              _showFrequencyDialog();
                            } else {
                              setState(() => _isRecurring = false);
                            }
                          },
                          activeColor: Colors.blue,
                        ),
                        const Text('Регулярный платеж',
                            style: TextStyle(fontSize: 16)),
                        if (_isRecurring) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8)),
                            child: Text(
                                _getFrequencyTextFor(
                                    _recurringFrequency, _recurringInterval),
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.blue)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text('Комментарий',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _commentController,
                      onChanged: (value) => _comment = value,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Дополнительная информация...',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottomPadding),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.light
                    ? Colors.white
                    : Colors.grey.shade900,
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -5))
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Удалить транзакцию'),
                              content: const Text('Вы уверены?'),
                              actions: [
                                TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Отмена')),
                                TextButton(
                                  onPressed: () {
                                    widget.onTransactionDeleted(
                                        widget.transaction.id);
                                    Navigator.pop(context);
                                    Navigator.pop(context);
                                  },
                                  style: TextButton.styleFrom(
                                      foregroundColor: Colors.red),
                                  child: const Text('Удалить'),
                                ),
                              ],
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            padding: const EdgeInsets.symmetric(vertical: 12)),
                        child: const Text('Удалить',
                            style: TextStyle(fontSize: 16)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _saveTransferChanges,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: colorScheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12)),
                        child: const Text('Сохранить',
                            style: TextStyle(fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    // ДЛЯ ОБЫЧНЫХ ТРАНЗАКЦИЙ
    final categoryColor =
        _type == TransactionType.expense ? Colors.red : Colors.green;

    return Container(
      height: MediaQuery.of(context).size.height * 0.95,
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.light
            ? Colors.white
            : Colors.grey.shade900,
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
                borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text('Редактировать транзакцию',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary)),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: viewInsets.bottom + 150),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: categoryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      children: [
                        Icon(
                            _type == TransactionType.expense
                                ? Icons.trending_down
                                : Icons.trending_up,
                            color: categoryColor,
                            size: 24),
                        const SizedBox(width: 8),
                        Text(
                            _type == TransactionType.expense
                                ? 'Расход'
                                : 'Доход',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: categoryColor)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (!_isInterestTransaction) ...[
                    const Text('Категория',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<Category>(
                      value: _selectedCategory,
                      items: (_type == TransactionType.expense
                              ? _expenseCategories
                              : _incomeCategories)
                          .map((category) {
                        return DropdownMenuItem(
                          value: category,
                          child: Row(
                            children: [
                              Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                      color: category.color.withOpacity(0.2),
                                      shape: BoxShape.circle),
                                  child: Icon(category.icon,
                                      color: category.color, size: 18)),
                              const SizedBox(width: 12),
                              Text(category.name,
                                  style: const TextStyle(fontSize: 15)),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) => setState(() {
                        _selectedCategory = value;
                        _selectedSubCategory = null;
                      }),
                      decoration: InputDecoration(
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10))),
                    ),
                    if (_selectedCategory != null &&
                        _selectedCategory!.subCategories.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Text('Подкатегория',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<SubCategory>(
                        value: _selectedSubCategory,
                        items: _selectedCategory!.subCategories.map((sub) {
                          return DropdownMenuItem(
                            value: sub,
                            child: Row(
                              children: [
                                Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                        color: sub.color.withOpacity(0.2),
                                        shape: BoxShape.circle),
                                    child: Icon(sub.icon,
                                        color: sub.color, size: 14)),
                                const SizedBox(width: 8),
                                Text(sub.name,
                                    style: const TextStyle(fontSize: 14)),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (value) =>
                            setState(() => _selectedSubCategory = value),
                        decoration: InputDecoration(
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10))),
                      ),
                    ],
                    const SizedBox(height: 16),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.shade200)),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue.shade700),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Text(
                                  'Это транзакция начисления процентов. Категория и подкатегория не требуются.',
                                  style: TextStyle(
                                      color: Colors.blue.shade700,
                                      fontSize: 14))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  const Text('Сумма',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                        border: Border.all(
                            color: colorScheme.primary.withOpacity(0.3)),
                        borderRadius: BorderRadius.circular(12)),
                    child: TextField(
                      controller: _amountController,
                      readOnly: true,
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary),
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                          hintText: '0'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: colorScheme.primary.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: colorScheme.primary.withOpacity(0.2))),
                    child: Column(
                      children: [
                        Row(children: [
                          _buildCalcButton('1', colorScheme),
                          _buildCalcButton('2', colorScheme),
                          _buildCalcButton('3', colorScheme),
                          _buildCalcButton('⌫', colorScheme, isSpecial: true)
                        ]),
                        const SizedBox(height: 8),
                        Row(children: [
                          _buildCalcButton('4', colorScheme),
                          _buildCalcButton('5', colorScheme),
                          _buildCalcButton('6', colorScheme),
                          _buildCalcButton('+', colorScheme, isSpecial: true)
                        ]),
                        const SizedBox(height: 8),
                        Row(children: [
                          _buildCalcButton('7', colorScheme),
                          _buildCalcButton('8', colorScheme),
                          _buildCalcButton('9', colorScheme),
                          _buildCalcButton('-', colorScheme, isSpecial: true)
                        ]),
                        const SizedBox(height: 8),
                        Row(children: [
                          _buildCalcButton(',', colorScheme, isSpecial: true),
                          _buildCalcButton('0', colorScheme),
                          _buildCalcButton('C', colorScheme, isSpecial: true),
                          _buildCalcButton('=', colorScheme, isSpecial: true)
                        ]),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Название',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _titleController,
                    onChanged: (value) => _title = value,
                    decoration: InputDecoration(
                        hintText: 'Например: Зарплата, Продукты...',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10))),
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030));
                      if (date != null) setState(() => _selectedDate = date);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                      decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(10)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.calendar_today,
                              color: colorScheme.primary, size: 20),
                          const SizedBox(width: 8),
                          Text(DateFormat('dd.MM.yyyy').format(_selectedDate),
                              style: const TextStyle(fontSize: 16)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Счет',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 300),
                    child: DropdownButtonFormField<Account>(
                      value: _selectedAccount,
                      isExpanded: true,
                      items: _accounts.map((account) {
                        return DropdownMenuItem(
                          value: account,
                          child: Row(
                            children: [
                              Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                      color: account.color.withOpacity(0.2),
                                      shape: BoxShape.circle),
                                  child: Icon(account.icon,
                                      color: account.color, size: 18)),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: Text(account.name,
                                      style: const TextStyle(fontSize: 14),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis)),
                              const SizedBox(width: 8),
                              Text(
                                  '${account.balance.toStringAsFixed(0)} ${account.currency}',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: account.balance >= 0
                                          ? Colors.green
                                          : Colors.red)),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) =>
                          setState(() => _selectedAccount = value),
                      decoration: InputDecoration(
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Checkbox(
                        value: _isRecurring,
                        onChanged: (value) {
                          if (value == true) {
                            _showFrequencyDialog();
                          } else {
                            setState(() => _isRecurring = false);
                          }
                        },
                        activeColor: categoryColor,
                      ),
                      const Text('Регулярный платеж',
                          style: TextStyle(fontSize: 16)),
                      if (_isRecurring) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                              color: categoryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8)),
                          child: Text(
                              _getFrequencyTextFor(
                                  _recurringFrequency, _recurringInterval),
                              style: TextStyle(
                                  fontSize: 12, color: categoryColor)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('Комментарий',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _commentController,
                    onChanged: (value) => _comment = value,
                    maxLines: 3,
                    decoration: InputDecoration(
                        hintText: 'Дополнительная информация...',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10))),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + viewInsets.bottom),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.light
                  ? Colors.white
                  : Colors.grey.shade900,
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -5))
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Удалить транзакцию'),
                            content: const Text('Вы уверены?'),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Отмена')),
                              TextButton(
                                onPressed: () {
                                  widget.onTransactionDeleted(
                                      widget.transaction.id);
                                  Navigator.pop(context);
                                  Navigator.pop(context);
                                },
                                style: TextButton.styleFrom(
                                    foregroundColor: Colors.red),
                                child: const Text('Удалить'),
                              ),
                            ],
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 12)),
                      child:
                          const Text('Удалить', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        String amountForParse = _amount.replaceAll(',', '.');
                        final updatedTransaction = Transaction(
                          id: widget.transaction.id,
                          userId: widget.transaction.userId,
                          title: _titleController.text,
                          amount: double.tryParse(amountForParse) ?? 0,
                          date: _selectedDate,
                          type: _type,
                          category: _selectedCategory?.name ?? 'Другое',
                          subCategory: _selectedSubCategory?.name,
                          accountId: _selectedAccount?.id,
                          comment: _commentController.text,
                          isRecurring: _isRecurring,
                          recurringInterval:
                              _isRecurring ? _recurringInterval : null,
                          recurringFrequency:
                              _isRecurring ? _recurringFrequency : null,
                        );
                        widget.onTransactionUpdated(updatedTransaction);
                        Navigator.pop(context);
                        SnackbarUtils.showSuccess(
                            context, 'Транзакция обновлена');
                      },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12)),
                      child: const Text('Сохранить',
                          style: TextStyle(fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveTransferChanges() async {
    if (_selectedFromAccount == null || _selectedToAccount == null) {
      SnackbarUtils.showError(context, 'Выберите счета для перевода');
      return;
    }
    if (_selectedFromAccount!.id == _selectedToAccount!.id) {
      SnackbarUtils.showError(context, 'Счета должны быть разными');
      return;
    }
    if (_amount.isEmpty) {
      SnackbarUtils.showError(context, 'Введите сумму');
      return;
    }
    final newAmount = double.tryParse(_amount.replaceAll(',', '.')) ?? 0;
    if (newAmount <= 0) {
      SnackbarUtils.showError(context, 'Введите корректную сумму');
      return;
    }

    final updatedTransaction = Transaction(
      id: widget.transaction.id,
      userId: widget.transaction.userId,
      title: '${_selectedFromAccount!.name} → ${_selectedToAccount!.name}',
      amount: newAmount,
      date: _selectedDate,
      type: TransactionType.expense,
      category: 'Перевод',
      subCategory: null,
      accountId: null,
      comment: _commentController.text,
      isRecurring: _isRecurring,
      recurringInterval: _isRecurring ? _recurringInterval : null,
      recurringFrequency: _isRecurring ? _recurringFrequency : null,
      fromAccountId: _selectedFromAccount!.id,
      toAccountId: _selectedToAccount!.id,
    );

    widget.onTransactionUpdated(updatedTransaction);
    Navigator.pop(context);
    SnackbarUtils.showSuccess(context, 'Перевод обновлен');
  }
}
