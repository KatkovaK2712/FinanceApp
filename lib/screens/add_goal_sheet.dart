import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/category_service.dart';
import '../widgets/custom_date_picker.dart';
import '../utils/amount_formatter.dart';
import '../models/models.dart';
import '../utils/snackbar_utils.dart';

class AddGoalSheet extends StatefulWidget {
  final Function(Goal) onGoalAdded;
  final Goal? goalToEdit;
  final List<Account>? accounts;

  const AddGoalSheet({
    super.key,
    required this.onGoalAdded,
    this.goalToEdit,
    this.accounts,
  });

  @override
  State<AddGoalSheet> createState() => _AddGoalSheetState();
}

class _AddGoalSheetState extends State<AddGoalSheet> {
  final _titleController = TextEditingController();
  final _targetAmountController = TextEditingController();
  final _currentAmountController = TextEditingController();

  DateTime _selectedDate = DateTime.now().add(const Duration(days: 30));
  bool _showOnHomeScreen = true;
  Color _selectedColor = Colors.purple;
  IconData _selectedIcon = Icons.flag;
  String? _selectedAccountId; // 'none' или id счёта

  List<Account> _accounts = [];

  @override
  void initState() {
    super.initState();
    _loadAccounts();
    CategoryService.addAccountsListener(_onAccountsChanged);

    if (widget.goalToEdit != null) {
      _titleController.text = widget.goalToEdit!.title;
      _targetAmountController.text =
          AmountFormatter.formatNumber(widget.goalToEdit!.targetAmount);
      _selectedDate = widget.goalToEdit!.targetDate;
      _showOnHomeScreen = widget.goalToEdit!.showOnHomeScreen;
      _selectedColor = widget.goalToEdit!.color;
      _selectedIcon = widget.goalToEdit!.icon;

      // Проверяем, существует ли такой счет
      final accountExists =
          _accounts.any((a) => a.id == widget.goalToEdit!.accountId);
      _selectedAccountId = (widget.goalToEdit!.accountId != null &&
              accountExists)
          ? widget.goalToEdit!.accountId
          : (_accounts.isNotEmpty ? _accounts.first.id : null); // 👈 ИЗМЕНЕНО
    } else {
      _selectedAccountId =
          _accounts.isNotEmpty ? _accounts.first.id : null; // 👈 ИЗМЕНЕНО
    }
  }

  void _onAccountsChanged() {
    _loadAccounts();
    // Обновляем текущую сумму, если выбран счёт
    if (_selectedAccountId != 'none' && _selectedAccountId != null) {
      final selectedAccount = _accounts.firstWhere(
        (a) => a.id == _selectedAccountId,
        orElse: () => null as Account,
      );
      _currentAmountController.text =
          AmountFormatter.formatNumber(selectedAccount.balance);
    }
  }

  Future<void> _loadAccounts() async {
    final accounts = widget.accounts ?? await CategoryService.loadAccounts();
    setState(() {
      _accounts = accounts;
    });

    if (widget.goalToEdit != null && widget.goalToEdit!.accountId != null) {
      final selectedAccount = _accounts.firstWhere(
        (a) => a.id == widget.goalToEdit!.accountId,
        orElse: () => null as Account,
      );
      _currentAmountController.text =
          AmountFormatter.formatNumber(selectedAccount.balance);
    } else if (_accounts.isNotEmpty && _selectedAccountId == null) {
      _selectedAccountId = _accounts.first.id; // 👈 ИЗМЕНЕНО
    }
  }

  @override
  void dispose() {
    CategoryService.removeAccountsListener(_onAccountsChanged);
    _titleController.dispose();
    _targetAmountController.dispose();
    _currentAmountController.dispose();
    super.dispose();
  }

  void _onAmountChanged(String value, TextEditingController controller) {
    String clean = AmountFormatter.validateAndClean(value);
    controller.text = AmountFormatter.formatDisplay(clean);
    controller.selection = TextSelection.fromPosition(
      TextPosition(offset: controller.text.length),
    );
  }

  void _saveGoal() {
    if (_titleController.text.isEmpty) {
      SnackbarUtils.showError(context, 'Введите название цели');
      return;
    }

    double targetAmount =
        AmountFormatter.parseToDouble(_targetAmountController.text);
    double currentAmount =
        AmountFormatter.parseToDouble(_currentAmountController.text);

    final goal = Goal(
      id: widget.goalToEdit?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      title: _titleController.text,
      targetDate: _selectedDate,
      targetAmount: targetAmount,
      currentAmount: currentAmount,
      accountId: _selectedAccountId,
      showOnHomeScreen: _showOnHomeScreen,
      color: _selectedColor,
      icon: _selectedIcon,
    );

    widget.onGoalAdded(goal);
    Navigator.pop(context);
    SnackbarUtils.showSuccess(
        context, widget.goalToEdit == null ? 'Цель создана' : 'Цель обновлена');
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final viewInsets = MediaQuery.of(context).viewInsets;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
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
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              widget.goalToEdit == null ? 'Новая цель' : 'Редактировать цель',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Название
                  const Text('Название',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      hintText: 'Например: Новая машина, Квартира...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  const SizedBox(height: 20),

                  // Сумма цели
                  const Text('Сумма цели',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _targetAmountController,
                    keyboardType: TextInputType.number,
                    onChanged: (value) =>
                        _onAmountChanged(value, _targetAmountController),
                    decoration: InputDecoration(
                      hintText: '0',
                      prefixIcon: const Icon(Icons.flag),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  const SizedBox(height: 12),

                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 18,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'При привязке к счету сумма накоплений будет автоматически отслеживаться по балансу выбранного счета',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.primary,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                  // Счёт для накопления (НОВЫЙ БЛОК)
                  const Text('Счёт для накопления',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedAccountId,
                    isExpanded: true,
                    items: _accounts
                        .map((account) => DropdownMenuItem(
                              value: account.id,
                              child: Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: account.color.withOpacity(0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(account.icon,
                                        color: account.color, size: 18),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      account.name,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ))
                        .toList(),
                    onChanged: (value) async {
                      setState(() => _selectedAccountId = value);
                      if (value != null) {
                        final accounts = await CategoryService.loadAccounts();
                        final selectedAccount =
                            accounts.firstWhere((a) => a.id == value);
                        _currentAmountController.text =
                            AmountFormatter.formatNumber(
                                selectedAccount.balance);
                      }
                    },
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  const SizedBox(height: 20),

                  // Месяц достижения
                  const Text('Месяц достижения',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      showDialog(
                        context: context,
                        builder: (context) => CustomDatePicker(
                          initialDate: _selectedDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2035),
                          onDateSelected: (date) {
                            setState(() => _selectedDate = date);
                          },
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today,
                              color: colorScheme.primary),
                          const SizedBox(width: 12),
                          Text(
                            DateFormat('dd.MM.yyyy').format(_selectedDate),
                            style: const TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Цвет
                  const Text('Цвет',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 40,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: 8,
                      itemBuilder: (context, index) {
                        final colors = [
                          Colors.blue,
                          Colors.green,
                          Colors.red,
                          Colors.purple,
                          Colors.orange,
                          Colors.pink,
                          Colors.teal,
                          Colors.amber
                        ];
                        return GestureDetector(
                          onTap: () =>
                              setState(() => _selectedColor = colors[index]),
                          child: Container(
                            width: 40,
                            height: 40,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: colors[index],
                              shape: BoxShape.circle,
                              border: _selectedColor == colors[index]
                                  ? Border.all(color: Colors.white, width: 3)
                                  : null,
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Иконка
                  const Text('Иконка',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 50,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: 8,
                      itemBuilder: (context, index) {
                        final icons = [
                          Icons.flag,
                          Icons.home,
                          Icons.car_rental,
                          Icons.favorite,
                          Icons.school,
                          Icons.flight,
                          Icons.shopping_bag,
                          Icons.health_and_safety
                        ];
                        return GestureDetector(
                          onTap: () =>
                              setState(() => _selectedIcon = icons[index]),
                          child: Container(
                            width: 50,
                            height: 50,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: _selectedIcon == icons[index]
                                  ? _selectedColor.withOpacity(0.2)
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _selectedIcon == icons[index]
                                    ? _selectedColor
                                    : Colors.grey.shade300,
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              icons[index],
                              color: _selectedIcon == icons[index]
                                  ? _selectedColor
                                  : Colors.grey,
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Показывать на главном экране
                  Row(
                    children: [
                      Switch(
                        value: _showOnHomeScreen,
                        onChanged: (value) =>
                            setState(() => _showOnHomeScreen = value),
                        activeColor: colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Показывать на главном экране',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ],
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
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _saveGoal,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    widget.goalToEdit == null ? 'Создать цель' : 'Сохранить',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
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
