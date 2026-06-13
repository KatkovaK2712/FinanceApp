import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/category_service.dart';
import '../services/transaction_service.dart';
import '../models/transaction_models.dart';
import '../widgets/edit_category_dialog.dart';
import '../widgets/edit_subcategory_dialog.dart';
import '../widgets/custom_date_picker.dart';
import '../services/category_type_service.dart';
import '../models/goal.dart';
import '../services/goal_service.dart';
import '../providers/notification_provider.dart';
import '../models/notification_model.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'dart:async';
import '../utils/snackbar_utils.dart';
import 'add_transaction_sheet.dart';

enum TransactionTab { expense, income, transfer }

typedef TransactionCallback = void Function(Transaction transaction);

class AddTransactionSheet extends StatefulWidget {
  final TransactionCallback onTransactionAdded;

  const AddTransactionSheet({super.key, required this.onTransactionAdded});

  @override
  State<AddTransactionSheet> createState() => _AddTransactionSheetState();
}

class _AddTransactionSheetState extends State<AddTransactionSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  TransactionTab _currentTab = TransactionTab.expense;

  List<Category> _expenseCategories = [];
  List<Category> _incomeCategories = [];
  List<Account> _accounts = [];

  Category? _selectedCategory;
  SubCategory? _selectedSubCategory;

  Account? _selectedFromAccount;
  Account? _selectedToAccount;

  String _amount = '';
  late TextEditingController _amountController;
  String _comment = '';
  late TextEditingController _commentController;
  DateTime _selectedDate = DateTime.now();
  Account? _selectedAccount;
  bool _isRecurring = false;
  Goal? _selectedGoalForTransfer;
  String _operation = '';
  double _firstNumber = 0;
  bool _waitingForSecondNumber = false;
  String _formatAmount(double amount) {
    return '${NumberFormat('#,##0.00', 'ru_RU').format(amount)} ₽';
  }

  final List<Category> _hiddenExpenseCategories = [];
  final List<Category> _hiddenIncomeCategories = [];
  final Map<String, List<SubCategory>> _hiddenExpenseSubCategories = {};
  final Map<String, List<SubCategory>> _hiddenIncomeSubCategories = {};

  String _recurringFrequency = 'month';
  int _recurringInterval = 1;
  final List<Color> availableColors = [
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

  void _loadDefaultCategories() {
    _expenseCategories = [
      Category(
        id: 'exp_food',
        name: 'Продукты',
        icon: Icons.restaurant,
        color: Colors.orange,
        subCategories: [
          SubCategory(
            id: 'food_products',
            name: 'Супермаркет',
            icon: Icons.shopping_cart,
            color: Colors.orange,
          ),
          SubCategory(
            id: 'food_cafe',
            name: 'Кафе',
            icon: Icons.local_cafe,
            color: Colors.orange,
          ),
        ],
      ),
      Category(
        id: 'exp_transport',
        name: 'Транспорт',
        icon: Icons.directions_car,
        color: Colors.blue,
        subCategories: [
          SubCategory(
            id: 'trans_public',
            name: 'Общественный',
            icon: Icons.directions_bus,
            color: Colors.blue,
          ),
          SubCategory(
            id: 'trans_taxi',
            name: 'Такси',
            icon: Icons.taxi_alert,
            color: Colors.blue,
          ),
        ],
      ),
      Category(
        id: 'exp_entertainment',
        name: 'Развлечения',
        icon: Icons.movie,
        color: Colors.purple,
        subCategories: [
          SubCategory(
            id: 'ent_cinema',
            name: 'Кино',
            icon: Icons.movie,
            color: Colors.purple,
          ),
          SubCategory(
            id: 'ent_games',
            name: 'Игры',
            icon: Icons.games,
            color: Colors.purple,
          ),
        ],
      ),
    ];

    _incomeCategories = [
      Category(
        id: 'inc_salary',
        name: 'Зарплата',
        icon: Icons.work,
        color: Colors.green,
        subCategories: [
          SubCategory(
            id: 'salary_main',
            name: 'Основная',
            icon: Icons.work,
            color: Colors.green,
          ),
          SubCategory(
            id: 'salary_bonus',
            name: 'Премия',
            icon: Icons.emoji_events,
            color: Colors.green,
          ),
        ],
      ),
      Category(
        id: 'inc_freelance',
        name: 'Фриланс',
        icon: Icons.computer,
        color: Colors.teal,
        subCategories: [],
      ),
    ];
  }

  Color _getDefaultColorForType(
    AccountType type,
    List<Account> existingAccounts,
  ) {
    final Map<AccountType, List<Color>> preferredColors = {
      AccountType.cash: [Colors.green, Colors.lightGreen, Colors.teal],
      AccountType.debitCard: [
        Colors.blue,
        Colors.lightBlue,
        Colors.cyan,
        Colors.indigo,
      ],
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
    final preferred = preferredColors[type] ?? [Colors.grey];

    for (var color in preferred) {
      if (!usedColors.contains(color)) {
        return color;
      }
    }

    for (var color in availableColors) {
      if (!usedColors.contains(color)) {
        return color;
      }
    }

    return preferred.first;
  }

  void _showFrequencyDialog() {
    int tempInterval = _recurringInterval;
    String tempFrequency = _recurringFrequency;
    final intervalController = TextEditingController(
      text: tempInterval.toString(),
    );

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
                              horizontal: 8,
                              vertical: 8,
                            ),
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
                            value: 'week',
                            child: Text('неделю'),
                          ),
                          DropdownMenuItem(
                            value: 'month',
                            child: Text('месяц'),
                          ),
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
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Платеж будет повторяться $tempInterval ${_getFrequencyTextFor(tempFrequency, tempInterval)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.primary,
                      ),
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
    String everyWord;
    if (frequency == 'week' && interval == 1) {
      everyWord = 'каждую';
    } else if (interval == 1) {
      everyWord = 'каждый';
    } else {
      everyWord = 'каждые';
    }

    String unitWord;
    switch (frequency) {
      case 'day':
        if (interval == 1)
          unitWord = 'день';
        else if (interval >= 2 && interval <= 4)
          unitWord = 'дня';
        else
          unitWord = 'дней';
        break;
      case 'week':
        if (interval == 1)
          unitWord = 'неделю';
        else if (interval >= 2 && interval <= 4)
          unitWord = 'недели';
        else
          unitWord = 'недель';
        break;
      case 'month':
        if (interval == 1)
          unitWord = 'месяц';
        else if (interval >= 2 && interval <= 4)
          unitWord = 'месяца';
        else
          unitWord = 'месяцев';
        break;
      case 'year':
        if (interval == 1)
          unitWord = 'год';
        else if (interval >= 2 && interval <= 4)
          unitWord = 'года';
        else
          unitWord = 'лет';
        break;
      default:
        unitWord = 'месяц';
    }

    if (interval == 1) {
      return '$everyWord $unitWord';
    } else {
      return '$everyWord $interval $unitWord';
    }
  }

  String _getFrequencyText() {
    return _getFrequencyTextFor(_recurringFrequency, _recurringInterval);
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _currentTab = TransactionTab.values[_tabController.index];
        _selectedCategory = null;
        _selectedSubCategory = null;
        _selectedFromAccount = null;
        _selectedToAccount = null;
      });
    });

    _loadData();
    _amountController = TextEditingController();
    _commentController = TextEditingController();
    CategoryService.addAccountsListener(_onAccountsChanged);
  }

  Future<void> _loadData() async {
    final categories = await CategoryService.loadCategories();
    final accounts = await CategoryService.loadAccounts();

    final categoryTypes = await CategoryTypeService.getCategoryTypes();

    setState(() {
      _expenseCategories = [];
      _incomeCategories = [];

      for (var category in categories) {
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
        } else {
          _incomeCategories.add(category);
        }
      }

      if (_expenseCategories.isEmpty && _incomeCategories.isEmpty) {
        _loadDefaultCategories();
      }

      _accounts = accounts
          .fold<Map<String, Account>>({}, (map, account) {
            map[account.id] = account;
            return map;
          })
          .values
          .toList();

      _hiddenExpenseCategories.clear();
      _hiddenExpenseSubCategories.clear();
      _hiddenIncomeCategories.clear();
      _hiddenIncomeSubCategories.clear();

      for (var category in _expenseCategories) {
        if (category.isHidden) {
          _hiddenExpenseCategories.add(category);
          for (var sub in category.subCategories) {
            if (sub.isHidden) {
              if (!_hiddenExpenseSubCategories.containsKey(category.id)) {
                _hiddenExpenseSubCategories[category.id] = [];
              }
              _hiddenExpenseSubCategories[category.id]!.add(sub);
            }
          }
        }
      }

      for (var category in _incomeCategories) {
        if (category.isHidden) {
          _hiddenIncomeCategories.add(category);
          for (var sub in category.subCategories) {
            if (sub.isHidden) {
              if (!_hiddenIncomeSubCategories.containsKey(category.id)) {
                _hiddenIncomeSubCategories[category.id] = [];
              }
              _hiddenIncomeSubCategories[category.id]!.add(sub);
            }
          }
        }
      }

      if (_accounts.isNotEmpty) {
        var mainAccount = _accounts.firstWhere(
          (a) => a.type == AccountType.debitCard,
          orElse: () => _accounts.firstWhere(
            (a) => a.type == AccountType.cash,
            orElse: () => _accounts.first,
          ),
        );
        _selectedAccount = mainAccount;
      }
    });
  }

  void _onAccountsChanged() {
    print('🔄 AddTransactionSheet: обновление счетов');
    _loadAccountsOnly();
  }

  Future<void> _loadAccountsOnly() async {
    final accounts = await CategoryService.loadAccounts();

    // Фильтруем счета для текущего типа транзакции
    List<Account> filteredAccounts;

    if (_currentTab == TransactionTab.expense) {
      // Для расходов - показываем счета с возможностью снятия (allowWithdraw)
      filteredAccounts = accounts
          .where(
            (a) =>
                a.type != AccountType.loan &&
                (a.type != AccountType.deposit || (a.allowWithdraw ?? true)) &&
                (a.type != AccountType.debtOwed &&
                    a.type != AccountType.debtToPay), // долги тоже исключаем
          )
          .toList();
    } else if (_currentTab == TransactionTab.income) {
      // Для доходов - показываем счета с возможностью пополнения (allowDeposit)
      filteredAccounts = accounts
          .where(
            (a) =>
                a.type != AccountType.loan &&
                (a.type != AccountType.deposit || (a.allowDeposit ?? true)) &&
                (a.type != AccountType.debtOwed &&
                    a.type != AccountType.debtToPay), // долги тоже исключаем
          )
          .toList();
    } else {
      // Для переводов - отдельная логика в _buildTransferAccounts
      filteredAccounts = accounts;
    }

    // Убираем дубликаты по id
    final uniqueAccounts = filteredAccounts
        .fold<Map<String, Account>>({}, (map, account) {
          map[account.id] = account;
          return map;
        })
        .values
        .toList();

    // Сохраняем id текущего выбранного счета
    final String? selectedAccountId = _selectedAccount?.id;

    setState(() {
      _accounts = uniqueAccounts;

      // Если был выбран какой-то счет — ищем его в новом списке
      if (selectedAccountId != null) {
        try {
          _selectedAccount = _accounts.firstWhere(
            (a) => a.id == selectedAccountId,
          );
        } catch (e) {
          // Если не нашли — сбрасываем
          _selectedAccount = null;
        }
      }

      // Если счет не выбран и список не пуст — выбираем подходящий
      if (_selectedAccount == null && _accounts.isNotEmpty) {
        try {
          _selectedAccount = _accounts.firstWhere(
            (a) => a.type == AccountType.debitCard,
          );
        } catch (e) {
          try {
            _selectedAccount = _accounts.firstWhere(
              (a) => a.type == AccountType.cash,
            );
          } catch (e) {
            _selectedAccount = _accounts.first;
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _amountController.dispose();
    _commentController.dispose();
    CategoryService.removeAccountsListener(_onAccountsChanged);
    super.dispose();
  }

  Future<void> _saveAllCategories() async {
    final allCategories = [..._expenseCategories, ..._incomeCategories];
    await CategoryService.saveCategories(allCategories);
  }

  Future<void> _saveAllAccounts() async {
    await CategoryService.saveAccounts(_accounts);
  }

  void _editCategory(Category category, bool isExpense) {
    showDialog(
      context: context,
      builder: (context) => EditCategoryDialog(
        category: category,
        onSave: (updated) async {
          setState(() {
            if (isExpense) {
              final index = _expenseCategories.indexWhere(
                (c) => c.id == updated.id,
              );
              if (index != -1) _expenseCategories[index] = updated;
            } else {
              final index = _incomeCategories.indexWhere(
                (c) => c.id == updated.id,
              );
              if (index != -1) _incomeCategories[index] = updated;
            }
          });
          await _saveAllCategories();
        },
      ),
    );
  }

  void _deleteCategory(Category category, bool isExpense) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить категорию'),
        content: const Text(
          'Все подкатегории также будут удалены. Вы уверены?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () async {
              setState(() {
                if (isExpense) {
                  _expenseCategories.removeWhere((c) => c.id == category.id);
                } else {
                  _incomeCategories.removeWhere((c) => c.id == category.id);
                }
              });
              await _saveAllCategories();
              if (mounted) {
                Navigator.pop(context);
                SnackbarUtils.showWarning(context, 'Категория удалена');
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
  }

  void _hideCategory(Category category, bool isExpense) {
    setState(() {
      category.isHidden = true;
      if (isExpense) {
        _hiddenExpenseCategories.add(category);
        if (!_hiddenExpenseSubCategories.containsKey(category.id)) {
          _hiddenExpenseSubCategories[category.id] = [];
        }
        for (var sub in category.subCategories) {
          sub.isHidden = true;
          if (!_hiddenExpenseSubCategories[category.id]!.contains(sub)) {
            _hiddenExpenseSubCategories[category.id]!.add(sub);
          }
        }
      } else {
        _hiddenIncomeCategories.add(category);
        if (!_hiddenIncomeSubCategories.containsKey(category.id)) {
          _hiddenIncomeSubCategories[category.id] = [];
        }
        for (var sub in category.subCategories) {
          sub.isHidden = true;
          if (!_hiddenIncomeSubCategories[category.id]!.contains(sub)) {
            _hiddenIncomeSubCategories[category.id]!.add(sub);
          }
        }
      }
    });
    _saveAllCategories();
    SnackbarUtils.showInfo(context, 'Категория скрыта');
  }

  void _restoreCategory(Category category, bool isExpense) {
    setState(() {
      category.isHidden = false;
      if (isExpense) {
        _hiddenExpenseCategories.remove(category);
        for (var sub in category.subCategories) {
          sub.isHidden = false;
          _hiddenExpenseSubCategories[category.id]?.remove(sub);
        }
        if (_hiddenExpenseSubCategories[category.id]?.isEmpty ?? false) {
          _hiddenExpenseSubCategories.remove(category.id);
        }
      } else {
        _hiddenIncomeCategories.remove(category);
        for (var sub in category.subCategories) {
          sub.isHidden = false;
          _hiddenIncomeSubCategories[category.id]?.remove(sub);
        }
        if (_hiddenIncomeSubCategories[category.id]?.isEmpty ?? false) {
          _hiddenIncomeSubCategories.remove(category.id);
        }
      }
    });
    _saveAllCategories();
  }

  void _editSubCategory(SubCategory subCategory, Category parent) {
    showDialog(
      context: context,
      builder: (context) => EditSubCategoryDialog(
        subCategory: subCategory,
        parentCategory: parent,
        onSave: (updated) async {
          setState(() {
            final index = parent.subCategories.indexWhere(
              (s) => s.id == updated.id,
            );
            if (index != -1) parent.subCategories[index] = updated;
          });
          await _saveAllCategories();
        },
      ),
    );
  }

  void _deleteSubCategory(SubCategory subCategory, Category parent) {
    setState(() {
      parent.subCategories.removeWhere((s) => s.id == subCategory.id);
    });
    _saveAllCategories();
    SnackbarUtils.showWarning(context, 'Подкатегория удалена');
  }

  void _hideSubCategory(SubCategory subCategory, Category parent) {
    setState(() {
      subCategory.isHidden = true;
      if (_currentTab == TransactionTab.expense) {
        if (!_hiddenExpenseSubCategories.containsKey(parent.id)) {
          _hiddenExpenseSubCategories[parent.id] = [];
        }
        if (!_hiddenExpenseSubCategories[parent.id]!.contains(subCategory)) {
          _hiddenExpenseSubCategories[parent.id]!.add(subCategory);
        }
      } else {
        if (!_hiddenIncomeSubCategories.containsKey(parent.id)) {
          _hiddenIncomeSubCategories[parent.id] = [];
        }
        if (!_hiddenIncomeSubCategories[parent.id]!.contains(subCategory)) {
          _hiddenIncomeSubCategories[parent.id]!.add(subCategory);
        }
      }
    });
    _saveAllCategories();
    SnackbarUtils.showInfo(context, 'Подкатегория скрыта');
  }

  void _restoreSubCategory(
    SubCategory subCategory,
    Category parent,
    bool isExpense,
  ) {
    setState(() {
      parent.isHidden = false;
      subCategory.isHidden = false;
      if (isExpense) {
        _hiddenExpenseCategories.remove(parent);
        _hiddenExpenseSubCategories[parent.id]?.remove(subCategory);
        if (_hiddenExpenseSubCategories[parent.id]?.isEmpty ?? false) {
          _hiddenExpenseSubCategories.remove(parent.id);
        }
      } else {
        _hiddenIncomeCategories.remove(parent);
        _hiddenIncomeSubCategories[parent.id]?.remove(subCategory);
        if (_hiddenIncomeSubCategories[parent.id]?.isEmpty ?? false) {
          _hiddenIncomeSubCategories.remove(parent.id);
        }
      }
    });
    _saveAllCategories();
  }

  void _showRestoreDialog(bool isExpense) {
    final categories = isExpense ? _expenseCategories : _incomeCategories;
    final color = isExpense ? Colors.red.shade300 : Colors.green.shade300;
    final hiddenCategories = isExpense
        ? _hiddenExpenseCategories
        : _hiddenIncomeCategories;
    final hiddenSubCategories = isExpense
        ? _hiddenExpenseSubCategories
        : _hiddenIncomeSubCategories;

    final selectedCategories = <Category>{};
    final selectedSubIds = <String>{};

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Восстановить скрытые'),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: ListView(
                  children: [
                    if (hiddenCategories.isNotEmpty) ...[
                      const Text(
                        'Категории:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      ...hiddenCategories.map(
                        (category) => Container(
                          margin: const EdgeInsets.symmetric(vertical: 2),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: selectedCategories.contains(category)
                                ? color.withOpacity(0.2)
                                : null,
                          ),
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                if (selectedCategories.contains(category)) {
                                  selectedCategories.remove(category);
                                  for (var sub in category.subCategories) {
                                    selectedSubIds.remove(sub.id);
                                  }
                                } else {
                                  selectedCategories.add(category);
                                  for (var sub in category.subCategories) {
                                    selectedSubIds.add(sub.id);
                                  }
                                }
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 8,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color:
                                            selectedCategories.contains(
                                              category,
                                            )
                                            ? color
                                            : Colors.grey.shade400,
                                        width: 2,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                      color:
                                          selectedCategories.contains(category)
                                          ? color
                                          : Colors.transparent,
                                    ),
                                    child: selectedCategories.contains(category)
                                        ? Center(
                                            child: Icon(
                                              Icons.check,
                                              size: 18,
                                              color: Colors.white,
                                            ),
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 12),
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: category.color.withOpacity(0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      category.icon,
                                      color: category.color,
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      category.name,
                                      style: TextStyle(
                                        fontWeight:
                                            selectedCategories.contains(
                                              category,
                                            )
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                  if (selectedCategories.contains(category))
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: color,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '${category.subCategories.length}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (hiddenSubCategories.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Подкатегории:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      ...hiddenSubCategories.entries.expand((entry) {
                        final category = categories.firstWhere(
                          (c) => c.id == entry.key,
                        );
                        return entry.value.map((sub) {
                          final isCategorySelected = selectedCategories
                              .contains(category);
                          return Container(
                            margin: const EdgeInsets.symmetric(vertical: 2),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: selectedSubIds.contains(sub.id)
                                  ? color.withOpacity(0.2)
                                  : null,
                            ),
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  if (selectedSubIds.contains(sub.id)) {
                                    selectedSubIds.remove(sub.id);
                                  } else {
                                    selectedSubIds.add(sub.id);
                                  }
                                });
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 8,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 20,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color:
                                              selectedSubIds.contains(sub.id) ||
                                                  isCategorySelected
                                              ? color
                                              : Colors.grey.shade400,
                                          width: 2,
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                        color:
                                            selectedSubIds.contains(sub.id) ||
                                                isCategorySelected
                                            ? color
                                            : Colors.transparent,
                                      ),
                                      child:
                                          selectedSubIds.contains(sub.id) ||
                                              isCategorySelected
                                          ? Center(
                                              child: Icon(
                                                Icons.check,
                                                size: 14,
                                                color: Colors.white,
                                              ),
                                            )
                                          : null,
                                    ),
                                    const SizedBox(width: 12),
                                    Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color: sub.color.withOpacity(0.2),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        sub.icon,
                                        color: sub.color,
                                        size: 14,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '${category.name} → ${sub.name}',
                                        style: TextStyle(
                                          fontWeight:
                                              selectedSubIds.contains(sub.id) ||
                                                  isCategorySelected
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                          color:
                                              isCategorySelected &&
                                                  !selectedSubIds.contains(
                                                    sub.id,
                                                  )
                                              ? Colors.grey
                                              : null,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        });
                      }),
                    ],
                    if (hiddenCategories.isEmpty && hiddenSubCategories.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Text('Нет скрытых элементов'),
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Отмена'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    for (var category in selectedCategories) {
                      _restoreCategory(category, isExpense);
                    }
                    for (var subId in selectedSubIds) {
                      bool alreadyRestored = false;
                      for (var category in selectedCategories) {
                        if (category.subCategories.any((s) => s.id == subId)) {
                          alreadyRestored = true;
                          break;
                        }
                      }
                      if (!alreadyRestored) {
                        for (var entry in hiddenSubCategories.entries) {
                          final category = categories.firstWhere(
                            (c) => c.id == entry.key,
                          );
                          final sub = entry.value.firstWhere(
                            (s) => s.id == subId,
                            orElse: () => null as SubCategory,
                          );
                          _restoreSubCategory(sub, category, isExpense);
                          break;
                        }
                      }
                    }
                    await _saveAllCategories();
                    if (mounted) {
                      Navigator.pop(context);
                      SnackbarUtils.showSuccess(
                        context,
                        'Восстановлено ${selectedCategories.length + selectedSubIds.length} элементов',
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(
                    'Восстановить (${selectedCategories.length + selectedSubIds.length})',
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddCategoryDialog(Color categoryColor) {
    final nameController = TextEditingController();
    IconData selectedIcon = Icons.category;
    Color selectedColor = categoryColor;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 24,
            ),
            child: Container(
              padding: const EdgeInsets.all(20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Новая категория',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameController,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Название категории',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Выберите иконку:'),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 100,
                      child: GridView.builder(
                        shrinkWrap: true,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 5,
                              childAspectRatio: 1,
                            ),
                        itemCount: availableIcons.length,
                        itemBuilder: (context, index) {
                          final iconInfo = availableIcons[index];
                          return IconButton(
                            icon: Icon(iconInfo.icon),
                            color: selectedIcon == iconInfo.icon
                                ? selectedColor
                                : null,
                            onPressed: () =>
                                setState(() => selectedIcon = iconInfo.icon),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Выберите цвет:'),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 50,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: availableColors.length,
                        itemBuilder: (context, index) {
                          final color = availableColors[index];
                          return GestureDetector(
                            onTap: () => setState(() => selectedColor = color),
                            child: Container(
                              width: 40,
                              height: 40,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: selectedColor == color
                                    ? Border.all(color: Colors.white, width: 3)
                                    : null,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Отмена'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () async {
                            if (nameController.text.isNotEmpty) {
                              final newCategory = Category(
                                id: 'cat_${DateTime.now().millisecondsSinceEpoch}',
                                name: nameController.text,
                                icon: selectedIcon,
                                color: selectedColor,
                                subCategories: [],
                              );

                              // ✅ ОБНОВЛЯЕМ ЛОКАЛЬНЫЙ СПИСОК
                              setState(() {
                                if (_currentTab == TransactionTab.expense) {
                                  _expenseCategories.add(newCategory);
                                } else {
                                  _incomeCategories.add(newCategory);
                                }
                              });

                              // ✅ СОХРАНЯЕМ ВСЕ КАТЕГОРИИ В CategoryService
                              final allCategories = [
                                ..._expenseCategories,
                                ..._incomeCategories,
                              ];
                              await CategoryService.saveCategories(
                                allCategories,
                              );

                              if (mounted) {
                                Navigator.pop(context);
                                SnackbarUtils.showSuccess(
                                  context,
                                  'Категория добавлена',
                                );
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: selectedColor,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Добавить'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showAddSubCategoryDialog(Category category, Color color) {
    final nameController = TextEditingController();
    IconData selectedIcon = category.icon;
    Color selectedColor = category.color;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 24,
            ),
            child: Container(
              padding: const EdgeInsets.all(20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Новая подкатегория для ${category.name}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameController,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Название',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Выберите иконку:'),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 100,
                      child: GridView.builder(
                        shrinkWrap: true,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 5,
                              childAspectRatio: 1,
                            ),
                        itemCount: availableIcons.length,
                        itemBuilder: (context, index) {
                          final iconInfo = availableIcons[index];
                          return IconButton(
                            icon: Icon(iconInfo.icon),
                            color: selectedIcon == iconInfo.icon
                                ? selectedColor
                                : null,
                            onPressed: () =>
                                setState(() => selectedIcon = iconInfo.icon),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Выберите цвет:'),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 50,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: availableColors.length,
                        itemBuilder: (context, index) {
                          final color = availableColors[index];
                          return GestureDetector(
                            onTap: () => setState(() => selectedColor = color),
                            child: Container(
                              width: 40,
                              height: 40,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: selectedColor == color
                                    ? Border.all(color: Colors.white, width: 3)
                                    : null,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Отмена'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () async {
                            if (nameController.text.isNotEmpty) {
                              final newSubCategory = SubCategory(
                                id: '${category.id}_sub${category.subCategories.length}',
                                name: nameController.text,
                                icon: selectedIcon,
                                color: selectedColor,
                              );
                              setState(
                                () =>
                                    category.subCategories.add(newSubCategory),
                              );
                              await _saveAllCategories();
                              if (mounted) {
                                Navigator.pop(context);
                                SnackbarUtils.showSuccess(
                                  context,
                                  'Подкатегория добавлена',
                                );
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: selectedColor,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Добавить'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showAddAccountDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return const AddAccountDialogContent();
      },
    );
  }

  Widget _buildCategorySelection() {
    if (_currentTab == TransactionTab.transfer) {
      return _buildTransferAccounts();
    }

    final categories = _currentTab == TransactionTab.expense
        ? _expenseCategories
        : _incomeCategories;
    final isExpense = _currentTab == TransactionTab.expense;
    final colorScheme = Theme.of(context).colorScheme;

    final hiddenCategories = isExpense
        ? _hiddenExpenseCategories
        : _hiddenIncomeCategories;
    final hiddenSubCategories = isExpense
        ? _hiddenExpenseSubCategories
        : _hiddenIncomeSubCategories;
    final hasHidden =
        hiddenCategories.isNotEmpty || hiddenSubCategories.isNotEmpty;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showAddCategoryDialog(colorScheme.primary),
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text(
                    'Добавить категорию',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    minimumSize: const Size(double.infinity, 50),
                  ),
                ),
              ),
              if (hasHidden)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: IconButton(
                    icon: const Icon(Icons.visibility, color: Colors.white),
                    onPressed: () => _showRestoreDialog(isExpense),
                    style: IconButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      padding: const EdgeInsets.all(12),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: categories.length,
            onReorder: (oldIndex, newIndex) {
              setState(() {
                if (newIndex > oldIndex) {
                  newIndex--;
                }
                final item = categories.removeAt(oldIndex);
                categories.insert(newIndex, item);
              });
              _saveAllCategories();
            },
            itemBuilder: (context, index) {
              final category = categories[index];
              if (category.isHidden) return const SizedBox.shrink();

              return Dismissible(
                key: Key('cat_${category.id}'),
                direction: DismissDirection.horizontal,
                background: Container(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.only(left: 20),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.edit, color: Colors.white, size: 24),
                      const SizedBox(width: 8),
                      const Text(
                        'Ред.',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                secondaryBackground: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  decoration: BoxDecoration(
                    color: Colors.red.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Удал.',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.delete, color: Colors.white, size: 24),
                    ],
                  ),
                ),
                confirmDismiss: (direction) async {
                  if (direction == DismissDirection.endToStart) {
                    final confirm = await showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Удалить категорию'),
                        content: const Text(
                          'Все подкатегории также будут удалены. Вы уверены?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Отмена'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                            child: const Text('Удалить'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) _deleteCategory(category, isExpense);
                    return false;
                  } else {
                    _editCategory(category, isExpense);
                    return false;
                  }
                },
                child: Card(
                  key: Key('cat_${category.id}'),
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 2,
                  child: Column(
                    children: [
                      // КАТЕГОРИЯ
                      InkWell(
                        onTap: () =>
                            setState(() => _selectedCategory = category),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.drag_handle, color: Colors.grey),
                              const SizedBox(width: 8),
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: category.color.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  category.icon,
                                  color: category.color,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  category.name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.add,
                                  color: Colors.white,
                                ),
                                onPressed: () => _showAddSubCategoryDialog(
                                  category,
                                  colorScheme.primary,
                                ),
                                style: IconButton.styleFrom(
                                  backgroundColor: colorScheme.primary,
                                  padding: const EdgeInsets.all(8),
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 36,
                                  minHeight: 36,
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: Icon(
                                  category.isHidden
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: Colors.white,
                                ),
                                onPressed: () =>
                                    _hideCategory(category, isExpense),
                                style: IconButton.styleFrom(
                                  backgroundColor: category.isHidden
                                      ? Colors.grey.shade400
                                      : colorScheme.primary,
                                  padding: const EdgeInsets.all(8),
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 36,
                                  minHeight: 36,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // ПОДКАТЕГОРИИ
                      if (category.subCategories.isNotEmpty)
                        Column(
                          children: category.subCategories.map((sub) {
                            if (sub.isHidden) return const SizedBox.shrink();
                            return Dismissible(
                              key: Key('sub_${sub.id}'),
                              direction: DismissDirection.horizontal,
                              background: Container(
                                alignment: Alignment.centerLeft,
                                padding: const EdgeInsets.only(left: 20),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade200,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.edit,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Ред.',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              secondaryBackground: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade200,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(
                                      'Удал.',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(
                                      Icons.delete,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ],
                                ),
                              ),
                              confirmDismiss: (direction) async {
                                if (direction == DismissDirection.endToStart) {
                                  final confirm = await showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Удалить подкатегорию'),
                                      content: const Text('Вы уверены?'),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, false),
                                          child: const Text('Отмена'),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, true),
                                          style: TextButton.styleFrom(
                                            foregroundColor: Colors.red,
                                          ),
                                          child: const Text('Удалить'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirm == true)
                                    _deleteSubCategory(sub, category);
                                  return false;
                                } else {
                                  _editSubCategory(sub, category);
                                  return false;
                                }
                              },
                              child: InkWell(
                                onTap: () => setState(() {
                                  _selectedCategory = category;
                                  _selectedSubCategory = sub;
                                }),
                                child: Padding(
                                  padding: const EdgeInsets.only(
                                    left: 64,
                                    right: 12,
                                    bottom: 8,
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          color: sub.color.withOpacity(0.2),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          sub.icon,
                                          color: sub.color,
                                          size: 18,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          sub.name,
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          Icons.visibility_off,
                                          size: 18,
                                          color: Colors.grey,
                                        ),
                                        onPressed: () =>
                                            _hideSubCategory(sub, category),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // Получить счета для списания (from) - исключаем кредиты и вклады без снятия
  List<Account> _getFromAccounts() {
    return _accounts
        .where(
          (a) =>
              a.type !=
                  AccountType
                      .loan && // кредиты нельзя использовать для списания
              (a.type != AccountType.deposit ||
                  (a.allowWithdraw ??
                      true)), // вклады только если разрешено снятие
        )
        .toList();
  }

  // Получить счета для зачисления (to) - исключаем вклады без пополнения
  List<Account> _getToAccounts() {
    return _accounts
        .where(
          (a) =>
              a.type !=
                  AccountType
                      .loan && // кредиты нельзя использовать для зачисления (кредит - это долг)
              (a.type != AccountType.deposit ||
                  (a.allowDeposit ??
                      true)), // вклады только если разрешено пополнение
        )
        .toList();
  }

  Widget _buildTransferAccounts() {
    final colorScheme = Theme.of(context).colorScheme;

    // Получаем выбранный счет для списания
    final selectedFromId = _selectedFromAccount?.id;

    // Фильтруем счета для списания (from) - исключаем кредиты
    List<Account> fromAccounts = _accounts
        .where((a) => a.type != AccountType.loan)
        .toList();

    // Фильтруем счета для зачисления (to)
    List<Account> toAccounts = _accounts;

    // Если выбран счет "долг мне" (debtOwed) для списания, исключаем кредиты из списка зачисления
    if (_selectedFromAccount?.type == AccountType.debtOwed) {
      toAccounts = _accounts.where((a) => a.type != AccountType.loan).toList();
    }

    // Если выбран счет "кредит" для зачисления, исключаем "долг мне" из списка списания
    if (_selectedToAccount?.type == AccountType.loan) {
      fromAccounts = _accounts
          .where((a) => a.type != AccountType.debtOwed)
          .toList();
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: ElevatedButton.icon(
            onPressed: _showAddAccountDialog,
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text(
              'Добавить новый счет',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              minimumSize: const Size(double.infinity, 50),
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Списать с:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...fromAccounts.map(
                (account) => _buildAccountTile(
                  account,
                  isSelected: _selectedFromAccount?.id == account.id,
                  onTap: () {
                    setState(() {
                      _selectedFromAccount = account;
                      // При смене счета списания сбрасываем выбранный счет зачисления
                      _selectedToAccount = null;
                    });
                  },
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Перевести на:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...toAccounts.map(
                (account) => _buildAccountTile(
                  account,
                  isSelected: _selectedToAccount?.id == account.id,
                  onTap: () => setState(() => _selectedToAccount = account),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAccountTile(
    Account account, {
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: account.color.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(account.icon, color: account.color, size: 24),
        ),
        title: Text(account.name),
        subtitle: Text(
          '${account.balance.toStringAsFixed(2)} ${account.currency} • ${account.type.displayName}',
          style: TextStyle(
            color: account.balance >= 0 ? Colors.green : Colors.red,
          ),
        ),
        trailing: isSelected
            ? Icon(Icons.check_circle, color: Colors.green)
            : null,
        onTap: onTap,
      ),
    );
  }

  Widget _buildTransactionDetails(double bottomPadding) {
    final color = _currentTab == TransactionTab.expense
        ? Colors.red
        : Colors.green;
    final colorScheme = Theme.of(context).colorScheme;

    if (_selectedCategory == null) {
      return const Center(child: Text('Выберите категорию'));
    }

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 80,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: _selectedCategory!.color.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _selectedCategory!.icon,
                          color: _selectedCategory!.color,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedCategory!.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (_selectedSubCategory != null)
                              Row(
                                children: [
                                  Container(
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      color: _selectedSubCategory!.color
                                          .withOpacity(0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      _selectedSubCategory!.icon,
                                      color: _selectedSubCategory!.color,
                                      size: 14,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _selectedSubCategory!.name,
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _selectedCategory = null;
                            _selectedSubCategory = null;
                          });
                        },
                        child: const Text('Изменить'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Сумма',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: colorScheme.primary.withOpacity(0.3),
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: _amountController,
                    readOnly: true,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      hintText: '0',
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: colorScheme.primary.withOpacity(0.2),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          _buildCalcButton('1', colorScheme),
                          _buildCalcButton('2', colorScheme),
                          _buildCalcButton('3', colorScheme),
                          _buildCalcButton('⌫', colorScheme, isSpecial: true),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildCalcButton('4', colorScheme),
                          _buildCalcButton('5', colorScheme),
                          _buildCalcButton('6', colorScheme),
                          _buildCalcButton('+', colorScheme, isSpecial: true),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildCalcButton('7', colorScheme),
                          _buildCalcButton('8', colorScheme),
                          _buildCalcButton('9', colorScheme),
                          _buildCalcButton('-', colorScheme, isSpecial: true),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildCalcButton(',', colorScheme, isSpecial: true),
                          _buildCalcButton('0', colorScheme),
                          _buildCalcButton('C', colorScheme, isSpecial: true),
                          _buildCalcButton('=', colorScheme, isSpecial: true),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          showDialog(
                            context: context,
                            builder: (context) => CustomDatePicker(
                              initialDate: _selectedDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                              onDateSelected: (date) {
                                setState(() => _selectedDate = date);
                              },
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.calendar_today,
                                color: colorScheme.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                DateFormat('dd.MM.yyyy').format(_selectedDate),
                                style: const TextStyle(fontSize: 16),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'Счет',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonFormField<String>(
                    value: _selectedAccount?.id,
                    isExpanded: true,
                    items: _accounts
                        .where(
                          (a) =>
                              a.type != AccountType.loan &&
                              (a.type != AccountType.deposit ||
                                  (_currentTab == TransactionTab.income
                                      ? (a.allowDeposit ?? true)
                                      : (a.allowWithdraw ?? true))),
                        )
                        .map(
                          (account) => DropdownMenuItem<String>(
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
                                  child: Icon(
                                    account.icon,
                                    color: account.color,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    account.name,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (account.type == AccountType.deposit) ...[
                                  const SizedBox(width: 8),
                                  Icon(
                                    Icons.info_outline,
                                    size: 14,
                                    color: Colors.grey,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      final selectedAccount = _accounts.firstWhere(
                        (a) => a.id == value,
                      );
                      setState(() => _selectedAccount = selectedAccount);
                    },
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                    ),
                    selectedItemBuilder: (context) {
                      return _accounts
                          .where(
                            (a) =>
                                a.type != AccountType.loan &&
                                (a.type != AccountType.deposit ||
                                    (_currentTab == TransactionTab.income
                                        ? (a.allowDeposit ?? true)
                                        : (a.allowWithdraw ?? true))),
                          )
                          .map((account) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: account.color.withOpacity(0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      account.icon,
                                      color: account.color,
                                      size: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      account.name,
                                      style: const TextStyle(fontSize: 14),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    '${account.balance.toStringAsFixed(0)} ${account.currency}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: account.balance >= 0
                                          ? Colors.green
                                          : Colors.red,
                                    ),
                                    maxLines: 1,
                                  ),
                                ],
                              ),
                            );
                          })
                          .toList();
                    },
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _showAddAccountDialog,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Добавить новый счет'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary.withOpacity(0.1),
                    foregroundColor: colorScheme.primary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: colorScheme.primary.withOpacity(0.3),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Checkbox(
                      value: _isRecurring,
                      onChanged: (value) {
                        if (value == true) {
                          _showFrequencyDialog();
                        } else {
                          setState(() {
                            _isRecurring = false;
                          });
                        }
                      },
                      activeColor: color,
                    ),
                    const Text(
                      'Регулярный платеж',
                      style: TextStyle(fontSize: 16),
                    ),
                    if (_isRecurring) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Каждые $_recurringInterval ${_getFrequencyText()}',
                          style: TextStyle(fontSize: 12, color: color),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'Комментарий',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _commentController,
                  onChanged: (value) => _comment = value,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Дополнительная информация...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
        Container(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottomPadding),
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
                onPressed: _saveTransaction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Добавить',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTransferDetails(double bottomPadding) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 80,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      InkWell(
                        onTap: () {
                          setState(() {
                            _selectedFromAccount = null;
                            _selectedToAccount = null;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              Icon(Icons.arrow_downward, color: Colors.red),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Списать с: ${_selectedFromAccount?.name ?? 'не выбран'}',
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ),
                              const Icon(
                                Icons.edit,
                                size: 18,
                                color: Colors.blue,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () {
                          setState(() {
                            _selectedFromAccount = null;
                            _selectedToAccount = null;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              Icon(Icons.arrow_upward, color: Colors.green),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Зачислить на: ${_selectedToAccount?.name ?? 'не выбран'}',
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ),
                              const Icon(
                                Icons.edit,
                                size: 18,
                                color: Colors.blue,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ✅ ПРЕДУПРЕЖДЕНИЕ ДЛЯ КРЕДИТА
                if (_selectedToAccount?.type == AccountType.loan)
                  Container(
                    margin: const EdgeInsets.only(top: 16),
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
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Внимание! Платёж по кредиту нельзя будет отредактировать или удалить. Пожалуйста, проверьте сумму перед подтверждением.',
                            style: TextStyle(
                              color: Colors.orange.shade900,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 20),

                const Text(
                  'Сумма',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: colorScheme.primary.withOpacity(0.3),
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      String cleaned = value.replaceAll(RegExp(r'[^\d.]'), '');
                      if (cleaned != _amount) {
                        _amount = cleaned;
                        _amountController.value = TextEditingValue(
                          text: _getDisplayAmount(),
                          selection: TextSelection.fromPosition(
                            TextPosition(offset: _getDisplayAmount().length),
                          ),
                        );
                      }
                    },
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      hintText: '0',
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: colorScheme.primary.withOpacity(0.2),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          _buildCalcButton('1', colorScheme),
                          _buildCalcButton('2', colorScheme),
                          _buildCalcButton('3', colorScheme),
                          _buildCalcButton('⌫', colorScheme, isSpecial: true),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildCalcButton('4', colorScheme),
                          _buildCalcButton('5', colorScheme),
                          _buildCalcButton('6', colorScheme),
                          _buildCalcButton('+', colorScheme, isSpecial: true),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildCalcButton('7', colorScheme),
                          _buildCalcButton('8', colorScheme),
                          _buildCalcButton('9', colorScheme),
                          _buildCalcButton('-', colorScheme, isSpecial: true),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildCalcButton(',', colorScheme, isSpecial: true),
                          _buildCalcButton('0', colorScheme),
                          _buildCalcButton('C', colorScheme, isSpecial: true),
                          _buildCalcButton('=', colorScheme, isSpecial: true),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          showDialog(
                            context: context,
                            builder: (context) => CustomDatePicker(
                              initialDate: _selectedDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                              onDateSelected: (date) {
                                setState(() => _selectedDate = date);
                              },
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.calendar_today,
                                color: colorScheme.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                DateFormat('dd.MM.yyyy').format(_selectedDate),
                                style: const TextStyle(fontSize: 16),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                Row(
                  children: [
                    Checkbox(
                      value: _isRecurring,
                      onChanged: (value) {
                        if (value == true) {
                          _showFrequencyDialog();
                        } else {
                          setState(() {
                            _isRecurring = false;
                          });
                        }
                      },
                      activeColor: Colors.blue,
                    ),
                    const Text(
                      'Регулярный платеж',
                      style: TextStyle(fontSize: 16),
                    ),
                    if (_isRecurring) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Каждые $_recurringInterval ${_getFrequencyText()}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.blue,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 20),

                const Text(
                  'Комментарий',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _commentController,
                  onChanged: (value) => _comment = value,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Дополнительная информация...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),

                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
        Container(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottomPadding),
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
                onPressed: _saveTransaction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Перевести',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _getDisplayAmount() {
    if (_amount.isEmpty) return '0';
    try {
      String displayAmount = _amount.replaceAll('.', ',');
      if (!displayAmount.contains(',')) {
        final buffer = StringBuffer();
        for (int i = 0; i < displayAmount.length; i++) {
          if (i > 0 && (displayAmount.length - i) % 3 == 0) {
            buffer.write(' ');
          }
          buffer.write(displayAmount[i]);
        }
        return buffer.toString();
      }
      return displayAmount;
    } catch (e) {
      return _amount.replaceAll('.', ',');
    }
  }

  void _addDigit(String digit) {
    setState(() {
      String actualDigit = digit == ',' ? '.' : digit;

      if (actualDigit == '⌫') {
        if (_amount.isNotEmpty)
          _amount = _amount.substring(0, _amount.length - 1);
      } else if (actualDigit == 'C') {
        _amount = '';
        _operation = '';
        _firstNumber = 0;
        _waitingForSecondNumber = false;
      } else if (actualDigit == '+' || actualDigit == '-') {
        if (_amount.isNotEmpty) {
          _firstNumber = double.tryParse(_amount) ?? 0;
          _operation = actualDigit;
          _amount = '';
          _waitingForSecondNumber = true;
        }
      } else if (actualDigit == '=') {
        if (_operation.isNotEmpty && _amount.isNotEmpty) {
          double secondNumber = double.tryParse(_amount) ?? 0;
          double result = 0;
          if (_operation == '+')
            result = _firstNumber + secondNumber;
          else if (_operation == '-')
            result = _firstNumber - secondNumber;
          _amount = result.toString();
          _operation = '';
          _waitingForSecondNumber = false;
        }
      } else if (actualDigit == '.' && !_amount.contains('.')) {
        if (_amount.isEmpty)
          _amount = '0.';
        else
          _amount += '.';
      } else if (actualDigit != '.') {
        _amount += actualDigit;
      }

      _amountController.text = _getDisplayAmount();
    });
  }

  Widget _buildCalcButton(
    String text,
    ColorScheme colorScheme, {
    bool isSpecial = false,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Material(
          color: isSpecial
              ? colorScheme.primary.withOpacity(0.15)
              : colorScheme.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: () => _addDigit(text),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 20,
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

  bool _isSaving = false;
  Future<void> _recalculateLoanAfterPayment(
    Account loan,
    double paymentAmount,
  ) async {
    print('🔄 Перерасчет кредита ${loan.name}');
    print('   - Платеж: $paymentAmount');
    print('   - Текущий остаток: ${loan.balance}');

    // 1. Вычитаем платеж из остатка долга (остаток хранится как отрицательное число)
    double currentDebt = loan.balance.abs();
    double newRemainingDebt = currentDebt - paymentAmount;
    if (newRemainingDebt < 0) newRemainingDebt = 0;

    // 2. Обновляем остаток основного долга
    loan.remainingPrincipal = newRemainingDebt;
    loan.balance = -newRemainingDebt; // отрицательный для кредита

    // 3. Пересчитываем оставшийся срок
    final monthlyPayment = loan.monthlyPayment ?? 0;
    if (monthlyPayment > 0) {
      final remainingMonths = (newRemainingDebt / monthlyPayment).ceil();
      loan.remainingMonths = remainingMonths;
      print(
        '   - Новый остаток: ${loan.balance}, оставшихся месяцев: $remainingMonths',
      );
    }

    // 4. Сохраняем обновленный кредит
    final allAccounts = await CategoryService.loadAccounts();
    final index = allAccounts.indexWhere((a) => a.id == loan.id);
    if (index != -1) {
      allAccounts[index] = loan;
      await CategoryService.saveAccounts(allAccounts);
      print('✅ Кредит сохранен');
    }
  }

  Future<void> _recalculateDebtAfterPayment(
    Account debt,
    double paymentAmount,
  ) async {
    print('🔄 Перерасчет долга ${debt.name}');

    double currentDebt = debt.balance.abs();
    double newRemainingDebt = currentDebt - paymentAmount;
    if (newRemainingDebt < 0) newRemainingDebt = 0;

    debt.remainingPrincipal = newRemainingDebt;
    debt.balance = -newRemainingDebt;

    if (debt.monthlyPayment != null && debt.monthlyPayment! > 0) {
      final remainingMonths = (newRemainingDebt / debt.monthlyPayment!).ceil();
      debt.remainingMonths = remainingMonths;
    }

    final allAccounts = await CategoryService.loadAccounts();
    final index = allAccounts.indexWhere((a) => a.id == debt.id);
    if (index != -1) {
      allAccounts[index] = debt;
      await CategoryService.saveAccounts(allAccounts);
    }
  }

  void _saveTransaction() async {
    print('🚀 _saveTransaction НАЧАЛ');
    if (_isSaving) {
      print('⚠️ _saveTransaction уже выполняется, пропускаем');
      return;
    }

    _isSaving = true;
    print('🔍 _saveTransaction начат');

    try {
      if (_amount.isEmpty) {
        print('❌ Ошибка: сумма пустая');
        SnackbarUtils.showError(context, 'Введите сумму');
        _isSaving = false;
        return;
      }

      String amountForParse = _amount.replaceAll(',', '.');
      double amount = double.tryParse(amountForParse) ?? 0;

      // ========== ОБРАБОТКА ДОЛГОВ ==========

      // 1. ДОЛГ МНЕ (debtOwed) → на обычный счет
      if (_selectedFromAccount?.type == AccountType.debtOwed &&
          _selectedToAccount != null &&
          _selectedToAccount?.type != AccountType.debtOwed &&
          _selectedToAccount?.type != AccountType.debtToPay) {
        print('🔹 Ветка: ДОЛГ МНЕ');

        final transaction = Transaction(
          id: 'transfer_${DateTime.now().millisecondsSinceEpoch}',
          userId: 'default_user',
          title: '${_selectedFromAccount!.name} → ${_selectedToAccount!.name}',
          amount: amount,
          date: _selectedDate,
          type: TransactionType.income,
          category: 'Долг мне',
          subCategory: _selectedToAccount!.name,
          accountId: _selectedToAccount!.id,
          comment: _comment,
          isRecurring: false,
          fromAccountId: _selectedFromAccount!.id,
          toAccountId: _selectedToAccount!.id,
        );

        await TransactionService.addTransaction(transaction);
        widget.onTransactionAdded(transaction);

        if (mounted) {
          print('🔹 Закрываю окно (ДОЛГ МНЕ)');
          Navigator.pop(context);
          SnackbarUtils.showSuccess(context, 'Средства получены от должника');
        }
        _isSaving = false;
        return;
      }

      // 2. Обычный счет → ДОЛЖЕН Я
      if (_selectedFromAccount != null &&
          _selectedFromAccount?.type != AccountType.debtOwed &&
          _selectedFromAccount?.type != AccountType.debtToPay &&
          _selectedToAccount?.type == AccountType.debtToPay) {
        print('🔹 Ветка: ДОЛЖЕН Я');

        final transaction = Transaction(
          id: 'transfer_${DateTime.now().millisecondsSinceEpoch}',
          userId: 'default_user',
          title: '${_selectedFromAccount!.name} → ${_selectedToAccount!.name}',
          amount: amount,
          date: _selectedDate,
          type: TransactionType.expense,
          category: 'Должен я',
          subCategory: _selectedFromAccount!.name,
          accountId: _selectedFromAccount!.id,
          comment: _comment,
          isRecurring: false,
          fromAccountId: _selectedFromAccount!.id,
          toAccountId: _selectedToAccount!.id,
        );

        await TransactionService.addTransaction(transaction);
        widget.onTransactionAdded(transaction);

        if (mounted) {
          print('🔹 Закрываю окно (ДОЛЖЕН Я)');
          Navigator.pop(context);
          SnackbarUtils.showSuccess(context, 'Платеж по долгу отправлен');
        }
        _isSaving = false;
        return;
      }

      // ========== ОБЫЧНЫЕ ПЕРЕВОДЫ ==========
      if (_currentTab == TransactionTab.transfer) {
        print('🔹 Ветка: ПЕРЕВОД');

        if (_selectedFromAccount == null || _selectedToAccount == null) {
          SnackbarUtils.showError(context, 'Выберите счета для перевода');
          _isSaving = false;
          return;
        }

        if (_selectedFromAccount!.id == _selectedToAccount!.id) {
          SnackbarUtils.showError(context, 'Счета должны быть разными');
          _isSaving = false;
          return;
        }

        if (_selectedFromAccount!.balance < amount) {
          SnackbarUtils.showError(
            context,
            'Недостаточно средств на счете ${_selectedFromAccount!.name}',
          );
          _isSaving = false;
          return;
        }

        // ✅ ЕСЛИ ЭТО ПЛАТЕЖ ПО КРЕДИТУ (перевод на кредитный счет)
        if (_selectedToAccount?.type == AccountType.loan) {
          await _recalculateLoanAfterPayment(_selectedToAccount!, amount);
        }

        // ✅ ЕСЛИ ЭТО ВОЗВРАТ ДОЛГА МНЕ (перевод с debtOwed на обычный счет)
        if (_selectedFromAccount?.type == AccountType.debtOwed) {
          await _recalculateDebtAfterPayment(_selectedFromAccount!, amount);
        }

        // ✅ ЕСЛИ ЭТО ПЛАТЕЖ ПО ДОЛГУ (перевод с обычного счета на debtToPay)
        if (_selectedToAccount?.type == AccountType.debtToPay) {
          await _recalculateDebtAfterPayment(_selectedToAccount!, amount);
        }

        final transferTransaction = Transaction(
          id: 'transfer_${DateTime.now().millisecondsSinceEpoch}',
          userId: 'default_user',
          title: '${_selectedFromAccount!.name} → ${_selectedToAccount!.name}',
          amount: amount,
          date: _selectedDate,
          type: TransactionType.expense,
          category: 'Перевод',
          subCategory: null,
          comment: _comment,
          isRecurring: _isRecurring,
          recurringInterval: _isRecurring ? _recurringInterval : null,
          recurringFrequency: _isRecurring ? _recurringFrequency : null,
          fromAccountId: _selectedFromAccount!.id,
          toAccountId: _selectedToAccount!.id,
        );

        await TransactionService.addTransaction(transferTransaction);
        widget.onTransactionAdded(transferTransaction);

        if (mounted) {
          print('🔹 Закрываю окно (ПЕРЕВОД)');
          Navigator.pop(context);
          SnackbarUtils.showSuccess(context, 'Перевод выполнен');
        }
        _isSaving = false;
        return;
      }

      // ========== ОБЫЧНЫЕ ДОХОДЫ/РАСХОДЫ ==========
      print('🔹 Ветка: ОБЫЧНЫЙ ДОХОД/РАСХОД');

      TransactionType type = _currentTab == TransactionTab.expense
          ? TransactionType.expense
          : TransactionType.income;

      print('🔹 Тип транзакции: $type');

      final newTransaction = Transaction(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: 'default_user',
        title: _comment.isEmpty
            ? (_selectedCategory?.name ?? 'Без названия')
            : _comment,
        amount: amount,
        date: _selectedDate,
        type: type,
        category: _selectedCategory?.name ?? 'Другое',
        subCategory: _selectedSubCategory?.name,
        accountId: _selectedAccount?.id,
        comment: _comment,
        isRecurring: _isRecurring,
        recurringInterval: _isRecurring ? _recurringInterval : null,
        recurringFrequency: _isRecurring ? _recurringFrequency : null,
      );

      print('🔹 Транзакция создана, id: ${newTransaction.id}');

      await TransactionService.addTransaction(newTransaction);
      print('🔹 Транзакция добавлена в сервис');

      // ✅ ЗАКРЫВАЕМ ОКНО СРАЗУ (до вызова колбэка)
      if (mounted) {
        print('🔹 mounted = true, ВЫЗЫВАЮ Navigator.pop');
        Navigator.pop(context);
        print('🔹 Navigator.pop выполнен');
        SnackbarUtils.showSuccess(context, 'Транзакция добавлена');
      }

      // ✅ ВЫЗЫВАЕМ КОЛБЭК ПОСЛЕ ЗАКРЫТИЯ
      widget.onTransactionAdded(newTransaction);
      print('🔹 widget.onTransactionAdded выполнен');

      // ✅ ОБНОВЛЯЕМ ДАННЫЕ (в фоне)
      await _loadAccountsOnly();
      _isSaving = false;
    } catch (e) {
      print('❌ Ошибка: $e');
      _isSaving = false;
    }
  }

  Future<void> _checkBudgetAndNotify(Transaction transaction) async {
    // Проверяем только расходы
    if (transaction.type != TransactionType.expense) return;

    // Загружаем бюджет
    final prefs = await SharedPreferences.getInstance();
    final String? budgetsJson = prefs.getString('budgets');
    if (budgetsJson == null) return;

    final Map<String, dynamic> budgets = jsonDecode(budgetsJson);

    // Загружаем категории, чтобы найти ID категории по названию
    final categories = await CategoryService.loadCategories();

    // Ищем категорию по названию
    final category = categories.firstWhere(
      (c) => c.name == transaction.category,
      orElse: () => null as Category,
    );

    // Ключ бюджета для этой категории
    final budgetKey = 'cat_${category.id}';
    final categoryBudget = budgets[budgetKey] ?? 0.0;

    if (categoryBudget == 0) return;

    // Считаем сумму расходов за месяц по этой категории
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0);

    final allTransactions = await TransactionService.loadTransactions();
    final monthExpenses = allTransactions
        .where(
          (t) =>
              t.type == TransactionType.expense &&
              t.category == transaction.category &&
              t.date.isAfter(startOfMonth.subtract(const Duration(days: 1))) &&
              t.date.isBefore(endOfMonth.add(const Duration(days: 1))),
        )
        .toList();

    final totalSpent = monthExpenses.fold(0.0, (sum, t) => sum + t.amount);

    // Проверяем, превышен ли бюджет
    if (totalSpent > categoryBudget) {
      // Сохраняем уведомление
      final notificationProvider = Provider.of<NotificationProvider>(
        context,
        listen: false,
      );

      final notification = BudgetNotification(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: 'Превышение бюджета!',
        message:
            'Бюджет категории "${transaction.category}" (${_formatAmount(categoryBudget)}) превышен. Потрачено: ${_formatAmount(totalSpent)}',
        date: DateTime.now(),
        isRead: false,
        categoryId: transaction.category,
        budgetAmount: categoryBudget,
        spentAmount: totalSpent,
      );

      await notificationProvider.addNotification(notification);

      // Показываем красивое всплывающее окно по центру
      if (mounted) {
        final colorScheme = Theme.of(context).colorScheme;

        final dialog = showDialog(
          context: context,
          barrierDismissible: true,
          builder: (BuildContext dialogContext) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colorScheme.primary,
                      colorScheme.primary.withOpacity(0.85),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.white,
                        size: 42,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '⚠️ Превышение бюджета!',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${transaction.category}\n${_formatAmount(totalSpent)} из ${_formatAmount(categoryBudget)}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.9),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Превышение: ${_formatAmount(totalSpent - categoryBudget)}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      }
    }
  }

  Widget _buildTransferToGoal() {
    final colorScheme = Theme.of(context).colorScheme;

    return FutureBuilder<List<Goal>>(
      future: GoalService.loadGoals(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.flag, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('Нет целей для пополнения'),
                SizedBox(height: 8),
                Text('Создайте цель в разделе "Планирование"'),
              ],
            ),
          );
        }

        final goals = snapshot.data!;
        Goal? selectedGoal;

        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: DropdownButtonFormField<Goal>(
                    decoration: InputDecoration(
                      labelText: 'Выберите цель',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: goals.map((goal) {
                      return DropdownMenuItem<Goal>(
                        value: goal,
                        child: Row(
                          children: [
                            Icon(goal.icon, color: goal.color, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(goal.title),
                                  Text(
                                    'Накоплено: ${goal.currentAmount.toStringAsFixed(2)} ₽ / ${goal.targetAmount.toStringAsFixed(2)} ₽',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setStateDialog(() {
                        selectedGoal = value;
                        _selectedGoalForTransfer = value;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 20),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildTransferToGoalDetails(Goal goal) {
    final colorScheme = Theme.of(context).colorScheme;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 80,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: goal.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: goal.color.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(goal.icon, color: goal.color, size: 28),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              goal.title,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: goal.color,
                              ),
                            ),
                            Text(
                              'Цель: ${_formatAmount(goal.targetAmount)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            Text(
                              'Накоплено: ${_formatAmount(goal.currentAmount)}',
                              style: TextStyle(fontSize: 12, color: goal.color),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Сумма',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: colorScheme.primary.withOpacity(0.3),
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: _amountController,
                    readOnly: true,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      hintText: '0',
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: colorScheme.primary.withOpacity(0.2),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          _buildCalcButton('1', colorScheme),
                          _buildCalcButton('2', colorScheme),
                          _buildCalcButton('3', colorScheme),
                          _buildCalcButton('⌫', colorScheme, isSpecial: true),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildCalcButton('4', colorScheme),
                          _buildCalcButton('5', colorScheme),
                          _buildCalcButton('6', colorScheme),
                          _buildCalcButton('+', colorScheme, isSpecial: true),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildCalcButton('7', colorScheme),
                          _buildCalcButton('8', colorScheme),
                          _buildCalcButton('9', colorScheme),
                          _buildCalcButton('-', colorScheme, isSpecial: true),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildCalcButton(',', colorScheme, isSpecial: true),
                          _buildCalcButton('0', colorScheme),
                          _buildCalcButton('C', colorScheme, isSpecial: true),
                          _buildCalcButton('=', colorScheme, isSpecial: true),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Счет списания',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<Account>(
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
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              account.icon,
                              color: account.color,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              account.name,
                              style: const TextStyle(fontSize: 15),
                            ),
                          ),
                          Text(
                            '${account.balance.toStringAsFixed(2)} ${account.currency}',
                            style: TextStyle(
                              fontSize: 12,
                              color: account.balance >= 0
                                  ? Colors.green
                                  : Colors.red,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) =>
                      setState(() => _selectedAccount = value),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Комментарий',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _commentController,
                  onChanged: (value) => _comment = value,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Дополнительная информация...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
        Container(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottomPadding),
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
                onPressed: () => _saveTransferToGoal(goal),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Перевести на цель',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _saveTransferToGoal(Goal goal) async {
    if (_amount.isEmpty) {
      SnackbarUtils.showError(context, 'Введите сумму');
      return;
    }
    final goal = _selectedGoalForTransfer;
    if (goal == null) {
      SnackbarUtils.showError(context, 'Выберите цель');
      return;
    }
    String amountForParse = _amount.replaceAll(',', '.');
    double amount = double.tryParse(amountForParse) ?? 0;

    if (amount <= 0) {
      SnackbarUtils.showError(context, 'Введите корректную сумму');
      return;
    }

    if (_selectedAccount == null) {
      SnackbarUtils.showError(context, 'Выберите счет списания');
      return;
    }

    if (_selectedAccount!.balance < amount) {
      SnackbarUtils.showError(
        context,
        'Недостаточно средств на счете ${_selectedFromAccount!.name}',
      );
      return;
    }

    // Обновляем баланс счета
    final accounts = await CategoryService.loadAccounts();
    final accountIndex = accounts.indexWhere(
      (a) => a.id == _selectedAccount!.id,
    );
    if (accountIndex != -1) {
      accounts[accountIndex].balance -= amount;
      await CategoryService.saveAccounts(accounts);
    }

    // Обновляем цель
    goal.currentAmount += amount;
    await GoalService.saveGoals([goal]);

    // Создаём транзакцию
    final transaction = Transaction(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: 'default_user',
      title: 'Пополнение цели: ${goal.title}',
      amount: amount,
      date: _selectedDate,
      type: TransactionType.expense,
      category: 'Пополнение цели',
      subCategory: goal.title,
      accountId: _selectedAccount!.id,
      comment: _comment,
      isRecurring: false,
    );

    await TransactionService.addTransaction(transaction);
    widget.onTransactionAdded(transaction);

    if (mounted) {
      Navigator.pop(context);
      SnackbarUtils.showSuccess(
        context,
        'Цель пополнена на ${_formatAmount(amount)}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final mediaQuery = MediaQuery.of(context);
    final bottomPadding = mediaQuery.padding.bottom;

    return Container(
      height: mediaQuery.size.height * 0.9,
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
            padding: const EdgeInsets.all(12),
            child: Text(
              _shouldShowCategorySelection()
                  ? (_currentTab == TransactionTab.transfer
                        ? 'Выберите счета'
                        : 'Выберите категорию')
                  : 'Детали транзакции',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
          ),
          TabBar(
            controller: _tabController,
            labelColor: colorScheme.primary,
            unselectedLabelColor: Colors.grey,
            indicatorColor: colorScheme.primary,
            tabs: const [
              Tab(text: '💰 Расход'),
              Tab(text: '📈 Доход'),
              Tab(text: '🔄 Перевод'),
            ],
          ),
          Expanded(
            child: _shouldShowCategorySelection()
                ? (_currentTab == TransactionTab.transfer
                      ? _buildTransferAccounts()
                      : _buildCategorySelection())
                : (_currentTab == TransactionTab.transfer
                      ? _buildTransferDetails(bottomPadding)
                      : _buildTransactionDetails(bottomPadding)),
          ),
          SizedBox(height: bottomPadding),
        ],
      ),
    );
  }

  bool _shouldShowCategorySelection() {
    if (_currentTab == TransactionTab.transfer) {
      return _selectedFromAccount == null || _selectedToAccount == null;
    }
    return _selectedCategory == null;
  }
}

// ============================================================
// НОВЫЙ КЛАСС ВНЕ _AddTransactionSheetState
// ============================================================
class AddAccountDialogContent extends StatefulWidget {
  const AddAccountDialogContent({super.key});

  @override
  State<AddAccountDialogContent> createState() =>
      _AddAccountDialogContentState();
}

class _AddAccountDialogContentState extends State<AddAccountDialogContent> {
  late final TextEditingController nameController;
  late final TextEditingController balanceController;

  AccountType selectedType = AccountType.cash;
  IconData selectedIcon = Icons.money;
  Color selectedColor = Colors.green;
  bool showOnHomeScreen = true;
  bool isMainAccount = false;

  bool _isColorInitialized = false;

  final List<Color> _allColors = [
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
    Colors.lightGreenAccent,
    Colors.tealAccent,
    Colors.cyanAccent,
    Colors.indigoAccent,
    Colors.deepPurpleAccent,
  ];

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController();
    balanceController = TextEditingController();
  }

  @override
  void dispose() {
    nameController.dispose();
    balanceController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isColorInitialized) {
      _isColorInitialized = true;
      _initColor();
    }
  }

  Future<void> _initColor() async {
    final defaultColor = await _getAvailableColorForAccountType(selectedType);
    if (mounted && selectedColor != defaultColor) {
      setState(() {
        selectedColor = defaultColor;
      });
      print(
        '🎨 Цвет инициализирован: $defaultColor для типа ${selectedType.displayName}',
      );
    }
  }

  Future<Color> _getAvailableColorForAccountType(AccountType type) async {
    final existingAccounts = await CategoryService.loadAccounts();

    final Map<AccountType, List<Color>> preferredColors = {
      AccountType.cash: [
        Colors.green,
        Colors.lightGreen,
        Colors.teal,
        Colors.lime,
        Colors.greenAccent,
      ],
      AccountType.debitCard: [
        Colors.blue,
        Colors.lightBlue,
        Colors.cyan,
        Colors.indigo,
        Colors.blueAccent,
        Colors.cyanAccent,
      ],
      AccountType.creditCard: [
        Colors.red,
        Colors.deepOrange,
        Colors.orange,
        Colors.redAccent,
        Colors.deepOrangeAccent,
      ],
      AccountType.deposit: [
        Colors.purple,
        Colors.deepPurple,
        Colors.purpleAccent,
        Colors.deepPurpleAccent,
      ],
      AccountType.savings: [
        Colors.teal,
        Colors.cyan,
        Colors.tealAccent,
        Colors.cyanAccent,
      ],
      AccountType.loan: [
        Colors.deepOrange,
        Colors.brown,
        Colors.orange,
        Colors.deepOrangeAccent,
      ],
      AccountType.investment: [
        Colors.lightGreen,
        Colors.green,
        Colors.lightGreenAccent,
        Colors.teal,
      ],
      AccountType.debtOwed: [
        Colors.amber,
        Colors.yellow,
        Colors.orangeAccent,
        Colors.amberAccent,
      ],
      AccountType.debtToPay: [
        Colors.brown,
        Colors.deepOrange,
        Colors.orange,
        Colors.red,
      ],
      AccountType.other: [
        Colors.grey,
        Colors.blueGrey,
        Colors.grey.shade600,
        Colors.grey.shade500,
      ],
    };

    final Set<Color> usedColors = existingAccounts.map((a) => a.color).toSet();
    final preferred = preferredColors[type] ?? _allColors;

    for (var color in preferred) {
      if (!usedColors.contains(color)) {
        return color;
      }
    }

    for (var color in _allColors) {
      if (!usedColors.contains(color)) {
        return color;
      }
    }

    return preferred.first;
  }

  Future<void> _saveAccount() async {
    if (nameController.text.isEmpty) {
      SnackbarUtils.showError(context, 'Введите название счета');
      return;
    }

    double balance = double.tryParse(balanceController.text) ?? 0;

    final newAccount = Account(
      id: 'acc_${DateTime.now().millisecondsSinceEpoch}',
      name: nameController.text,
      balance: balance,
      initialBalance: balance,
      createdDate: DateTime.now(),
      currency: '₽',
      type: selectedType,
      icon: selectedIcon,
      color: selectedColor,
      showOnHomeScreen: showOnHomeScreen,
      isMain: isMainAccount,
    );

    List<Account> accounts = await CategoryService.loadAccounts();
    accounts.add(newAccount);
    await CategoryService.saveAccounts(accounts);

    CategoryService.notifyAccountsListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_${newAccount.id}', showOnHomeScreen);
    await prefs.setBool('main_${newAccount.id}', isMainAccount);

    if (mounted) {
      await Future.delayed(const Duration(milliseconds: 100));
      Navigator.pop(context);
      SnackbarUtils.showSuccess(context, 'Счет добавлен');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

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
              'Новый счет',
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
                  const Text(
                    'Название',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      hintText: 'Название счета',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Тип счета',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<AccountType>(
                    value: selectedType,
                    items: AccountType.values.map((type) {
                      return DropdownMenuItem(
                        value: type,
                        child: Text(type.displayName),
                      );
                    }).toList(),
                    onChanged: (value) async {
                      setState(() {
                        selectedType = value!;
                        selectedIcon = value.defaultIcon;
                      });
                      final newColor = await _getAvailableColorForAccountType(
                        selectedType,
                      );
                      if (mounted && selectedColor != newColor) {
                        setState(() {
                          selectedColor = newColor;
                        });
                      }
                    },
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Начальный баланс',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: balanceController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: '0',
                      prefixIcon: const Icon(Icons.attach_money),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Цвет',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 50,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: availableColors.length,
                      itemBuilder: (context, index) {
                        final color = availableColors[index];
                        return GestureDetector(
                          onTap: () => setState(() => selectedColor = color),
                          child: Container(
                            width: 40,
                            height: 40,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: selectedColor == color
                                  ? Border.all(color: Colors.white, width: 3)
                                  : null,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Switch(
                        value: showOnHomeScreen,
                        onChanged: (value) =>
                            setState(() => showOnHomeScreen = value),
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
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Switch(
                        value: isMainAccount,
                        onChanged: (value) =>
                            setState(() => isMainAccount = value),
                        activeColor: colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Основной счет (баланс в шапке)',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
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
                  onPressed: _saveAccount,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Создать счет',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
